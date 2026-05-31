import XCTest
@testable import MeetingNotes

/// NoteRepository 单元测试：覆盖元数据入库、文件归档、按日期排序、标题/正文关键词搜索（需求 11.2、11.4）。
final class NoteRepositoryTests: XCTestCase {
    private var tempDir: URL!
    private var repository: NoteRepository!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NoteRepoTests-\(UUID().uuidString)", isDirectory: true)
        repository = try NoteRepository(baseDirectory: tempDir)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try FileManager.default.removeItem(at: tempDir)
        }
        repository = nil
        tempDir = nil
    }

    // MARK: - Helpers

    /// 写一个临时 WAV 源文件并返回 URL。
    private func makeAudioSource(_ name: String = "src.wav") throws -> URL {
        let url = tempDir.appendingPathComponent(name)
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: url) // "RIFF" 头占位
        return url
    }

    private func makeNote(
        id: UUID = UUID(),
        title: String,
        startedAt: Date = Date(),
        sectionContent: String = "默认正文",
        todoText: String = "跟进事项"
    ) -> MeetingNote {
        MeetingNote(
            id: id,
            title: title,
            startedAt: startedAt,
            duration: 120,
            audioPath: "",
            transcriptPath: "",
            templateId: "default",
            sections: [NoteSection(heading: "摘要", content: sectionContent, isHighlighted: false)],
            todos: [TodoItem(text: todoText, done: false, owner: "张三", dueDate: nil)],
            highlights: [],
            visuals: nil
        )
    }

    // MARK: - 保存与归档

    func testSaveArchivesFilesAndUpdatesPaths() throws {
        let note = makeNote(title: "周会")
        let audio = try makeAudioSource()

        let saved = try repository.save(note, audioSource: audio, transcriptText: "完整转写文本")

        // 路径已更新到 <id> 目录下，三个归档文件均存在。
        XCTAssertTrue(saved.audioPath.hasSuffix("\(note.id.uuidString)/audio.wav"))
        XCTAssertTrue(saved.transcriptPath.hasSuffix("\(note.id.uuidString)/transcript.txt"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: saved.audioPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: saved.transcriptPath))

        let transcript = try String(contentsOfFile: saved.transcriptPath, encoding: .utf8)
        XCTAssertEqual(transcript, "完整转写文本")
    }

    func testLoadRoundTripsFullNote() throws {
        let id = UUID()
        let note = makeNote(id: id, title: "需求评审", sectionContent: "讨论了登录改造")
        let audio = try makeAudioSource()
        _ = try repository.save(note, audioSource: audio, transcriptText: "原始转写")

        let loaded = try repository.load(id: id)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.title, "需求评审")
        XCTAssertEqual(loaded?.sections.first?.content, "讨论了登录改造")
        XCTAssertEqual(loaded?.todos.first?.owner, "张三")
    }

    func testLoadReturnsNilForUnknownId() throws {
        XCTAssertNil(try repository.load(id: UUID()))
    }

    // MARK: - 按日期排序（需求 11.2）

    func testFetchAllOrderedByDateDescending() throws {
        let older = makeNote(title: "上周会议", startedAt: Date(timeIntervalSince1970: 1_000))
        let newer = makeNote(title: "今天会议", startedAt: Date(timeIntervalSince1970: 2_000))
        _ = try repository.save(older, audioSource: try makeAudioSource("a.wav"), transcriptText: "a")
        _ = try repository.save(newer, audioSource: try makeAudioSource("b.wav"), transcriptText: "b")

        let all = try repository.fetchAllOrderedByDate()
        XCTAssertEqual(all.map(\.title), ["今天会议", "上周会议"])
    }

    // MARK: - 关键词搜索（需求 11.4）

    func testSearchMatchesTitle() throws {
        _ = try repository.save(makeNote(title: "产品路线规划"), audioSource: try makeAudioSource("a.wav"), transcriptText: "x")
        _ = try repository.save(makeNote(title: "技术债务清理"), audioSource: try makeAudioSource("b.wav"), transcriptText: "y")

        let results = try repository.search(keyword: "路线")
        XCTAssertEqual(results.map(\.title), ["产品路线规划"])
    }

    func testSearchMatchesBodyContent() throws {
        _ = try repository.save(
            makeNote(title: "无关标题", sectionContent: "本次确定灰度发布节奏"),
            audioSource: try makeAudioSource("a.wav"),
            transcriptText: "x"
        )
        _ = try repository.save(
            makeNote(title: "另一个会", sectionContent: "聊聊招聘"),
            audioSource: try makeAudioSource("b.wav"),
            transcriptText: "y"
        )

        let results = try repository.search(keyword: "灰度发布")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "无关标题")
    }

    func testEmptyKeywordReturnsAll() throws {
        _ = try repository.save(makeNote(title: "会议一"), audioSource: try makeAudioSource("a.wav"), transcriptText: "x")
        _ = try repository.save(makeNote(title: "会议二"), audioSource: try makeAudioSource("b.wav"), transcriptText: "y")

        XCTAssertEqual(try repository.search(keyword: "   ").count, 2)
    }

    func testLikeWildcardTreatedLiterally() throws {
        _ = try repository.save(makeNote(title: "进度100%达成"), audioSource: try makeAudioSource("a.wav"), transcriptText: "x")
        _ = try repository.save(makeNote(title: "进度未达成"), audioSource: try makeAudioSource("b.wav"), transcriptText: "y")

        // "%" 应按字面匹配，而不是通配，故只命中含 "%" 的那条。
        let results = try repository.search(keyword: "100%")
        XCTAssertEqual(results.map(\.title), ["进度100%达成"])
    }

    // MARK: - 删除

    func testDeleteRemovesMetadataAndArchive() throws {
        let id = UUID()
        let note = makeNote(id: id, title: "待删除")
        let saved = try repository.save(note, audioSource: try makeAudioSource(), transcriptText: "x")

        try repository.delete(id: id)

        XCTAssertNil(try repository.load(id: id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: saved.audioPath))
    }
}
