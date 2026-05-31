import SwiftUI

/// 菜单栏面板「录音态 / 暂停态」内容视图（界面层，任务 14.2，需求 5.2、6.1-6.5、7.1）。
///
/// 作为 `MenuBarPanelView` 在 `.recording` 与 `.paused` 两个分支的内容主体（外壳的标题栏、
/// 分隔线、外边距与固定宽度由 `MenuBarPanelView` 提供）。两个分支同属一次录音会话，故共用本视图，
/// 仅按 `state` 区分录制中 / 已暂停的展示与「暂停 / 继续」按钮。自上而下展示：
/// - 录制中指示：区别于待机态的脉冲录制点 + 状态文案（需求 6.1）；
/// - 实时走动时长：由 `elapsedProvider` 每 0.1s 刷新，暂停时数值冻结（需求 6.2）；
/// - 音量波形：维护一段滚动样本缓冲，随系统 / 麦克风电平跳动（需求 5.2、6.3）；
/// - 系统 / 麦克风收音状态：分别标识「收音中 / 静音」（需求 5.2）；
/// - 当前模板与切换入口：展示所选模板名并提供菜单切换（需求 6.4、6.5）；
/// - 一键添加重点标记（需求 7.1）；
/// - 暂停 / 继续、结束并生成纪要（需求 6.6、6.7、6.8）。
///
/// 纯展示视图：数据经 `init` 注入、交互经回调上抛，不直接持有业务服务，便于预览与测试。
/// 取色全部来自 `@Environment(\.themeTokens)`，不写死色值（需求 17.4）；文案均为中文（需求 1.1）。
struct RecordingPanelView: View {
    @Environment(\.themeTokens) private var tokens

    /// 当前状态，仅取 `.recording` / `.paused`，决定录制指示与暂停 / 继续按钮（需求 6.1、6.6、6.7）。
    private let state: RecordingState
    /// 实时录音时长取值闭包：每个计时 tick 调用以读取最新已录时长（暂停时上游会冻结，需求 6.2）。
    private let elapsedProvider: () -> TimeInterval
    /// 系统声音当前电平（0...1），驱动波形跳动（需求 5.2、6.3）。
    private let systemLevel: Float
    /// 麦克风当前电平（0...1），驱动波形跳动（需求 5.2、6.3）。
    private let micLevel: Float
    /// 系统声音通路是否被标识为静音（需求 5.2、5.3）。
    private let systemSilent: Bool
    /// 麦克风通路是否被标识为静音（需求 5.2、5.4）。
    private let micSilent: Bool
    /// 本次录音所选模板（需求 6.4）。
    private let selectedTemplate: NoteTemplate
    /// 可切换的模板列表（需求 6.4、6.5）。
    private let availableTemplates: [NoteTemplate]

    /// 点击「暂停」（需求 6.6）。
    private let onPause: () -> Void
    /// 点击「继续」（需求 6.7）。
    private let onResume: () -> Void
    /// 点击「结束并生成纪要」（需求 6.8）。
    private let onStop: () -> Void
    /// 切换模板（需求 6.5）。
    private let onSelectTemplate: (NoteTemplate) -> Void
    /// 一键添加重点标记（需求 7.1）。
    private let onAddHighlight: () -> Void

    /// 当前展示的录音时长（秒），由计时器从 `elapsedProvider` 刷新。
    @State private var displayedElapsed: TimeInterval = 0
    /// 波形滚动样本缓冲（0...1），最新样本在尾部。
    @State private var samples: [Float] = Array(repeating: 0, count: RecordingPanelView.sampleCount)

    /// 波形样本数量（柱条数）。
    private static let sampleCount = 44
    /// 计时 / 采样节拍：10Hz，兼顾走动平滑与开销。
    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    /// - Parameters:
    ///   - state: 当前状态（`.recording` / `.paused`）。
    ///   - elapsedProvider: 读取实时录音时长的闭包。
    ///   - systemLevel / micLevel: 两路当前电平（0...1）。
    ///   - systemSilent / micSilent: 两路静音标识。
    ///   - selectedTemplate: 当前所选模板。
    ///   - availableTemplates: 可切换的模板列表。
    ///   - onPause / onResume / onStop / onSelectTemplate / onAddHighlight: 交互回调。
    init(state: RecordingState,
         elapsedProvider: @escaping () -> TimeInterval,
         systemLevel: Float,
         micLevel: Float,
         systemSilent: Bool,
         micSilent: Bool,
         selectedTemplate: NoteTemplate,
         availableTemplates: [NoteTemplate],
         onPause: @escaping () -> Void = {},
         onResume: @escaping () -> Void = {},
         onStop: @escaping () -> Void = {},
         onSelectTemplate: @escaping (NoteTemplate) -> Void = { _ in },
         onAddHighlight: @escaping () -> Void = {}) {
        self.state = state
        self.elapsedProvider = elapsedProvider
        self.systemLevel = systemLevel
        self.micLevel = micLevel
        self.systemSilent = systemSilent
        self.micSilent = micSilent
        self.selectedTemplate = selectedTemplate
        self.availableTemplates = availableTemplates
        self.onPause = onPause
        self.onResume = onResume
        self.onStop = onStop
        self.onSelectTemplate = onSelectTemplate
        self.onAddHighlight = onAddHighlight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit * 1.75) {
            indicatorRow
            timerLabel
            waveformSection
            sourceStatusSection
            templateRow
            highlightButton
            controlButtons
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { displayedElapsed = elapsedProvider() }
        .onReceive(ticker) { _ in tick() }
    }

    /// 计时节拍处理：刷新时长展示并向波形缓冲追加一个样本（录音中取实时电平，暂停则归零回落）。
    private func tick() {
        displayedElapsed = elapsedProvider()
        let nextSample: Float = state == .recording ? min(max(max(systemLevel, micLevel), 0), 1) : 0
        var updated = samples
        updated.removeFirst()
        updated.append(nextSample)
        samples = updated
    }
}

// MARK: - 录制中指示（需求 6.1）

private extension RecordingPanelView {
    /// 录制中状态指示：脉冲录制点 + 状态文案，区别于待机态（需求 6.1）。
    /// 录音中用录制红并持续脉冲；暂停时停摆并降为次要色，提示「已暂停」。
    var indicatorRow: some View {
        HStack(spacing: tokens.spacingUnit) {
            PulsingDot(color: state == .recording ? tokens.recording : tokens.textSecondary,
                       animated: state == .recording)
            Text(state == .recording ? "录制中" : "已暂停")
                .font(.title3.bold())
                .foregroundColor(state == .recording ? tokens.recording : tokens.textSecondary)
            Spacer()
        }
    }

    /// 实时走动时长：mm:ss（不足 1 小时）或 hh:mm:ss（满 1 小时），等宽数字避免抖动（需求 6.2）。
    var timerLabel: some View {
        Text(Self.formatDuration(displayedElapsed))
            .font(.system(size: 40, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(tokens.textPrimary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    /// 将秒数格式化为 mm:ss 或 hh:mm:ss（需求 6.2）。
    static func formatDuration(_ duration: TimeInterval) -> String {
        let total = max(0, Int(duration))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// 脉冲圆点：录音中以缩放 + 透明度做呼吸动画，作为录制中视觉指示（需求 6.1）。
private struct PulsingDot: View {
    let color: Color
    let animated: Bool
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .scaleEffect(animated && pulsing ? 1.25 : 0.85)
            .opacity(animated && pulsing ? 0.55 : 1)
            .animation(animated ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .default,
                       value: pulsing)
            .onAppear { pulsing = true }
    }
}

// MARK: - 音量波形（需求 5.2、6.3）

private extension RecordingPanelView {
    /// 音量波形区：一排随电平跳动的柱条，最新样本在右侧（需求 5.2、6.3）。
    var waveformSection: some View {
        WaveformView(samples: samples, barColor: tokens.recording, baselineColor: tokens.textSecondary)
            .frame(height: 48)
            .frame(maxWidth: .infinity)
            .padding(tokens.spacingUnit * 1.25)
            .background(
                RoundedRectangle(cornerRadius: tokens.cornerRadius)
                    .fill(tokens.surface)
            )
    }
}

/// 波形可视化：把 `samples`（0...1）映射为一排高度不一的柱条，随录音电平实时跳动（需求 6.3）。
private struct WaveformView: View {
    let samples: [Float]
    let barColor: Color
    let baselineColor: Color

    var body: some View {
        GeometryReader { proxy in
            let count = max(samples.count, 1)
            let spacing: CGFloat = 2
            let barWidth = max((proxy.size.width - spacing * CGFloat(count - 1)) / CGFloat(count), 1)
            let maxHeight = proxy.size.height
            let minHeight: CGFloat = 3

            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                    let level = CGFloat(min(max(sample, 0), 1))
                    let height = minHeight + level * (maxHeight - minHeight)
                    Capsule()
                        .fill(level > 0.02 ? barColor : baselineColor.opacity(0.35))
                        .frame(width: barWidth, height: height)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
        }
    }
}

// MARK: - 系统 / 麦克风收音状态（需求 5.2）

private extension RecordingPanelView {
    /// 双音源实时收音状态：分别标识系统声音、麦克风「收音中 / 静音」（需求 5.2、5.3、5.4）。
    var sourceStatusSection: some View {
        HStack(spacing: tokens.spacingUnit) {
            SourceStatusChip(title: "系统声音",
                             activeIcon: "speaker.wave.2.fill",
                             silentIcon: "speaker.slash.fill",
                             silent: systemSilent)
            SourceStatusChip(title: "麦克风",
                             activeIcon: "mic.fill",
                             silentIcon: "mic.slash.fill",
                             silent: micSilent)
        }
    }
}

/// 单个音源的收音状态徽标：收音中用主色，静音用次要色并标注「静音」（需求 5.2）。
private struct SourceStatusChip: View {
    @Environment(\.themeTokens) private var tokens

    let title: String
    let activeIcon: String
    let silentIcon: String
    let silent: Bool

    var body: some View {
        HStack(spacing: tokens.spacingUnit * 0.5) {
            Image(systemName: silent ? silentIcon : activeIcon)
                .font(.caption)
                .foregroundColor(silent ? tokens.textSecondary : tokens.accentPrimary)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(tokens.textSecondary)
                Text(silent ? "静音" : "收音中")
                    .font(.caption.bold())
                    .foregroundColor(silent ? tokens.textSecondary : tokens.accentPrimary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, tokens.spacingUnit)
        .padding(.vertical, tokens.spacingUnit * 0.75)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: tokens.cornerRadius)
                .fill(tokens.surface)
        )
    }
}

// MARK: - 当前模板与切换入口（需求 6.4、6.5）

private extension RecordingPanelView {
    /// 当前模板行：展示所选模板名 + 切换菜单（需求 6.4、6.5）。
    var templateRow: some View {
        HStack(spacing: tokens.spacingUnit) {
            Image(systemName: "doc.text")
                .foregroundColor(tokens.textSecondary)
            VStack(alignment: .leading, spacing: 0) {
                Text("纪要模板")
                    .font(.caption2)
                    .foregroundColor(tokens.textSecondary)
                Text(selectedTemplate.name)
                    .font(.subheadline.bold())
                    .foregroundColor(tokens.textPrimary)
                    .lineLimit(1)
            }
            Spacer()
            Menu {
                ForEach(availableTemplates) { template in
                    Button {
                        onSelectTemplate(template)
                    } label: {
                        if template.id == selectedTemplate.id {
                            Label(template.name, systemImage: "checkmark")
                        } else {
                            Text(template.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: tokens.spacingUnit * 0.5) {
                    Text("切换")
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .font(.callout)
                .foregroundColor(tokens.accentPrimary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(tokens.spacingUnit * 1.25)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: tokens.cornerRadius)
                .fill(tokens.surface)
        )
    }
}

// MARK: - 重点标记（需求 7.1）

private extension RecordingPanelView {
    /// 一键添加重点标记按钮（需求 7.1）：辅助操作，描边样式区别于主操作。
    var highlightButton: some View {
        Button(action: onAddHighlight) {
            HStack(spacing: tokens.spacingUnit) {
                Image(systemName: "bookmark.fill")
                Text("标记重点")
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

// MARK: - 暂停 / 继续、结束（需求 6.6、6.7、6.8）

private extension RecordingPanelView {
    /// 底部控制按钮：左侧暂停 / 继续随状态切换，右侧结束并生成纪要（需求 6.6、6.7、6.8）。
    var controlButtons: some View {
        HStack(spacing: tokens.spacingUnit) {
            pauseResumeButton
            stopButton
        }
    }

    /// 暂停 / 继续按钮：录音中显示「暂停」触发 `onPause`，暂停态显示「继续」触发 `onResume`（需求 6.6、6.7）。
    @ViewBuilder
    var pauseResumeButton: some View {
        let isRecording = state == .recording
        Button(action: isRecording ? onPause : onResume) {
            HStack(spacing: tokens.spacingUnit * 0.5) {
                Image(systemName: isRecording ? "pause.fill" : "play.fill")
                Text(isRecording ? "暂停" : "继续")
                    .fontWeight(.semibold)
            }
            .foregroundColor(tokens.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, tokens.spacingUnit * 1.5)
            .background(
                RoundedRectangle(cornerRadius: tokens.cornerRadius)
                    .fill(tokens.accentSecondary.opacity(0.4))
            )
        }
        .buttonStyle(.plain)
    }

    /// 结束并生成纪要按钮：录制红填充强调，触发 `onStop` 进入处理态（需求 6.8）。
    var stopButton: some View {
        Button(action: onStop) {
            HStack(spacing: tokens.spacingUnit * 0.5) {
                Image(systemName: "stop.fill")
                Text("结束并生成纪要")
                    .fontWeight(.semibold)
            }
            .foregroundColor(tokens.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, tokens.spacingUnit * 1.5)
            .background(
                RoundedRectangle(cornerRadius: tokens.cornerRadius)
                    .fill(tokens.recording)
            )
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
/// 预览样例数据。用经典 `PreviewProvider` 而非 `#Preview` 宏，以兼容仅装有 Command Line Tools 的构建环境。
private enum RecordingPanelPreviewData {
    static let templates: [NoteTemplate] = [
        NoteTemplate(id: "builtin.default", name: "默认", isBuiltin: true, instruction: ""),
        NoteTemplate(id: "builtin.standup", name: "站会", isBuiltin: true, instruction: ""),
        NoteTemplate(id: "builtin.review", name: "评审", isBuiltin: true, instruction: ""),
        NoteTemplate(id: "builtin.interview", name: "面试", isBuiltin: true, instruction: "")
    ]
}

/// 预览：覆盖「录音中 + 双路收音（浅色）」「暂停 + 麦克风静音（深色）」两种典型组合。
struct RecordingPanelView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RecordingPanelView(
                state: .recording,
                elapsedProvider: { 95 },
                systemLevel: 0.7,
                micLevel: 0.4,
                systemSilent: false,
                micSilent: false,
                selectedTemplate: RecordingPanelPreviewData.templates[0],
                availableTemplates: RecordingPanelPreviewData.templates
            )
            .padding()
            .frame(width: 360)
            .themeTokens(.light)
            .previewDisplayName("录音中-双路收音")

            RecordingPanelView(
                state: .paused,
                elapsedProvider: { 3725 },
                systemLevel: 0,
                micLevel: 0,
                systemSilent: false,
                micSilent: true,
                selectedTemplate: RecordingPanelPreviewData.templates[1],
                availableTemplates: RecordingPanelPreviewData.templates
            )
            .padding()
            .frame(width: 360)
            .themeTokens(.dark)
            .previewDisplayName("暂停-麦克风静音-深色")
        }
    }
}
#endif
