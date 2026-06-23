# FocusGlobe — AdMob Setup

AdMob is integrated **SDK-guarded**, exactly like the Google Maps integration:
all SDK calls live behind `#if canImport(GoogleMobileAds)` / `#if
canImport(UserMessagingPlatform)`. **The app builds and runs with no ad
dependency today** (ads simply don't show, Landing never blocks). Adding the
Swift Package below "lights up" real ads. Nothing here changes RevenueCat,
pricing, the paywall, journeys, or maps.

## 1. Add the Swift Package

Xcode ▸ File ▸ Add Package Dependencies… ▸ paste:

```
https://github.com/googleads/swift-package-manager-google-mobile-ads.git
```

Add both products to the **FocusGlobe** app target:
- `GoogleMobileAds`
- `UserMessagingPlatform` (UMP consent)

> The `canImport(...)` blocks target the **modern Swift package (v11+/v12)**
> (`MobileAds`, `InterstitialAd`, `RewardedAd`, `Request`, `FullScreenContentDelegate`).
> If you pin a different major version, a few type names may need a minor tweak —
> the no-SDK fallback is unaffected.

## 2. Info.plist keys (app target)

The project uses a generated Info.plist — add these via the target's **Info** tab
(custom keys) or an `Info.plist`:

- **`GADApplicationIdentifier`** (String) = `ca-app-pub-2780304092271589~4583163289`
- **`SKAdNetworkItems`** — paste Google's current SKAdNetwork identifiers list
  (from the AdMob docs) so attribution works.
- **`NSUserTrackingUsageDescription`** (String) — *only if you decide to request
  ATT* (see §8), e.g. "FocusGlobe uses this to show more relevant ads." Rewarded
  and the journey-complete interstitial work without ATT (non-personalised ads),
  so ATT is optional.

## 3. IDs — where they live

All IDs are centralised in **`FocusGlobe/Services/AdMobConfig.swift`**:

- **App ID:** `ca-app-pub-2780304092271589~4583163289` (`ADMOB_APP_ID`, also in Info.plist)
- **Publisher ID:** `pub-2780304092271589`
- Production ad units (used in **RELEASE** only):
  - Rewarded Double Miles Landing — `ca-app-pub-2780304092271589/2338881545`
  - Rewarded Daily Mission Boost — `ca-app-pub-2780304092271589/1025799876`
  - Interstitial Journey Complete — `ca-app-pub-2780304092271589/3081117578`
- In **DEBUG** the service automatically uses **Google's official test ad unit
  IDs** instead, so you never send test traffic to production units.

`FocusGlobe/Services/AdService.swift` is the centralised service (UMP consent →
SDK init → load/serve). It exposes `start()`, `showRewarded(_:isPro:)`,
`presentJourneyCompleteInterstitial(isPro:completion:)`, plus privacy-options
helpers.

## 4. AdMob dashboard ad units to create

| Dashboard name | Format | Unit ID |
|----------------|--------|---------|
| iOS Rewarded - Double Miles Landing | Rewarded | `…/2338881545` |
| iOS Rewarded - Daily Mission Boost | Rewarded | `…/1025799876` |
| iOS Interstitial - Journey Complete | Interstitial | `…/3081117578` |

## 5. Reward settings

| Placement | Reward amount | Reward item |
|-----------|---------------|-------------|
| Double Miles | `1` | `double_miles` |
| Daily Mission Boost | `1` | `mission_boost` |
| Journey Complete Interstitial | — | no reward |

(The app grants its own miles on the reward callback — the AdMob amount/item are
just the dashboard metadata.)

## 6. Where ads appear (and don't)

- **Double Miles** — Landing screen "Double your miles" card (free users only;
  the card is already hidden for Pro). Grants **only** after Google's reward
  callback; closing early grants nothing.
- **Daily Mission Boost** — infrastructure ready via
  `AppModel.watchDailyMissionBoostAd()` (grants a small flat miles top-up on
  reward). **Connection point:** call it from a free-user "Boost (watch ad)"
  affordance in the Daily Goals / Streak area when you want to surface it.
- **Journey Complete interstitial** — shown once, skippably, **after** a journey
  finishes and **before** Landing, for free users only. If not loaded / no
  presenter / Pro → Landing appears immediately.
- **Never:** banners, app-open, native, ads during a journey / focus ritual /
  boarding, or any ad for Pro users.

## 7. Testing with test ad IDs

- Just run a **DEBUG** build — `AdMobConfig` already returns Google's test unit
  IDs, so you'll see test ads (and never risk your account).
- Optionally register your device as a test device on the real units via
  `MobileAds.shared.requestConfiguration.testDeviceIdentifiers` in
  `AdService.finishConsent()` if you want to verify production units safely.

## 8. UMP / Privacy & Messaging + ATT

- In **AdMob ▸ Privacy & messaging**, create a **GDPR (EU consent)** message and
  (optionally) an **ATT** message. The app calls
  `UMPConsentInformation.requestConsentInfoUpdate` then
  `UMPConsentForm.loadAndPresentIfRequired` at launch, and only requests ads once
  `canRequestAds` is true. It fails safe (proceeds with whatever is allowed) if
  the form can't load, and won't spam (UMP only shows the form when required).
- **Privacy options entry:** `AdService.privacyOptionsRequired` /
  `presentPrivacyOptions()` are ready — add a "Privacy options" row in Settings
  (only shown when `privacyOptionsRequired`) if your region requires it.
- **ATT:** optional. If you enable an ATT message in UMP, present it after the
  consent form (UMP can sequence it) and add `NSUserTrackingUsageDescription`.
  Without ATT the app serves non-personalised ads, which is fine.

## 9. Analytics

All ad lifecycle events are logged through the existing `AnalyticsService`
(`admob_consent_*`, `interstitial_ad_*`, `rewarded_ad_*`, `ad_skipped_for_pro`,
`ad_skipped_not_ready`). No new analytics SDK was added.
