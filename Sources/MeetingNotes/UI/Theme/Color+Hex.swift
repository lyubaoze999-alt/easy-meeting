import SwiftUI

/// 由十六进制字符串构造 `Color` 的便捷扩展。
///
/// 设计令牌（ThemeTokens）以设计稿给出的十六进制色值录入，此扩展仅供
/// 主题令牌定义内部使用，业务视图不应直接调用，以保证「令牌是唯一色值来源」
/// （需求 17.4）。支持 `#RRGGBB` / `RRGGBB` 两种写法，非法输入回退为黑色。
extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red, green, blue: UInt64
        if cleaned.count == 6 {
            red = (value >> 16) & 0xFF
            green = (value >> 8) & 0xFF
            blue = value & 0xFF
        } else {
            (red, green, blue) = (0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(red) / 255.0,
            green: Double(green) / 255.0,
            blue: Double(blue) / 255.0,
            opacity: 1.0
        )
    }
}
