import SwiftUI

/// Centralised responsive layout tokens + helpers, so every screen adapts cleanly
/// from a compact iPhone up through iPad (portrait & landscape), resizable Stage
/// Manager windows and Apple Silicon Mac — without hard-coded, phone-only sizing.
///
/// Design intent: **the premium iPhone-portrait layout is unchanged.** Every max
/// width below is larger than an iPhone-portrait content width, so on a phone the
/// `…MaxWidth` modifiers are no-ops (content stays full-width) and the adaptive
/// grids resolve to the same 2 columns. On wider displays the same modifiers
/// centre content within a comfortable band and the grids gain columns — so a
/// screen never stretches into one ugly full-width sheet or a lonely phone column.
enum Layout {
    // Comfortable maximum content widths (centred on large displays; no-ops on
    // phones narrower than the value). Tuned to read as intentional panels.
    /// General scrollable, content-heavy screens (e.g. Passport).
    static let content: CGFloat = 700
    /// Text-led single column (e.g. Landing).
    static let readable: CGFloat = 560
    /// Settings list.
    static let settings: CGFloat = 620
    /// Paywall purchase panel.
    static let paywall: CGFloat = 540
    /// Home / Route-selection bottom control clusters.
    static let cluster: CGFloat = 560
    /// Active-journey bottom readouts band.
    static let journeyReadouts: CGFloat = 620
    /// Tasteful cap for the in-journey banner so it never spans a huge window.
    static let bannerMaxWidth: CGFloat = 480

    /// Adaptive card-grid columns: ~2 on a phone, more on iPad/Mac, reflowing in
    /// resizable windows. `minWidth` sets the smallest acceptable tile and the
    /// `maximum` keeps tiles from ballooning on very wide displays.
    static func cardColumns(minWidth: CGFloat = 158,
                            maxWidth: CGFloat = 260,
                            spacing: CGFloat = AppSpacing.sm) -> [GridItem] {
        [GridItem(.adaptive(minimum: minWidth, maximum: maxWidth), spacing: spacing)]
    }
}

extension View {
    /// Centre content within a max width on large screens (a no-op on phones
    /// narrower than `width`). Built on the existing `readableWidth`.
    func contentMaxWidth(_ width: CGFloat = Layout.content) -> some View {
        readableWidth(width)
    }
    /// Centre a Settings list within a comfortable width on iPad/Mac.
    func settingsMaxWidth() -> some View { readableWidth(Layout.settings) }
    /// Centre the paywall purchase panel within a premium width on iPad/Mac.
    func paywallMaxWidth() -> some View { readableWidth(Layout.paywall) }
    /// Centre a bottom control cluster (Home / Route selection) on wide screens.
    func clusterMaxWidth() -> some View { readableWidth(Layout.cluster) }
}
