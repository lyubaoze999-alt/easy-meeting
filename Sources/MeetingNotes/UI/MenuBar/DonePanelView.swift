import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// 菜单栏面板「完成态」内容视图（界面层，任务 14.4，需求 10.1-10.4）。
///
/// 作为 `MenuBarPanelView` 在 `.finished` 且 `ProcessingPipeline.stage == .done` 时的内容主体
/// （外壳的标题栏、分隔线、外边距与固定宽度由 `MenuBarPanelView` 提供）。自上而下展示：
/// - 完成提示：对勾图标 +「纪要已生成」成功标题（需求 10.1）；
/// - 会议标题与会议时长：展示 `note.title` 与格式化时长（需求 10.1）；
/// - 纪要预览：会议摘要（命中「摘要」分区，否则退回首个分区正文）与前两条待办（需求 10.2）；
/// - 「查看完整纪要」按钮：触发 `onViewFull`，由上层在纪要库中打开该条纪要（需求 10.3）；
/// - 「复制」按钮：触发 `onCopy`，把纪要内容写入系统剪贴板（需求 10.4）。
///
/// 纯展示视图：纪要经 `init` 注入，两个操作经回调上抛，不直接持有业务服务，便于预览与测试。
/// 取色全部来自 `@Environment(\.themeTokens)`，不写死色值（需求 17.4）；文案均为中文（需求 1.1）。
struct DonePanelView: View {
    @Environment(\.themeTokens) private var tokens

    /// 已生成并落库的纪要（需求 10.1、10.2）。
    private let note: MeetingNote
    /// 点击「查看完整纪要」：在纪要库中打开该条纪要（需求 10.3）。
    private let onViewFull: () -> Void
    /// 点击「复制」：将纪要内容复制到系统剪贴板（需求 10.4）。
    private let onCopy: () -> Void

    /// - Parameters:
    ///   - note: 已生成的纪要。
    ///   - onViewFull: 「查看完整纪要」回调，默认无操作。
    ///   - onCopy: 「复制」回调，默认把纪要的纯文本表示写入剪贴板（`DonePanelView.copyToPasteboard`）。
    init(note: MeetingNote,
         onViewFull: @escaping () -> Void = {},
         onCopy: (() -> Void)? = nil) {
        self.note = note
        self.onViewFull = onViewFull
        self.onCopy = onCopy ?? { DonePanelView.copyToPasteboard(note) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit * 2) {
            successHeader
            metaSection
            previewSection
            actionButtons
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 完成提示与会议元信息（需求 10.1）

private extension DonePanelView {
    /// 完成提示：对勾图标 +「纪要已生成」成功标题（需求 10.1）。
    var successHeader: some View {
        HStack(spacing: tokens.spacingUnit) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(tokens.accentPrimary)
            Text("纪要已生成")
                .font(.title3.bold())
                .foregroundColor(tokens.textPrimary)
            Spacer(minLength: 0)
        }
    }

    /// 会议标题与会议时长（需求 10.1）。标题为空时退回占位文案，时长格式化为 mm:ss / hh:mm:ss。
    var metaSection: some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit * 0.5) {
            Text(displayTitle)
                .font(.headline)
                .foregroundColor(tokens.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: tokens.spacingUnit * 0.5) {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(tokens.textSecondary)
                Text("会议时长 \(durationText)")
                    .font(.caption)
                    .foregroundColor(tokens.textSecondary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 会议标题展示文案，标题为空白时退回占位。
    var displayTitle: String {
        let trimmed = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名会议" : trimmed
    }

    /// 录音时长的中文展示（mm:ss 或 hh:mm:ss）。
    var durationText: String {
        DonePanelView.formatDuration(note.duration)
    }
}

// MARK: - 纪要预览：摘要 + 前两条待办（需求 10.2）

private extension DonePanelView {
    /// 纪要预览区：会议摘要 + 前两条待办（需求 10.2）。
    var previewSection: some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit * 1.25) {
            summaryCard
            todosCard
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 会议摘要卡片：命中「摘要」分区的正文，否则退回首个分区正文（需求 10.2）。
    var summaryCard: some View {
        previewCard(iconName: "doc.text", title: "会议摘要") {
            Text(summaryText)
                .font(.callout)
                .foregroundColor(tokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 前两条待办卡片（需求 10.2）。无待办时展示占位文案。
    @ViewBuilder
    var todosCard: some View {
        previewCard(iconName: "checklist", title: "待办事项") {
            if previewTodos.isEmpty {
                Text("暂无待办事项")
                    .font(.callout)
                    .foregroundColor(tokens.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: tokens.spacingUnit) {
                    ForEach(Array(previewTodos.enumerated()), id: \.offset) { _, todo in
                        todoRow(todo)
                    }
                }
            }
        }
    }

    /// 单条待办：勾选框图标 + 待办内容 +（责任人 / 截止时间，若有）。
    func todoRow(_ todo: TodoItem) -> some View {
        HStack(alignment: .top, spacing: tokens.spacingUnit) {
            Image(systemName: todo.done ? "checkmark.square.fill" : "square")
                .font(.callout)
                .foregroundColor(todo.done ? tokens.accentPrimary : tokens.textSecondary)
            VStack(alignment: .leading, spacing: tokens.spacingUnit * 0.25) {
                Text(todo.text)
                    .font(.callout)
                    .foregroundColor(tokens.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let meta = todoMeta(todo) {
                    Text(meta)
                        .font(.caption)
                        .foregroundColor(tokens.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// 待办的责任人 / 截止时间附注，二者皆缺则为 nil。
    func todoMeta(_ todo: TodoItem) -> String? {
        var parts: [String] = []
        if let owner = todo.owner?.trimmingCharacters(in: .whitespacesAndNewlines), !owner.isEmpty {
            parts.append("负责人：\(owner)")
        }
        if let due = todo.dueDate?.trimmingCharacters(in: .whitespacesAndNewlines), !due.isEmpty {
            parts.append("截止：\(due)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// 摘要文本：优先命中标题包含「摘要」的分区，否则退回首个分区正文；都没有则占位。
    var summaryText: String {
        DonePanelView.summary(of: note)
    }

    /// 预览展示的前两条待办（需求 10.2）。
    var previewTodos: [TodoItem] {
        Array(note.todos.prefix(2))
    }

    /// 通用预览卡片外壳：图标 + 标题 + 自定义内容。
    func previewCard<Content: View>(iconName: String,
                                    title: String,
                                    @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit) {
            HStack(spacing: tokens.spacingUnit * 0.75) {
                Image(systemName: iconName)
                    .foregroundColor(tokens.accentPrimary)
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(tokens.textPrimary)
            }
            content()
        }
        .padding(tokens.spacingUnit * 1.5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: tokens.cornerRadius)
                .fill(tokens.surface)
        )
    }
}

// MARK: - 操作按钮：查看完整纪要 / 复制（需求 10.3、10.4）

private extension DonePanelView {
    /// 底部操作区：「查看完整纪要」（主操作）+「复制」（次操作）。
    var actionButtons: some View {
        HStack(spacing: tokens.spacingUnit * 1.5) {
            Button(action: onViewFull) {
                Text("查看完整纪要")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, tokens.spacingUnit * 1.25)
                    .background(
                        RoundedRectangle(cornerRadius: tokens.cornerRadius)
                            .fill(tokens.accentPrimary)
                    )
            }
            .buttonStyle(.plain)

            Button(action: onCopy) {
                HStack(spacing: tokens.spacingUnit * 0.5) {
                    Image(systemName: "doc.on.doc")
                    Text("复制")
                        .fontWeight(.medium)
                }
                .foregroundColor(tokens.accentPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, tokens.spacingUnit * 1.25)
                .background(
                    RoundedRectangle(cornerRadius: tokens.cornerRadius)
                        .stroke(tokens.accentPrimary, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 摘要提取 / 时长格式化 / 剪贴板写入（可复用的纯逻辑）

extension DonePanelView {
    /// 提取会议摘要：优先返回标题含「摘要」的分区正文，否则退回首个非空分区正文；都没有则占位（需求 10.2）。
    static func summary(of note: MeetingNote) -> String {
        if let summarySection = note.sections.first(where: { $0.heading.contains("摘要") }),
           !summarySection.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return summarySection.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let firstSection = note.sections.first(where: {
            !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) {
            return firstSection.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "暂无摘要内容"
    }

    /// 把秒数格式化为 mm:ss 或 hh:mm:ss（与处理态时长展示口径一致）。
    static func formatDuration(_ duration: TimeInterval) -> String {
        let total = max(Int(duration.rounded()), 0)
        let seconds = total % 60
        let minutes = (total / 60) % 60
        let hours = total / 3600
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// 构建纪要的纯文本表示：标题、各分区、待办，逐行拼接（需求 10.4 的默认复制内容）。
    static func plainText(of note: MeetingNote) -> String {
        var lines: [String] = []
        let title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        lines.append(title.isEmpty ? "未命名会议" : title)
        lines.append("会议时长 \(formatDuration(note.duration))")

        for section in note.sections {
            let heading = section.heading.trimmingCharacters(in: .whitespacesAndNewlines)
            let content = section.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !heading.isEmpty || !content.isEmpty else { continue }
            lines.append("")
            if !heading.isEmpty { lines.append("【\(heading)】") }
            if !content.isEmpty { lines.append(content) }
        }

        if !note.todos.isEmpty {
            lines.append("")
            lines.append("【待办事项】")
            for todo in note.todos {
                var line = todo.done ? "[x] " : "[ ] "
                line += todo.text
                var meta: [String] = []
                if let owner = todo.owner?.trimmingCharacters(in: .whitespacesAndNewlines), !owner.isEmpty {
                    meta.append("负责人：\(owner)")
                }
                if let due = todo.dueDate?.trimmingCharacters(in: .whitespacesAndNewlines), !due.isEmpty {
                    meta.append("截止：\(due)")
                }
                if !meta.isEmpty { line += "（\(meta.joined(separator: " "))）" }
                lines.append(line)
            }
        }

        return lines.joined(separator: "\n")
    }

    /// 默认复制实现：把纪要的纯文本表示写入系统剪贴板（需求 10.4）。
    /// 仅在可导入 AppKit 的平台（macOS）生效，其余平台为无操作以保证可构建。
    static func copyToPasteboard(_ note: MeetingNote) {
        #if canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(plainText(of: note), forType: .string)
        #endif
    }
}

#if DEBUG
/// 预览：覆盖含摘要 / 待办的完整纪要与缺摘要场景，验证完成提示、预览块与操作按钮在浅 / 深主题下的呈现。
///
/// 用经典 `PreviewProvider` 而非 `#Preview` 宏，以兼容仅装有 Command Line Tools 的构建环境。
struct DonePanelView_Previews: PreviewProvider {
    private static func sampleNote(withSummary: Bool = true) -> MeetingNote {
        MeetingNote(
            id: UUID(),
            title: "Q3 产品规划评审会",
            startedAt: Date(),
            duration: 3725,
            audioPath: "",
            transcriptPath: "",
            templateId: "default",
            sections: withSummary
                ? [
                    NoteSection(heading: "会议摘要",
                                content: "本次会议确认了 Q3 产品主线聚焦于离线处理体验优化，并就资源排期达成一致。",
                                isHighlighted: false),
                    NoteSection(heading: "关键决策", content: "优先交付完成态面板。", isHighlighted: true)
                ]
                : [
                    NoteSection(heading: "讨论要点",
                                content: "围绕菜单栏面板四态切换展开讨论。",
                                isHighlighted: false)
                ],
            todos: [
                TodoItem(text: "整理完成态面板交付排期", done: false, owner: "小林", dueDate: "本周五"),
                TodoItem(text: "补充完成态单元测试", done: false, owner: nil, dueDate: nil),
                TodoItem(text: "第三条不应展示", done: true, owner: nil, dueDate: nil)
            ],
            highlights: [],
            visuals: nil
        )
    }

    static var previews: some View {
        Group {
            DonePanelView(note: sampleNote())
                .padding()
                .frame(width: 360)
                .themeTokens(.light)
                .previewDisplayName("完成态-含摘要-浅色")

            DonePanelView(note: sampleNote(withSummary: false))
                .padding()
                .frame(width: 360)
                .themeTokens(.dark)
                .previewDisplayName("完成态-退回首分区-深色")
        }
    }
}
#endif
