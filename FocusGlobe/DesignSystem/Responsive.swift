import SwiftUI
import UIKit

/// Layout categories derived from the view's real container, not device idiom
/// or size class. This is the source of truth for window-resizable surfaces.
enum FocusViewportClass: Equatable, Sendable {
    case compact
    case regular
    case wide
}

/// FocusGlobe's reusable, container-driven metrics. The values deliberately
/// scale as a coherent family: text, controls, cards, gaps and modal artwork
/// grow together, while readable content remains centred on wide windows.
struct FocusViewportMetrics: Equatable, Sendable {
    let size: CGSize
    let kind: FocusViewportClass

    init(size: CGSize) {
        self.size = size
        let shortest = min(size.width, size.height)
        if size.width < 430 || shortest < 360 {
            kind = .compact
        } else if size.width < 900 {
            kind = .regular
        } else {
            kind = .wide
        }
    }

    var isCompact: Bool { kind == .compact }
    var isWide: Bool { kind == .wide }
    var isShort: Bool { size.height < 700 }

    var pagePadding: CGFloat {
        switch kind { case .compact: 16; case .regular: 24; case .wide: 40 }
    }
    var titleSize: CGFloat {
        switch kind { case .compact: 29; case .regular: 34; case .wide: 39 }
    }
    var bodySize: CGFloat {
        switch kind { case .compact: 15; case .regular: 16.5; case .wide: 18 }
    }
    var modalTitleSize: CGFloat {
        switch kind { case .compact: 29; case .regular: 35; case .wide: 40 }
    }
    var modalPadding: CGFloat {
        switch kind { case .compact: 20; case .regular: 28; case .wide: 34 }
    }
    var buttonHeight: CGFloat {
        switch kind { case .compact: 54; case .regular: 60; case .wide: 64 }
    }
    var navigationControlSize: CGFloat {
        switch kind { case .compact: 46; case .regular: 52; case .wide: 58 }
    }
    var cardSpacing: CGFloat {
        switch kind { case .compact: 12; case .regular: 16; case .wide: 20 }
    }
    var sectionSpacing: CGFloat {
        switch kind { case .compact: 20; case .regular: 28; case .wide: 34 }
    }
    var paywallHeroHeight: CGFloat {
        if isShort { return 190 }
        return switch kind { case .compact: 230; case .regular: 300; case .wide: 360 }
    }
    var carouselCardWidth: CGFloat {
        switch kind {
        case .compact: min(270, size.width - pagePadding * 2)
        case .regular: min(330, size.width * 0.52)
        case .wide: min(390, size.width * 0.34)
        }
    }
    var homeContentWidth: CGFloat {
        min(size.width - pagePadding * 2, kind == .wide ? 860 : 720)
    }

    /// Horizontal inset for Home's FULL-WIDTH header (greeting + top controls).
    ///
    /// The header spans the window rather than the centred reading column that
    /// holds the balloon, Sky title and Start Focus — on a wide Mac window those
    /// two want completely different widths, and sharing one container is what
    /// left the greeting and the coin balance huddled around the middle.
    ///
    /// Compact returns `pagePadding` exactly, so iPhone is bit-for-bit unchanged:
    /// there `homeContentWidth` already resolves to the full width minus that
    /// same padding.
    var homeHeaderMargin: CGFloat {
        switch kind {
        case .compact: return pagePadding
        case .regular: return max(pagePadding, 48)
        case .wide:    return min(72, max(48, size.width * 0.045))
        }
    }

    /// The header's own ceiling. Generous enough that a normal Mac window spans
    /// edge to edge, capped so a 27-inch display does not fling the greeting and
    /// the coin balance to opposite ends of the desk.
    var homeHeaderWidth: CGFloat {
        min(size.width - homeHeaderMargin * 2, kind == .wide ? 1400 : 1024)
    }
    var readableContentWidth: CGFloat {
        min(size.width - pagePadding * 2, kind == .wide ? 920 : 720)
    }
    var storeContentWidth: CGFloat {
        min(size.width - pagePadding * 2, kind == .wide ? 1180 : 900)
    }
    var modalWidth: CGFloat {
        min(size.width - pagePadding * 2,
            kind == .compact ? 440 : (kind == .regular ? 580 : 660))
    }
    var storePanelHeight: CGFloat {
        let fraction: CGFloat = kind == .wide ? 0.48 : 0.46
        let cap: CGFloat = kind == .wide ? 520 : 450
        return min(cap, max(330, size.height * fraction))
    }
    var storeCardMinimumWidth: CGFloat {
        switch kind { case .compact: 100; case .regular: 180; case .wide: 220 }
    }
}

private struct FocusViewportMetricsKey: EnvironmentKey {
    static let defaultValue = FocusViewportMetrics(size: CGSize(width: 390, height: 844))
}

extension EnvironmentValues {
    var focusViewport: FocusViewportMetrics {
        get { self[FocusViewportMetricsKey.self] }
        set { self[FocusViewportMetricsKey.self] = newValue }
    }
}

private struct FocusResponsiveLayoutModifier: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { proxy in
            content
                .environment(\.focusViewport, FocusViewportMetrics(size: proxy.size))
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

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

    /// True on iPad and on Mac running "Designed for iPad". Cached (the idiom
    /// never changes at runtime) so the hot `AppTypography`/`pad(_:_:)` paths
    /// don't re-query `UIDevice` on every access.
    static var isTabletOrMac: Bool { isPadIdiom }
    static let isPadIdiom: Bool = UIDevice.current.userInterfaceIdiom == .pad

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
    static let paywall: CGFloat = 600       // paywall content cap (560–620 band)
    static let streak: CGFloat = 520        // streak-details modal (480–540 band)
    static let reward: CGFloat = 460        // coin / reward sheets (420–480 band)
    static let cluster: CGFloat = 760       // Home / Route bottom clusters
    static let journeyReadouts: CGFloat = 820
    static let bannerMaxWidth: CGFloat = 540

    // MARK: Premium modal panel sizing (iPad/Mac centred modals)

    static let modalMaxWidth: CGFloat = 900
    static let modalMaxHeight: CGFloat = 900
    static let paywallPanelWidth: CGFloat = 760
    static let paywallPanelHeight: CGFloat = 860   // ≈ content; avoids giant empty space
    static let streakPanelWidth: CGFloat = 720
    static let streakPanelHeight: CGFloat = 660
    static let resumePanelWidth: CGFloat = 600
    static let resumePanelHeight: CGFloat = 500
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
    let regular: CGFloat
    func body(content: Content) -> some View {
        content
            // Always cap against the actual proposal. Narrow containers are
            // naturally smaller than the cap; wide windows centre the column.
            // No size-class assumption is involved.
            .frame(maxWidth: regular)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    /// Install real window/container metrics for the whole app. Re-evaluates
    /// automatically as an iPad split view or Mac window is resized.
    func focusResponsiveLayout() -> some View {
        modifier(FocusResponsiveLayoutModifier())
    }

    /// Centre content within a tablet max width on iPad/Mac (no-op on iPhone).
    func contentMaxWidth(_ width: CGFloat = Layout.content) -> some View {
        modifier(RegularMaxWidth(regular: width))
    }
    func settingsMaxWidth() -> some View { modifier(RegularMaxWidth(regular: Layout.settings)) }
    func paywallMaxWidth() -> some View { modifier(RegularMaxWidth(regular: Layout.paywall)) }
    func clusterMaxWidth() -> some View { modifier(RegularMaxWidth(regular: Layout.cluster)) }
    /// Streak-details modal cap (iPad/Mac centred; full-width on iPhone).
    func streakMaxWidth() -> some View { modifier(RegularMaxWidth(regular: Layout.streak)) }
    /// Coin / reward sheet cap (Coin Spin, Booster, Daily Gift) — snug on iPad/Mac.
    func rewardMaxWidth() -> some View { modifier(RegularMaxWidth(regular: Layout.reward)) }
}

// MARK: - Adaptive premium modal

extension View {
    /// Present `content` as a normal **sheet on iPhone**, and as a large, centred
    /// **premium panel on iPad/Mac** (over a dimmed backdrop) — instead of the
    /// tiny system form-sheet that looks compressed on a big screen.
    @ViewBuilder
    func adaptiveModal<C: View>(isPresented: Binding<Bool>,
                               width: CGFloat,
                               height: CGFloat,
                               onDismiss: (() -> Void)? = nil,
                               @ViewBuilder content: @escaping () -> C) -> some View {
        if Layout.isPadIdiom {
            fullScreenCover(isPresented: isPresented, onDismiss: onDismiss) {
                AdaptiveModalPanel(width: width, height: height, isPresented: isPresented, content: content)
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
    let height: CGFloat
    @Binding var isPresented: Bool
    let content: () -> C

    init(width: CGFloat, height: CGFloat, isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> C) {
        self.width = width
        self.height = height
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
                    // Size to the content's natural height (capped to the window)
                    // rather than stretching to fill — so a short modal stays a
                    // snug panel with no giant empty space; taller content scrolls.
                    .frame(width: min(width, geo.size.width - 48),
                           height: min(height, geo.size.height - 64))
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
