import SwiftUI

/// 外观设置界面（界面层，任务 16.2，需求 17.1、17.2）。
///
/// 提供浅色 / 深色 / 跟随系统三个主题选项（需求 17.1）的 `Picker`，绑定到
/// `ThemeManager.currentMode`；用户选择后即时调用 `setMode(_:)` 切换主题，
/// 取色基于 `@Environment(\.themeTokens)` 的视图随之即时刷新（需求 17.2）。
///
/// 取色全部来自 `@Environment(\.themeTokens)`（需求 17.4），自有文案均为中文（需求 1.1）。
struct AppearanceSettingsView: View {
    @Environment(\.themeTokens) private var tokens
    @ObservedObject var themeManager: ThemeManager

    /// 主题模式本地镜像：保证 `Picker` 交互即时刷新，并经 `onChange` 写回管理器（需求 17.2）。
    @State private var mode: ThemeMode

    /// - Parameter themeManager: 主题管理服务（提供并切换当前主题模式）。
    init(themeManager: ThemeManager) {
        self.themeManager = themeManager
        _mode = State(initialValue: themeManager.currentMode)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: tokens.spacingUnit * 2) {
                Text("外观主题")
                    .font(.headline)
                    .foregroundColor(tokens.textPrimary)
                Text("选择应用的浅色或深色外观，或跟随 macOS 系统设置自动切换。")
                    .font(.caption)
                    .foregroundColor(tokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Picker("外观主题", selection: $mode) {
                    Text("浅色").tag(ThemeMode.light)
                    Text("深色").tag(ThemeMode.dark)
                    Text("跟随系统").tag(ThemeMode.system)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(tokens.spacingUnit * 3)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(tokens.background)
        .onChange(of: mode) { _, newValue in
            themeManager.setMode(newValue)
        }
    }
}

#if DEBUG
/// 预览：覆盖「跟随系统（浅色令牌）」与「深色」两种典型组合。
///
/// 用经典 `PreviewProvider` 而非 `#Preview` 宏，以兼容仅装有 Command Line Tools 的构建环境。
struct AppearanceSettingsView_Previews: PreviewProvider {
    @MainActor
    private static func makeManager(theme: ThemeMode) -> ThemeManager {
        let suite = "preview.appearance.\(theme.rawValue)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        let store = SettingsStore(defaults: defaults, keychain: AppearancePreviewKeychain())
        store.updateTheme(theme)
        return ThemeManager(settingsStore: store)
    }

    static var previews: some View {
        Group {
            AppearanceSettingsView(themeManager: makeManager(theme: .system))
                .frame(width: 480, height: 320)
                .themeTokens(.light)
                .previewDisplayName("跟随系统-浅色")

            AppearanceSettingsView(themeManager: makeManager(theme: .dark))
                .frame(width: 480, height: 320)
                .themeTokens(.dark)
                .previewDisplayName("深色")
        }
    }
}

/// 预览专用的内存版 Keychain，避免预览写入真实钥匙串。
private final class AppearancePreviewKeychain: KeychainStoring {
    private var storage: [KeychainServiceIdentifier: String] = [:]
    func saveAPIKey(_ apiKey: String, for service: KeychainServiceIdentifier) throws {
        storage[service] = apiKey
    }
    func loadAPIKey(for service: KeychainServiceIdentifier) throws -> String? {
        storage[service]
    }
    func deleteAPIKey(for service: KeychainServiceIdentifier) throws {
        storage[service] = nil
    }
}
#endif
