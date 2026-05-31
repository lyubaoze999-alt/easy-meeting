#if canImport(AppKit)
import AppKit
import SwiftUI

/// 纪要库与设置窗口的管理器（界面层，任务 18.1）。
///
/// 菜单栏应用（LSUIElement）无主窗口，纪要库与设置以独立 `NSWindow` 承载 SwiftUI 视图按需打开。
/// 每类窗口单例复用：重复打开时前置已有窗口而非新建（需求 4.6、4.7、10.3）。
/// 承载的 SwiftUI 根视图注入当前主题令牌，保持与菜单栏面板一致的外观（需求 17.4）。
@MainActor
final class AppWindowManager {

    // MARK: - 依赖

    private let noteRepository: NoteStoring
    private let settingsStore: SettingsStore
    private let templateManager: TemplateManager
    private let themeManager: ThemeManager
    private let transcriptionClient: OpenAICompatibleClienting

    // MARK: - 单例窗口

    private var libraryWindow: NSWindow?
    private var settingsWindow: NSWindow?
    /// 纪要库视图模型常驻，使「打开某条纪要」可定位选中（需求 10.3）。
    private var libraryViewModel: NotesLibraryViewModel?

    /// - Parameters:
    ///   - noteRepository: 纪要仓储，纪要库的数据来源。
    ///   - settingsStore: 配置管理，服务配置界面的数据来源。
    ///   - templateManager: 模板管理，模板设置界面的数据来源。
    ///   - themeManager: 主题管理，外观设置界面的数据来源与窗口令牌注入来源。
    ///   - transcriptionClient: 连接测试用的 OpenAI 兼容客户端。
    init(noteRepository: NoteStoring,
         settingsStore: SettingsStore,
         templateManager: TemplateManager,
         themeManager: ThemeManager,
         transcriptionClient: OpenAICompatibleClienting = OpenAICompatibleClient()) {
        self.noteRepository = noteRepository
        self.settingsStore = settingsStore
        self.templateManager = templateManager
        self.themeManager = themeManager
        self.transcriptionClient = transcriptionClient
    }
}

// MARK: - 纪要库（需求 4.6、10.3）

extension AppWindowManager {
    /// 打开纪要库窗口；已打开则前置。可选定位到某条纪要并选中（需求 10.3）。
    func openLibrary(selecting note: MeetingNote? = nil) {
        let viewModel = ensureLibraryViewModel()
        viewModel.load()
        if let note {
            viewModel.select(note)
        }

        if let window = libraryWindow {
            bringToFront(window)
            return
        }

        let root = NotesLibraryView(viewModel: viewModel)
            .themeTokens(themeManager.tokens)
        let window = makeWindow(
            title: "纪要库",
            size: NSSize(width: 880, height: 560),
            root: root
        )
        libraryWindow = window
        bringToFront(window)
    }

    /// 纪要库视图模型懒构造并复用。
    private func ensureLibraryViewModel() -> NotesLibraryViewModel {
        if let viewModel = libraryViewModel { return viewModel }
        let viewModel = NotesLibraryViewModel(store: noteRepository)
        libraryViewModel = viewModel
        return viewModel
    }
}

// MARK: - 设置（需求 4.7、15、16、17）

extension AppWindowManager {
    /// 打开设置窗口；已打开则前置。设置以选项卡承载服务配置 / 模板 / 外观三块。
    func openSettings() {
        if let window = settingsWindow {
            bringToFront(window)
            return
        }

        let root = SettingsRootView(
            settingsStore: settingsStore,
            templateManager: templateManager,
            themeManager: themeManager,
            transcriptionClient: transcriptionClient
        )
        .themeTokens(themeManager.tokens)
        let window = makeWindow(
            title: "设置",
            size: NSSize(width: 560, height: 640),
            root: root
        )
        settingsWindow = window
        bringToFront(window)
    }
}

// MARK: - 窗口工具

private extension AppWindowManager {
    /// 构造一个承载 SwiftUI 根视图的标准窗口。
    func makeWindow<Root: View>(title: String, size: NSSize, root: Root) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        window.center()
        window.contentViewController = NSHostingController(rootView: root)
        return window
    }

    /// 前置窗口并激活应用（菜单栏应用为 .accessory，需要临时激活才能让窗口获得焦点）。
    func bringToFront(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

/// 设置窗口根视图：以选项卡组织服务配置 / 模板管理 / 外观设置（需求 15、16、17）。
private struct SettingsRootView: View {
    @Environment(\.themeTokens) private var tokens

    let settingsStore: SettingsStore
    let templateManager: TemplateManager
    let themeManager: ThemeManager
    let transcriptionClient: OpenAICompatibleClienting

    var body: some View {
        TabView {
            ServiceConfigView(settings: settingsStore, client: transcriptionClient)
                .tabItem { Label("服务配置", systemImage: "network") }

            TemplateManagementView(templateManager: templateManager)
                .tabItem { Label("纪要模板", systemImage: "doc.text") }

            AppearanceSettingsView(themeManager: themeManager)
                .tabItem { Label("外观", systemImage: "paintpalette") }
        }
        .frame(minWidth: 520, minHeight: 600)
        .background(tokens.background)
    }
}
#endif
