import SwiftUI

/// The app's semantic colour palette — the **Expedition** identity.
///
/// FocusGlobe reads like paper, ink and golden-hour light, not a satellite
/// dashboard. Every colour adapts to Light and Dark so the whole UI looks
/// intentional in both, and there is **no pure black and no pure white anywhere**.
///
/// Light Mode → "field-journal daylight": warm cream paper, sepia ink, aged gold.
/// Dark Mode  → "night expedition": deep navy paper, cream ink, warm lantern glow.
///
/// The token *names* and *signatures* are unchanged from the previous design, so
/// every screen that already consumes them (all of them) simply inherits the new
/// look with no layout edits — only the underlying values changed, plus a set of
/// expedition-specific additions at the bottom.
enum AppColors {

    // MARK: Backgrounds  (aged paper in Light, deep navy paper in Dark)
    static let backgroundTop    = Color.dynamic(light: 0xF7EFDD, dark: 0x161B26)
    static let backgroundBottom = Color.dynamic(light: 0xEFE4CB, dark: 0x0F131B)

    // MARK: Surfaces / glass  (a lighter parchment card that lifts off the page)
    static let glassTint   = Color.dynamic(light: 0xFBF5E6, dark: 0x1E2534)
    static let islandTint  = Color.dynamic(light: 0xFCF7EA, dark: 0x1B2130)

    // MARK: Text  (sepia ink on paper / cream ink on night)
    static let textPrimary   = Color.dynamic(light: 0x2E2417, dark: 0xF1E7D2)
    static let textSecondary = Color.dynamic(light: 0x6B5C45, dark: 0xC2B69C)
    static let textTertiary  = Color.dynamic(light: 0x9C8C71, dark: 0x8A7F68)

    // MARK: Brand  (deep teal — the expedition's signature accent)
    static let brand     = Color.dynamic(light: 0x1E6E68, dark: 0x5CB4AC)
    static let brandDeep = Color.dynamic(light: 0x14524D, dark: 0x3C928A)
    static let brandSoft = Color.dynamic(light: 0xC5DBD7, dark: 0x23413E)

    // MARK: Primary CTA
    /// A confident teal "set-off" button with cream label — reads cleanly over the
    /// dark expedition map on Home *and* over cream paper screens, and is visually
    /// distinct from the generic white/blue buttons of similar apps.
    static let ctaFill = Color.dynamic(light: 0x1E6E68, dark: 0x2E8880)
    /// The label colour on `ctaFill`.
    static let ctaText = Color.dynamic(light: 0xF8F1E1, dark: 0xF3EAD6)

    // MARK: Accents / status
    /// Aged gold foil — used sparingly for premium touches and highlights.
    static let gold    = Color.dynamic(light: 0xB78A2E, dark: 0xEBB765)
    static let success = Color.dynamic(light: 0x4F7A46, dark: 0x62B07F)
    /// Doubles as the error colour and echoes the sealing-wax accent.
    static let danger  = Color.dynamic(light: 0xA23B2C, dark: 0xE07A5F)

    // MARK: Lines & separators  (faint ink rules on paper, in both modes)
    static var hairline: Color {
        Color.dynamic(light: 0x2E2417, lightAlpha: 0.10, dark: 0xF1E7D2, darkAlpha: 0.10)
    }
    /// Card / pill edge — a subtle ink hairline on the parchment card.
    static var glassStroke: Color {
        Color.dynamic(light: 0x2E2417, lightAlpha: 0.14, dark: 0xF1E7D2, darkAlpha: 0.16)
    }

    /// Soft shadow used under floating elements (kept neutral so it never tints).
    static var shadow: Color { Color.black.opacity(0.16) }

    // MARK: - Expedition palette (new semantic tokens)
    //
    // These name the expedition materials directly, for surfaces built during the
    // redesign. They intentionally overlap some of the tokens above (e.g. `ink` ==
    // `textPrimary`) so new code can read expressively without diverging values.

    /// Warm paper — the base "page" colour.
    static let paper       = Color.dynamic(light: 0xF7EFDD, dark: 0x161B26)
    /// A slightly deeper aged-paper tone for layering pages/cards.
    static let paperDeep   = Color.dynamic(light: 0xEADFC4, dark: 0x1B2130)
    /// Sepia — muted brown for secondary ink, sketch lines, faded stamps.
    static let sepia       = Color.dynamic(light: 0x6B5C45, dark: 0xC2B69C)
    /// Ink — the darkest writing colour on the page.
    static let ink         = Color.dynamic(light: 0x2E2417, dark: 0xF1E7D2)
    /// Muted terracotta — warm secondary accent (routes, tags, illustrations).
    static let terracotta  = Color.dynamic(light: 0xBE6A45, dark: 0xD98A63)
    /// Deep teal — the primary accent (alias of `brand`, named for clarity).
    static let teal        = Color.dynamic(light: 0x1E6E68, dark: 0x5CB4AC)
    /// Sealing-wax red — the signature "stamp/seal" accent. Use it rarely and it
    /// becomes the thing people remember.
    static let waxSeal     = Color.dynamic(light: 0x9B3324, dark: 0xC65C4A)
    /// Gold foil — premium/rare highlight (alias of `gold`).
    static let goldFoil    = Color.dynamic(light: 0xB78A2E, dark: 0xEBB765)
    /// Warm lantern glow — the light source of the night expedition.
    static let lantern     = Color.dynamic(light: 0xE8A94B, dark: 0xF0BE6E)
}
