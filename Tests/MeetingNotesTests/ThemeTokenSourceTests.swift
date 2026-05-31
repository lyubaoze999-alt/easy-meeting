import XCTest
import SwiftCheck
@testable import MeetingNotes

/// Property 6「主题令牌唯一来源」属性测试（需求 17.4、17.5）。
///
/// 不变量：
/// - 每个 ThemeMode 解析出的令牌完全由其对应的 ThemeTokens 决定（light→.light，dark→.dark）；
/// - 切换主题后解析结果随之变化，且仅来自 ThemeTokens（无硬编码、无第三来源）。
final class ThemeTokenSourceTests: XCTestCase {

    /// 任意主题模式生成器。
    private var modeGen: Gen<ThemeMode> {
        Gen.fromElements(of: [ThemeMode.light, .dark, .system])
    }

    func testResolvedTokensComeOnlyFromThemeTokens() {
        property("light/dark 模式解析出的令牌恒等于对应的 ThemeTokens 静态实例") <- forAll(modeGen) { (mode: ThemeMode) in
            let resolved = ThemeManager.resolveTokens(for: mode)
            switch mode {
            case .light:
                return resolved == ThemeTokens.light
            case .dark:
                return resolved == ThemeTokens.dark
            case .system:
                // 跟随系统：解析结果必为 light 或 dark 两套令牌之一，不存在第三来源。
                return resolved == ThemeTokens.light || resolved == ThemeTokens.dark
            }
        }
    }

    func testLightAndDarkTokensAreDistinct() {
        // 两套令牌必须有实际差异，否则「唯一来源」失去意义。
        XCTAssertNotEqual(ThemeTokens.light, ThemeTokens.dark)
    }
}
