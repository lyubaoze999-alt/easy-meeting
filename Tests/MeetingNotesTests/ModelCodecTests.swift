import XCTest
@testable import MeetingNotes

/// 数据模型编解码单元测试（需求 12.2）。
///
/// 验证 MeetingNote 及其嵌套结构、NoteTemplate、AppSettings/ServiceConfig/ThemeMode、
/// NoteVisuals（timeline/mindmap/keyNumbers）经 JSONEncoder 编码后再 JSONDecoder 解码，
/// 解码结果与原始值完全相等（往返一致）。
final class ModelCodecTests: XCTestCase {

    // MARK: - 编解码器

    /// 统一日期策略：两侧均用 .iso8601，保证含 Date 的模型往返一致。
    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// 通用往返断言：编码 value → 解码 → 断言与原值相等。
    private func assertRoundTrip<T: Codable & Equatable>(
        _ value: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let data = try makeEncoder().encode(value)
        let decoded = try makeDecoder().decode(T.self, from: data)
        XCTAssertEqual(decoded, value, "\(T.self) JSON 往返后不一致", file: file, line: line)
    }

    // MARK: - 代表性实例

    /// .iso8601 默认精度到秒，用整秒时间戳避免亚秒精度丢失导致的误判。
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    /// 含嵌套 sections / todos / highlights / visuals 的完整纪要。
    private func makeFullNote() -> MeetingNote {
        MeetingNote(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            title: "季度产品评审会",
            startedAt: fixedDate,
            duration: 3_725,
            audioPath: "/notes/abc/audio.wav",
            transcriptPath: "/notes/abc/transcript.txt",
            templateId: "review",
            sections: [
                NoteSection(heading: "会议摘要", content: "评审了 Q3 路线图与资源排布。", isHighlighted: false),
                NoteSection(heading: "关键决策", content: "确定优先上线支付重构。", isHighlighted: true)
            ],
            todos: [
                TodoItem(text: "补充竞品分析", done: false, owner: "张三", dueDate: "本周五"),
                TodoItem(text: "对齐设计稿", done: true, owner: nil, dueDate: nil)
            ],
            highlights: [12.5, 480.0, 1_203.75],
            visuals: makeFullVisuals()
        )
    }

    /// 三类可视化数据齐全的 NoteVisuals（含递归 mindmap）。
    private func makeFullVisuals() -> NoteVisuals {
        NoteVisuals(
            timeline: [
                TimelineNode(time: "00:05", title: "开场", detail: "确认议程"),
                TimelineNode(time: "会议中段", title: "方案讨论", detail: nil)
            ],
            mindmap: MindmapNode(
                title: "Q3 规划",
                children: [
                    MindmapNode(title: "支付重构", children: [
                        MindmapNode(title: "风控对接", children: [])
                    ]),
                    MindmapNode(title: "增长实验", children: [])
                ]
            ),
            keyNumbers: [
                KeyNumber(label: "目标转化率", value: "15%", note: "环比提升 3pt"),
                KeyNumber(label: "投入人力", value: "3 人", note: nil)
            ]
        )
    }

    // MARK: - MeetingNote 及嵌套结构

    func testMeetingNoteRoundTrip() throws {
        try assertRoundTrip(makeFullNote())
    }

    /// 纯文本模式：visuals 为 nil、highlights 为空也应往返一致。
    func testMeetingNoteWithoutVisualsRoundTrip() throws {
        var note = makeFullNote()
        note.visuals = nil
        note.highlights = []
        try assertRoundTrip(note)
    }

    func testNoteSectionRoundTrip() throws {
        try assertRoundTrip(NoteSection(heading: "讨论要点", content: "围绕排期展开。", isHighlighted: true))
    }

    func testTodoItemRoundTrip() throws {
        try assertRoundTrip(TodoItem(text: "发出会议纪要", done: false, owner: "李四", dueDate: "明天"))
    }

    /// 可选字段全为 nil 的 TodoItem。
    func testTodoItemWithNilOptionalsRoundTrip() throws {
        try assertRoundTrip(TodoItem(text: "待认领", done: false, owner: nil, dueDate: nil))
    }

    // MARK: - NoteVisuals（timeline / mindmap / keyNumbers）

    func testNoteVisualsFullRoundTrip() throws {
        try assertRoundTrip(makeFullVisuals())
    }

    /// 三类可视化全为 nil 的空壳也应往返一致。
    func testNoteVisualsAllNilRoundTrip() throws {
        try assertRoundTrip(NoteVisuals(timeline: nil, mindmap: nil, keyNumbers: nil))
    }

    func testTimelineNodeRoundTrip() throws {
        try assertRoundTrip(TimelineNode(time: "01:00", title: "收尾", detail: "明确 owner"))
    }

    /// 递归 mindmap：多层嵌套与空子节点。
    func testMindmapNodeRecursiveRoundTrip() throws {
        let node = MindmapNode(title: "根", children: [
            MindmapNode(title: "A", children: [
                MindmapNode(title: "A-1", children: []),
                MindmapNode(title: "A-2", children: [
                    MindmapNode(title: "A-2-1", children: [])
                ])
            ]),
            MindmapNode(title: "B", children: [])
        ])
        try assertRoundTrip(node)
    }

    func testKeyNumberRoundTrip() throws {
        try assertRoundTrip(KeyNumber(label: "NPS", value: "42", note: nil))
    }

    // MARK: - NoteTemplate

    func testBuiltinTemplateRoundTrip() throws {
        try assertRoundTrip(NoteTemplate(id: "default", name: "默认", isBuiltin: true, instruction: "按摘要/关键决策/待办/讨论要点输出。"))
    }

    func testCustomTemplateRoundTrip() throws {
        try assertRoundTrip(NoteTemplate(id: UUID().uuidString, name: "我的模板", isBuiltin: false, instruction: "聚焦行动项与风险。"))
    }

    // MARK: - 配置与主题（ServiceConfig / AppSettings / ThemeMode）

    func testServiceConfigRoundTrip() throws {
        try assertRoundTrip(ServiceConfig(baseURL: "https://api.example.com/v1", apiKey: "sk-test-123", model: "whisper-1"))
    }

    func testThemeModeRoundTrip() throws {
        for mode in [ThemeMode.light, .dark, .system] {
            try assertRoundTrip(mode)
        }
    }

    func testAppSettingsRoundTrip() throws {
        let settings = AppSettings(
            transcription: ServiceConfig(baseURL: "https://asr.example.com/v1", apiKey: "sk-asr", model: "whisper-large"),
            summary: ServiceConfig(baseURL: "https://llm.example.com/v1", apiKey: "sk-llm", model: "gpt-4o-mini"),
            theme: .system,
            imageMode: true
        )
        try assertRoundTrip(settings)
    }
}
