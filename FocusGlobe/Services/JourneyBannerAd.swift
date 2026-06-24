import SwiftUI
import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// DEBUG-only logging for the in-journey banner path, so the whole "should it
/// show? did it load?" decision is traceable while testing. Compiles to nothing
/// in RELEASE — no shipped debug logs or UI.
enum JourneyBannerLog {
    static func event(_ name: String, _ detail: String = "") {
        #if DEBUG
        print("[JourneyBanner] \(name)\(detail.isEmpty ? "" : " — \(detail)")")
        #endif
    }
}

/// A small, adaptive AdMob banner shown during an active journey for **free
/// users only**.
///
/// Reactive + robust:
///  • observes `AdService`, so it appears as soon as UMP consent allows ads —
///    even if that resolves a moment *after* the journey starts;
///  • reserves real height only once an ad has actually loaded (never a blank
///    box in RELEASE), and collapses cleanly on failure;
///  • waits for a valid presenter (`rootViewController`) before requesting, and
///    retries if one isn't ready yet;
///  • Pro users are excluded by the caller AND re-checked here, and never load
///    an ad.
///
/// SDK-guarded: with no GoogleMobileAds package linked it is an empty view.
///
/// > Targets the modern Google Mobile Ads Swift Package (v11+/v12): `BannerView`,
/// > `AdSize`, `currentOrientationAnchoredAdaptiveBanner(width:)`, `Request`,
/// > `BannerViewDelegate`.
struct JourneyBannerAd: View {
    @ObservedObject var ads: AdService
    let isPro: Bool

    #if canImport(GoogleMobileAds)
    @State private var loaded = false
    @State private var failed = false
    @State private var timedOut = false
    @State private var measuredWidth: CGFloat = 0

    var body: some View {
        content
            .onAppear { logState() }
            // React to Pro / consent changes (consent may resolve after start).
            .onChange(of: isPro) { _, _ in resetIfHidden(); logState() }
            .onChange(of: ads.canRequestAds) { _, _ in resetIfHidden(); logState() }
    }

    @ViewBuilder private var content: some View {
        if isPro {
            Color.clear.frame(height: 0)            // Pro: never any banner
        } else if !ads.canRequestAds {
            Color.clear.frame(height: 0)            // wait for consent; appears later
        } else {
            slot
        }
    }

    private var slot: some View {
        let w = min(measuredWidth, Layout.bannerMaxWidth)   // cap so it stays tasteful on iPad/Mac
        let hasWidth = w >= 200
        return Group {
            if debugPlaceholderActive {
                // DEBUG only: the real (test) banner failed or never called back —
                // show a tasteful placeholder so the slot/layout is still proven.
                debugPlaceholder(width: hasWidth ? w : Layout.bannerMaxWidth)
            } else if hasWidth {
                // Stays mounted across the not-loaded → loaded transition (same
                // identity, so the ad is requested only once); height grows on load.
                BannerRepresentable(width: w, loaded: $loaded, failed: $failed)
                    .frame(width: w, height: loaded ? Self.bannerHeight(for: w) : unloadedHeight)
                    .overlay(loadingOverlay)
            } else {
                // First layout pass: measure the container width before sizing the ad.
                Color.clear.frame(height: 0)
            }
        }
        .frame(maxWidth: .infinity)              // centre the (capped-width) banner
        .background(widthReader)                 // measure the available container width
        .opacity(slotVisible ? 1 : 0)
        .padding(.top, slotVisible ? AppSpacing.sm : 0)
        .animation(.easeInOut(duration: 0.25), value: loaded)
        .animation(.easeInOut(duration: 0.25), value: timedOut)
        .accessibilityHidden(true)
        .onChange(of: loaded) { _, isLoaded in
            if isLoaded { JourneyBannerLog.event("journey_banner_visible") }
        }
        .task {
            // Fail-safe: if neither a load nor a fail callback arrives (e.g. the SDK
            // never calls back), surface the DEBUG placeholder after a short wait so
            // the slot is still visible/debuggable. No effect in RELEASE.
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !loaded && !failed { timedOut = true }
        }
    }

    /// Whether the slot currently shows anything (a loaded ad, or — DEBUG only —
    /// the placeholder). In RELEASE an unloaded/failed banner stays invisible.
    private var slotVisible: Bool {
        if loaded { return true }
        #if DEBUG
        return true   // DEBUG: the loading strip / placeholder is intentionally visible
        #else
        return false
        #endif
    }

    /// Measures the available container width (no layout impact) so the adaptive
    /// banner is sized only once a valid width is known — and re-measures if a
    /// window resizes (iPad Stage Manager / Mac).
    private var widthReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { updateWidth(proxy.size.width) }
                .onChange(of: proxy.size.width) { _, w in updateWidth(w) }
        }
    }

    private func updateWidth(_ w: CGFloat) {
        guard w > 0 else { JourneyBannerLog.event("journey_banner_width_invalid"); return }
        if abs(w - measuredWidth) > 0.5 { measuredWidth = w }
    }

    private func resetIfHidden() {
        // If we left the showable state, clear load flags so a later return
        // re-requests cleanly.
        if isPro || !ads.canRequestAds { loaded = false; failed = false; timedOut = false }
    }

    private func logState() {
        if isPro {
            JourneyBannerLog.event("journey_banner_hidden_pro")
        } else if !ads.canRequestAds {
            JourneyBannerLog.event("journey_banner_hidden_ads_not_allowed")
        } else {
            JourneyBannerLog.event("journey_banner_should_show")
        }
    }

    // MARK: Sizing

    /// The loaded banner height for `width` (anchored adaptive banners derive
    /// their height from the available width), with a standard-banner fallback so
    /// a loaded ad always gets a real, visible height.
    static func bannerHeight(for width: CGFloat) -> CGFloat {
        let h = currentOrientationAnchoredAdaptiveBanner(width: width).size.height
        return h > 0 ? h : 50
    }

    // MARK: DEBUG-only loading affordance + placeholder (never in RELEASE)

    /// While the (test) ad is still loading: in DEBUG reserve a tiny strip so the
    /// active slot is visible; in RELEASE keep it collapsed (no blank box).
    private var unloadedHeight: CGFloat {
        #if DEBUG
        return 24
        #else
        return 0
        #endif
    }

    /// DEBUG: show the placeholder once the real test ad has failed or timed out
    /// (and hasn't loaded). Always false in RELEASE — failures collapse cleanly.
    private var debugPlaceholderActive: Bool {
        #if DEBUG
        return (failed || timedOut) && !loaded
        #else
        return false
        #endif
    }

    /// DEBUG-only: a tasteful placeholder occupying the exact banner slot, proving
    /// the layout works even when the simulator/network can't fill a real ad.
    @ViewBuilder private func debugPlaceholder(width: CGFloat) -> some View {
        #if DEBUG
        let w = min(max(width, 200), Layout.bannerMaxWidth)
        Text("Test banner placeholder")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.7))
            .frame(width: w, height: Self.bannerHeight(for: w))
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1))
        #else
        EmptyView()
        #endif
    }

    /// DEBUG-only: a faint "Ad loading…" label while the test ad is in flight.
    @ViewBuilder private var loadingOverlay: some View {
        #if DEBUG
        if !loaded && !failed && !timedOut {
            Text("Ad loading…")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        #else
        EmptyView()
        #endif
    }
    #else
    // No GoogleMobileAds package linked → no banner, no layout impact.
    var body: some View { EmptyView() }
    #endif
}

#if canImport(GoogleMobileAds)
/// Bridges a Google `BannerView` (anchored adaptive) into SwiftUI. Requests only
/// once a valid presenter exists (retrying via `updateUIView` if not), and reports
/// load success/failure back through bindings.
private struct BannerRepresentable: UIViewRepresentable {
    let width: CGFloat
    @Binding var loaded: Bool
    @Binding var failed: Bool

    func makeCoordinator() -> Coordinator { Coordinator(loaded: $loaded, failed: $failed) }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: width))
        banner.adUnitID = AdMobConfig.bannerJourneyID            // test ID in DEBUG, prod in RELEASE
        banner.delegate = context.coordinator
        banner.backgroundColor = .clear
        context.coordinator.loadIfNeeded(banner)
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        // Retry the request if a presenter wasn't available at creation time.
        context.coordinator.loadIfNeeded(banner)
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        private let loaded: Binding<Bool>
        private let failed: Binding<Bool>
        private var didRequest = false

        init(loaded: Binding<Bool>, failed: Binding<Bool>) {
            self.loaded = loaded
            self.failed = failed
        }

        // Main-actor isolated: only ever called from `makeUIView`/`updateUIView`
        // (UIViewRepresentable is `@MainActor`), so the main-actor-isolated
        // `AdService.topViewController()` can be called directly and safely.
        @MainActor
        func loadIfNeeded(_ banner: BannerView) {
            guard !didRequest else { return }
            guard let root = AdService.topViewController() else { return }   // wait for a presenter
            banner.rootViewController = root
            didRequest = true
            JourneyBannerLog.event("journey_banner_requested")
            banner.load(Request())
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            JourneyBannerLog.event("journey_banner_loaded")
            failed.wrappedValue = false
            loaded.wrappedValue = true
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            JourneyBannerLog.event("journey_banner_failed", error.localizedDescription)
            loaded.wrappedValue = false
            failed.wrappedValue = true
        }
    }
}
#endif
