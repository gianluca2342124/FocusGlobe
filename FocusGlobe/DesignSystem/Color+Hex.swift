import SwiftUI

extension Color {
    /// Creates a colour from a 0xRRGGBB hex value (with optional alpha).
    init(hex: UInt, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    /// Returns a colour that resolves differently in light vs dark mode.
    static func dynamic(light: UInt, dark: UInt) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
    }

    /// Like `dynamic(light:dark:)` but with a per-mode alpha, so a token can be, for
    /// example, a subtle dark hairline in Light Mode and a soft white one in Dark
    /// Mode without changing the Dark value.
    static func dynamic(light: UInt, lightAlpha: Double,
                        dark: UInt, darkAlpha: Double) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark, alpha: darkAlpha))
                : UIColor(Color(hex: light, alpha: lightAlpha))
        })
    }
}
