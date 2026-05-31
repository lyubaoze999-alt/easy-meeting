import XCTest
@testable import MeetingNotes

/// Prompt 组装与 JSON 解析单元测试（任务 9.4，需求 7.3、12.2）。
final class SummaryPromptParseTests: XCTestCase {

    private let template = NoteTemplate(
        id: "default", name: "默认", isBuiltin: true,
        instruction: "按摘要/关键决策/待办/讨论要点输出。"
    )

    // MARK: - Prompt 组装（需求 7.3、16.2）

    func testUserPromptInjectsTemplateInstructionAndTranscript() {
        let prompt = SummaryPromptBuilder.userPrompt(
            transcript: "今天讨论了发布计划。",
            template: template,
            highlights: []
        )
        XCTAssertTrue(prompt.contains("按摘要/关键决策/待办/讨论要点输出。"))
        XCTAssertTrue(prompt.contains("今天讨论了发布计划。"))
        XCTAssertTrue(prompt.contains("没有重点标记"))
    }

    func testUserPromptInjectsHighlightTimestamps() {
        let prompt = SummaryPromptBuilder.userPrompt(
            transcript: "内容",
            template: template,
            highlights: [65, 3725]  // 01:05 与 01:02:05
        )
        XCTAssertTrue(prompt.contains("01:05"))
        XCTAssertTrue(prompt.contains("01:02:05"))
    }

    func testTimestampFormatting() {
        XCTAssertEqual(SummaryPromptBuilder.formatTimestamp(5), "00:05")
        XCTAssertEqual(SummaryPromptBuilder.formatTimestamp(65), "01:05")
        XCTAssertEqual(SummaryPromptBuilder.formatTimestamp(3725), "01:02:05")
    }

    func testImageModeSystemPromptRequestsVisuals() {
        let withImages = SummaryPromptBuilder.systemPrompt(imageMode: true)
        let textOnly = SummaryPromptBuilder.systemPrompt(imageMode: false)
        XCTAssertTrue(withImages.contains("visuals"))
        XCTAssertTrue(withImages.contains("timeline"))
        XCTAssertFalse(textOnly.contains("visuals"))
    }

    // MARK: - 响应解析（需求 12.2）

    func testExtractContentFromChatResponse() throws {
        let response = """
        {"choices":[{"message":{"content":"{\\"title\\":\\"会议\\"}"}}]}
        """
        let content = try LLMSummaryService.extractContent(from: Data(response.utf8))
        XCTAssertEqual(content, "{\"title\":\"会议\"}")
    }

    func testExtractContentThrowsOnEmptyChoices() {
        let response = #"{"choices":[]}"#
        XCTAssertThrowsError(try LLMSummaryService.extractContent(from: Data(response.utf8))) { error in
            XCTAssertEqual(error as? SummaryError, .emptyContent)
        }
    }

    func testDecodeSummaryContentParsesSectionsAndTodos() throws {
        let json = """
        {"title":"需求评审","sections":[{"heading":"摘要","content":"概述","isHighlighted":true}],"todos":[{"text":"跟进","owner":"李四","dueDate":"周一"}]}
        """
        let summary = try LLMSummaryService.decodeSummaryContent(json)
        XCTAssertEqual(summary.title, "需求评审")
        XCTAssertEqual(summary.sections?.first?.heading, "摘要")
        XCTAssertEqual(summary.sections?.first?.isHighlighted, true)
        XCTAssertEqual(summary.todos?.first?.owner, "李四")
    }

    func testDecodeStripsMarkdownCodeFence() throws {
        let fenced = """
        ```json
        {"title":"围栏内","sections":[],"todos":[]}
        ```
        """
        let summary = try LLMSummaryService.decodeSummaryContent(fenced)
        XCTAssertEqual(summary.title, "围栏内")
    }

    func testMakeNoteMapsHighlightFlagAndNormalizesEmptyOwner() throws {
        let json = """
        {"title":"会","sections":[{"heading":"H","content":"C","isHighlighted":true}],"todos":[{"text":"t","owner":"   ","dueDate":null}]}
        """
        let summary = try LLMSummaryService.decodeSummaryContent(json)
        let note = LLMSummaryService.makeNote(
            from: summary, highlights: [10], templateId: "default", imageMode: false, context: SummaryContext()
        )
        XCTAssertEqual(note.sections.first?.isHighlighted, true)
        XCTAssertNil(note.todos.first?.owner)          // 纯空白归一化为 nil
        XCTAssertEqual(note.highlights, [10])
        XCTAssertEqual(note.templateId, "default")
    }
}
