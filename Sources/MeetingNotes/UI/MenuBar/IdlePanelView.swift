import SwiftUI

/// 菜单栏面板「待机态」内容视图（界面层，任务 14.1，需求 3.4、4.1-4.8）。
///
/// 作为 `MenuBarPanelView` 在 `.idle` 分支的内容主体（外壳的标题栏、分隔线、外边距与
/// 固定宽度由 `MenuBarPanelView` 提供），本视图自上而下展示：
/// - 「开始记录」主操作按钮（需求 4.1），点击触发 `onStartRecording`，由上层进入录音态（需求 4.8）；
/// - 系统声音与麦克风各自的就绪状态，未授权时标识「未就绪 / 未授予」（需求 3.4、4.2）；
/// - 最近 3 条纪要列表（需求 4.3），点击某条触发 `onOpenNote` 打开详情（需求 4.4）；
/// - 当前转写服务模型名与「查看全部」入口（需求 4.5），点击触发 `onOpenLibrary` 打开纪要库（需求 4.6）；
/// - 设置入口（需求 4.7），点击触发 `onOpenSettings`。
///
/// 纯展示视图：数据经 `init` 注入、交互经回调上抛，不直接持有业务服务，便于预览与测试。
/// 真实数据源与回调由上层（任务 18.1）接通。取色全部来自 `@Environment(\.themeTokens)`，
/// 不写死色值（需求 17.4）；自有文案均为中文（需求 1.1）。
struct IdlePanelView: View {
    @Environment(\.themeTokens) private var tokens

    /// 最近纪要，调用方应已截取为最多 3 条（需求 4.3）。
    private let recentNotes: [MeetingNote]
    /// 双音源就绪情况，决定系统声音 / 麦克风的就绪标识（需求 3.4、4.2）。
    private let readiness: AudioSourceReadiness
    /// 当前转写服务模型名，按用户输入原样展示（需求 4.5、1.2）。
    private let transcriptionModelName: String

    /// 点击「开始记录」（需求 4.1、4.8）。
    private let onStartRecording: () -> Void
    /// 点击某条最近纪要，打开其详情（需求 4.4）。
    private let onOpenNote: (MeetingNote) -> Void
    /// 点击「查看全部」，打开纪要库（需求 4.6）。
    private let onOpenLibrary: () -> Void
    /// 点击设置入口（需求 4.7）。
    private let onOpenSettings: () -> Void

    /// - Parameters:
    ///   - recentNotes: 最近纪要（最多 3 条）。
    ///   - readiness: 双音源就绪情况。
    ///   - transcriptionModelName: 当前转写模型名。
    ///   - onStartRecording: 开始记录回调。
    ///   - onOpenNote: 打开纪要详情回调。
    ///   - onOpenLibrary: 打开纪要库回调。
    ///   - onOpenSettings: 打开设置回调。
    init(recentNotes: [MeetingNote],
         readiness: AudioSourceReadiness,
         transcriptionModelName: String,
         onStartRecording: @escaping () -> Void = {},
         onOpenNote: @escaping (MeetingNote) -> Void = { _ in },
         onOpenLibrary: @escaping () -> Void = {},
         onOpenSettings: @escaping () -> Void = {}) {
        self.recentNotes = recentNotes
        self.readiness = readiness
        self.transcriptionModelName = transcriptionModelName
        self.onStartRecording = onStartRecording
        self.onOpenNote = onOpenNote
        self.onOpenLibrary = onOpenLibrary
        self.onOpenSettings = onOpenSettings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit * 2) {
            startButton
            readinessSection
            recentNotesSection
            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 开始记录（需求 4.1、4.8）

private extension IdlePanelView {
    /// 「开始记录」主操作按钮：主色填充、占满宽度，点击进入录音态（需求 4.1、4.8）。
    var startButton: some View {
        Button(action: onStartRecording) {
            HStack(spacing: tokens.spacingUnit) {
                Image(systemName: "record.circle.fill")
                Text("开始记录")
                    .fontWeight(.semibold)
            }
            .foregroundColor(tokens.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, tokens.spacingUnit * 1.5)
            .background(
                RoundedRectangle(cornerRadius: tokens.cornerRadius)
                    .fill(tokens.accentPrimary)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 音源就绪状态（需求 3.4、4.2）

private extension IdlePanelView {
    /// 系统声音与麦克风的就绪状态区：各展示一行，未授权时标识未就绪（需求 3.4、4.2）。
    var readinessSection: some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit) {
            AudioSourceRow(
                title: "系统声音",
                iconName: "speaker.wave.2.fill",
                status: readiness.systemAudio
            )
            AudioSourceRow(
                title: "麦克风",
                iconName: "mic.fill",
                status: readiness.microphone
            )
        }
        .padding(tokens.spacingUnit * 1.5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: tokens.cornerRadius)
                .fill(tokens.surface)
        )
    }
}

/// 单个音源的就绪状态行：图标 + 名称 + 就绪徽标。
private struct AudioSourceRow: View {
    @Environment(\.themeTokens) private var tokens

    let title: String
    let iconName: String
    let status: PermissionStatus

    var body: some View {
        HStack(spacing: tokens.spacingUnit) {
            Image(systemName: iconName)
                .foregroundColor(tokens.textSecondary)
            Text(title)
                .font(.subheadline)
                .foregroundColor(tokens.textPrimary)
            Spacer()
            statusBadge
        }
    }

    /// 就绪徽标：已授权显示「已就绪」，未授权显示「未就绪 / 未授予」（需求 3.4、4.2）。
    private var statusBadge: some View {
        Text(statusText)
            .font(.caption.bold())
            .foregroundColor(statusColor)
            .padding(.horizontal, tokens.spacingUnit)
            .padding(.vertical, tokens.spacingUnit * 0.5)
            .background(
                Capsule().fill(statusColor.opacity(0.15))
            )
    }

    /// 状态中文文案：已授权为就绪，已拒绝 / 未决定均标识未就绪并点出未授予（需求 3.4、1.1）。
    private var statusText: String {
        switch status {
        case .authorized: return "已就绪"
        case .denied: return "未就绪 · 未授予"
        case .notDetermined: return "未就绪 · 未授予"
        }
    }

    /// 状态色：就绪用主色，未就绪用录制红提示需处理（需求 17.4）。
    private var statusColor: Color {
        switch status {
        case .authorized: return tokens.accentPrimary
        case .denied, .notDetermined: return tokens.recording
        }
    }
}

// MARK: - 最近纪要（需求 4.3、4.4）

private extension IdlePanelView {
    /// 最近纪要区：标题行 + 最多 3 条列表；无纪要时展示中文空态（需求 4.3、1.1）。
    var recentNotesSection: some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit) {
            Text("最近纪要")
                .font(.subheadline.bold())
                .foregroundColor(tokens.textPrimary)

            if recentNotes.isEmpty {
                Text("还没有纪要，开始一次录音试试。")
                    .font(.callout)
                    .foregroundColor(tokens.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, tokens.spacingUnit)
            } else {
                VStack(spacing: tokens.spacingUnit * 0.75) {
                    ForEach(recentNotes) { note in
                        RecentNoteRow(note: note) { onOpenNote(note) }
                    }
                }
            }
        }
    }
}

/// 单条最近纪要行：标题 + 时间 / 时长，点击打开详情（需求 4.4）。
private struct RecentNoteRow: View {
    @Environment(\.themeTokens) private var tokens

    let note: MeetingNote
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: tokens.spacingUnit) {
                VStack(alignment: .leading, spacing: tokens.spacingUnit * 0.25) {
                    Text(note.title)
                        .font(.subheadline)
                        .foregroundColor(tokens.textPrimary)
                        .lineLimit(1)
                    Text("\(Self.dateText(note.startedAt)) · \(Self.durationText(note.duration))")
                        .font(.caption)
                        .foregroundColor(tokens.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(tokens.textSecondary)
            }
            .padding(tokens.spacingUnit)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: tokens.cornerRadius)
                    .fill(tokens.surface)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 纪要开始时间的中文展示（如 5月29日 14:30）。
    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }

    /// 时长的中文展示（如 1小时5分 / 12分 / 45秒）。
    private static func durationText(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded())
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
}

// MARK: - 底部：模型名 / 查看全部 / 设置（需求 4.5、4.6、4.7）

private extension IdlePanelView {
    /// 底部信息条：左侧转写模型名（需求 4.5），右侧「查看全部」（需求 4.6）与设置（需求 4.7）入口。
    var footer: some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit) {
            Divider()
            HStack(spacing: tokens.spacingUnit) {
                modelLabel
                Spacer()
                Button("查看全部", action: onOpenLibrary)
                    .buttonStyle(.plain)
                    .font(.callout)
                    .foregroundColor(tokens.accentPrimary)

                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                        .foregroundColor(tokens.textSecondary)
                }
                .buttonStyle(.plain)
                .help("设置")
            }
        }
    }

    /// 当前转写模型名展示：未配置模型名时给出中文占位提示（需求 4.5、1.1、1.2）。
    var modelLabel: some View {
        let trimmed = transcriptionModelName.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: tokens.spacingUnit * 0.25) {
            Text("转写模型")
                .font(.caption)
                .foregroundColor(tokens.textSecondary)
            Text(trimmed.isEmpty ? "未配置" : trimmed)
                .font(.caption.bold())
                .foregroundColor(trimmed.isEmpty ? tokens.recording : tokens.textPrimary)
                .lineLimit(1)
        }
    }
}

#if DEBUG
/// 预览样例数据，便于在 Canvas 查看待机态的有 / 无纪要、就绪 / 未就绪组合。
private enum IdlePanelPreviewData {
    static func note(_ title: String, minutesAgo: Int, duration: TimeInterval) -> MeetingNote {
        MeetingNote(
            id: UUID(),
            title: title,
            startedAt: Date().addingTimeInterval(TimeInterval(-minutesAgo * 60)),
            duration: duration,
            audioPath: "",
            transcriptPath: "",
            templateId: "default",
            sections: [],
            todos: [],
            highlights: [],
            visuals: nil
        )
    }

    static let recentNotes: [MeetingNote] = [
        note("产品周会", minutesAgo: 30, duration: 3900),
        note("技术评审 · 音频采集方案", minutesAgo: 180, duration: 1500),
        note("候选人面试", minutesAgo: 1440, duration: 45)
    ]
}

/// 预览：覆盖「有纪要 + 全部就绪（浅色）」「无纪要 + 部分未授予（深色）」两种典型组合。
///
/// 用经典 `PreviewProvider` 而非 `#Preview` 宏，以兼容仅装有 Command Line Tools 的构建环境。
struct IdlePanelView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            IdlePanelView(
                recentNotes: IdlePanelPreviewData.recentNotes,
                readiness: AudioSourceReadiness(systemAudio: .authorized, microphone: .authorized),
                transcriptionModelName: "whisper-1"
            )
            .padding()
            .frame(width: 360)
            .themeTokens(.light)
            .previewDisplayName("有纪要-全部就绪")

            IdlePanelView(
                recentNotes: [],
                readiness: AudioSourceReadiness(systemAudio: .denied, microphone: .notDetermined),
                transcriptionModelName: ""
            )
            .padding()
            .frame(width: 360)
            .themeTokens(.dark)
            .previewDisplayName("无纪要-未授予-深色")
        }
    }
}
#endif
