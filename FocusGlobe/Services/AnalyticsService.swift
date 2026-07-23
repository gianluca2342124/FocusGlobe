import Foundation

/// All analytics events the app emits. Defined in one place so they're easy to
/// audit before wiring a real provider.
enum AnalyticsEvent: String {
    case appOpened = "app_opened"
    case routeSelected = "route_selected"
    case journeyPassViewed = "journey_pass_viewed"
    case journeyStarted = "journey_started"
    case journeyPaused = "journey_paused"
    case journeyResumed = "journey_resumed"
    case journeyCancelled = "journey_cancelled"
    case journeyCompleted = "journey_completed"
    case rewardClaimed = "reward_claimed"
    case mockAdStarted = "mock_ad_started"
    case mockAdCompleted = "mock_ad_completed"
    case passportOpened = "passport_opened"
    case historyOpened = "history_opened"
    case settingsOpened = "settings_opened"
    case paywallOpened = "paywall_opened"
    case appearanceChanged = "appearance_changed"
    // AdMob / UMP consent
    case admobConsentRequested = "admob_consent_requested"
    case admobConsentReady = "admob_consent_ready"
    case admobConsentFailed = "admob_consent_failed"
    case interstitialAdRequested = "interstitial_ad_requested"
    case interstitialAdLoaded = "interstitial_ad_loaded"
    case interstitialAdFailed = "interstitial_ad_failed"
    case interstitialAdPresented = "interstitial_ad_presented"
    case interstitialAdDismissed = "interstitial_ad_dismissed"
    case rewardedAdRequested = "rewarded_ad_requested"
    case rewardedAdLoaded = "rewarded_ad_loaded"
    case rewardedAdFailed = "rewarded_ad_failed"
    case rewardedAdPresented = "rewarded_ad_presented"
    case rewardedAdCompleted = "rewarded_ad_completed"
    case rewardedAdRewardGranted = "rewarded_ad_reward_granted"
    case rewardedAdDismissed = "rewarded_ad_dismissed"
    case adSkippedForPro = "ad_skipped_for_pro"
    case adSkippedNotReady = "ad_skipped_not_ready"
    // Journey-complete interstitial (dedicated, granular)
    case interstitialJourneyCompleteRequested = "interstitial_journey_complete_requested"
    case interstitialJourneyCompleteLoaded = "interstitial_journey_complete_loaded"
    case interstitialJourneyCompleteNotReady = "interstitial_journey_complete_not_ready"
    case interstitialJourneyCompletePresented = "interstitial_journey_complete_presented"
    case interstitialJourneyCompleteFailed = "interstitial_journey_complete_failed"
    case interstitialJourneyCompleteDismissed = "interstitial_journey_complete_dismissed"
    case interstitialJourneyCompleteSkippedPro = "interstitial_journey_complete_skipped_pro"
    case interstitialJourneyCompleteContinueToLanding = "interstitial_journey_complete_continue_to_landing"
    // Retention notifications
    case notificationScheduled = "notification_scheduled"
    case notificationCancelled = "notification_cancelled"
    case notificationOpened = "notification_opened"
}

/// A mock analytics sink. In DEBUG it prints events; in release it's a no-op.
///
/// TODO: Replace with a real, privacy-respecting analytics provider. Any future
/// provider must honour App Tracking Transparency and avoid collecting personal
/// data (see PRIVACY_NOTES.md).
final class AnalyticsService {
    func log(_ event: AnalyticsEvent, _ parameters: [String: Any] = [:]) {
        #if DEBUG
        if parameters.isEmpty {
            print("📈 [analytics] \(event.rawValue)")
        } else {
            print("📈 [analytics] \(event.rawValue) \(parameters)")
        }
        #endif
    }
}
