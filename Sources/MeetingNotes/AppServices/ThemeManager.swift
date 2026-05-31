import Foundation
import Combine
#if canImport(AppKit)
import AppKit
#endif

/// 主题管理（应用服务层，对应设计「ThemeManager / Theme System」、需求 17）。
///
/// 职责：
/// - 提供浅色、深色、跟随系统三个主题选项（需求 17.1）。
/// - 将当前主题解析为一套 `ThemeTokens` 并以 `@Published` 暴露，视图绑定后
///   切换主题即时生效（需求 17.2）。
/// - 跟随系统模式下监听 `NSApp.effectiveAppearance`，系统深浅色变化时自动切换
///   令牌（需求 17.3）。
///
/// 单一数据源约束：选中的 `ThemeMode` 始终由注入的 `SettingsStore` 持有与持久化，
/// 本类不复制一份主题状态，只负责把模式解析为令牌并对外发布。
@MainActor
final class ThemeManager: ObservableObject {
    /// 当前生效的设计令牌。视图通过它取色，值变化即驱动界面刷新（需求 17.2）。
    @Published private(set) var tokens: ThemeTokens

    /// 配置管理，主题模式的唯一持久化来源（需求 17.1）。
    private let settingsStore: SettingsStore

    /// 对 `SettingsStore.settings.theme` 的订阅句柄。
    private var cancellables = Set<AnyCancellable>()

    #if canImport(AppKit)
    /// 对 `NSApplication.effectiveAppearance` 的 KVO 观察句柄（需求 17.3）。
    private var appearanceObservation: NSKeyValueObservation?
    #endif

    /// 当前选中的主题模式（读取自单一数据源 `SettingsStore`）。
    var currentMode: ThemeMode {
        settingsStore.settings.theme
    }

    /// - Parameter settingsStore: 配置管理，提供并持久化选中的主题模式。
    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        self.tokens = Self.resolveTokens(for: settingsStore.settings.theme)
        observeSelectedMode()
        observeSystemAppearance()
    }
}

// MARK: - 切换主题

extension ThemeManager {
    /// 切换主题模式（需求 17.1、17.2）。
    ///
    /// 写回 `SettingsStore`（唯一数据源并触发持久化），令牌随之即时重算并发布：
    /// `SettingsStore.settings` 的变更会同步驱动 `observeSelectedMode` 的订阅，
    /// 因此本方法返回前 `tokens` 已更新到新模式对应的令牌。
    func setMode(_ mode: ThemeMode) {
        settingsStore.updateTheme(mode)
    }
}

// MARK: - 令牌解析

extension ThemeManager {
    /// 将主题模式解析为一套设计令牌。
    ///
    /// - `light` → `ThemeTokens.light`
    /// - `dark` → `ThemeTokens.dark`
    /// - `system` → 依据系统外观就近匹配（浅色 Aqua → 浅色令牌，深色 darkAqua → 深色令牌）。
    static func resolveTokens(for mode: ThemeMode) -> ThemeTokens {
        switch mode {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return systemTokens()
        }
    }

    /// 跟随系统时，依据当前系统外观解析令牌（需求 17.3）。
    ///
    /// 无 AppKit 的环境（非 macOS 宿主）回退为浅色令牌。
    static func systemTokens() -> ThemeTokens {
        #if canImport(AppKit)
        let appearance = NSApplication.shared.effectiveAppearance
        let matched = appearance.bestMatch(from: [.aqua, .darkAqua])
        return matched == .darkAqua ? .dark : .light
        #else
        return .light
        #endif
    }

    /// 按给定模式重算令牌，仅在结果变化时发布，避免无谓刷新。
    private func applyTokens(for mode: ThemeMode) {
        let resolved = Self.resolveTokens(for: mode)
        if resolved != tokens {
            tokens = resolved
        }
    }
}

// MARK: - 监听

extension ThemeManager {
    /// 订阅单一数据源中的主题模式变化，模式改变时即时重算令牌（需求 17.2）。
    ///
    /// 订阅会立即收到当前模式，对已初始化的 `tokens` 是幂等的。
    private func observeSelectedMode() {
        settingsStore.$settings
            .map(\.theme)
            .removeDuplicates()
            .sink { [weak self] mode in
                self?.applyTokens(for: mode)
            }
            .store(in: &cancellables)
    }

    /// 监听系统外观变化（需求 17.3）。
    ///
    /// 仅当当前模式为 `system` 时，系统深浅色切换才会改变令牌；显式选择浅色或深色时，
    /// 重算结果与系统外观无关，故自动忽略系统外观变化。
    private func observeSystemAppearance() {
        #if canImport(AppKit)
        appearanceObservation = NSApplication.shared.observe(
            \.effectiveAppearance,
            options: [.new]
        ) { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                self.applyTokens(for: self.currentMode)
            }
        }
        #endif
    }
}
