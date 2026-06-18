import SwiftUI

/// The app's semantic colour palette. Every colour adapts to Light and Dark
/// mode so the whole UI looks intentional in both.
///
/// Light Mode → soft white, warm cream, pale sky, clean daylight.
/// Dark Mode  → deep navy, soft black, moonlight, calm night sky.
enum AppColors {

    // MARK: Backgrounds
    static let backgroundTop    = Color.dynamic(light: 0xF7F9FD, dark: 0x080B16)
    static let backgroundBottom = Color.dynamic(light: 0xE9F0FB, dark: 0x0D1326)

    // MARK: Surfaces / glass
    /// A subtle tint layered over system material to give glass depth.
    static let glassTint   = Color.dynamic(light: 0xFFFFFF, dark: 0x1A2238)
    static let islandTint  = Color.dynamic(light: 0xFFFFFF, dark: 0x161E33)

    // MARK: Text
    static let textPrimary   = Color.dynamic(light: 0x1A2230, dark: 0xF1F4FB)
    static let textSecondary = Color.dynamic(light: 0x586176, dark: 0xAEB7CC)
    static let textTertiary  = Color.dynamic(light: 0x8C95A8, dark: 0x707A92)

    // MARK: Brand
    static let brand     = Color.dynamic(light: 0x3E63E6, dark: 0x8FA2FF)
    static let brandDeep = Color.dynamic(light: 0x2E49C4, dark: 0x6C82F2)
    static let brandSoft = Color.dynamic(light: 0xCBD8FF, dark: 0x2A3868)

    // MARK: Accents / status
    static let gold    = Color.dynamic(light: 0xE0A23E, dark: 0xF2C879)
    static let success = Color.dynamic(light: 0x2FA66A, dark: 0x57D49A)
    static let danger  = Color.dynamic(light: 0xD7553F, dark: 0xF08A77)

    // MARK: Lines & separators (alpha-based so they adapt automatically)
    static var hairline: Color { Color.primary.opacity(0.07) }
    static var glassStroke: Color { Color.white.opacity(0.18) }

    /// Soft shadow used under floating elements.
    static var shadow: Color { Color.black.opacity(0.16) }
}
