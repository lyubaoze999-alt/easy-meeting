#if canImport(AppKit)
import AppKit
import SwiftUI
import Combine

/// 菜单栏图标与 Popover 容器控制器（界面层，对应设计「NSStatusItem + NSPopover (承载 SwiftUI)」、需求 2）。
///
/// 职责：
/// - 在系统菜单栏常驻一个 `NSStatusItem` 图标（需求 2.1）。
/// - 点击图标切换一个 `NSPopover` 的显隐，Popover 经 `NSHostingController` 承载
///   SwiftUI 面板 `MenuBarPanelView`（需求 2.2）。
/// - 订阅 `RecordingCoordinator.state`：录音 / 暂停期间图标切换为录制标识并以录制红
///   着色，区别于待机态（需求 2.3）。
/// - 图标的录制态完全由录音状态驱动，与 Popover 是否可见无关：Popover 因失焦自动
///   收起后，图标仍保持当前录制状态（需求 2.4）。
///
/// 全链路串联（任务 18.1）：本控制器把待机态所需数据（最近纪要、音源就绪、转写模型名、
/// 可切换模板）与处理流程编排器、跳转回调注入 `MenuBarPanelView`，使录音 → 处理 → 落库 →
/// 展示在面板内闭环。数据来源与跳转动作经构造参数注入，由 `AppDelegate` 装配。
///
/// 主题色随 `ThemeManager.tokens` 变化刷新，图标着色取自令牌 `recording`，不写死色值
/// （需求 17.4）。所有 tooltip / 文案为中文（需求 1.1）。
@MainActor
final class MenuBarController: NSObject {

    /// 面板待机态所需的快照数据，由 `AppDelegate` 注入并在数据变化时刷新（需求 4）。
    struct PanelData {
        var recentNotes: [MeetingNote]
        var readiness: AudioSourceReadiness
        var transcriptionModelName: String
        var availableTemplates: [NoteTemplate]

        init(recentNotes: [MeetingNote] = [],
             readiness: AudioSourceReadiness = AudioSourceReadiness(systemAudio: .notDetermined, microphone: .notDetermined),
             transcriptionModelName: String = "",
             availableTemplates: [NoteTemplate] = []) {
            self.recentNotes = recentNotes
            self.readiness = readiness
            self.transcriptionModelName = transcriptionModelName
            self.availableTemplates = availableTemplates
        }
    }

    /// 面板的跳转回调，由 `AppDelegate` 注入以打开纪要库 / 设置 / 某条纪要详情（需求 4.4、4.6、4.7、10.3）。
    struct PanelActions {
        var onOpenNote: (MeetingNote) -> Void = { _ in }
        var onOpenLibrary: () -> Void = {}
        var onOpenSettings: () -> Void = {}
    }

    // MARK: - 依赖

    private let coordinator: RecordingCoordinator
    private let themeManager: ThemeManager
    private let processingPipeline: ProcessingPipeline?
    /// 面板数据提供者：每次重建面板时调用以取最新快照（最近纪要等会随处理完成更新）。
    private let panelDataProvider: () -> PanelData
    private let actions: PanelActions

    // MARK: - AppKit 组件

    private let statusItem: NSStatusItem
    private let popover: NSPopover

    // MARK: - 订阅

    private var cancellables = Set<AnyCancellable>()

    /// - Parameters:
    ///   - coordinator: 录音协调器，图标录制态由其 `state` 驱动（需求 2.3、2.4）。
    ///   - themeManager: 主题管理，图标着色取自当前令牌并随主题切换刷新（需求 17.4）。
    ///   - processingPipeline: 离线处理流程编排器，驱动面板 `.finished` 分支的处理态 / 完成态（需求 8、10）。
    ///   - panelDataProvider: 面板待机态数据提供者，重建面板时取最新快照。
    ///   - actions: 面板跳转回调（打开纪要库 / 设置 / 某条纪要）。
    init(coordinator: RecordingCoordinator,
         themeManager: ThemeManager,
         processingPipeline: ProcessingPipeline? = nil,
         panelDataProvider: @escaping () -> PanelData = { PanelData() },
         actions: PanelActions = PanelActions()) {
        self.coordinator = coordinator
        self.themeManager = themeManager
        self.processingPipeline = processingPipeline
        self.panelDataProvider = panelDataProvider
        self.actions = actions
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        super.init()

        configureStatusItem()
        configurePopover()
        observeState()
    }

    /// 数据快照变化（如处理完成产出新纪要）后，外部调用以重建面板内容。
    func refreshPanel() {
        rebuildPanel()
    }
}

// MARK: - 配置

private extension MenuBarController {
    /// 配置常驻状态栏图标按钮（需求 2.1），并绑定点击切换 Popover（需求 2.2）。
    func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.toolTip = "会议纪要"
        applyIconAppearance(for: coordinator.state)
    }

    /// 配置承载 SwiftUI 面板的 Popover（需求 2.2）。
    ///
    /// `behavior = .transient`：点击面板外部或切换应用时自动收起；收起仅影响 Popover 可见性，
    /// 不改变录音状态，故图标录制态得以保持（需求 2.4）。
    func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        rebuildPanel()
    }

    /// 订阅录音状态与主题令牌变化，驱动图标外观刷新（需求 2.3、2.4、17.4）。
    func observeState() {
        // 录音状态变化：录音 / 暂停 → 录制标识，待机 / 结束 → 常态图标。
        coordinator.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.applyIconAppearance(for: state)
            }
            .store(in: &cancellables)

        // 主题令牌变化：重建面板宿主以注入新令牌，并按当前状态重新着色图标。
        themeManager.$tokens
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.rebuildPanel()
                self.applyIconAppearance(for: self.coordinator.state)
            }
            .store(in: &cancellables)
    }
}

// MARK: - 面板构建

private extension MenuBarController {
    /// 用最新快照数据 + 当前令牌重建 SwiftUI 面板宿主，注入处理流程编排器与跳转回调。
    func rebuildPanel() {
        let data = panelDataProvider()
        let panel = MenuBarPanelView(
            coordinator: coordinator,
            recentNotes: data.recentNotes,
            readiness: data.readiness,
            transcriptionModelName: data.transcriptionModelName,
            onOpenNote: actions.onOpenNote,
            onOpenLibrary: actions.onOpenLibrary,
            onOpenSettings: actions.onOpenSettings,
            availableTemplates: data.availableTemplates,
            processingPipeline: processingPipeline
        )
        .themeTokens(themeManager.tokens)
        popover.contentViewController = NSHostingController(rootView: panel)
    }
}

// MARK: - 图标外观（需求 2.1、2.3、2.4）

private extension MenuBarController {
    /// 录音会话中（录音中或暂停）使用录制标识图标，其余使用常态图标。
    ///
    /// 图标录制态只取决于录音状态，与 Popover 是否可见无关，因此面板失焦收起后
    /// 图标仍保持录制状态（需求 2.4）。
    func applyIconAppearance(for state: RecordingState) {
        guard let button = statusItem.button else { return }
        let isRecordingSession = (state == .recording || state == .paused)

        // 待机/结束：话筒轮廓；录音/暂停：声波图标作为录制中标识（需求 2.3）。
        let symbolName = isRecordingSession ? "waveform" : "mic"
        let description = isRecordingSession ? "录音中" : "会议纪要"
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description)
        image?.isTemplate = !isRecordingSession  // 录制态自定义着色，故关闭模板渲染
        button.image = image

        // 录制态以令牌 recording 着色突出，待机态恢复随系统的模板渲染（需求 2.3、17.4）。
        button.contentTintColor = isRecordingSession ? NSColor(themeManager.tokens.recording) : nil
        button.toolTip = isRecordingSession ? "会议纪要 · 录音中" : "会议纪要"
    }
}

// MARK: - 交互（需求 2.2）

private extension MenuBarController {
    /// 点击菜单栏图标切换 Popover 显隐（需求 2.2）。
    @objc func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            // 打开前重建面板，确保展示最新的最近纪要 / 音源就绪等快照。
            rebuildPanel()
            guard let button = statusItem.button else { return }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // 让 Popover 成为关键窗口，确保失焦时 .transient 行为正常触发收起（需求 2.4）。
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
#endif
