import SwiftUI
import UIKit

/// Centralised responsive layout tokens + a real **iPhone vs iPad/Mac scale
/// system**, so FocusGlobe reads as an Apple-quality tablet app — not a phone UI
/// on a big screen — while leaving the premium iPhone-portrait layout unchanged.
///
/// Signals:
///  • **Idiom** (`isPadIdiom` / `isTabletOrMac` / `pad(_:_:)` / the `*Scale`
///    multipliers) drives *scale* of fonts, controls and panels. Idiom is used
///    (not the size class) because the size class is unreliable inside
///    sheets/covers and reports `.pad` for Mac "Designed for iPad".
///  • **Horizontal size class** (`RegularMaxWidth`) drives content *centering*,
///    so a narrow iPad multitasking window doesn't get an over-wide column.
///
/// Scale is **conservative but clearly visible** (iPhone = 1.0; iPad/Mac ≈ 1.15),
/// and `AppTypography` multiplies its sizes by `fontScale`, so on iPhone every
/// size is identical (×1.0) and on iPad/Mac all text grows uniformly.
enum Layout {
    // MARK: Scale

    /// True on iPad and on Mac running "Designed for iPad".
    static var isTabletOrMac: Bool { isPadIdiom }
    static var isPadIdiom: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    /// Uniform type scale (drives `AppTypography`). iPhone 1.0; iPad/Mac larger.
    static var fontScale: CGFloat { isPadIdiom ? 1.15 : 1.0 }
    /// Control/affordance scale (button & tap-target heights, icons).
    static var controlScale: CGFloat { isPadIdiom ? 1.14 : 1.0 }
    /// General visual scale for bespoke sizes that don't go through the helpers.
    static var visualScale: CGFloat { isPadIdiom ? 1.16 : 1.0 }
    /// The Active-Journey HUD (readouts, pause, controls) reads from across the
    /// room, so it scales a little more.
    static var activeJourneyHUDScale: CGFloat { isPadIdiom ? 1.22 : 1.0 }

    /// Pick a phone vs tablet value (font size, padding, height, …).
    static func pad<T>(_ phone: T, _ tablet: T) -> T { isPadIdiom ? tablet : phone }
    /// Scale a phone metric by `controlScale` (rounded), for control sizing.
    static func control(_ phone: CGFloat) -> CGFloat { (phone * controlScale).rounded() }

    // MARK: Centred content widths (regular size class only; no-op on iPhone)

    static let content: CGFloat = 900      // Passport / general scroll screens
    static let readable: CGFloat = 720      // Landing single column
    static let settings: CGFloat = 780
    static let paywall: CGFloat = 760       // paywall content cap (matches the panel)
    static let cluster: CGFloat = 760       // Home / Route bottom clusters
    static let journeyReadouts: CGFloat = 820
    static let bannerMaxWidth: CGFloat = 540

    // MARK: Premium modal panel sizing (iPad/Mac centred modals)

    static let modalMaxWidth: CGFloat = 900
    static let paywallPanelWidth: CGFloat = 760
    static let streakPanelWidth: CGFloat = 720
    static let resumePanelWidth: CGFloat = 600
    static let homePanelWidth: CGFloat = 760       // == cluster
    static let passportContentWidth: CGFloat = 900 // == content

    /// Adaptive card-grid columns, scaled by layout: ~2 columns on a phone, more
    /// and larger tiles on iPad/Mac (so cards feel tablet-native, not shrunken).
    static func cardColumns(regular: Bool,
                            minPhone: CGFloat = 158,
                            minPad: CGFloat = 210,
                            spacing: CGFloat = AppSpacing.sm) -> [GridItem] {
        let minW = regular ? minPad : minPhone
        let maxW: CGFloat = regular ? 360 : 260
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

// MARK: - Adaptive premium modal

extension View {
    /// Present `content` as a normal **sheet on iPhone**, and as a large, centred
    /// **premium panel on iPad/Mac** (over a dimmed backdrop) — instead of the
    /// tiny system form-sheet that looks compressed on a big screen.
    @ViewBuilder
    func adaptiveModal<C: View>(isPresented: Binding<Bool>,
                               width: CGFloat,
                               onDismiss: (() -> Void)? = nil,
                               @ViewBuilder content: @escaping () -> C) -> some View {
        if Layout.isPadIdiom {
            fullScreenCover(isPresented: isPresented, onDismiss: onDismiss) {
                AdaptiveModalPanel(width: width, isPresented: isPresented, content: content)
            }
        } else {
            sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
        }
    }
}

/// The iPad/Mac modal panel: a centred, rounded panel over a dimmed backdrop
/// (tap outside to dismiss). The presenting app shows through, dimmed.
private struct AdaptiveModalPanel<C: View>: View {
    let width: CGFloat
    @Binding var isPresented: Bool
    let content: () -> C

    init(width: CGFloat, isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> C) {
        self.width = width
        self._isPresented = isPresented
        self.content = content
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { isPresented = false }
                content()
                    .frame(maxWidth: min(width, geo.size.width - 64),
                           maxHeight: geo.size.height - 96)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1))
                    .shadow(color: .black.opacity(0.55), radius: 44, y: 22)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .presentationBackground(.clear)   // let the dimmed app show behind the panel
    }
}
