import SwiftUI

/// 纪要库右侧正文视图（界面层，任务 15.2，需求 7.4、12.1～12.4）。
///
/// 展示当前选中纪要的结构化正文：
/// - 顶部展示标题、日期、时间段与时长（需求 12.1）。
/// - 按所选模板决定的分区顺序展示正文（需求 12.2）；默认模板对应
///   会议摘要 / 关键决策 / 待办事项 / 讨论要点 四个分区（需求 12.3）。
/// - 待办事项不以纯文本分区呈现，而是结构化列表：每条待办带勾选框、责任人与截止时间
///   （需求 12.4）。待办按其在模板分区中的应有位置插入，而非一律置于末尾。
/// - 命中重点标记的分区在标题旁标注「重点」（需求 7.4）。
///
/// 取色全部来自 `@Environment(\.themeTokens)`（需求 17.4），自有文案为中文（需求 1.1）。
///
/// 任务 15.3 将在此之上叠加纯文本 / 图文模式切换：正文渲染已拆为
/// `header` 与 `contentBlock(_:)` 等可复用片段，便于外层包裹模式切换而无需改动本视图。
struct NoteDetailView: View {
    @Environment(\.themeTokens) private var tokens

    let note: MeetingNote

    /// 当前展示模式，默认纯文本（需求 14.4）。用户可经分段控件切换到图文（需求 14.1）。
    @State private var mode: DisplayMode = .plainText

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: tokens.spacingUnit * 2) {
                header
                toolbarRow
                // 文字正文始终完整渲染：纯文本与图文模式都保留（需求 14.3、14.4，对应 Property 7）。
                ForEach(Array(contentBlocks.enumerated()), id: \.offset) { _, block in
                    contentBlock(block)
                }
                // 图文模式额外叠加可视化内容；无可视化时给出中文提示（需求 14.2、14.5）。
                if mode == .imageText {
                    visualsSection
                }
            }
            .padding(tokens.spacingUnit * 3)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tokens.background)
    }
}

// MARK: - 展示模式切换（需求 14.1、14.2、14.4、14.5）

extension NoteDetailView {
    /// 纪要展示模式：纯文本仅文字；图文在文字之上附加可视化内容。
    enum DisplayMode: CaseIterable, Identifiable {
        case plainText
        case imageText

        var id: Self { self }

        /// 分段控件标题（中文，需求 1.1）。
        var label: String {
            switch self {
            case .plainText: return "纯文本"
            case .imageText: return "图文"
            }
        }
    }

    /// 当前纪要是否含可生成展示的可视化内容（时间线 / 思维导图 / 关键数字至少一项非空）。
    var hasVisuals: Bool {
        NoteDetailView.hasVisuals(note.visuals)
    }

    /// 纯逻辑判断：可视化数据三类是否至少一项有内容，便于复用与测试（需求 14.5）。
    static func hasVisuals(_ visuals: NoteVisuals?) -> Bool {
        guard let visuals else { return false }
        let hasTimeline = !(visuals.timeline?.isEmpty ?? true)
        let hasMindmap = visuals.mindmap != nil
        let hasKeyNumbers = !(visuals.keyNumbers?.isEmpty ?? true)
        return hasTimeline || hasMindmap || hasKeyNumbers
    }
}

private extension NoteDetailView {
    /// 顶部工具行：左侧为纯文本 / 图文模式切换，右侧为复制全文 / 导出 Markdown 操作（需求 13.1、13.2、14.1）。
    var toolbarRow: some View {
        HStack(spacing: tokens.spacingUnit) {
            modePicker
            Spacer(minLength: tokens.spacingUnit)
            actionButtons
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 复制全文 / 导出 Markdown 动作区（需求 13.1、13.2）。
    var actionButtons: some View {
        HStack(spacing: tokens.spacingUnit) {
            // 复制全文：写入系统剪贴板（需求 13.1）。
            Button {
                NoteExporter.copyToPasteboard(NoteExporter.plainText(of: note))
            } label: {
                Label("复制全文", systemImage: "doc.on.doc")
                    .font(.callout)
                    .foregroundColor(tokens.accentPrimary)
            }
            .buttonStyle(.plain)
            .help("将纪要全文复制到剪贴板")

            // 导出 Markdown：弹出保存面板导出为 .md 文件（需求 13.2）。
            Button {
                NoteExporter.exportMarkdown(note)
            } label: {
                Label("导出 Markdown", systemImage: "square.and.arrow.up")
                    .font(.callout)
                    .foregroundColor(tokens.accentPrimary)
            }
            .buttonStyle(.plain)
            .help("将纪要导出为 Markdown 文件")
        }
    }

    /// 纯文本 / 图文分段切换控件（需求 14.1）。
    var modePicker: some View {
        Picker("展示模式", selection: $mode) {
            ForEach(DisplayMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }

    /// 图文模式下的可视化区：有内容则渲染 `NoteVisualsView`，否则提示无可视化内容（需求 14.2、14.5）。
    @ViewBuilder
    var visualsSection: some View {
        if let visuals = note.visuals, hasVisuals {
            NoteVisualsView(visuals: visuals)
        } else {
            Text("该纪要暂无可视化内容")
                .font(.callout)
                .foregroundColor(tokens.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 正文区块模型（需求 12.2、12.3）

extension NoteDetailView {
    /// 正文的一个有序区块：要么是文字分区，要么是结构化待办列表。
    enum DetailBlock {
        /// 文字分区（标题 + 正文，可能带重点标记）。
        case section(NoteSection)
        /// 结构化待办列表，`heading` 为该区块标题。
        case todos(heading: String)
    }

    /// 按模板分区顺序排好的正文区块。
    ///
    /// 规则：
    /// 1. 沿 `note.sections` 顺序遍历。若某分区标题表示「待办」且确有待办数据，
    ///    则在该位置以结构化待办列表替代纯文字分区（需求 12.4）。
    /// 2. 若遍历完仍未放入待办且存在待办数据，则补一个待办区块——默认模板按
    ///    会议摘要 / 关键决策 / 待办事项 / 讨论要点 的顺序插到「讨论要点」之前
    ///    （需求 12.3），其余模板追加到末尾。
    var contentBlocks: [DetailBlock] {
        var blocks: [DetailBlock] = []
        var todosPlaced = false

        for section in note.sections {
            if !todosPlaced, !note.todos.isEmpty, NoteDetailView.isTodoHeading(section.heading) {
                blocks.append(.todos(heading: NoteDetailView.todoHeading(from: section.heading)))
                todosPlaced = true
            } else {
                blocks.append(.section(section))
            }
        }

        if !todosPlaced, !note.todos.isEmpty {
            let todosBlock = DetailBlock.todos(heading: "待办事项")
            if NoteDetailView.isDefaultTemplate(note.templateId),
               let index = blocks.firstIndex(where: { block in
                   if case let .section(section) = block {
                       return section.heading.contains("讨论要点")
                   }
                   return false
               }) {
                blocks.insert(todosBlock, at: index)
            } else {
                blocks.append(todosBlock)
            }
        }

        return blocks
    }

    /// 渲染单个正文区块。
    @ViewBuilder
    func contentBlock(_ block: DetailBlock) -> some View {
        switch block {
        case let .section(section):
            sectionView(section)
        case let .todos(heading):
            todosView(heading: heading)
        }
    }
}

// MARK: - 标题与元信息（需求 12.1）

private extension NoteDetailView {
    /// 标题 + 日期 / 时间段 / 时长元信息行。
    var header: some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit) {
            Text(displayTitle)
                .font(.title2.bold())
                .foregroundColor(tokens.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: tokens.spacingUnit * 0.5) {
                Image(systemName: "calendar")
                    .font(.caption)
                Text(NoteDetailView.metaText(startedAt: note.startedAt, duration: note.duration))
                    .font(.caption)
            }
            .foregroundColor(tokens.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var displayTitle: String {
        let trimmed = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名会议" : trimmed
    }
}

// MARK: - 文字分区（需求 12.2、7.4）

private extension NoteDetailView {
    /// 单个文字分区：标题（命中重点标记则标注「重点」）+ 正文。
    func sectionView(_ section: NoteSection) -> some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit) {
            HStack(spacing: tokens.spacingUnit) {
                Text(section.heading)
                    .font(.headline)
                    .foregroundColor(tokens.textPrimary)
                if section.isHighlighted {
                    highlightBadge
                }
            }
            Text(section.content)
                .font(.body)
                .foregroundColor(tokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 重点标记角标（需求 7.4）。
    var highlightBadge: some View {
        Text("重点")
            .font(.caption2.bold())
            .foregroundColor(tokens.recording)
            .padding(.horizontal, tokens.spacingUnit * 0.75)
            .padding(.vertical, tokens.spacingUnit * 0.25)
            .background(Capsule().fill(tokens.recording.opacity(0.15)))
    }
}

// MARK: - 待办事项（需求 12.4）

private extension NoteDetailView {
    /// 结构化待办列表：每条待办带勾选框、内容，以及责任人 / 截止时间（若有）。
    func todosView(heading: String) -> some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit) {
            Text(heading)
                .font(.headline)
                .foregroundColor(tokens.textPrimary)
            ForEach(Array(note.todos.enumerated()), id: \.offset) { _, todo in
                todoRow(todo)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 单条待办行：勾选框 + 内容 +（责任人 / 截止时间）。
    func todoRow(_ todo: TodoItem) -> some View {
        HStack(alignment: .top, spacing: tokens.spacingUnit) {
            Image(systemName: todo.done ? "checkmark.square.fill" : "square")
                .foregroundColor(todo.done ? tokens.accentPrimary : tokens.textSecondary)
            VStack(alignment: .leading, spacing: tokens.spacingUnit * 0.25) {
                Text(todo.text)
                    .font(.body)
                    .foregroundColor(tokens.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let meta = NoteDetailView.todoMeta(todo) {
                    Text(meta)
                        .font(.caption)
                        .foregroundColor(tokens.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - 分区编排辅助（可复用纯逻辑）

extension NoteDetailView {
    /// 判断模板标识是否为默认模板（兼容 `builtin.default` 与历史短标识 `default`）。
    static func isDefaultTemplate(_ templateId: String) -> Bool {
        templateId == TemplateManager.BuiltinID.default || templateId == "default"
    }

    /// 判断分区标题是否表示「待办」分区。
    static func isTodoHeading(_ heading: String) -> Bool {
        heading.trimmingCharacters(in: .whitespacesAndNewlines).contains("待办")
    }

    /// 待办区块标题：沿用分区原标题，去空白后为空则回落为「待办事项」。
    static func todoHeading(from heading: String) -> String {
        let trimmed = heading.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "待办事项" : trimmed
    }
}

// MARK: - 文本格式化（可复用纯逻辑）

extension NoteDetailView {
    /// 元信息文案：日期 + 时间段 + 时长（如 2026年5月29日 14:30-15:32 · 1小时2分）。
    static func metaText(startedAt: Date, duration: TimeInterval) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")
        dateFormatter.dateFormat = "yyyy年M月d日"

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "zh_CN")
        timeFormatter.dateFormat = "HH:mm"

        let endDate = startedAt.addingTimeInterval(max(duration, 0))
        let dateText = dateFormatter.string(from: startedAt)
        let span = "\(timeFormatter.string(from: startedAt))-\(timeFormatter.string(from: endDate))"
        return "\(dateText) \(span) · \(durationText(duration))"
    }

    /// 时长中文展示（与列表行口径一致）。
    static func durationText(_ duration: TimeInterval) -> String {
        let totalSeconds = max(Int(duration.rounded()), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)小时\(minutes)分" : "\(hours)小时"
        }
        if minutes > 0 {
            return "\(minutes)分"
        }
        return "\(seconds)秒"
    }

    /// 待办的责任人 / 截止时间附注，二者皆缺则为 nil。
    static func todoMeta(_ todo: TodoItem) -> String? {
        var parts: [String] = []
        if let owner = todo.owner?.trimmingCharacters(in: .whitespacesAndNewlines), !owner.isEmpty {
            parts.append("负责人：\(owner)")
        }
        if let due = todo.dueDate?.trimmingCharacters(in: .whitespacesAndNewlines), !due.isEmpty {
            parts.append("截止：\(due)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

#if DEBUG
/// 预览样例数据：默认模板纪要，覆盖会议摘要 / 关键决策（重点标记）/ 待办事项 / 讨论要点四分区。
/// 用经典 `PreviewProvider` 而非 `#Preview` 宏，以兼容仅装有 Command Line Tools 的构建环境。
private enum NoteDetailPreviewData {
    static let note = MeetingNote(
        id: UUID(),
        title: "Q3 路线图评审",
        startedAt: Date(timeIntervalSince1970: 1_748_500_200),
        duration: 3720,
        audioPath: "/notes/preview/audio.wav",
        transcriptPath: "/notes/preview/transcript.txt",
        templateId: "builtin.default",
        sections: [
            NoteSection(heading: "会议摘要", content: "评审了 Q3 路线图与资源排布，确认优先推进支付重构。", isHighlighted: false),
            NoteSection(heading: "关键决策", content: "确定优先上线支付重构，搜索优化顺延至 Q4。", isHighlighted: true),
            NoteSection(heading: "讨论要点", content: "围绕排期与人力展开，QA 资源是主要约束。", isHighlighted: false)
        ],
        todos: [
            TodoItem(text: "拆解支付重构里程碑", done: false, owner: "李雷", dueDate: "本周五"),
            TodoItem(text: "同步搜索优化顺延结论", done: true, owner: nil, dueDate: nil)
        ],
        highlights: [620],
        visuals: nil
    )

    /// 含可视化数据的纪要：用于预览图文模式（时间线 / 思维导图 / 关键数字齐备）。
    static let noteWithVisuals = MeetingNote(
        id: UUID(),
        title: "Q3 路线图评审（图文）",
        startedAt: Date(timeIntervalSince1970: 1_748_500_200),
        duration: 3720,
        audioPath: "/notes/preview/audio.wav",
        transcriptPath: "/notes/preview/transcript.txt",
        templateId: "builtin.default",
        sections: [
            NoteSection(heading: "会议摘要", content: "评审了 Q3 路线图与资源排布，确认优先推进支付重构。", isHighlighted: false),
            NoteSection(heading: "关键决策", content: "确定优先上线支付重构，搜索优化顺延至 Q4。", isHighlighted: true),
            NoteSection(heading: "讨论要点", content: "围绕排期与人力展开，QA 资源是主要约束。", isHighlighted: false)
        ],
        todos: [
            TodoItem(text: "拆解支付重构里程碑", done: false, owner: "李雷", dueDate: "本周五")
        ],
        highlights: [620],
        visuals: NoteVisuals(
            timeline: [
                TimelineNode(time: "00:05", title: "开场与目标对齐", detail: "确认本次评审范围。"),
                TimelineNode(time: "00:20", title: "支付重构讨论", detail: nil),
                TimelineNode(time: "00:48", title: "排期与人力", detail: "QA 资源是主要约束。")
            ],
            mindmap: MindmapNode(
                title: "Q3 路线图",
                children: [
                    MindmapNode(title: "支付重构", children: [
                        MindmapNode(title: "里程碑拆解", children: []),
                        MindmapNode(title: "风险点", children: [])
                    ]),
                    MindmapNode(title: "搜索优化", children: [
                        MindmapNode(title: "顺延至 Q4", children: [])
                    ])
                ]
            ),
            keyNumbers: [
                KeyNumber(label: "目标转化率", value: "15%", note: "环比提升 3 个百分点"),
                KeyNumber(label: "待办数量", value: "2 个", note: nil)
            ]
        )
    )
}

struct NoteDetailView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NoteDetailView(note: NoteDetailPreviewData.note)
                .frame(width: 520, height: 480)
                .themeTokens(.light)
                .previewDisplayName("默认模板纪要-浅色")

            NoteDetailView(note: NoteDetailPreviewData.note)
                .frame(width: 520, height: 480)
                .themeTokens(.dark)
                .previewDisplayName("默认模板纪要-深色")

            NoteDetailView(note: NoteDetailPreviewData.noteWithVisuals)
                .frame(width: 520, height: 600)
                .themeTokens(.light)
                .previewDisplayName("含可视化纪要-浅色")
        }
    }
}
#endif
