import SwiftUI

/// Typography scale. Uses the rounded San Francisco design throughout for a
/// soft, calm, premium feel.
///
/// Every size is multiplied by `Layout.fontScale`, which is **1.0 on iPhone**
/// (so iPhone is byte-identical to before) and larger on iPad/Mac — so the whole
/// app's typography scales up uniformly on tablet without touching call sites.
enum AppTypography {
    private static var s: CGFloat { Layout.fontScale }

    static var hero: Font      { .system(size: 32 * s, weight: .bold,      design: .rounded) }
    static var title: Font     { .system(size: 26 * s, weight: .semibold,  design: .rounded) }
    static var title2: Font    { .system(size: 21 * s, weight: .semibold,  design: .rounded) }
    static var headline: Font  { .system(size: 18 * s, weight: .semibold,  design: .rounded) }
    static var body: Font      { .system(size: 16 * s, weight: .regular,   design: .rounded) }
    static var callout: Font   { .system(size: 15 * s, weight: .medium,    design: .rounded) }
    static var subhead: Font   { .system(size: 14 * s, weight: .medium,    design: .rounded) }
    static var caption: Font   { .system(size: 12.5 * s, weight: .medium,  design: .rounded) }
    static var micro: Font     { .system(size: 11 * s, weight: .semibold,  design: .rounded) }

    /// Countdown clocks — monospaced digits so the layout never jitters.
    static var timer: Font      { .system(size: 46 * s, weight: .semibold, design: .rounded).monospacedDigit() }
    static var timerLarge: Font { .system(size: 66 * s, weight: .bold,     design: .rounded).monospacedDigit() }
    static var timerPill: Font  { .system(size: 17 * s, weight: .semibold, design: .rounded).monospacedDigit() }
}
