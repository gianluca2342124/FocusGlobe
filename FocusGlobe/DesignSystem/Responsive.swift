import SwiftUI
import UIKit

/// Centralised responsive layout tokens + helpers so FocusGlobe reads as a real
/// iPad/Mac app — not a phone UI centred on a big screen — while leaving the
/// premium iPhone-portrait layout unchanged.
///
/// Two signals are used deliberately:
///  • **Horizontal size class** (`RegularMaxWidth`) drives content **centering**.
///    It correctly stays compact in narrow iPad multitasking / Slide Over windows,
///    so those don't get an over-wide centred column.
///  • **Idiom** (`Layout.isPadIdiom` / `Layout.pad(_:_:)`) drives **scale** of
///    fonts, controls and panels. Unlike the size class it is reliable inside
///    sheets/covers (where iPad reports a compact width), and reports `.pad` for
///    Mac "Designed for iPad" — so tablet sizing applies there too.
enum Layout {
    // Tablet (regular) maximum content widths — generous, so panels feel
    // intentionally designed for a tablet rather than a narrow phone column.
    static let content: CGFloat = 900      // Passport / general scroll screens
    static let readable: CGFloat = 720      // Landing single column
    static let settings: CGFloat = 760
    static let paywall: CGFloat = 700
    static let cluster: CGFloat = 720       // Home / Route bottom clusters
    static let journeyReadouts: CGFloat = 780
    /// Tasteful cap for the in-journey banner so it never spans a huge window.
    static let bannerMaxWidth: CGFloat = 520

    /// True on iPad and on Mac running the app "Designed for iPad". Reliable in
    /// sheets/covers (unlike the size class), so it's used to scale up sizing.
    static var isPadIdiom: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    /// Pick a phone vs tablet value (font size, padding, height, …).
    static func pad<T>(_ phone: T, _ tablet: T) -> T { isPadIdiom ? tablet : phone }

    /// Adaptive card-grid columns, scaled by layout: ~2 columns on a phone, more
    /// and larger tiles on iPad/Mac (so cards feel tablet-native, not shrunken).
    static func cardColumns(regular: Bool,
                            minPhone: CGFloat = 158,
                            minPad: CGFloat = 210,
                            spacing: CGFloat = AppSpacing.sm) -> [GridItem] {
        let minW = regular ? minPad : minPhone
        let maxW = regular ? 360 : 260
        return [GridItem(.adaptive(minimum: minW, maximum: maxW), spacing: spacing)]
    }
}

/// Caps width to `regular` ONLY when the horizontal size class is regular (iPad /
/// Mac / wide multitasking) and centres it. On compact (iPhone, and narrow iPad
/// multitasking) it is a no-op — full width, exactly as before on iPhone.
private struct RegularMaxWidth: ViewModifier {
    @Environment(\.horizontalSizeClass) private var hSize
    let regular: CGFloat
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: hSize == .regular ? regular : .infinity)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    /// Centre content within a tablet max width on iPad/Mac (no-op on iPhone).
    func contentMaxWidth(_ width: CGFloat = Layout.content) -> some View {
        modifier(RegularMaxWidth(regular: width))
    }
    func settingsMaxWidth() -> some View { modifier(RegularMaxWidth(regular: Layout.settings)) }
    func paywallMaxWidth() -> some View { modifier(RegularMaxWidth(regular: Layout.paywall)) }
    func clusterMaxWidth() -> some View { modifier(RegularMaxWidth(regular: Layout.cluster)) }
}
