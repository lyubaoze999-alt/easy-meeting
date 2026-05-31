import SwiftUI

/// 菜单栏面板「处理态」内容视图（界面层，任务 14.3，需求 8.2-8.6、9.3）。
///
/// 作为 `MenuBarPanelView` 在 `.finished` 且 `ProcessingPipeline.stage != .done` 时的内容主体
/// （外壳的标题栏、分隔线、外边距与固定宽度由 `MenuBarPanelView` 提供）。自上而下展示：
/// - 分步进度条：「保存音频 → 语音转写 → 生成纪要」三步，已完成步骤打勾、当前步骤高亮（需求 8.2）；
/// - 音频信息：音频保存完成后展示录音时长与文件大小（需求 8.3）；
/// - 转写进度：转写阶段展示当前片号 / 总片数与所用转写模型名（需求 8.4、9.3）；
/// - 生成状态：纪要生成阶段展示进行中状态（需求 8.5）；
/// - 失败提示：失败终态展示中文错误原因；
/// - 「在后台继续，完成后通知我」入口（需求 8.6），点击触发 `onContinueInBackground`，
///   并在已选择后反映「完成后将通知你」的已启用态。
///
/// 纯展示视图：阶段 / 音频信息 / 模型名 / 通知意图经 `init` 注入，交互经回调上抛，不直接持有业务服务，
/// 便于预览与测试；实际接线由 `MenuBarPanelView` 订阅 `ProcessingPipeline` 后注入实时值。
/// 取色全部来自 `@Environment(\.themeTokens)`，不写死色值（需求 17.4）；文案均为中文（需求 1.1）。
struct ProcessingPanelView: View {
    @Environment(\.themeTokens) private var tokens

    /// 当前处理阶段，驱动分步进度与各信息块的展示（需求 8.2、8.4、8.5）。
    private let stage: ProcessingStage
    /// 音频保存阶段产出的音频信息（时长、文件大小，需求 8.3）；未完成保存阶段时为 nil。
    private let audioInfo: ProcessedAudioInfo?
    /// 当前转写服务模型名（需求 8.4、9.3），按用户配置原样展示（需求 1.2）。
    private let transcriptionModel: String
    /// 用户是否已选择「在后台继续，完成后通知我」（需求 8.6），决定入口的已启用反馈。
    private let willNotifyOnCompletion: Bool

    /// 点击「在后台继续，完成后通知我」（需求 8.6）。
    private let onContinueInBackground: () -> Void

    /// - Parameters:
    ///   - stage: 当前处理阶段。
    ///   - audioInfo: 音频信息（时长 / 文件大小），未完成保存阶段时为 nil。
    ///   - transcriptionModel: 当前转写模型名。
    ///   - willNotifyOnCompletion: 是否已选择后台继续并通知。
    ///   - onContinueInBackground: 后台继续回调。
    init(stage: ProcessingStage,
         audioInfo: ProcessedAudioInfo?,
         transcriptionModel: String,
         willNotifyOnCompletion: Bool,
         onContinueInBackground: @escaping () -> Void = {}) {
        self.stage = stage
        self.audioInfo = audioInfo
        self.transcriptionModel = transcriptionModel
        self.willNotifyOnCompletion = willNotifyOnCompletion
        self.onContinueInBackground = onContinueInBackground
    }

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit * 2) {
            stepper
            detailSection
            if case let .failed(error) = stage {
                failureBanner(error)
            }
            backgroundContinueButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 分步进度（需求 8.2）

private extension ProcessingPanelView {
    /// 处理流程的三步顺序：保存音频 → 语音转写 → 生成纪要（需求 8.1、8.2）。
    /// 取各代表阶段的 `displayName` 作为步骤标题，避免在视图层重复硬编码文案。
    static let steps: [ProcessingStage] = [
        .savingAudio,
        .transcribing(current: 0, total: 0),
        .summarizing
    ]

    /// 用于分步高亮的「有效阶段序号」：正常阶段取其 rank；
    /// 失败时按错误归属的阶段取序号，从而把出错的那一步标红（需求 8.2）。
    var activeRank: Int {
        if case let .failed(error) = stage {
            return ProcessingPanelView.rank(forFailed: error)
        }
        return stage.rank
    }

    /// 把失败原因映射到出错所处的步骤序号（保存音频 1 / 语音转写 2 / 生成纪要 3）。
    static func rank(forFailed error: ProcessingError) -> Int {
        switch error {
        case .servicesNotConfigured, .audioUnavailable:
            return ProcessingStage.savingAudio.rank
        case .transcriptionFailed:
            return ProcessingStage.transcribing(current: 0, total: 0).rank
        case .summarizationFailed, .persistenceFailed:
            return ProcessingStage.summarizing.rank
        }
    }

    /// 是否处于失败终态。
    var isFailed: Bool {
        if case .failed = stage { return true }
        return false
    }

    /// 分步进度区：三步竖排，已完成打勾、当前步高亮（失败则当前步标红，需求 8.2）。
    var stepper: some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit) {
            ForEach(Array(ProcessingPanelView.steps.enumerated()), id: \.offset) { _, step in
                StepRow(
                    title: step.displayName,
                    state: stepState(for: step.rank)
                )
            }
        }
        .padding(tokens.spacingUnit * 1.5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: tokens.cornerRadius)
                .fill(tokens.surface)
        )
    }

    /// 计算某一步相对当前进度的状态：已完成 / 进行中（失败时为出错）/ 待处理。
    func stepState(for stepRank: Int) -> StepState {
        if stepRank < activeRank {
            return .completed
        }
        if stepRank == activeRank {
            return isFailed ? .failed : .current
        }
        return .pending
    }
}

/// 单个步骤相对当前进度的状态。
private enum StepState {
    /// 已完成：打勾。
    case completed
    /// 进行中：高亮当前步。
    case current
    /// 出错：当前步失败标红。
    case failed
    /// 待处理：尚未到达。
    case pending
}

/// 分步进度的单行：左侧状态圆点 + 连接线，右侧步骤标题。
private struct StepRow: View {
    @Environment(\.themeTokens) private var tokens

    let title: String
    let state: StepState

    var body: some View {
        HStack(alignment: .center, spacing: tokens.spacingUnit) {
            indicator
            Text(title)
                .font(.subheadline.weight(state == .current ? .bold : .regular))
                .foregroundColor(titleColor)
            Spacer(minLength: 0)
            if state == .current {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            }
        }
    }

    /// 状态圆点：已完成显示对勾、出错显示叉、进行中实心高亮、待处理空心降级。
    @ViewBuilder
    private var indicator: some View {
        switch state {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(tokens.accentPrimary)
        case .current:
            Image(systemName: "circle.fill")
                .foregroundColor(tokens.accentPrimary)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(tokens.recording)
        case .pending:
            Image(systemName: "circle")
                .foregroundColor(tokens.textSecondary.opacity(0.5))
        }
    }

    /// 标题色：进行中 / 已完成用主文字色，待处理降级为次要色，出错用录制红。
    private var titleColor: Color {
        switch state {
        case .completed, .current:
            return tokens.textPrimary
        case .failed:
            return tokens.recording
        case .pending:
            return tokens.textSecondary
        }
    }
}

// MARK: - 阶段明细：音频信息 / 转写进度 / 生成状态（需求 8.3、8.4、8.5、9.3）

private extension ProcessingPanelView {
    /// 阶段明细区：根据当前阶段展示对应信息块。
    /// 音频信息一旦在保存阶段产出，后续阶段持续展示（需求 8.3）；转写阶段叠加片号 / 模型（需求 8.4、9.3）；
    /// 生成阶段展示进行中状态（需求 8.5）。
    @ViewBuilder
    var detailSection: some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit * 1.25) {
            // 音频保存完成后展示时长与文件大小，并在转写 / 生成阶段持续可见（需求 8.3）。
            if let audioInfo {
                audioInfoCard(audioInfo)
            }

            // 转写阶段：展示当前片号 / 总片数与转写模型（需求 8.4、9.3）。
            if case let .transcribing(current, total) = stage {
                transcriptionCard(current: current, total: total)
            }

            // 生成阶段：展示纪要生成进行中状态（需求 8.5）。
            if case .summarizing = stage {
                summarizingCard
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 音频信息卡片：录音时长 + 文件大小（需求 8.3）。
    func audioInfoCard(_ info: ProcessedAudioInfo) -> some View {
        infoCard(iconName: "waveform", title: "音频已保存") {
            HStack(spacing: tokens.spacingUnit * 2) {
                metric(label: "录音时长", value: info.durationText)
                metric(label: "文件大小", value: info.fileSizeText)
            }
        }
    }

    /// 转写进度卡片：当前片号 / 总片数 + 进度条 + 转写模型（需求 8.4、9.3）。
    func transcriptionCard(current: Int, total: Int) -> some View {
        let safeTotal = max(total, 1)
        let clampedCurrent = min(max(current, 0), safeTotal)
        let fraction = Double(clampedCurrent) / Double(safeTotal)
        let modelText = transcriptionModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return infoCard(iconName: "text.bubble", title: "语音转写中") {
            VStack(alignment: .leading, spacing: tokens.spacingUnit) {
                HStack {
                    Text("当前片段")
                        .font(.caption)
                        .foregroundColor(tokens.textSecondary)
                    Spacer()
                    Text("第 \(clampedCurrent) / \(safeTotal) 片")
                        .font(.caption.bold())
                        .foregroundColor(tokens.textPrimary)
                        .monospacedDigit()
                }
                ProgressView(value: fraction)
                    .tint(tokens.accentPrimary)
                metric(label: "转写模型", value: modelText.isEmpty ? "未配置" : modelText)
            }
        }
    }

    /// 纪要生成卡片：展示进行中状态（需求 8.5）。
    var summarizingCard: some View {
        infoCard(iconName: "doc.text.magnifyingglass", title: "生成纪要中") {
            HStack(spacing: tokens.spacingUnit) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("正在依据所选模板整理结构化纪要…")
                    .font(.callout)
                    .foregroundColor(tokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// 通用信息卡片外壳：图标 + 标题 + 自定义内容。
    func infoCard<Content: View>(iconName: String,
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

    /// 一个「标签 + 数值」的纵向指标展示。
    func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit * 0.25) {
            Text(label)
                .font(.caption)
                .foregroundColor(tokens.textSecondary)
            Text(value)
                .font(.callout.bold())
                .foregroundColor(tokens.textPrimary)
                .lineLimit(1)
        }
    }
}

// MARK: - 失败提示

private extension ProcessingPanelView {
    /// 失败横幅：以录制红展示中文错误原因（终态）。
    func failureBanner(_ error: ProcessingError) -> some View {
        HStack(alignment: .top, spacing: tokens.spacingUnit) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(tokens.recording)
            Text(error.message)
                .font(.callout)
                .foregroundColor(tokens.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(tokens.spacingUnit * 1.5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: tokens.cornerRadius)
                .fill(tokens.recording.opacity(0.12))
        )
    }
}

// MARK: - 在后台继续，完成后通知我（需求 8.6）

private extension ProcessingPanelView {
    /// 「在后台继续，完成后通知我」入口（需求 8.6）。
    /// 未选择时为可点击的描边按钮；已选择后切换为已启用提示，反映稍后将通知用户。
    @ViewBuilder
    var backgroundContinueButton: some View {
        if willNotifyOnCompletion {
            HStack(spacing: tokens.spacingUnit) {
                Image(systemName: "bell.badge.fill")
                    .foregroundColor(tokens.accentPrimary)
                Text("将在后台继续，完成后通知你")
                    .font(.callout.weight(.medium))
                    .foregroundColor(tokens.accentPrimary)
                Spacer(minLength: 0)
            }
            .padding(.vertical, tokens.spacingUnit * 1.25)
            .padding(.horizontal, tokens.spacingUnit * 1.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: tokens.cornerRadius)
                    .fill(tokens.accentPrimary.opacity(0.12))
            )
        } else {
            Button(action: onContinueInBackground) {
                HStack(spacing: tokens.spacingUnit) {
                    Image(systemName: "bell")
                    Text("在后台继续，完成后通知我")
                        .fontWeight(.medium)
                    Spacer(minLength: 0)
                }
                .foregroundColor(tokens.accentPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, tokens.spacingUnit * 1.25)
                .padding(.horizontal, tokens.spacingUnit * 1.5)
                .background(
                    RoundedRectangle(cornerRadius: tokens.cornerRadius)
                        .stroke(tokens.accentPrimary, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

#if DEBUG
/// 预览：覆盖处理流程的几个典型阶段，验证分步高亮、各信息块与后台继续入口在浅 / 深主题下的呈现。
///
/// 用经典 `PreviewProvider` 而非 `#Preview` 宏，以兼容仅装有 Command Line Tools 的构建环境。
/// 直接以阶段 / 音频信息 / 模型名构造（presentational init），无需装配 `ProcessingPipeline`。
struct ProcessingPanelView_Previews: PreviewProvider {
    private static let audioInfo = ProcessedAudioInfo(duration: 3725, fileSizeBytes: 8_540_160)

    static var previews: some View {
        Group {
            ProcessingPanelView(
                stage: .transcribing(current: 2, total: 5),
                audioInfo: audioInfo,
                transcriptionModel: "whisper-1",
                willNotifyOnCompletion: false
            )
            .padding()
            .frame(width: 360)
            .themeTokens(.light)
            .previewDisplayName("转写中-未通知")

            ProcessingPanelView(
                stage: .summarizing,
                audioInfo: audioInfo,
                transcriptionModel: "whisper-1",
                willNotifyOnCompletion: true
            )
            .padding()
            .frame(width: 360)
            .themeTokens(.dark)
            .previewDisplayName("生成中-已选后台通知-深色")

            ProcessingPanelView(
                stage: .failed(.transcriptionFailed(reason: "网络连接超时")),
                audioInfo: audioInfo,
                transcriptionModel: "whisper-1",
                willNotifyOnCompletion: false
            )
            .padding()
            .frame(width: 360)
            .themeTokens(.light)
            .previewDisplayName("转写失败")
        }
    }
}
#endif
