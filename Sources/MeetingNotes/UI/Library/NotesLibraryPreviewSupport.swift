#if DEBUG
import Foundation

/// 纪要库预览 / 测试用的内存版仓储与样例数据（仅 DEBUG 编译）。
///
/// `InMemoryNoteStore` 用内存数组实现 `NoteStoring`，不触碰 SQLite / 文件系统，
/// 供 SwiftUI 预览与单元测试驱动 `NotesLibraryViewModel`。搜索按标题 / 正文关键词
/// 不区分大小写命中（需求 11.4），列表按开始时间降序返回（需求 11.2）。
final class InMemoryNoteStore: NoteStoring {
    private(set) var notes: [MeetingNote]

    init(notes: [MeetingNote]) {
        self.notes = notes
    }

    @discardableResult
    func save(_ note: MeetingNote, audioSource: URL?, transcriptText: String?) throws -> MeetingNote {
        notes.removeAll { $0.id == note.id }
        notes.append(note)
        return note
    }

    func load(id: UUID) throws -> MeetingNote? {
        notes.first { $0.id == id }
    }

    func fetchAllOrderedByDate() throws -> [MeetingNote] {
        notes.sorted { $0.startedAt > $1.startedAt }
    }

    func search(keyword: String) throws -> [MeetingNote] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return try fetchAllOrderedByDate() }
        let needle = trimmed.lowercased()
        return try fetchAllOrderedByDate().filter { note in
            Self.searchText(for: note).lowercased().contains(needle)
        }
    }

    func delete(id: UUID) throws {
        notes.removeAll { $0.id == id }
    }

    /// 汇总标题 + 分区正文 + 待办文本为可搜索字符串（与 NoteRepository 口径一致）。
    private static func searchText(for note: MeetingNote) -> String {
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

/// 预览样例数据与现成视图模型工厂。
enum NotesLibraryPreviewSupport {
    /// 构造一条样例纪要。`minutesAgo` 控制其相对现在的开始时间，用于触发不同日期分组。
    static func note(_ title: String,
                     minutesAgo: Int,
                     duration: TimeInterval,
                     highlighted: Bool = false) -> MeetingNote {
        MeetingNote(
            id: UUID(),
            title: title,
            startedAt: Date().addingTimeInterval(TimeInterval(-minutesAgo * 60)),
            duration: duration,
            audioPath: "",
            transcriptPath: "",
            templateId: "default",
            sections: [
                NoteSection(heading: "会议摘要",
                            content: "围绕纪要库左右分栏与列表搜索的实现方案达成一致，明确按日期分组展示。",
                            isHighlighted: false),
                NoteSection(heading: "关键决策",
                            content: "左侧列表分今天 / 昨天 / 本周早些时候三组，右侧展示正文。",
                            isHighlighted: highlighted)
            ],
            todos: [
                TodoItem(text: "完成左侧列表分组逻辑", done: true, owner: "小林", dueDate: "今天"),
                TodoItem(text: "联调搜索过滤", done: false, owner: nil, dueDate: "本周五")
            ],
            highlights: highlighted ? [120] : [],
            visuals: nil
        )
    }

    /// 覆盖今天 / 昨天 / 本周早些时候三组的样例纪要集合。
    static func sampleNotes() -> [MeetingNote] {
        [
            note("产品周会", minutesAgo: 30, duration: 3900, highlighted: true),
            note("技术评审 · 音频采集方案", minutesAgo: 90, duration: 1500),
            note("昨天的需求对齐会", minutesAgo: 60 * 26, duration: 2700),
            note("周一项目启动会", minutesAgo: 60 * 24 * 3, duration: 3600)
        ]
    }

    /// 有数据的视图模型（已加载）。
    @MainActor
    static func populatedViewModel() -> NotesLibraryViewModel {
        let store = InMemoryNoteStore(notes: sampleNotes())
        let viewModel = NotesLibraryViewModel(store: store)
        viewModel.load()
        return viewModel
    }

    /// 空数据的视图模型（已加载）。
    @MainActor
    static func emptyViewModel() -> NotesLibraryViewModel {
        let viewModel = NotesLibraryViewModel(store: InMemoryNoteStore(notes: []))
        viewModel.load()
        return viewModel
    }
}
#endif
