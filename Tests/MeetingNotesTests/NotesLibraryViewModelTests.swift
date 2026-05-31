import XCTest
@testable import MeetingNotes

/// 纪要库视图模型与日期分组单元测试（任务 15.1，需求 11.2、11.4、11.5）。
///
/// 覆盖：按日期分组归类（今天 / 昨天 / 本周早些时候 / 更早）、搜索过滤、选中态协调。
@MainActor
final class NotesLibraryViewModelTests: XCTestCase {

    // MARK: - 测试辅助

    /// 固定参考时刻：2026-05-29（周五）14:30，便于稳定地落入各日期分组。
    private func referenceDate() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 29
        components.hour = 14
        components.minute = 30
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    /// 周一起始的日历，保证"本周"边界稳定（与系统区域无关）。
    private func mondayCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // 周一
        return calendar
    }

    private func makeNote(_ title: String,
                          startedAt: Date,
                          sections: [NoteSection] = [],
                          todos: [TodoItem] = []) -> MeetingNote {
        MeetingNote(
            id: UUID(),
            title: title,
            startedAt: startedAt,
            duration: 600,
            audioPath: "",
            transcriptPath: "",
            templateId: "default",
            sections: sections,
            todos: todos,
            highlights: [],
            visuals: nil
        )
    }

    // MARK: - 日期分组（需求 11.2）

    func testDateGroupClassification() {
        let calendar = mondayCalendar()
        let now = referenceDate()

        let today = now.addingTimeInterval(-3600)                 // 同一天早些
        let yesterday = now.addingTimeInterval(-26 * 3600)        // 约 26 小时前 = 昨天
        let earlierThisWeek = now.addingTimeInterval(-3 * 24 * 3600) // 周二，本周更早
        let lastWeek = now.addingTimeInterval(-9 * 24 * 3600)     // 上周

        XCTAssertEqual(NoteDateGroup.group(for: today, relativeTo: now, calendar: calendar), .today)
        XCTAssertEqual(NoteDateGroup.group(for: yesterday, relativeTo: now, calendar: calendar), .yesterday)
        XCTAssertEqual(NoteDateGroup.group(for: earlierThisWeek, relativeTo: now, calendar: calendar), .earlierThisWeek)
        XCTAssertEqual(NoteDateGroup.group(for: lastWeek, relativeTo: now, calendar: calendar), .earlier)
    }

    func testSectionsAreOrderedAndNonEmptyOnly() {
        let now = referenceDate()
        let store = InMemoryNoteStore(notes: [
            makeNote("今天会", startedAt: now.addingTimeInterval(-3600)),
            makeNote("昨天会", startedAt: now.addingTimeInterval(-26 * 3600)),
            makeNote("上周会", startedAt: now.addingTimeInterval(-9 * 24 * 3600))
        ])
        let vm = NotesLibraryViewModel(store: store,
                                       calendar: mondayCalendar(),
                                       referenceDate: { self.referenceDate() })
        vm.load()

        let groups = vm.sections.map(\.group)
        // 无"本周早些时候"数据 → 该分组不出现，其余按 今天→昨天→更早 顺序。
        XCTAssertEqual(groups, [.today, .yesterday, .earlier])
    }

    // MARK: - 搜索过滤（需求 11.4）

    func testSearchFiltersByTitleOrBody() {
        let now = referenceDate()
        let store = InMemoryNoteStore(notes: [
            makeNote("产品周会", startedAt: now.addingTimeInterval(-3600),
                     sections: [NoteSection(heading: "摘要", content: "讨论音频采集方案", isHighlighted: false)]),
            makeNote("技术评审", startedAt: now.addingTimeInterval(-7200),
                     sections: [NoteSection(heading: "摘要", content: "评审纪要库布局", isHighlighted: false)])
        ])
        let vm = NotesLibraryViewModel(store: store, calendar: mondayCalendar(), referenceDate: { self.referenceDate() })
        vm.load()
        XCTAssertEqual(vm.notes.count, 2)

        // 标题命中。
        vm.searchText = "产品"
        XCTAssertEqual(vm.notes.map(\.title), ["产品周会"])

        // 正文命中。
        vm.searchText = "布局"
        XCTAssertEqual(vm.notes.map(\.title), ["技术评审"])

        // 清空恢复全部。
        vm.searchText = ""
        XCTAssertEqual(vm.notes.count, 2)
    }

    // MARK: - 选中态协调（需求 11.5）

    func testLoadSelectsFirstNote() {
        let now = referenceDate()
        let first = makeNote("最新", startedAt: now.addingTimeInterval(-600))
        let second = makeNote("较早", startedAt: now.addingTimeInterval(-3600))
        let vm = NotesLibraryViewModel(store: InMemoryNoteStore(notes: [second, first]),
                                       calendar: mondayCalendar(),
                                       referenceDate: { self.referenceDate() })
        vm.load()
        // 按时间降序，首条应为"最新"。
        XCTAssertEqual(vm.selectedNote?.id, first.id)
        XCTAssertTrue(vm.isSelected(first))
        XCTAssertFalse(vm.isSelected(second))
    }

    func testSelectionFallsBackWhenFilteredOut() {
        let now = referenceDate()
        let a = makeNote("产品周会", startedAt: now.addingTimeInterval(-600))
        let b = makeNote("技术评审", startedAt: now.addingTimeInterval(-3600))
        let vm = NotesLibraryViewModel(store: InMemoryNoteStore(notes: [a, b]),
                                       calendar: mondayCalendar(),
                                       referenceDate: { self.referenceDate() })
        vm.load()
        vm.select(b)
        XCTAssertEqual(vm.selectedNote?.id, b.id)

        // 搜索过滤掉当前选中项 → 回退到结果首条。
        vm.searchText = "产品"
        XCTAssertEqual(vm.selectedNote?.id, a.id)
    }

    func testEmptyStoreHasNoSelection() {
        let vm = NotesLibraryViewModel(store: InMemoryNoteStore(notes: []),
                                       calendar: mondayCalendar(),
                                       referenceDate: { self.referenceDate() })
        vm.load()
        XCTAssertNil(vm.selectedNote)
        XCTAssertTrue(vm.sections.isEmpty)
    }
}
