import Foundation

/// A mock rewarded-ad service.
///
/// Ads only ever appear *after* landing (never during focus). For the MVP this
/// simulates a rewarded ad with a short delay and always "succeeds".
///
/// TODO: Replace with a real rewarded-ad SDK (e.g. AdMob / a mediation layer).
/// Keep the async `showRewardedAd()` contract so callers don't change. Any real
/// integration must respect App Tracking Transparency and the rule that ads
/// never interrupt an active focus session.
@MainActor
final class AdService {
    /// Simulated rewarded ad. Returns `true` when the reward should be granted.
    func showRewardedAd() async -> Bool {
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s mock playback
        return true
    }
}
