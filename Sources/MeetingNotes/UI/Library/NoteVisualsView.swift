import SwiftUI

/// 图文模式可视化视图（界面层，任务 15.3，需求 14.2、14.3）。
///
/// 渲染纪要的 `NoteVisuals`：时间线、思维导图、关键数字三类可视化内容。
/// 三类内容均按需渲染——某类为 nil 或空时跳过该分区，仅展示已生成的内容（需求 14.2）。
/// 本视图为「附加」视图，由外层 `NoteDetailView` 在图文模式下叠加于完整文字正文之后，
/// 文字内容始终由 `NoteDetailView` 保留（需求 14.3，对应设计 Property 7）。
///
/// 取色全部来自 `@Environment(\.themeTokens)`（需求 17.4），分区标题为中文。
struct NoteVisualsView: View {
    @Environment(\.themeTokens) private var tokens

    let visuals: NoteVisuals

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit * 2) {
            if let timeline = visuals.timeline, !timeline.isEmpty {
                timelineSection(timeline)
            }
            if let mindmap = visuals.mindmap {
                mindmapSection(mindmap)
            }
            if let keyNumbers = visuals.keyNumbers, !keyNumbers.isEmpty {
                keyNumbersSection(keyNumbers)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 分区标题

private extension NoteVisualsView {
    func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundColor(tokens.textPrimary)
    }
}

// MARK: - 时间线（需求 14.2）

private extension NoteVisualsView {
    /// 时间线：纵向节点列表，每节点展示时间 + 标题 + 可选详情。
    func timelineSection(_ nodes: [TimelineNode]) -> some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit) {
            sectionTitle("时间线")
            VStack(alignment: .leading, spacing: tokens.spacingUnit * 1.5) {
                ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                    timelineRow(node)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func timelineRow(_ node: TimelineNode) -> some View {
        HStack(alignment: .top, spacing: tokens.spacingUnit) {
            Circle()
                .fill(tokens.accentPrimary)
                .frame(width: tokens.spacingUnit, height: tokens.spacingUnit)
                .padding(.top, tokens.spacingUnit * 0.5)
            VStack(alignment: .leading, spacing: tokens.spacingUnit * 0.25) {
                HStack(spacing: tokens.spacingUnit * 0.75) {
                    Text(node.time)
                        .font(.caption.bold())
                        .foregroundColor(tokens.accentPrimary)
                    Text(node.title)
                        .font(.body)
                        .foregroundColor(tokens.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let detail = node.detail?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(tokens.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - 思维导图（需求 14.2）

private extension NoteVisualsView {
    /// 思维导图：缩进式递归树，根节点为整图标题。
    func mindmapSection(_ root: MindmapNode) -> some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit) {
            sectionTitle("思维导图")
            mindmapNodeView(root, depth: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 递归渲染单个思维导图节点：按层级缩进，子节点依次展开。
    func mindmapNodeView(_ node: MindmapNode, depth: Int) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: tokens.spacingUnit * 0.5) {
                HStack(alignment: .top, spacing: tokens.spacingUnit * 0.5) {
                    Text(depth == 0 ? "●" : "–")
                        .font(.caption)
                        .foregroundColor(depth == 0 ? tokens.accentPrimary : tokens.textSecondary)
                    Text(node.title)
                        .font(depth == 0 ? .body.bold() : .body)
                        .foregroundColor(tokens.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(Array(node.children.enumerated()), id: \.offset) { _, child in
                    mindmapNodeView(child, depth: depth + 1)
                        .padding(.leading, tokens.spacingUnit * 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        )
    }
}

// MARK: - 关键数字（需求 14.2）

private extension NoteVisualsView {
    /// 关键数字：卡片列表，每卡片展示数值 + 标签 + 可选附注。
    func keyNumbersSection(_ numbers: [KeyNumber]) -> some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit) {
            sectionTitle("关键数字")
            VStack(alignment: .leading, spacing: tokens.spacingUnit) {
                ForEach(Array(numbers.enumerated()), id: \.offset) { _, number in
                    keyNumberCard(number)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func keyNumberCard(_ number: KeyNumber) -> some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit * 0.25) {
            Text(number.value)
                .font(.title3.bold())
                .foregroundColor(tokens.accentPrimary)
            Text(number.label)
                .font(.caption)
                .foregroundColor(tokens.textPrimary)
            if let note = number.note?.trimmingCharacters(in: .whitespacesAndNewlines),
               !note.isEmpty {
                Text(note)
                    .font(.caption2)
                    .foregroundColor(tokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(tokens.spacingUnit * 1.5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: tokens.cornerRadius)
                .fill(tokens.surface)
        )
    }
}

#if DEBUG
/// 预览样例：三类可视化内容齐备。用经典 `PreviewProvider` 以兼容仅装 Command Line Tools 的构建环境。
struct NoteVisualsView_Previews: PreviewProvider {
    static let sample = NoteVisuals(
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

    static var previews: some View {
        Group {
            NoteVisualsView(visuals: sample)
                .padding()
                .frame(width: 520)
                .themeTokens(.light)
                .previewDisplayName("可视化-浅色")

            NoteVisualsView(visuals: sample)
                .padding()
                .frame(width: 520)
                .themeTokens(.dark)
                .previewDisplayName("可视化-深色")
        }
    }
}
#endif
