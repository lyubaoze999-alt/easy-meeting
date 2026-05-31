import SwiftUI

/// 设计令牌（对应需求 17.4、17.5）。
///
/// 一套主题等于一份 `ThemeTokens`。颜色、圆角、间距全部抽为令牌，视图只引用
/// 令牌而不写死样式值，新增主题只需新增一份令牌并在选择器登记，无需改业务代码
/// （需求 17.5）。色值取自 Stitch 设计稿（见 design.md「设计令牌」表）。
struct ThemeTokens: Equatable {
    /// 主色：主要操作按钮、强调元素。
    let accentPrimary: Color
    /// 辅色：次要强调、选中态背景等。
    let accentSecondary: Color
    /// 背景：窗口/面板底色。
    let background: Color
    /// 卡片面：卡片、列表项等悬浮于背景之上的表面。
    let surface: Color
    /// 主文字：标题与正文主色。
    let textPrimary: Color
    /// 次要文字：时间、辅助说明等降级信息。
    let textSecondary: Color
    /// 录制红：录音中指示、波形等录制态元素。
    let recording: Color
    /// 圆角半径：卡片、按钮统一圆角。
    let cornerRadius: CGFloat
    /// 间距基准单位：布局间距以其倍数派生。
    let spacingUnit: CGFloat
}

extension ThemeTokens {
    /// 浅色主题令牌（design.md「设计令牌」表浅色列）。
    static let light = ThemeTokens(
        accentPrimary: Color(hex: "#6366F1"),
        accentSecondary: Color(hex: "#ADC6FF"),
        background: Color(hex: "#FFFFFF"),
        surface: Color(hex: "#FAF9FE"),
        textPrimary: Color(hex: "#1A1B1F"),
        textSecondary: Color(hex: "#6B6F76"),
        recording: Color(hex: "#FF3B30"),
        cornerRadius: 12,
        spacingUnit: 8
    )

    /// 深色主题令牌（design.md「设计令牌」表深色列）。
    static let dark = ThemeTokens(
        accentPrimary: Color(hex: "#6366F1"),
        accentSecondary: Color(hex: "#C0C1FF"),
        background: Color(hex: "#0B1326"),
        surface: Color(hex: "#2D3449"),
        textPrimary: Color(hex: "#FFFFFF"),
        textSecondary: Color(hex: "#A8ADB8"),
        recording: Color(hex: "#FFB4AB"),
        cornerRadius: 12,
        spacingUnit: 8
    )
}
