import SwiftUI

/// 菜单栏面板的 SwiftUI 根容器（界面层，对应设计「NSStatusItem + NSPopover (承载 SwiftUI)」）。
///
/// 由 `NSPopover` 通过 `NSHostingController` 承载（见 `MenuBarController`）。本视图是
/// 四态面板（待机 / 录音 / 处理 / 完成，任务 14.1-14.4）的统一外壳：
/// - 订阅 `RecordingCoordinator`（`ObservableObject`），按 `state` 切换内容区；
/// - 取色全部来自 `@Environment(\.themeTokens)`，不写死色值（需求 17.4）；
/// - 自有文案均为中文（需求 1.1）。
///
/// 当前内容区为占位实现：保留真实的容器结构（标题栏、状态切换、令牌取色、固定宽度），
/// 各状态对应的具体面板将在任务 14.x 中替换内容主体，无需改动本外壳。
struct MenuBarPanelView: View {
    @Environment(\.themeTokens) private var tokens
    /// 录音协调器：面板内容随其 `state` 切换四态（需求 4.8、6.8）。
    @ObservedObject var coordinator: RecordingCoordinator

    // MARK: - 待机态数据与回调（任务 14.1，需求 4）
    //
    // 以下数据 / 回调供 `.idle` 分支的 `IdlePanelView` 使用。默认值为空数据与无操作回调，
    // 使本视图（及 `MenuBarController`）无需额外依赖即可装配；真实数据源与跳转回调
    // 由上层在串联全链路时注入（任务 18.1）。

    /// 待机态展示的最近纪要（最多 3 条，需求 4.3）。
    private let recentNotes: [MeetingNote]
    /// 待机态展示的双音源就绪情况（需求 3.4、4.2）。
    private let readiness: AudioSourceReadiness
    /// 待机态展示的当前转写模型名（需求 4.5）。
    private let transcriptionModelName: String
    /// 打开某条纪要详情（需求 4.4）。
    private let onOpenNote: (MeetingNote) -> Void
    /// 打开纪要库（需求 4.6）。
    private let onOpenLibrary: () -> Void
    /// 打开设置（需求 4.7）。
    private let onOpenSettings: () -> Void

    // MARK: - 录音态数据与回调（任务 14.2，需求 5.2、6）
    //
    // 以下数据供 `.recording` / `.paused` 分支的 `RecordingPanelView` 使用。默认值为空数据，
    // 使本视图无需额外依赖即可装配；实时电平 / 静音状态与可切换模板由上层在串联全链路时注入
    // （任务 18.1）。模板切换、暂停 / 继续 / 结束、添加重点标记均直接调用 `coordinator` 方法。

    /// 系统声音当前电平（0...1），驱动录音态波形（需求 5.2、6.3）。
    private let systemLevel: Float
    /// 麦克风当前电平（0...1），驱动录音态波形（需求 5.2、6.3）。
    private let micLevel: Float
    /// 系统声音通路是否被标识为静音（需求 5.3）。
    private let systemSilent: Bool
    /// 麦克风通路是否被标识为静音（需求 5.4）。
    private let micSilent: Bool
    /// 录音态可切换的模板列表（需求 6.4、6.5）。
    private let availableTemplates: [NoteTemplate]

    // MARK: - 处理态依赖（任务 14.3 / 14.4，需求 8）
    //
    // 离线处理流程编排器。结束录音后由上层注入（任务 18.1），驱动 `.finished` 分支按
    // `ProcessingPipeline.stage` 在「处理态面板」与「完成态面板」间切换：stage != .done 展示处理态
    // （任务 14.3 的 `ProcessingPanelView`），stage == .done 展示完成态（任务 14.4 填充）。
    // 为 nil 时（如尚未串联或预览）退回到简单占位，保证本外壳可独立装配。

    /// 离线处理流程编排器，可选注入；为 nil 时 `.finished` 分支展示占位。
    private let processingPipeline: ProcessingPipeline?

    /// - Parameters:
    ///   - coordinator: 录音协调器，驱动四态切换。
    ///   - recentNotes: 最近纪要（最多 3 条），默认空。
    ///   - readiness: 双音源就绪情况，默认两路均未决定。
    ///   - transcriptionModelName: 当前转写模型名，默认空。
    ///   - onOpenNote / onOpenLibrary / onOpenSettings: 待机态跳转回调，默认无操作。
    ///   - systemLevel / micLevel: 录音态两路实时电平，默认 0。
    ///   - systemSilent / micSilent: 录音态两路静音标识，默认不静音。
    ///   - availableTemplates: 录音态可切换的模板列表，默认空。
    ///   - processingPipeline: 离线处理流程编排器，默认 nil（`.finished` 分支退回占位）。
    init(coordinator: RecordingCoordinator,
         recentNotes: [MeetingNote] = [],
         readiness: AudioSourceReadiness = AudioSourceReadiness(systemAudio: .notDetermined, microphone: .notDetermined),
         transcriptionModelName: String = "",
         onOpenNote: @escaping (MeetingNote) -> Void = { _ in },
         onOpenLibrary: @escaping () -> Void = {},
         onOpenSettings: @escaping () -> Void = {},
         systemLevel: Float = 0,
         micLevel: Float = 0,
         systemSilent: Bool = false,
         micSilent: Bool = false,
         availableTemplates: [NoteTemplate] = [],
         processingPipeline: ProcessingPipeline? = nil) {
        _coordinator = ObservedObject(wrappedValue: coordinator)
        self.recentNotes = recentNotes
        self.readiness = readiness
        self.transcriptionModelName = transcriptionModelName
        self.onOpenNote = onOpenNote
        self.onOpenLibrary = onOpenLibrary
        self.onOpenSettings = onOpenSettings
        self.systemLevel = systemLevel
        self.micLevel = micLevel
        self.systemSilent = systemSilent
        self.micSilent = micSilent
        self.availableTemplates = availableTemplates
        self.processingPipeline = processingPipeline
    }

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit * 1.5) {
            header
            Divider()
            content
        }
        .padding(tokens.spacingUnit * 2)
        .frame(width: 360, alignment: .leading)
        .background(tokens.background)
    }

    /// 顶部标题栏：应用名 + 当前状态徽标。
    private var header: some View {
        HStack {
            Text("会议纪要")
                .font(.headline)
                .foregroundColor(tokens.textPrimary)
            Spacer()
            stateBadge
        }
    }

    /// 当前录音状态的中文徽标，录音 / 暂停态用录制红强调（需求 2.3、17.4）。
    private var stateBadge: some View {
        Text(coordinator.state.displayName)
            .font(.caption.bold())
            .foregroundColor(isRecordingSession ? tokens.recording : tokens.textSecondary)
            .padding(.horizontal, tokens.spacingUnit)
            .padding(.vertical, tokens.spacingUnit * 0.5)
            .background(
                Capsule().fill((isRecordingSession ? tokens.recording : tokens.textSecondary).opacity(0.15))
            )
    }

    /// 内容区：按状态切换。各分支主体由任务 14.x 填充，此处为保留结构的占位。
    @ViewBuilder
    private var content: some View {
        switch coordinator.state {
        case .idle:
            IdlePanelView(
                recentNotes: recentNotes,
                readiness: readiness,
                transcriptionModelName: transcriptionModelName,
                onStartRecording: startRecording,
                onOpenNote: onOpenNote,
                onOpenLibrary: onOpenLibrary,
                onOpenSettings: onOpenSettings
            )
        case .recording, .paused:
            RecordingPanelView(
                state: coordinator.state,
                elapsedProvider: { [coordinator] in coordinator.elapsedDuration },
                systemLevel: systemLevel,
                micLevel: micLevel,
                systemSilent: systemSilent,
                micSilent: micSilent,
                selectedTemplate: coordinator.selectedTemplate,
                availableTemplates: availableTemplates,
                onPause: pauseRecording,
                onResume: resumeRecording,
                onStop: stopRecording,
                onSelectTemplate: { _ = coordinator.selectTemplate($0) },
                onAddHighlight: { _ = coordinator.addHighlight() }
            )
        case .finished:
            finishedContent
        }
    }

    /// `.finished` 分支内容：注入了处理流程编排器时按其 `stage` 切换处理态 / 完成态，
    /// 否则退回简单占位（需求 8.2-8.6、8.8、10）。
    ///
    /// stage != .done（处理中或失败）→ 处理态面板（任务 14.3）；stage == .done → 完成态面板（任务 14.4）。
    /// 完成态的「查看完整纪要」复用待机态的 `onOpenNote` 在纪要库中打开该条纪要（需求 10.3），
    /// 「复制」走 `DonePanelView` 默认的剪贴板写入（需求 10.4）；生成纪要缺失时退回简单占位。
    @ViewBuilder
    private var finishedContent: some View {
        if let processingPipeline {
            ProcessingStageContainer(
                pipeline: processingPipeline,
                onOpenNote: onOpenNote,
                donePlaceholder: { statePlaceholder(title: "完成", hint: "纪要已生成完成。") }
            )
        } else {
            statePlaceholder(title: "处理中", hint: "录音已结束，正在生成纪要。")
        }
    }

    /// 占位内容块：展示状态标题与中文说明，保留令牌取色与布局，待 14.x 替换主体。
    private func statePlaceholder(title: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit) {
            Text(title)
                .font(.title3.bold())
                .foregroundColor(tokens.textPrimary)
            Text(hint)
                .font(.callout)
                .foregroundColor(tokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(tokens.spacingUnit * 2)
        .background(
            RoundedRectangle(cornerRadius: tokens.cornerRadius)
                .fill(tokens.surface)
        )
    }

    /// 是否处于录音会话中（录音中或暂停），用于图标 / 徽标的录制态强调（需求 2.3、2.4）。
    private var isRecordingSession: Bool {
        coordinator.state == .recording || coordinator.state == .paused
    }

    /// 点击「开始记录」：驱动录音协调器从待机进入录音态（需求 4.8）。
    ///
    /// `coordinator.start()` 内部会先启动音频采集再迁移状态；采集启动失败时保持待机态，
    /// 状态机会拒绝非法迁移，故此处吞掉错误不致崩溃，待 18.1 串联时再补充失败提示。
    private func startRecording() {
        Task { @MainActor in
            try? await coordinator.start()
        }
    }

    /// 点击「暂停」：录音中 → 暂停（需求 6.6）。非法迁移由状态机拒绝，吞掉错误不致崩溃。
    private func pauseRecording() {
        try? coordinator.pause()
    }

    /// 点击「继续」：暂停 → 录音中（需求 6.7）。
    private func resumeRecording() {
        try? coordinator.resume()
    }

    /// 点击「结束并生成纪要」：录音中 / 暂停 → 结束（需求 6.8）。
    ///
    /// `coordinator.stop()` 收尾采集并保存 WAV 地址后迁移到结束态，待 18.1 串联时交给处理流程。
    private func stopRecording() {
        Task { @MainActor in
            try? await coordinator.stop()
        }
    }
}

/// `.finished` 状态下订阅 `ProcessingPipeline` 的内容容器（界面层，任务 14.3 / 14.4）。
///
/// 以 `@ObservedObject` 订阅编排器，使阶段 / 音频信息 / 模型名 / 通知意图 / 生成纪要变化实时驱动刷新；
/// 据 `stage` 切换：未完成（处理中或失败）展示 `ProcessingPanelView`（需求 8.2-8.6、9.3），
/// 已完成（`stage == .done`）且已有生成纪要时展示 `DonePanelView`（需求 10），否则退回外层占位。
private struct ProcessingStageContainer<DonePlaceholder: View>: View {
    /// 离线处理流程编排器，实时驱动处理态 / 完成态刷新。
    @ObservedObject var pipeline: ProcessingPipeline
    /// 完成态「查看完整纪要」回调：在纪要库中打开该条纪要（需求 10.3）。
    let onOpenNote: (MeetingNote) -> Void
    /// 完成态兜底占位（`stage == .done` 但生成纪要缺失时展示，正常流程不应发生）。
    let donePlaceholder: () -> DonePlaceholder

    var body: some View {
        if case .done = pipeline.stage {
            if let note = pipeline.generatedNote {
                DonePanelView(
                    note: note,
                    onViewFull: { onOpenNote(note) }
                )
            } else {
                donePlaceholder()
            }
        } else {
            ProcessingPanelView(
                stage: pipeline.stage,
                audioInfo: pipeline.audioInfo,
                transcriptionModel: pipeline.transcriptionModel,
                willNotifyOnCompletion: pipeline.willNotifyOnCompletion,
                onContinueInBackground: { Task { await pipeline.continueInBackgroundAndNotify() } }
            )
        }
    }
}
