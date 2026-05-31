import AppKit
import Combine

/// 应用入口。
///
/// 本应用为常驻菜单栏的 Agent App（需求 2.1）：
/// - Info.plist 中 `LSUIElement = true` 使其无 Dock 图标、无主窗口；
/// - 运行期将激活策略设为 `.accessory`，与 LSUIElement 保持一致，
///   确保通过 `swift run` 启动时也表现为菜单栏常驻形态。
@main
enum MeetingNotesApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

/// 应用代理：启动时装配并串联全链路（任务 18.1）。
///
/// 依赖装配顺序遵循分层：配置 → 主题 / 模板 → 仓储 / 客户端 / 服务 → 录音协调 / 处理流程 → 窗口 / 菜单栏。
/// 录音 → 处理 → 落库 → 展示的闭环：
/// - 菜单栏面板「开始记录 / 结束」驱动 `RecordingCoordinator` 状态机（需求 4.8、6.8）；
/// - 监听其状态迁移到 `.finished`，用录音产物构建 `ProcessingInput` 交给 `ProcessingPipeline`
///   顺序执行 保存音频 → 转写 → 生成 → 落库（需求 8.1、8.8）；
/// - 处理完成后刷新待机态最近纪要；完成态「查看完整纪要」在纪要库中打开该条纪要（需求 10.3）。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - 配置 / 主题 / 模板

    private let settingsStore = SettingsStore()
    private lazy var themeManager = ThemeManager(settingsStore: settingsStore)
    private lazy var templateManager = TemplateManager(settingsStore: settingsStore)

    // MARK: - 基础设施 / 领域服务

    /// 纪要仓储。沙盒不可用时为 nil，处理流程将无法落库（应用仍可启动）。
    private let noteRepository: NoteStoring? = try? NoteRepository()
    private let apiClient = OpenAICompatibleClient()
    private let permissionManager = PermissionManager()

    // MARK: - 编排层

    private let recordingCoordinator: RecordingCoordinator
    /// 处理流程编排器。依赖仓储，仓储不可用时为 nil。
    private let processingPipeline: ProcessingPipeline?

    // MARK: - 界面入口

    private var menuBarController: MenuBarController?
    private var windowManager: AppWindowManager?

    private var cancellables = Set<AnyCancellable>()
    /// 防止同一次 `.finished` 重复触发处理。
    private var isProcessing = false

    override init() {
        // 录音协调器：注入真实双音源采集服务，初始模板取默认模板。
        let coordinator = RecordingCoordinator(
            audioCapture: CoreAudioCaptureService(),
            initialTemplate: TemplateManager(settingsStore: settingsStore).defaultTemplate
        )
        self.recordingCoordinator = coordinator

        // 处理流程：转写（切片 + OpenAI 兼容客户端）+ 生成 + 仓储落库 + 完成通知。
        if let repository = noteRepository {
            let transcription = SlicingTranscriptionService(client: apiClient, slicer: AudioSlicer())
            let summary = LLMSummaryService(client: apiClient)
            self.processingPipeline = ProcessingPipeline(
                transcriptionService: transcription,
                summaryService: summary,
                noteRepository: repository,
                settingsStore: settingsStore,
                completionNotifier: CompletionNotifierFactory.makeDefault()
            )
        } else {
            self.processingPipeline = nil
        }
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 纪要库 / 设置窗口管理器。
        if let repository = noteRepository {
            windowManager = AppWindowManager(
                noteRepository: repository,
                settingsStore: settingsStore,
                templateManager: templateManager,
                themeManager: themeManager,
                transcriptionClient: apiClient
            )
        }

        // 菜单栏入口：注入处理流程、面板数据提供者与跳转回调，闭合全链路。
        menuBarController = MenuBarController(
            coordinator: recordingCoordinator,
            themeManager: themeManager,
            processingPipeline: processingPipeline,
            panelDataProvider: { [weak self] in self?.makePanelData() ?? .init() },
            actions: makePanelActions()
        )

        observeRecordingLifecycle()
        observeProcessingCompletion()
    }
}

// MARK: - 面板数据与跳转（需求 4）

private extension AppDelegate {
    /// 构建待机态面板快照：最近 3 条纪要、双音源就绪、转写模型名、可切换模板。
    func makePanelData() -> MenuBarController.PanelData {
        let recent = (try? noteRepository?.fetchAllOrderedByDate()) ?? []
        return MenuBarController.PanelData(
            recentNotes: Array(recent.prefix(3)),
            readiness: permissionManager.audioSourceReadiness(),
            transcriptionModelName: settingsStore.config(for: .transcription).model,
            availableTemplates: templateManager.allTemplates
        )
    }

    /// 面板跳转回调：打开纪要库 / 设置 / 某条纪要详情（需求 4.4、4.6、4.7、10.3）。
    func makePanelActions() -> MenuBarController.PanelActions {
        MenuBarController.PanelActions(
            onOpenNote: { [weak self] note in self?.windowManager?.openLibrary(selecting: note) },
            onOpenLibrary: { [weak self] in self?.windowManager?.openLibrary() },
            onOpenSettings: { [weak self] in self?.windowManager?.openSettings() }
        )
    }
}

// MARK: - 录音 → 处理 串联（需求 6.8、8.1、8.8）

private extension AppDelegate {
    /// 监听录音状态：迁移到 `.finished` 且有录音产物时，构建输入交给处理流程。
    func observeRecordingLifecycle() {
        recordingCoordinator.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self, state == .finished else { return }
                self.startProcessingIfNeeded()
            }
            .store(in: &cancellables)
    }

    /// 用录音产物构建 `ProcessingInput` 并启动处理（去重，避免重复触发）。
    func startProcessingIfNeeded() {
        guard !isProcessing,
              let pipeline = processingPipeline,
              let audioURL = recordingCoordinator.recordedAudioURL else { return }
        isProcessing = true

        let input = ProcessingInput(
            audioURL: audioURL,
            template: recordingCoordinator.selectedTemplate,
            highlights: recordingCoordinator.highlights,
            startedAt: recordingCoordinator.sessionStartedAt ?? Date(),
            duration: recordingCoordinator.elapsedDuration
        )

        Task { @MainActor in
            _ = await pipeline.process(input)
            self.isProcessing = false
        }
    }

    /// 监听处理完成：产出新纪要后刷新菜单栏面板的最近纪要快照（需求 8.8）。
    func observeProcessingCompletion() {
        guard let pipeline = processingPipeline else { return }
        pipeline.$generatedNote
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                guard note != nil else { return }
                self?.menuBarController?.refreshPanel()
            }
            .store(in: &cancellables)
    }
}
