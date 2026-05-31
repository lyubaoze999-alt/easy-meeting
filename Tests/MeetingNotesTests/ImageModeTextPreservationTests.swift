import XCTest
import SwiftCheck
@testable import MeetingNotes

/// Property 7「图文模式不丢文字」属性测试（需求 14.3）。
///
/// 不变量：对任意模型输出（含 sections / todos / visuals），makeNote 在 imageMode=true 与
/// imageMode=false 下产出的文字内容（title / sections / todos）完全一致；图文模式仅额外附加 visuals。
final class ImageModeTextPreservationTests: XCTestCase {

    /// 用一段固定的 SummaryContent（含可视化）验证文字在两种模式下一致。
    func testTextIdenticalRegardlessOfImageMode() throws {
        let json = """
        {
          "title": "季度评审",
          "sections": [
            {"heading": "会议摘要", "content": "回顾季度目标完成度。", "isHighlighted": true},
            {"heading": "讨论要点", "content": "讨论了资源分配。", "isHighlighted": false}
          ],
          "todos": [
            {"text": "补充数据", "owner": "张三", "dueDate": "周五"},
            {"text": "对齐排期", "owner": null, "dueDate": null}
          ],
          "visuals": {
            "timeline": [{"time": "00:05", "title": "开场", "detail": null}],
            "mindmap": {"title": "季度", "children": [{"title": "目标", "children": []}]},
            "keyNumbers": [{"label": "完成率", "value": "80%", "note": null}]
          }
        }
        """
        let summary = try LLMSummaryService.decodeSummaryContent(json)
        let ctx = SummaryContext()

        let textOnly = LLMSummaryService.makeNote(
            from: summary, highlights: [], templateId: "t", imageMode: false, context: ctx
        )
        let withImages = LLMSummaryService.makeNote(
            from: summary, highlights: [], templateId: "t", imageMode: true, context: ctx
        )

        // 文字部分完全一致。
        XCTAssertEqual(textOnly.title, withImages.title)
        XCTAssertEqual(textOnly.sections, withImages.sections)
        XCTAssertEqual(textOnly.todos, withImages.todos)

        // 纯文本模式无 visuals；图文模式有 visuals（附加）。
        XCTAssertNil(textOnly.visuals)
        XCTAssertNotNil(withImages.visuals)
    }

    /// 属性化：对任意标题/分区文本，两种模式下文字字段恒等。
    func testTextFieldsAreModeInvariantProperty() {
        let nonEmpty = String.arbitrary.suchThat { !$0.isEmpty }
        property("title 与 section 文字在 imageMode 切换下不变") <- forAll(nonEmpty, nonEmpty, nonEmpty) {
            (title: String, heading: String, content: String) in
            // 用 JSON 走与生产一致的解析路径，避免直接构造内部 DTO。
            let escapedTitle = Self.jsonEscape(title)
            let escapedHeading = Self.jsonEscape(heading)
            let escapedContent = Self.jsonEscape(content)
            let json = """
            {"title":"\(escapedTitle)","sections":[{"heading":"\(escapedHeading)","content":"\(escapedContent)","isHighlighted":false}],"todos":[],"visuals":{"keyNumbers":[{"label":"x","value":"1"}]}}
            """
            guard let summary = try? LLMSummaryService.decodeSummaryContent(json) else {
                // 解析失败的随机串不参与不变量判定。
                return true
            }
            let ctx = SummaryContext()
            let a = LLMSummaryService.makeNote(from: summary, highlights: [], templateId: "t", imageMode: false, context: ctx)
            let b = LLMSummaryService.makeNote(from: summary, highlights: [], templateId: "t", imageMode: true, context: ctx)
            return a.title == b.title && a.sections == b.sections && a.todos == b.todos
        }
    }

    /// 最小 JSON 字符串转义，覆盖反斜杠、引号与控制字符。
    private static func jsonEscape(_ s: String) -> String {
        var out = ""
        for ch in s.unicodeScalars {
            switch ch {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if ch.value < 0x20 {
                    out += String(format: "\\u%04x", ch.value)
                } else {
                    out.unicodeScalars.append(ch)
                }
            }
        }
        return out
    }
}
