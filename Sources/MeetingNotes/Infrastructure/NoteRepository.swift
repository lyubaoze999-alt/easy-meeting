import Foundation
import GRDB

/// 纪要存储过程中可能出现的错误（需求 11.2、11.4）。
enum NoteRepositoryError: Error, Equatable {
    /// 无法定位或创建应用沙盒目录。
    case sandboxUnavailable
    /// 归档某个文件失败（音频 / 转写 / 正文）。
    case archiveFailed(reason: String)
    /// note.json 已记录但磁盘上缺失或无法解码，纪要正文不可读。
    case noteBodyUnreadable(id: UUID)
}

/// 纪要仓储抽象：元数据入 SQLite，音频 / 原始转写 / 正文 JSON 按 `note.id` 归档到沙盒。
///
/// 对应设计「存储策略」与需求 11.2（按日期分组浏览）、11.4（标题或正文关键词搜索）。
/// 注意：本层只持久化 `MeetingNote`，绝不接触 `apiKey`（密钥仅经 KeychainStore 入 Keychain，
/// 守住 Property 5「密钥不外泄」）。
protocol NoteStoring {
    /// 持久化纪要：归档音频 / 转写 / 正文文件并写入元数据。返回归档后路径已更新的纪要。
    /// - Parameters:
    ///   - note: 待保存的纪要（其 `audioPath` / `transcriptPath` 可指向归档前的临时文件）。
    ///   - audioSource: 录音产出的 WAV 源文件；为 nil 时回退到 `note.audioPath`。
    ///   - transcriptText: 原始转写全文；为 nil 时回退到 `note.transcriptPath` 指向的文件。
    @discardableResult
    func save(_ note: MeetingNote, audioSource: URL?, transcriptText: String?) throws -> MeetingNote

    /// 读取单条纪要的完整正文（从归档的 note.json 还原）；不存在返回 nil。
    func load(id: UUID) throws -> MeetingNote?

    /// 按录音开始时间降序返回全部纪要（今天/昨天/本周等日期分组由上层计算，需求 11.2）。
    func fetchAllOrderedByDate() throws -> [MeetingNote]

    /// 按关键词搜索：标题或正文命中即返回，结果按时间降序（需求 11.4）。
    func search(keyword: String) throws -> [MeetingNote]

    /// 删除一条纪要及其归档目录。
    func delete(id: UUID) throws
}

/// 基于 GRDB（SQLite）+ FileManager 的纪要仓储实现。
///
/// - 元数据（标题、开始时间、时长、模板、各文件路径、用于搜索的去标准化正文）入 `meeting_note` 表。
/// - 音频 WAV、原始转写文本、纪要正文 JSON 按 `note.id` 归档到沙盒 `Notes/<id>/` 目录下。
/// - 关键词搜索命中标题或正文（需求 11.4）；列表按开始时间降序返回，日期分组在上层计算（需求 11.2）。
final class NoteRepository: NoteStoring {
    /// 沙盒根目录（默认 Application Support/<bundle>/），其下含 `notes.sqlite` 与 `Notes/<id>/`。
    private let baseDirectory: URL
    /// 归档文件所在目录（`baseDirectory/Notes`）。
    private let notesDirectory: URL
    /// SQLite 连接队列。
    private let dbQueue: DatabaseQueue
    private let fileManager: FileManager

    /// - Parameters:
    ///   - baseDirectory: 自定义沙盒根目录，nil 时取 Application Support 下的应用子目录（便于测试注入临时目录）。
    ///   - fileManager: 文件管理器，默认 `.default`。
    init(baseDirectory: URL? = nil, fileManager: FileManager = .default) throws {
        self.fileManager = fileManager

        let resolvedBase: URL
        if let baseDirectory {
            resolvedBase = baseDirectory
        } else {
            guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw NoteRepositoryError.sandboxUnavailable
            }
            resolvedBase = appSupport.appendingPathComponent("com.meetingnotes", isDirectory: true)
        }
        self.baseDirectory = resolvedBase
        self.notesDirectory = resolvedBase.appendingPathComponent("Notes", isDirectory: true)

        do {
            try fileManager.createDirectory(at: resolvedBase, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: notesDirectory, withIntermediateDirectories: true)
        } catch {
            throw NoteRepositoryError.sandboxUnavailable
        }

        let dbURL = resolvedBase.appendingPathComponent("notes.sqlite")
        self.dbQueue = try DatabaseQueue(path: dbURL.path)
        try Self.createSchema(dbQueue)
    }

    /// 建表（幂等）：纪要元数据表，含用于关键词搜索的去标准化 `search_text` 列。
    private static func createSchema(_ dbQueue: DatabaseQueue) throws {
        try dbQueue.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS meeting_note (
                    id TEXT PRIMARY KEY NOT NULL,
                    title TEXT NOT NULL,
                    started_at DOUBLE NOT NULL,
                    duration DOUBLE NOT NULL,
                    template_id TEXT NOT NULL,
                    audio_path TEXT NOT NULL,
                    transcript_path TEXT NOT NULL,
                    body_path TEXT NOT NULL,
                    search_text TEXT NOT NULL
                )
                """)
            // 按日期分组浏览依赖开始时间排序（需求 11.2）。
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_meeting_note_started_at ON meeting_note(started_at DESC)")
        }
    }
}

// MARK: - 写入

extension NoteRepository {
    @discardableResult
    func save(_ note: MeetingNote, audioSource: URL? = nil, transcriptText: String? = nil) throws -> MeetingNote {
        let noteDir = notesDirectory.appendingPathComponent(note.id.uuidString, isDirectory: true)
        do {
            try fileManager.createDirectory(at: noteDir, withIntermediateDirectories: true)
        } catch {
            throw NoteRepositoryError.archiveFailed(reason: "无法创建纪要目录: \(error.localizedDescription)")
        }

        // 1) 音频 WAV 归档到 <id>/audio.wav。
        let archivedAudioURL = noteDir.appendingPathComponent("audio.wav")
        let audioOrigin = audioSource ?? URL(fileURLWithPath: note.audioPath)
        if audioOrigin.path != archivedAudioURL.path {
            try archiveFile(from: audioOrigin, to: archivedAudioURL, label: "音频")
        }

        // 2) 原始转写文本归档到 <id>/transcript.txt。
        let archivedTranscriptURL = noteDir.appendingPathComponent("transcript.txt")
        if let transcriptText {
            do {
                try transcriptText.write(to: archivedTranscriptURL, atomically: true, encoding: .utf8)
            } catch {
                throw NoteRepositoryError.archiveFailed(reason: "无法写入转写文本: \(error.localizedDescription)")
            }
        } else {
            let transcriptOrigin = URL(fileURLWithPath: note.transcriptPath)
            if transcriptOrigin.path != archivedTranscriptURL.path {
                try archiveFile(from: transcriptOrigin, to: archivedTranscriptURL, label: "转写文本")
            }
        }

        // 路径更新为归档后位置，再把正文 JSON 落盘。
        var archived = note
        archived.audioPath = archivedAudioURL.path
        archived.transcriptPath = archivedTranscriptURL.path

        let archivedBodyURL = noteDir.appendingPathComponent("note.json")
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(archived)
            try data.write(to: archivedBodyURL, options: .atomic)
        } catch {
            throw NoteRepositoryError.archiveFailed(reason: "无法写入纪要正文 JSON: \(error.localizedDescription)")
        }

        // 元数据 + 去标准化搜索文本入库。
        let searchText = Self.makeSearchText(for: archived)
        try dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT OR REPLACE INTO meeting_note
                        (id, title, started_at, duration, template_id, audio_path, transcript_path, body_path, search_text)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    archived.id.uuidString,
                    archived.title,
                    archived.startedAt.timeIntervalSince1970,
                    archived.duration,
                    archived.templateId,
                    archived.audioPath,
                    archived.transcriptPath,
                    archivedBodyURL.path,
                    searchText
                ]
            )
        }
        return archived
    }

    /// 拷贝源文件到归档位置；目标已存在时先移除以保证覆盖写。
    private func archiveFile(from origin: URL, to destination: URL, label: String) throws {
        guard fileManager.fileExists(atPath: origin.path) else {
            throw NoteRepositoryError.archiveFailed(reason: "\(label)源文件不存在: \(origin.path)")
        }
        do {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: origin, to: destination)
        } catch {
            throw NoteRepositoryError.archiveFailed(reason: "\(label)归档失败: \(error.localizedDescription)")
        }
    }

    /// 汇总标题、分区正文、待办文本为单个可搜索字符串（支撑需求 11.4 的正文关键词命中）。
    private static func makeSearchText(for note: MeetingNote) -> String {
        var parts: [String] = [note.title]
        for section in note.sections {
            parts.append(section.heading)
            parts.append(section.content)
        }
        for todo in note.todos {
            parts.append(todo.text)
            if let owner = todo.owner { parts.append(owner) }
        }
        return parts.joined(separator: "\n")
    }
}

// MARK: - 读取与查询

extension NoteRepository {
    func load(id: UUID) throws -> MeetingNote? {
        let bodyURL = notesDirectory
            .appendingPathComponent(id.uuidString, isDirectory: true)
            .appendingPathComponent("note.json")

        // 先确认元数据存在，避免把"从未保存"与"正文损坏"混为一谈。
        let exists = try dbQueue.read { db in
            try Bool.fetchOne(db, sql: "SELECT 1 FROM meeting_note WHERE id = ?", arguments: [id.uuidString]) ?? false
        }
        guard exists else { return nil }

        guard fileManager.fileExists(atPath: bodyURL.path),
              let data = fileManager.contents(atPath: bodyURL.path) else {
            throw NoteRepositoryError.noteBodyUnreadable(id: id)
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(MeetingNote.self, from: data)
        } catch {
            throw NoteRepositoryError.noteBodyUnreadable(id: id)
        }
    }

    func fetchAllOrderedByDate() throws -> [MeetingNote] {
        let bodyPaths = try dbQueue.read { db in
            try String.fetchAll(
                db,
                sql: "SELECT body_path FROM meeting_note ORDER BY started_at DESC"
            )
        }
        return try decodeNotes(atBodyPaths: bodyPaths)
    }

    func search(keyword: String) throws -> [MeetingNote] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return try fetchAllOrderedByDate() }

        // 标题或正文（去标准化 search_text）命中即返回（需求 11.4），按时间降序。
        let pattern = "%\(escapeLike(trimmed))%"
        let bodyPaths = try dbQueue.read { db in
            try String.fetchAll(
                db,
                sql: """
                    SELECT body_path FROM meeting_note
                    WHERE title LIKE ? ESCAPE '\\' OR search_text LIKE ? ESCAPE '\\'
                    ORDER BY started_at DESC
                    """,
                arguments: [pattern, pattern]
            )
        }
        return try decodeNotes(atBodyPaths: bodyPaths)
    }

    func delete(id: UUID) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM meeting_note WHERE id = ?", arguments: [id.uuidString])
        }
        let noteDir = notesDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
        if fileManager.fileExists(atPath: noteDir.path) {
            try fileManager.removeItem(at: noteDir)
        }
    }

    /// 按归档正文路径批量解码为 `MeetingNote`，跳过磁盘上缺失的条目。
    private func decodeNotes(atBodyPaths paths: [String]) throws -> [MeetingNote] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var notes: [MeetingNote] = []
        for path in paths {
            guard let data = fileManager.contents(atPath: path) else { continue }
            let note = try decoder.decode(MeetingNote.self, from: data)
            notes.append(note)
        }
        return notes
    }

    /// 转义 LIKE 通配符，使用户输入中的 `%` / `_` / `\` 按字面匹配。
    private func escapeLike(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }
}
