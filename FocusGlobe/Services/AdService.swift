import Foundation
import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif
#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif

/// The centralised AdMob service for FocusGlobe.
///
/// **SDK-guarded** (the same pattern as the Google Maps integration): when the
/// Google Mobile Ads Swift Package is linked it resolves UMP consent, initialises
/// the SDK and serves real ads (two rewarded placements + one journey-complete
/// interstitial). When the package is **absent**, every method is a safe no-op —
/// rewarded → `false`, interstitial → the completion runs immediately — so the
/// app builds and runs with zero ad dependencies and Landing never blocks.
///
/// Guarantees (see ADMOB_SETUP.md):
///  • Never shows ads to Pro users (rewarded, interstitial, and the banner).
///  • The only banner is the small in-journey banner (`JourneyBannerAd`, free
///    users only, below the readouts); no app-open / native ads; no ads during
///    the focus ritual or boarding, and none on Home/Choose/Passport/Settings/Landing.
///  • No ad request before UMP consent is resolved or safely allowed.
///  • Fails silently and gracefully everywhere.
///
/// > The code in the `canImport(GoogleMobileAds)` blocks targets the modern
/// > Google Mobile Ads Swift Package (v11+/v12). If you link a different major
/// > version, a few type names (`MobileAds`, `InterstitialAd`, `RewardedAd`,
/// > `Request`) may need a minor adjustment — the non-SDK fallback is unaffected.
@MainActor
final class AdService: NSObject {

    enum Placement {
        case doubleMiles, dailyBoost
        var adUnitID: String {
            switch self {
            case .doubleMiles: return AdMobConfig.rewardedDoubleMilesID
            case .dailyBoost:  return AdMobConfig.rewardedDailyBoostID
            }
        }
        var rewardItem: String {
            switch self {
            case .doubleMiles: return AdMobConfig.doubleMilesRewardItem
            case .dailyBoost:  return AdMobConfig.dailyBoostRewardItem
            }
        }
    }

    private var analytics: AnalyticsService?
    private var started = false
    private var canRequestAds = false

    #if canImport(GoogleMobileAds)
    private var interstitial: InterstitialAd?
    private var rewardedAds: [String: RewardedAd] = [:]
    private var rewardContinuation: CheckedContinuation<Bool, Never>?
    private var rewardEarnedThisPresentation = false
    private var interstitialCompletion: (() -> Void)?
    private var interstitialDidPresent = false
    #endif

    // MARK: Setup

    func configure(analytics: AnalyticsService) {
        self.analytics = analytics
    }

    /// Resolve UMP consent (showing a form if required), then initialise the SDK
    /// and preload ads. Safe to call once at launch; never requests ads before
    /// consent is resolved or safely allowed.
    func start() {
        guard !started else { return }
        started = true
        analytics?.log(.admobConsentRequested)
        #if canImport(UserMessagingPlatform)
        let params = RequestParameters()
        ConsentInformation.shared.requestConsentInfoUpdate(with: params) { [weak self] error in
            guard let self else { return }
            if let error {
                self.analytics?.log(.admobConsentFailed, ["error": error.localizedDescription])
                self.finishConsent()       // fail-safe: proceed with whatever is allowed
                return
            }
            if let vc = Self.topViewController() {
                ConsentForm.loadAndPresentIfRequired(from: vc) { [weak self] formError in
                    if let formError {
                        self?.analytics?.log(.admobConsentFailed, ["error": formError.localizedDescription])
                    }
                    self?.finishConsent()
                }
            } else {
                self.finishConsent()
            }
        }
        #else
        finishConsent()
        #endif
    }

    private func finishConsent() {
        #if canImport(UserMessagingPlatform)
        canRequestAds = ConsentInformation.shared.canRequestAds
        #else
        canRequestAds = true
        #endif
        analytics?.log(.admobConsentReady, ["canRequestAds": canRequestAds])
        guard canRequestAds else { return }
        #if canImport(GoogleMobileAds)
        // Preload only AFTER SDK initialisation completes — loading before
        // `start` finishes can silently fail (which is why the interstitial was
        // never ready while the on-demand rewarded ad worked).
        MobileAds.shared.start { [weak self] _ in
            guard let self else { return }
            self.loadInterstitial()
            self.preloadRewarded(AdMobConfig.rewardedDoubleMilesID)
            self.preloadRewarded(AdMobConfig.rewardedDailyBoostID)
        }
        #endif
    }

    /// Preload the journey-complete interstitial (call when a journey starts) so
    /// it is ready by the time the journey ends. No-op for Pro / before consent.
    func preloadInterstitial(isPro: Bool) {
        guard !isPro else { return }
        #if canImport(GoogleMobileAds)
        loadInterstitial()
        #endif
    }

    /// Present the EU/UK privacy options form (wire to a Settings row when
    /// `privacyOptionsRequired`). Safe no-op otherwise.
    func presentPrivacyOptions() {
        #if canImport(UserMessagingPlatform)
        guard let vc = Self.topViewController() else { return }
        ConsentForm.presentPrivacyOptionsForm(from: vc) { _ in }
        #endif
    }

    var privacyOptionsRequired: Bool {
        #if canImport(UserMessagingPlatform)
        return ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        #else
        return false
        #endif
    }

    /// Whether ad requests are currently permitted — i.e. UMP consent has been
    /// resolved and allows ads (or there's no UMP, in which case it's allowed
    /// once `start()` finishes). The in-journey banner reads this so it never
    /// loads before consent. Pro gating is handled separately by the caller.
    var adsAllowed: Bool { canRequestAds }

    // MARK: Rewarded

    /// Show a rewarded ad for `placement`. Returns `true` only after Google's
    /// reward callback fired (closing early → `false`). Never shown to Pro users.
    func showRewarded(_ placement: Placement, isPro: Bool) async -> Bool {
        if isPro { analytics?.log(.adSkippedForPro); return false }
        analytics?.log(.rewardedAdRequested, ["item": placement.rewardItem])
        #if canImport(GoogleMobileAds)
        guard canRequestAds else { analytics?.log(.adSkippedNotReady); return false }

        let ad: RewardedAd
        if let cached = rewardedAds[placement.adUnitID] {
            ad = cached
            rewardedAds[placement.adUnitID] = nil
        } else {
            do {
                ad = try await RewardedAd.load(with: placement.adUnitID, request: Request())
                analytics?.log(.rewardedAdLoaded)
            } catch {
                analytics?.log(.rewardedAdFailed, ["error": error.localizedDescription])
                return false
            }
        }
        guard let vc = Self.topViewController() else { analytics?.log(.adSkippedNotReady); return false }

        ad.fullScreenContentDelegate = self
        rewardEarnedThisPresentation = false
        analytics?.log(.rewardedAdPresented)
        let earned = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            rewardContinuation = cont
            ad.present(from: vc) { [weak self] in
                self?.rewardEarnedThisPresentation = true
                self?.analytics?.log(.rewardedAdCompleted)
            }
        }
        preloadRewarded(placement.adUnitID)
        if earned { analytics?.log(.rewardedAdRewardGranted, ["item": placement.rewardItem]) }
        return earned
        #else
        analytics?.log(.adSkippedNotReady)
        return false
        #endif
    }

    /// Backwards-compatible alias used by the existing Double-Miles flow.
    func showRewardedAd() async -> Bool { await showRewarded(.doubleMiles, isPro: false) }

    // MARK: Interstitial (journey complete → before Landing)

    /// Present the single skippable journey-complete interstitial, then call
    /// `completion`. Pro / not-loaded / no-presenter → `completion` runs
    /// immediately, so Landing is never blocked or delayed forever. Only one is
    /// presented per completed journey (the caller invokes this once).
    func presentJourneyCompleteInterstitial(isPro: Bool, completion: @escaping () -> Void) {
        analytics?.log(.interstitialJourneyCompleteRequested)
        if isPro {
            analytics?.log(.interstitialJourneyCompleteSkippedPro)
            continueToLanding(completion)
            return
        }
        #if canImport(GoogleMobileAds)
        guard canRequestAds, let ad = interstitial, let vc = Self.topViewController() else {
            analytics?.log(.interstitialJourneyCompleteNotReady)
            continueToLanding(completion)
            return
        }
        interstitial = nil
        interstitialCompletion = completion
        interstitialDidPresent = false
        ad.fullScreenContentDelegate = self
        ad.present(from: vc)
        // Safety: if it never actually presents, continue to Landing instead of
        // waiting — never block the user indefinitely.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, self.interstitialCompletion != nil, !self.interstitialDidPresent else { return }
            self.analytics?.log(.interstitialJourneyCompleteFailed, ["reason": "present_timeout"])
            self.finishInterstitial()
        }
        #else
        analytics?.log(.interstitialJourneyCompleteNotReady)
        continueToLanding(completion)
        #endif
    }

    /// Immediate-skip path → Landing (Pro / not ready / no SDK).
    private func continueToLanding(_ completion: @escaping () -> Void) {
        analytics?.log(.interstitialJourneyCompleteContinueToLanding)
        completion()
    }

    #if canImport(GoogleMobileAds)
    /// Resolve a presented interstitial exactly once, then preload the next.
    private func finishInterstitial() {
        guard let completion = interstitialCompletion else { return }
        interstitialCompletion = nil
        analytics?.log(.interstitialJourneyCompleteContinueToLanding)
        completion()
        loadInterstitial()   // ready for the next journey
    }
    #endif

    // MARK: Loading

    #if canImport(GoogleMobileAds)
    private func loadInterstitial() {
        guard canRequestAds, interstitial == nil else { return }
        analytics?.log(.interstitialJourneyCompleteRequested)
        Task { [weak self] in
            guard let self else { return }
            do {
                let ad = try await InterstitialAd.load(
                    with: AdMobConfig.interstitialJourneyCompleteID, request: Request())
                self.interstitial = ad
                self.analytics?.log(.interstitialJourneyCompleteLoaded)
            } catch {
                self.analytics?.log(.interstitialJourneyCompleteFailed, ["error": error.localizedDescription])
            }
        }
    }

    private func preloadRewarded(_ unitID: String) {
        guard canRequestAds, rewardedAds[unitID] == nil else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let ad = try await RewardedAd.load(with: unitID, request: Request())
                self.rewardedAds[unitID] = ad
                self.analytics?.log(.rewardedAdLoaded)
            } catch {
                self.analytics?.log(.rewardedAdFailed, ["error": error.localizedDescription])
            }
        }
    }
    #endif

    // MARK: Helpers

    /// The top-most presented view controller (a safe presenter for full-screen ads).
    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }
        let keyWindow = windows.first { $0.isKeyWindow } ?? windows.first
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

#if canImport(GoogleMobileAds)
extension AdService: FullScreenContentDelegate {
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        // Only relevant for the interstitial (rewarded logs its own present).
        if interstitialCompletion != nil {
            interstitialDidPresent = true
            analytics?.log(.interstitialJourneyCompletePresented)
        }
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        // Resolve whichever presentation was active (only one at a time).
        if let cont = rewardContinuation {
            rewardContinuation = nil
            analytics?.log(.rewardedAdDismissed)
            cont.resume(returning: rewardEarnedThisPresentation)
        }
        if interstitialCompletion != nil {
            analytics?.log(.interstitialJourneyCompleteDismissed)
            finishInterstitial()        // → continue to Landing + preload next
        }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContent error: Error) {
        if let cont = rewardContinuation {
            rewardContinuation = nil
            analytics?.log(.rewardedAdFailed, ["error": error.localizedDescription])
            cont.resume(returning: false)
        }
        if interstitialCompletion != nil {
            analytics?.log(.interstitialJourneyCompleteFailed, ["error": error.localizedDescription])
            finishInterstitial()        // never block Landing
        }
    }
}
#endif
