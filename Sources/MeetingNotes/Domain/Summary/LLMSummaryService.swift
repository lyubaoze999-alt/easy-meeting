import Foundation

/// 基于 OpenAI 兼容客户端的纪要生成实现（需求 7.3、7.4、12.2、16.2）。
///
/// 流程：
/// 1. 用 `SummaryPromptBuilder` 组装 system / user 提示，注入模板纪要指令与重点标记时间点。
/// 2. POST `chat/completions`，解析 `choices[0].message.content` 中的纪要 JSON。
/// 3. 把分区、待办映射为 `MeetingNote`，命中重点标记的分区标注 `isHighlighted`。
///
/// 本任务（9.1）聚焦文字路径，`imageMode` 透传但暂不生成可视化数据（visuals 置 nil，由任务 9.2 补充）。
final class LLMSummaryService: SummaryService {
    private let client: OpenAICompatibleClienting
    /// 生成纪要的补充上下文工厂：编排层可注入真实上下文，默认使用占位值。
    private let contextProvider: () -> SummaryContext

    /// - Parameters:
    ///   - client: OpenAI 兼容客户端，用于调用总结服务（注入便于测试）。
    ///   - contextProvider: 返回 `SummaryContext` 的工厂，补齐纪要元数据；默认占位上下文。
    init(client: OpenAICompatibleClienting,
         contextProvider: @escaping () -> SummaryContext = { .placeholder }) {
        self.client = client
        self.contextProvider = contextProvider
    }

    func summarize(transcript: String,
                   template: NoteTemplate,
                   highlights: [TimeInterval],
                   imageMode: Bool,
                   config: ServiceConfig) async throws -> MeetingNote {
        try await summarize(
            transcript: transcript,
            template: template,
            highlights: highlights,
            imageMode: imageMode,
            config: config,
            context: contextProvider()
        )
    }

    /// 带显式上下文的重载：编排层（任务 12.1）可传入录音时间、时长、文件路径以构造完整纪要。
    func summarize(transcript: String,
                   template: NoteTemplate,
                   highlights: [TimeInterval],
                   imageMode: Bool,
                   config: ServiceConfig,
                   context: SummaryContext) async throws -> MeetingNote {
        // 1) 组装请求体。
        let request = ChatCompletionRequest(
            model: config.model,
            messages: [
                .system(SummaryPromptBuilder.systemPrompt(imageMode: imageMode)),
                .user(SummaryPromptBuilder.userPrompt(
                    transcript: transcript,
                    template: template,
                    highlights: highlights
                ))
            ],
            responseFormat: .json
        )

        let body: Data
        do {
            body = try JSONEncoder().encode(request)
        } catch {
            throw SummaryError.requestFailed(reason: error.localizedDescription)
        }

        // 2) 调用 chat/completions。
        let responseData: Data
        do {
            responseData = try await client.postJSON(
                path: "chat/completions",
                body: body,
                config: config
            )
        } catch {
            throw SummaryError.requestFailed(reason: error.localizedDescription)
        }

        // 3) 解析外层响应，取出 content。
        let content = try Self.extractContent(from: responseData)

        // 4) 解析 content 内的纪要 JSON。
        let summary = try Self.decodeSummaryContent(content)

        // 5) 映射为 MeetingNote。
        return Self.makeNote(
            from: summary,
            highlights: highlights,
            templateId: template.id,
            imageMode: imageMode,
            context: context
        )
    }

    // MARK: - 响应解析

    /// 取出 `choices[0].message.content`，为空则抛错。
    static func extractContent(from data: Data) throws -> String {
        let response: ChatCompletionResponse
        do {
            response = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        } catch {
            throw SummaryError.responseDecodingFailed
        }
        guard let content = response.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SummaryError.emptyContent
        }
        return content
    }

    /// 把模型返回的内容解析为 `SummaryContent`。
    ///
    /// 兼容模型把 JSON 包在 Markdown 代码块（```json ... ```）中的情况，先剥离再解析。
    static func decodeSummaryContent(_ content: String) throws -> SummaryContent {
        let cleaned = stripCodeFence(content)
        guard let data = cleaned.data(using: .utf8) else {
            throw SummaryError.contentDecodingFailed
        }
        do {
            return try JSONDecoder().decode(SummaryContent.self, from: data)
        } catch {
            throw SummaryError.contentDecodingFailed
        }
    }

    /// 剥离可能存在的 Markdown 代码块围栏，提取其中的 JSON 文本。
    static func stripCodeFence(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix("```") else { return text }
        // 去掉起始围栏行（可能是 ``` 或 ```json）。
        if let firstNewline = text.firstIndex(of: "\n") {
            text = String(text[text.index(after: firstNewline)...])
        }
        // 去掉结尾围栏。
        if text.hasSuffix("```") {
            text = String(text.dropLast(3))
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 映射为 MeetingNote

    /// 把解析出的纪要内容与上下文组装为完整 `MeetingNote`（需求 7.4、12.2、14.2、14.3）。
    ///
    /// - Parameter imageMode: 图文模式开关。`true` 时把解析出的可视化数据填入 `visuals`；
    ///   `false` 时 `visuals` 恒为 nil。无论模式如何，文字内容（标题/分区/待办）始终完整保留（需求 14.3）。
    static func makeNote(from summary: SummaryContent,
                         highlights: [TimeInterval],
                         templateId: String,
                         imageMode: Bool,
                         context: SummaryContext) -> MeetingNote {
        let sections: [NoteSection] = (summary.sections ?? []).map { dto in
            NoteSection(
                heading: dto.heading ?? "",
                content: dto.content ?? "",
                // 命中重点标记的分区标注 isHighlighted（需求 7.4）。
                isHighlighted: dto.isHighlighted ?? false
            )
        }

        let todos: [TodoItem] = (summary.todos ?? []).map { dto in
            TodoItem(
                text: dto.text ?? "",
                done: dto.done ?? false,
                owner: normalizeOptional(dto.owner),
                dueDate: normalizeOptional(dto.dueDate)
            )
        }

        let title = (summary.title?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
            $0.isEmpty ? nil : $0
        } ?? "未命名会议"

        return MeetingNote(
            id: context.noteId,
            title: title,
            startedAt: context.startedAt,
            duration: context.duration,
            audioPath: context.audioPath,
            transcriptPath: context.transcriptPath,
            templateId: templateId,
            sections: sections,
            todos: todos,
            highlights: highlights,
            // 图文模式填充可视化数据；纯文本模式恒为 nil（需求 14.2、16.5）。
            // 文字内容（sections、todos）始终完整，可视化仅为附加（需求 14.3）。
            visuals: imageMode ? mapVisuals(summary.visuals) : nil
        )
    }

    /// 把可视化 DTO 映射为 `NoteVisuals`，缺省字段保持 nil（需求 14.2）。
    ///
    /// 当 DTO 为 nil 或三类内容都为空时返回 nil，便于界面层按「无可视化内容」处理（需求 14.5）。
    static func mapVisuals(_ dto: SummaryContent.VisualsDTO?) -> NoteVisuals? {
        guard let dto else { return nil }

        let timeline: [TimelineNode]? = dto.timeline.flatMap { nodes in
            let mapped = nodes.map { node in
                TimelineNode(
                    time: node.time ?? "",
                    title: node.title ?? "",
                    detail: normalizeOptional(node.detail)
                )
            }
            return mapped.isEmpty ? nil : mapped
        }

        let mindmap = dto.mindmap.map(mapMindmap)

        let keyNumbers: [KeyNumber]? = dto.keyNumbers.flatMap { numbers in
            let mapped = numbers.map { number in
                KeyNumber(
                    label: number.label ?? "",
                    value: number.value ?? "",
                    note: normalizeOptional(number.note)
                )
            }
            return mapped.isEmpty ? nil : mapped
        }

        // 三类可视化全为空时视为无可视化内容。
        if timeline == nil && mindmap == nil && keyNumbers == nil {
            return nil
        }

        return NoteVisuals(timeline: timeline, mindmap: mindmap, keyNumbers: keyNumbers)
    }

    /// 递归映射思维导图节点，children 缺省视为空数组。
    static func mapMindmap(_ dto: SummaryContent.MindmapNodeDTO) -> MindmapNode {
        MindmapNode(
            title: dto.title ?? "",
            children: (dto.children ?? []).map(mapMindmap)
        )
    }

    /// 把模型返回的空字符串/纯空白归一化为 nil（responsible 字段未识别时）。
    private static func normalizeOptional(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }
}
