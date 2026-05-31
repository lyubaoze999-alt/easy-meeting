import Foundation

/// Prompt 组装器：把转写文本、模板纪要指令、重点标记时间点拼成发给总结服务的提示（需求 7.3、16.2）。
///
/// 输出两段提示：
/// - `systemPrompt`：固定的角色设定与输出格式约束（要求返回结构化 JSON）。
/// - `userPrompt`：模板纪要指令 + 重点标记时间点 + 完整转写文本。
///
/// 所有面向模型与用户的文案均为中文（会议内容为中文，需求 1.1）。
enum SummaryPromptBuilder {
    /// 组装系统提示：约束模型按指定 JSON 结构输出纪要。
    ///
    /// - Parameter imageMode: 图文模式开关（需求 16.5、14.2）。
    ///   - `true`：在标题/分区/待办之外，额外要求模型输出 `visuals` 对象
    ///     （时间线 timeline / 思维导图 mindmap / 关键数字 keyNumbers）。
    ///   - `false`：纯文本模式，提示中不出现 `visuals`，仅生成文字内容。
    static func systemPrompt(imageMode: Bool) -> String {
        // 文字部分的 JSON 结构在两种模式下保持一致（需求 14.3：图文模式文字始终保留）。
        let textSchema = """
          "title": "会议标题（简明概括本次会议主题）",
          "sections": [
            {
              "heading": "分区标题（遵循模板指令定义的分区）",
              "content": "分区正文内容",
              "isHighlighted": false
            }
          ],
          "todos": [
            {
              "text": "待办事项内容",
              "owner": "责任人，未识别到则为 null",
              "dueDate": "截止时间文本，未识别到则为 null"
            }
          ]
        """

        let textRules = """
        1. sections 按模板指令定义的分区顺序组织，每个分区一项。
        2. 若某个分区的内容涉及下文给出的「重点标记时间点」，请把该分区的 isHighlighted 置为 true，否则置为 false。
        3. todos 从会议内容中提炼可执行的待办；识别不到责任人或截止时间时，对应字段返回 null。
        4. 所有内容使用中文。
        """

        if imageMode {
            // 图文模式：文字结构 + visuals 可视化结构（需求 16.5、14.2）。
            return """
            你是一名专业的会议纪要整理助手。你会收到一段会议语音的转写文本，\
            转写文本可能包含口语化表达、重复和识别误差，请结合上下文理解其真实含义。

            请严格按照用户提供的纪要模板指令组织内容，并只返回一个 JSON 对象，不要输出任何额外解释、注释或 Markdown 代码块标记。

            JSON 必须符合以下结构：
            {
            \(textSchema),
              "visuals": {
                "timeline": [
                  {
                    "time": "时间标签（如 \\"00:05\\" 或 \\"会议中段\\"）",
                    "title": "该时间点的标题",
                    "detail": "详细描述，没有则为 null"
                  }
                ],
                "mindmap": {
                  "title": "中心主题",
                  "children": [
                    { "title": "子主题", "children": [] }
                  ]
                },
                "keyNumbers": [
                  {
                    "label": "指标名称（如 \\"目标转化率\\"）",
                    "value": "指标数值文本（如 \\"15%\\"、\\"3 个\\"）",
                    "note": "补充说明，没有则为 null"
                  }
                ]
              }
            }

            要求：
            \(textRules)
            5. visuals 用于图文模式的可视化展示，是对文字内容的补充，不得削减或替代 sections、todos 中的文字内容。
            6. timeline 按会议时间顺序梳理关键节点；mindmap 以本次会议主题为中心节点递归组织层级，叶子节点的 children 为空数组；keyNumbers 提炼会议中出现的量化指标。
            7. 若某类可视化内容确实无法从会议中提炼，可将该字段（timeline / mindmap / keyNumbers）设为 null 或空数组，但文字内容必须完整。
            """
        }

        // 纯文本模式：仅生成文字内容，不要求 visuals（需求 14.2）。
        return """
        你是一名专业的会议纪要整理助手。你会收到一段会议语音的转写文本，\
        转写文本可能包含口语化表达、重复和识别误差，请结合上下文理解其真实含义。

        请严格按照用户提供的纪要模板指令组织内容，并只返回一个 JSON 对象，不要输出任何额外解释、注释或 Markdown 代码块标记。

        JSON 必须符合以下结构：
        {
        \(textSchema)
        }

        要求：
        \(textRules)
        """
    }

    /// 组装用户提示：模板纪要指令 + 重点标记时间点 + 完整转写文本（需求 7.3、16.2）。
    ///
    /// - Parameters:
    ///   - transcript: 完整转写文本。
    ///   - template: 所选模板，使用其 `instruction` 指导分区结构。
    ///   - highlights: 重点标记时间点（秒），作为聚焦输入提供给模型。
    static func userPrompt(transcript: String,
                           template: NoteTemplate,
                           highlights: [TimeInterval]) -> String {
        let highlightBlock: String
        if highlights.isEmpty {
            highlightBlock = "本次会议没有重点标记。"
        } else {
            let formatted = highlights
                .sorted()
                .map { "- \(formatTimestamp($0))" }
                .joined(separator: "\n")
            highlightBlock = """
            本次会议的重点标记时间点如下（相对录音起点），\
            请重点关注这些时间附近讨论的内容，并在对应分区把 isHighlighted 置为 true：
            \(formatted)
            """
        }

        return """
        【纪要模板指令】
        \(template.instruction)

        【重点标记时间点】
        \(highlightBlock)

        【会议转写文本】
        \(transcript)
        """
    }

    /// 把秒数格式化为 `HH:MM:SS` 或 `MM:SS`，便于模型理解时间点位置。
    static func formatTimestamp(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
