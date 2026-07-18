import SwiftUI

/// The app's semantic colour palette — **FocusGlobe 2026**: ultra-minimal,
/// cinematic, cozy. Dark Mode is the app's default face: a near-black warm
/// canvas where huge skies and a tiny white balloon are the visual, not chrome.
/// Light Mode is soft warm paper. No cold navy anywhere; no clutter colours.
///
/// Token *names* and *signatures* are unchanged from previous passes, so every
/// screen that consumes them inherits the new look with no layout edits.
enum AppColors {

    // MARK: The ONE neutral foundation — #181721
    /// FocusGlobe's canonical dark neutral (the color behind the app logo).
    /// EVERY neutral dark surface — Settings/Passport backgrounds, dark modals,
    /// neutral sheets and cards, supporting chrome — derives from this single
    /// value (or an opacity/shade variant of it), never from ad-hoc charcoals.
    /// Sky artwork and atmospheric environments are exempt: they provide the
    /// emotional color; this provides the calm ground beneath everything else.
    static let neutralBase = Color(hex: 0x181721)
    /// A slightly deeper shade of the same hue for gradient bottoms/depth.
    static let neutralDeep = Color(hex: 0x100F16)
    /// A slightly lifted shade of the same hue for elevated surfaces.
    static let neutralRaised = Color(hex: 0x1E1D29)

    // MARK: Backgrounds  (the #181721 neutral by night / soft warm paper by day)
    static let backgroundTop    = Color.dynamic(light: 0xF7F0E4, dark: 0x181721)
    static let backgroundBottom = Color.dynamic(light: 0xEFE6D6, dark: 0x100F16)

    // MARK: Surfaces / glass (dark variants derive from the #181721 family)
    static let glassTint   = Color.dynamic(light: 0xFCF7EC, dark: 0x1E1D29)
    static let islandTint  = Color.dynamic(light: 0xFAF4E7, dark: 0x1B1A25)

    // MARK: Text  (warm cream on night / warm ink on paper)
    static let textPrimary   = Color.dynamic(light: 0x26221D, dark: 0xF7F1E7)
    static let textSecondary = Color.dynamic(light: 0x8A7D6A, dark: 0xA89D8C)
    static let textTertiary  = Color.dynamic(light: 0xAFA28C, dark: 0x6F675A)

    // MARK: Brand  (calm mint-teal accent)
    static let brand     = Color.dynamic(light: 0x2E9C80, dark: 0x6FD8B8)
    static let brandDeep = Color.dynamic(light: 0x217459, dark: 0x4DB596)
    static let brandSoft = Color.dynamic(light: 0xCFE8DE, dark: 0x1B2E28)

    // MARK: Primary CTA — bold, minimal: ink pill by day, cream pill by night.
    static let ctaFill = Color.dynamic(light: 0x1C1A17, dark: 0xF4EFE4)
    /// The label colour on `ctaFill`.
    static let ctaText = Color.dynamic(light: 0xF7F1E7, dark: 0x14120E)

    // MARK: Accents / status
    /// Premium gold — Ultra, streak embers, rare moments.
    static let gold    = Color.dynamic(light: 0xD9A94F, dark: 0xD8B56D)
    static let success = Color.dynamic(light: 0x3F9C7C, dark: 0x6FD8B8)
    /// Coral action/danger accent (rope, destructive).
    static let danger  = Color.dynamic(light: 0xD4553B, dark: 0xE9654B)

    // MARK: Lines & separators
    static var hairline: Color {
        Color.dynamic(light: 0x26221D, lightAlpha: 0.09, dark: 0xF7F1E7, darkAlpha: 0.09)
    }
    static var glassStroke: Color {
        Color.dynamic(light: 0x26221D, lightAlpha: 0.12, dark: 0xFFFFFF, darkAlpha: 0.10)
    }

    /// Soft shadow used under floating elements.
    static var shadow: Color { Color.black.opacity(0.24) }

    // MARK: - Expedition/material tokens (kept for compatibility; re-tuned to
    // the #181721 neutral family in dark)
    static let paper       = Color.dynamic(light: 0xF7F0E4, dark: 0x181721)
    static let paperDeep   = Color.dynamic(light: 0xEFE6D6, dark: 0x1E1D29)
    static let sepia       = Color.dynamic(light: 0x8A7D6A, dark: 0xA89D8C)
    static let ink         = Color.dynamic(light: 0x26221D, dark: 0xF7F1E7)
    static let terracotta  = Color.dynamic(light: 0xD4553B, dark: 0xE9654B)
    static let teal        = Color.dynamic(light: 0x2E9C80, dark: 0x6FD8B8)
    static let waxSeal     = Color.dynamic(light: 0xB2402C, dark: 0xE9654B)
    static let goldFoil    = Color.dynamic(light: 0xD9A94F, dark: 0xD8B56D)
    static let lantern     = Color.dynamic(light: 0xE8B45C, dark: 0xE9C07A)
    /// The balloon's default white (warm, never pure white).
    static let balloonWhite = Color.dynamic(light: 0xFFFFFF, dark: 0xF4EFE4)
}
