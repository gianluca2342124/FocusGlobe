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
        return Group {
            if w >= 200 {
                BannerRepresentable(width: w, loaded: $loaded, failed: $failed)
                    .frame(width: w, height: loaded ? Self.bannerHeight(for: w) : unloadedHeight)
            } else {
                // First layout pass: measure the container width before sizing the ad.
                Color.clear.frame(height: 0)
            }
        }
        .frame(maxWidth: .infinity)              // centre the (capped-width) banner
        .background(widthReader)                 // measure the available container width
        .opacity(loaded ? 1 : unloadedOpacity)
        .overlay(debugOverlay)
        .padding(.top, loaded ? AppSpacing.sm : 0)
        .animation(.easeInOut(duration: 0.25), value: loaded)
        .accessibilityHidden(true)
        .onChange(of: loaded) { _, isLoaded in
            if isLoaded { JourneyBannerLog.event("journey_banner_visible") }
        }
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
        if isPro || !ads.canRequestAds { loaded = false; failed = false }
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

    // MARK: DEBUG-only loading affordance (never in RELEASE)

    /// While the slot is active but an ad hasn't loaded yet: in DEBUG reserve a
    /// tiny visible strip so testers can confirm gating passed; in RELEASE keep
    /// it fully collapsed (no blank box). Collapses on failure either way.
    private var unloadedHeight: CGFloat {
        #if DEBUG
        return failed ? 0 : 24
        #else
        return 0
        #endif
    }
    private var unloadedOpacity: Double {
        #if DEBUG
        return failed ? 0 : 1
        #else
        return 0
        #endif
    }
    @ViewBuilder private var debugOverlay: some View {
        #if DEBUG
        if !loaded && !failed {
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
