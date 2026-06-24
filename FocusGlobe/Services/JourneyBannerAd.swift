import SwiftUI
import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// A small, adaptive AdMob **banner shown only during an active journey, only for
/// free users**.
///
/// SDK-guarded exactly like the rest of AdMob (`AdService`): with no
/// GoogleMobileAds package linked it compiles to an empty view. The caller places
/// it only when the user is **not Pro** and UMP consent **already allows ads**
/// (`vm.showsJourneyBanner`), so it never shows for Pro users and never requests
/// before consent. It fails gracefully — it stays at **zero height** until an ad
/// actually loads, so an unfilled/offline banner leaves no empty gap and never
/// covers the balloon, map controls or the pause button.
///
/// It's an *anchored adaptive* banner sized to the screen width (Google's
/// recommended format), rendered below the journey's time/distance readouts.
///
/// > The `canImport(GoogleMobileAds)` code targets the modern Google Mobile Ads
/// > Swift Package (v11+/v12): `BannerView`, `AdSize`,
/// > `currentOrientationAnchoredAdaptiveBanner(width:)`, `Request`,
/// > `BannerViewDelegate`. If you pin a different major version a couple of these
/// > names may need a minor tweak — the no-SDK fallback is unaffected.
struct JourneyBannerAd: View {
    #if canImport(GoogleMobileAds)
    @State private var loaded = false

    var body: some View {
        BannerRepresentable(loaded: $loaded)
            // Reserve height only once an ad has actually loaded, so there's never
            // an empty grey gap when the banner is unfilled or the device is offline.
            .frame(height: loaded ? BannerRepresentable.height : 0)
            .frame(maxWidth: .infinity)
            .opacity(loaded ? 1 : 0)
            .animation(.easeInOut(duration: 0.25), value: loaded)
            .accessibilityHidden(true)
    }
    #else
    // No GoogleMobileAds package linked → no banner, no layout impact.
    var body: some View { EmptyView() }
    #endif
}

#if canImport(GoogleMobileAds)
/// Bridges a Google `BannerView` (anchored adaptive) into SwiftUI and reports
/// load success/failure back via a binding so the host can reserve space only
/// when a real ad is present.
private struct BannerRepresentable: UIViewRepresentable {
    @Binding var loaded: Bool

    /// The anchored-adaptive banner height for the current screen width (anchored
    /// adaptive banners derive their height from the available width).
    static var height: CGFloat {
        let width = UIScreen.main.bounds.width
        return currentOrientationAnchoredAdaptiveBanner(width: width).size.height
    }

    func makeCoordinator() -> Coordinator { Coordinator(loaded: $loaded) }

    func makeUIView(context: Context) -> BannerView {
        let width = UIScreen.main.bounds.width
        let banner = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: width))
        banner.adUnitID = AdMobConfig.bannerJourneyID            // test ID in DEBUG, prod in RELEASE
        banner.rootViewController = AdService.topViewController()
        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        // Re-attach a presenter if the view-controller hierarchy changed.
        if banner.rootViewController == nil {
            banner.rootViewController = AdService.topViewController()
        }
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        private let loaded: Binding<Bool>
        init(loaded: Binding<Bool>) { self.loaded = loaded }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            loaded.wrappedValue = true
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            loaded.wrappedValue = false
        }
    }
}
#endif
