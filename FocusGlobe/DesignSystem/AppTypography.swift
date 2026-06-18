import SwiftUI

/// Typography scale. Uses the rounded San Francisco design throughout for a
/// soft, calm, premium feel.
enum AppTypography {
    static let hero      = Font.system(size: 32, weight: .bold,      design: .rounded)
    static let title     = Font.system(size: 26, weight: .semibold,  design: .rounded)
    static let title2    = Font.system(size: 21, weight: .semibold,  design: .rounded)
    static let headline  = Font.system(size: 18, weight: .semibold,  design: .rounded)
    static let body      = Font.system(size: 16, weight: .regular,   design: .rounded)
    static let callout   = Font.system(size: 15, weight: .medium,    design: .rounded)
    static let subhead   = Font.system(size: 14, weight: .medium,    design: .rounded)
    static let caption   = Font.system(size: 12.5, weight: .medium,  design: .rounded)
    static let micro     = Font.system(size: 11, weight: .semibold,  design: .rounded)

    /// Countdown clocks — monospaced digits so the layout never jitters.
    static let timer      = Font.system(size: 46, weight: .semibold, design: .rounded).monospacedDigit()
    static let timerLarge = Font.system(size: 66, weight: .bold,     design: .rounded).monospacedDigit()
    static let timerPill  = Font.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit()
}
