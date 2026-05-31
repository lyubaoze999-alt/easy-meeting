import XCTest
@testable import MeetingNotes

/// 纪要复制与导出文本拼装单元测试（任务 15.4，需求 13.1、13.2）。
///
/// 仅覆盖与平台无关的纯逻辑：`plainText(of:)` 全文表示、`markdown(of:)` Markdown 表示、
/// 以及导出文件名清理。剪贴板写入与保存面板依赖 AppKit GUI，不在单元测试范围内。
final class NoteExporterTests: XCTestCase {

    private let fixedDate = Date(timeIntervalSince1970: 1_748_500_200)

    /// 含分区（其一为重点标记）+ 待办（含责任人 / 截止时间）的代表性纪要。
    private func makeNote(title: String = "Q3 路线图评审") -> MeetingNote {
        MeetingNote(
            id: UUID(),
            title: title,
            startedAt: fixedDate,
            duration: 3720,
            audioPath: "/notes/x/audio.wav",
            transcriptPath: "/notes/x/transcript.txt",
            templateId: "builtin.default",
            sections: [
                NoteSection(heading: "会议摘要", content: "评审了 Q3 路线图。", isHighlighted: false),
                NoteSection(heading: "关键决策", content: "优先上线支付重构。", isHighlighted: true)
            ],
            todos: [
                TodoItem(text: "拆解里程碑", done: false, owner: "李雷", dueDate: "本周五"),
                TodoItem(text: "同步结论", done: true, owner: nil, dueDate: nil)
            ],
            highlights: [620],
            visuals: nil
        )
    }

    // MARK: - plainText（需求 13.1）

    func testPlainTextContainsTitleSectionsAndTodos() {
        let text = NoteExporter.plainText(of: makeNote())
        XCTAssertTrue(text.hasPrefix("Q3 路线图评审"), "首行应为会议标题")
        XCTAssertTrue(text.contains("【会议摘要】"), "应包含分区标题")
        XCTAssertTrue(text.contains("评审了 Q3 路线图。"), "应包含分区正文")
        XCTAssertTrue(text.contains("【关键决策】（重点）"), "重点分区应标注")
        XCTAssertTrue(text.contains("[ ] 拆解里程碑"), "未完成待办应为 [ ] 前缀")
        XCTAssertTrue(text.contains("[x] 同步结论"), "已完成待办应为 [x] 前缀")
        XCTAssertTrue(text.contains("负责人：李雷"), "应包含责任人")
        XCTAssertTrue(text.contains("截止：本周五"), "应包含截止时间")
    }

    func testPlainTextEmptyTitleFallsBack() {
        let text = NoteExporter.plainText(of: makeNote(title: "   "))
        XCTAssertTrue(text.hasPrefix("未命名会议"), "空白标题应退回占位文案")
    }

    // MARK: - markdown（需求 13.2）

    func testMarkdownStructure() {
        let md = NoteExporter.markdown(of: makeNote())
        XCTAssertTrue(md.contains("# Q3 路线图评审"), "应有一级标题")
        XCTAssertTrue(md.contains("## 会议摘要"), "分区应为二级标题")
        XCTAssertTrue(md.contains("## 关键决策（重点）"), "重点分区二级标题应标注")
        XCTAssertTrue(md.contains("## 待办事项"), "应有待办事项二级标题")
        XCTAssertTrue(md.contains("- [ ] 拆解里程碑"), "未完成待办应为复选框列表项")
        XCTAssertTrue(md.contains("- [x] 同步结论"), "已完成待办应为勾选复选框列表项")
        XCTAssertTrue(md.contains("负责人：李雷"), "待办应包含责任人")
    }

    func testMarkdownWithoutTodosHasNoTodoHeading() {
        var note = makeNote()
        note.todos = []
        let md = NoteExporter.markdown(of: note)
        XCTAssertFalse(md.contains("## 待办事项"), "无待办时不应出现待办事项分区")
    }

    // MARK: - 文件名清理（需求 13.2）

    func testSuggestedFileNameHasMarkdownExtension() {
        XCTAssertTrue(NoteExporter.suggestedFileName(for: makeNote()).hasSuffix(".md"))
    }

    func testSanitizedFileBaseStripsIllegalCharacters() {
        let base = NoteExporter.sanitizedFileBase("项目/评审:会议*?")
        XCTAssertFalse(base.contains("/"))
        XCTAssertFalse(base.contains(":"))
        XCTAssertFalse(base.contains("*"))
        XCTAssertFalse(base.contains("?"))
        XCTAssertFalse(base.isEmpty)
    }

    func testSanitizedFileBaseEmptyFallsBack() {
        XCTAssertEqual(NoteExporter.sanitizedFileBase("   "), "未命名会议")
    }
}
