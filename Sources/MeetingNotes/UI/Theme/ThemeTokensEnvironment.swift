import SwiftUI

/// 通过 `EnvironmentValues` 将设计令牌注入视图树（对应需求 17.4）。
///
/// 视图以 `@Environment(\.themeTokens) private var tokens` 读取当前令牌，
/// 仅引用令牌取色，不写死色值。根视图用 `.themeTokens(_:)` 注入对应主题的
/// 令牌，主题切换时下游视图自动随之刷新。
private struct ThemeTokensKey: EnvironmentKey {
    /// 默认值取浅色令牌，保证未显式注入时视图仍有可用令牌。
    static let defaultValue: ThemeTokens = .light
}

extension EnvironmentValues {
    var themeTokens: ThemeTokens {
        get { self[ThemeTokensKey.self] }
        set { self[ThemeTokensKey.self] = newValue }
    }
}

extension View {
    /// 将一套设计令牌注入视图树，供下游视图通过 `@Environment(\.themeTokens)` 读取。
    func themeTokens(_ tokens: ThemeTokens) -> some View {
        environment(\.themeTokens, tokens)
    }
}
