import SwiftUI

/// Typography scale. Uses the rounded San Francisco design throughout for a
/// soft, calm, premium feel.
///
/// Every size is multiplied by `Layout.fontScale`, which is **1.0 on iPhone**
/// (so iPhone is byte-identical to before) and larger on iPad/Mac — so the whole
/// app's typography scales up uniformly on tablet without touching call sites.
enum AppTypography {
    // `Layout.fontScale` is constant per device (1.0 iPhone, ~1.15 iPad/Mac), so
    // these are computed once as stored `static let`s — no per-render Font work.
    private static let s: CGFloat = Layout.fontScale

    static let hero      = Font.system(size: 32 * s, weight: .bold,      design: .rounded)
    static let title     = Font.system(size: 26 * s, weight: .semibold,  design: .rounded)
    static let title2    = Font.system(size: 21 * s, weight: .semibold,  design: .rounded)
    static let headline  = Font.system(size: 18 * s, weight: .semibold,  design: .rounded)
    static let body      = Font.system(size: 16 * s, weight: .regular,   design: .rounded)
    static let callout   = Font.system(size: 15 * s, weight: .medium,    design: .rounded)
    static let subhead   = Font.system(size: 14 * s, weight: .medium,    design: .rounded)
    static let caption   = Font.system(size: 12.5 * s, weight: .medium,  design: .rounded)
    static let micro     = Font.system(size: 11 * s, weight: .semibold,  design: .rounded)

    /// Countdown clocks — monospaced digits so the layout never jitters.
    static let timer      = Font.system(size: 46 * s, weight: .semibold, design: .rounded).monospacedDigit()
    static let timerLarge = Font.system(size: 66 * s, weight: .bold,     design: .rounded).monospacedDigit()
    static let timerPill  = Font.system(size: 17 * s, weight: .semibold, design: .rounded).monospacedDigit()
}
