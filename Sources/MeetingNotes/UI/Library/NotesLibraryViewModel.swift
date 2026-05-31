import Foundation
import Combine

/// 纪要库左侧列表的日期分组（需求 11.2）。
///
/// 分组从最近到最早排列：今天 / 昨天 / 本周早些时候 / 更早。
/// `rawValue` 同时作为分组的展示顺序，越小越靠前。需求 11.2 明确要求
/// 今天、昨天、本周早些时候三组；`更早` 作为超出本周的兜底分组，
/// 保证任意历史纪要都有归属，不会丢失。
enum NoteDateGroup: Int, CaseIterable {
    case today = 0
    case yesterday
    case earlierThisWeek
    case earlier

    /// 分组的中文标题（需求 1.1、11.2）。
    var title: String {
        switch self {
        case .today: return "今天"
        case .yesterday: return "昨天"
        case .earlierThisWeek: return "本周早些时候"
        case .earlier: return "更早"
        }
    }

    /// 判断某个开始时间相对参考时刻应归入哪个分组。
    /// - Parameters:
    ///   - date: 纪要的录音开始时间。
    ///   - referenceDate: 参考"现在"，便于测试注入固定时刻。
    ///   - calendar: 日历，决定一周的起始日等本地化规则。
    static func group(for date: Date, relativeTo referenceDate: Date, calendar: Calendar) -> NoteDateGroup {
        if calendar.isDate(date, inSameDayAs: referenceDate) {
            return .today
        }
        if calendar.isDateInYesterday(date) {
            return .yesterday
        }
        // 同属一个自然周（与参考时刻 weekOfYear 相同）但不在今天 / 昨天 → 本周早些时候。
        if calendar.isDate(date, equalTo: referenceDate, toGranularity: .weekOfYear) {
            return .earlierThisWeek
        }
        return .earlier
    }
}

/// 一个日期分组及其下的纪要列表（左侧列表的一段，需求 11.2）。
struct NoteDateSection: Identifiable {
    let group: NoteDateGroup
    let notes: [MeetingNote]
    var id: Int { group.rawValue }
}

/// 纪要库主窗口的视图模型（界面层，任务 15.1，需求 11.1-11.5）。
///
/// 从注入的 `NoteStoring` 加载纪要，持有搜索词与当前选中纪要，并把列表按日期
/// 分组（需求 11.2）暴露给视图。搜索词变化时按标题 / 正文关键词过滤（需求 11.4，
/// 实际命中逻辑在仓储层 `search(keyword:)` 完成），选中项变化驱动右侧正文展示
/// （需求 11.5）。
///
/// 加载失败时降级为空列表并清空选中，不向上抛错打断界面（仓储读盘异常在桌面场景
/// 罕见，列表为空已能传达"暂无可展示纪要"）。视图只读 `@Published` 状态并通过
/// 双向绑定修改 `searchText` / `selectedNote`，不直接接触仓储，便于预览与测试。
@MainActor
final class NotesLibraryViewModel: ObservableObject {
    /// 搜索框文本，双向绑定到搜索输入（需求 11.4）。空串表示展示全部。
    @Published var searchText: String = ""
    /// 当前选中的纪要，驱动右侧正文展示与左侧高亮（需求 11.5）。
    @Published var selectedNote: MeetingNote?
    /// 当前列表（已按开始时间降序），分组由 `sections` 派生。
    @Published private(set) var notes: [MeetingNote] = []

    private let store: NoteStoring
    /// 计算日期分组用的"现在"，测试可注入固定时刻。
    private let referenceDate: () -> Date
    private let calendar: Calendar
    private var cancellables = Set<AnyCancellable>()

    /// - Parameters:
    ///   - store: 纪要仓储依赖。
    ///   - calendar: 日期分组所用日历，默认当前日历。
    ///   - referenceDate: 参考"现在"的提供者，默认 `Date.init`，测试可注入固定时刻。
    init(store: NoteStoring,
         calendar: Calendar = .current,
         referenceDate: @escaping () -> Date = Date.init) {
        self.store = store
        self.calendar = calendar
        self.referenceDate = referenceDate

        // 搜索词变化即重新查询（需求 11.4）。dropFirst 跳过初始空串，
        // 初始加载交由 `load()` 显式触发。
        $searchText
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] keyword in
                self?.reload(keyword: keyword)
            }
            .store(in: &cancellables)
    }

    /// 当前列表按日期分组的结果，仅保留非空分组并按 今天→更早 顺序排列（需求 11.2）。
    var sections: [NoteDateSection] {
        let now = referenceDate()
        var buckets: [NoteDateGroup: [MeetingNote]] = [:]
        for note in notes {
            let group = NoteDateGroup.group(for: note.startedAt, relativeTo: now, calendar: calendar)
            buckets[group, default: []].append(note)
        }
        return NoteDateGroup.allCases.compactMap { group in
            guard let groupNotes = buckets[group], !groupNotes.isEmpty else { return nil }
            return NoteDateSection(group: group, notes: groupNotes)
        }
    }

    /// 初始加载：按当前搜索词查询并选中首条（需求 11.5 的默认展示）。
    func load() {
        reload(keyword: searchText)
    }

    /// 选中一条纪要，触发右侧正文展示与左侧高亮（需求 11.5）。
    func select(_ note: MeetingNote) {
        selectedNote = note
    }

    /// 判断某条纪要是否为当前选中项（左侧高亮用，需求 11.5）。
    func isSelected(_ note: MeetingNote) -> Bool {
        selectedNote?.id == note.id
    }

    /// 按关键词重新查询：空串取全部（按时间降序），否则交由仓储按标题 / 正文命中（需求 11.4）。
    /// 失败时降级为空列表并清空选中。
    private func reload(keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let result = trimmed.isEmpty
                ? try store.fetchAllOrderedByDate()
                : try store.search(keyword: trimmed)
            notes = result
            reconcileSelection()
        } catch {
            notes = []
            selectedNote = nil
        }
    }

    /// 协调选中态：保留仍在列表中的选中项，否则回退到首条；列表为空则清空选中（需求 11.5）。
    private func reconcileSelection() {
        if let current = selectedNote, notes.contains(where: { $0.id == current.id }) {
            // 用最新数据刷新选中项，避免展示陈旧正文。
            selectedNote = notes.first(where: { $0.id == current.id })
            return
        }
        selectedNote = notes.first
    }
}
