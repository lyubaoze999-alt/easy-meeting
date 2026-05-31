import Foundation

// MARK: - chat/completions 请求体

/// chat/completions 请求体（需求 12.2，对应 OpenAI 兼容协议）。
///
/// 仅包含必需字段：模型名（按用户输入原样使用，需求 1.2）与消息列表。
struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    /// 请求模型以 JSON 形式回复（兼容服务忽略该字段时不影响功能）。
    let responseFormat: ResponseFormat?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case responseFormat = "response_format"
    }

    struct ResponseFormat: Encodable {
        let type: String
        static let json = ResponseFormat(type: "json_object")
    }
}

/// 单条对话消息。
struct ChatMessage: Encodable {
    let role: String
    let content: String

    static func system(_ content: String) -> ChatMessage { .init(role: "system", content: content) }
    static func user(_ content: String) -> ChatMessage { .init(role: "user", content: content) }
}

// MARK: - chat/completions 响应体

/// chat/completions 响应体：仅取 `choices[0].message.content`，其余字段忽略。
struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }
        let message: Message
    }
    let choices: [Choice]
}

// MARK: - 模型输出的纪要结构（content 内的 JSON）

/// 模型在 `message.content` 中返回的纪要 JSON 结构（需求 12.2）。
///
/// 与 `MeetingNote` 解耦：模型只产出与生成相关的字段（标题、分区、待办），
/// 其余元数据（id、时间、路径等）由服务结合 `SummaryContext` 补齐。
struct SummaryContent: Decodable {
    let title: String?
    let sections: [SectionDTO]?
    let todos: [TodoDTO]?
    /// 图文模式下模型额外产出的可视化数据；纯文本模式或模型未产出时为 nil（需求 16.5、14.2）。
    let visuals: VisualsDTO?

    struct SectionDTO: Decodable {
        let heading: String?
        let content: String?
        let isHighlighted: Bool?
    }

    struct TodoDTO: Decodable {
        let text: String?
        let owner: String?
        let dueDate: String?
        /// 模型可能返回完成状态；缺省视为未完成。
        let done: Bool?
    }

    /// 可视化数据 DTO，与 `NoteVisuals` 解耦，所有字段可选以容忍模型输出缺省（需求 14.2）。
    struct VisualsDTO: Decodable {
        let timeline: [TimelineNodeDTO]?
        let mindmap: MindmapNodeDTO?
        let keyNumbers: [KeyNumberDTO]?
    }

    struct TimelineNodeDTO: Decodable {
        let time: String?
        let title: String?
        let detail: String?
    }

    /// 思维导图节点 DTO，递归结构，children 缺省视为空（需求 14.2）。
    struct MindmapNodeDTO: Decodable {
        let title: String?
        let children: [MindmapNodeDTO]?
    }

    struct KeyNumberDTO: Decodable {
        let label: String?
        let value: String?
        let note: String?
    }
}
