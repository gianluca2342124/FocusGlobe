import Foundation

/// The single, centralised place for AdMob identifiers.
///
/// SAFETY: production ad units are only ever used in **release** builds. In
/// DEBUG we use Google's official **test** ad unit IDs, so the App Store account
/// is never at risk of policy strikes from test traffic. The App ID below is the
/// real one (it ships in Info.plist regardless) — see ADMOB_SETUP.md.
enum AdMobConfig {

    // MARK: App-level (always the real values)

    /// AdMob App ID — also set in Info.plist as `GADApplicationIdentifier`.
    static let ADMOB_APP_ID = "ca-app-pub-2780304092271589~4583163289"
    static let publisherID  = "pub-2780304092271589"

    /// The real production ad unit IDs (used in release; listed here for
    /// reference and documentation — `rewardedDoubleMilesID` etc. below pick the
    /// correct value per build configuration).
    static let ADMOB_REWARDED_DOUBLE_MILES_ID        = "ca-app-pub-2780304092271589/2338881545"
    static let ADMOB_REWARDED_DAILY_BOOST_ID         = "ca-app-pub-2780304092271589/1025799876"
    static let ADMOB_INTERSTITIAL_JOURNEY_COMPLETE_ID = "ca-app-pub-2780304092271589/3081117578"
    /// AdMob dashboard unit "iOS Banner - Journey" — the small adaptive banner
    /// shown during an active journey for free users only.
    static let ADMOB_BANNER_JOURNEY_ID               = "ca-app-pub-2780304092271589/6065307904"

    // MARK: Active ad unit IDs (test in DEBUG, production in RELEASE)

    #if DEBUG
    // Google's official sample/test ad unit IDs — required while developing so we
    // never request production ads with test traffic.
    static let rewardedDoubleMilesID         = "ca-app-pub-3940256099942544/1712485313"  // test rewarded
    static let rewardedDailyBoostID          = "ca-app-pub-3940256099942544/1712485313"  // test rewarded
    static let interstitialJourneyCompleteID = "ca-app-pub-3940256099942544/4411468910"  // test interstitial
    static let bannerJourneyID               = "ca-app-pub-3940256099942544/2934735716"  // test banner
    #else
    static let rewardedDoubleMilesID         = ADMOB_REWARDED_DOUBLE_MILES_ID
    static let rewardedDailyBoostID          = ADMOB_REWARDED_DAILY_BOOST_ID
    static let interstitialJourneyCompleteID = ADMOB_INTERSTITIAL_JOURNEY_COMPLETE_ID
    static let bannerJourneyID               = ADMOB_BANNER_JOURNEY_ID
    #endif

    /// Reward amounts granted on a successful rewarded callback.
    static let doubleMilesRewardItem = "double_miles"
    static let dailyBoostRewardItem  = "mission_boost"
    /// Flat miles granted by the Daily Mission Boost rewarded ad.
    static let dailyBoostMiles = 25
}
