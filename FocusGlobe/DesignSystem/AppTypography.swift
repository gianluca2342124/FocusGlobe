import SwiftUI

/// Typography scale. Uses the clean **system** San Francisco (SF Pro) design
/// throughout for a modern, premium, highly readable feel — a polished
/// Apple/Google-style app voice, never a rounded/"cute" look. A few display
/// heroes below keep an elegant serif accent; everything else is system sans.
///
/// Every size is multiplied by `Layout.fontScale`, which is **1.0 on iPhone**
/// (so iPhone is byte-identical to before) and larger on iPad/Mac — so the whole
/// app's typography scales up uniformly on tablet without touching call sites.
enum AppTypography {
    // `Layout.fontScale` is constant per device (1.0 iPhone, ~1.15 iPad/Mac), so
    // these are computed once as stored `static let`s — no per-render Font work.
    private static let s: CGFloat = Layout.fontScale

    static let hero      = Font.system(size: 32 * s, weight: .bold,      design: .default)
    static let title     = Font.system(size: 26 * s, weight: .semibold,  design: .default)
    static let title2    = Font.system(size: 21 * s, weight: .semibold,  design: .default)
    static let headline  = Font.system(size: 18 * s, weight: .semibold,  design: .default)
    static let body      = Font.system(size: 16 * s, weight: .regular,   design: .default)
    static let callout   = Font.system(size: 15 * s, weight: .medium,    design: .default)
    static let subhead   = Font.system(size: 14 * s, weight: .medium,    design: .default)
    static let caption   = Font.system(size: 12.5 * s, weight: .medium,  design: .default)
    static let micro     = Font.system(size: 11 * s, weight: .semibold,  design: .default)

    /// Countdown clocks — monospaced digits so the layout never jitters.
    static let timer      = Font.system(size: 46 * s, weight: .semibold, design: .default).monospacedDigit()
    static let timerLarge = Font.system(size: 66 * s, weight: .bold,     design: .default).monospacedDigit()
    static let timerPill  = Font.system(size: 17 * s, weight: .semibold, design: .default).monospacedDigit()

    // MARK: - Expedition serif display
    //
    // An elegant serif (system **New York**, `design: .serif`) for titles,
    // destinations and journal headings — it evokes vintage print and travel
    // labels, and reads as clearly *not* a generic dashboard. Body/UI stays on the
    // rounded sans above; serif is reserved for display moments. New York is a
    // system font, so nothing is bundled and there is no licensing question.

    /// Big display serif — screen heroes and the destination on the expedition page.
    static let serifHero    = Font.system(size: 34 * s, weight: .bold,     design: .serif)
    /// Section / sheet / popup titles. Modernised to bold SF Rounded (the serif is
    /// now reserved for the Home greeting and a few display heroes) so popups read
    /// clean and premium with a strong hierarchy. Token names kept to avoid churn.
    static let serifTitle   = Font.system(size: 28 * s, weight: .bold, design: .default)
    static let serifTitle2  = Font.system(size: 22 * s, weight: .bold, design: .default)
    /// A destination / place name as it would be lettered on a map or postcard.
    static let destination  = Font.system(size: 24 * s, weight: .medium,   design: .serif)
    /// Journal prose — italic-friendly serif body for quotes and field notes.
    static let serifBody    = Font.system(size: 17 * s, weight: .regular,  design: .serif)
    /// Small serif label for stamps, dates and captions on the page.
    static let serifCaption = Font.system(size: 13 * s, weight: .medium,   design: .serif)
}
