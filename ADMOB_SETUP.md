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

`FocusGlobe/Info.plist` already contains the production AdMob keys:

- **`GADApplicationIdentifier`** (String) = `ca-app-pub-2780304092271589~4583163289` — ✅ already set, exactly.
- **`SKAdNetworkItems`** — ✅ present, currently containing **only Google's primary
  identifier** `cstr6suwn9.skadnetwork`. That is valid and must not be removed.
  > **TODO before final release:** periodically refresh `SKAdNetworkItems` from
  > Google's current official list (AdMob docs → *"Update your SKAdNetwork items"*),
  > and add the identifiers for any mediation/demand partners you enable, so
  > attribution coverage stays complete. **Never delete** `cstr6suwn9.skadnetwork`
  > or any existing identifier — only add.
- **`NSUserTrackingUsageDescription`** — *intentionally not set*: the app does **not**
  request ATT/IDFA tracking. Rewarded, interstitial and banner all serve without ATT
  (non-personalised when consent isn't granted). Add this key only if you later add
  an ATT prompt via UMP (see §8).

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
| iOS Banner - Journey | Banner | `…/6065307904` |

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
- **Journey banner** — a small **adaptive banner** during an active journey, free
  users only, placed below the time/distance readouts (`JourneyBannerAd`). It
  reserves space only once an ad loads, so it never covers the balloon, the map
  controls or the pause button, and it never appears for Pro users. Loads only
  after UMP consent allows ads. DEBUG uses Google's test banner unit.
- **Never:** app-open or native ads; banners anywhere except during a journey;
  any ad for Pro users; ads during the focus ritual or boarding.

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
`ad_skipped_not_ready`). `AnalyticsService` only **prints in DEBUG** and is a no-op
in Release, so no ad telemetry is emitted in production builds. The in-journey
banner's `JourneyBannerLog` is likewise compiled out of Release entirely.

## 10. Production readiness (TestFlight / App Store)

**Build-configuration safety (verified in code):**

- **Real IDs in Release.** `FocusGlobe/Services/AdMobConfig.swift` is the single
  source of truth. It uses Google's **test** ad unit IDs only inside `#if DEBUG`,
  and the **real FocusGlobe** unit IDs in every other configuration — Release,
  Archive, TestFlight and App Store. No `ca-app-pub-3940256099942544` (test) ID can
  reach a Release code path.
- **No "Test banner placeholder" in Release.** Every banner debug affordance
  (`debugPlaceholder`, the "Ad loading…" overlay, the reserved unloaded strip) is
  inside `#if DEBUG`. In Release a banner that hasn't loaded stays invisible at zero
  height and a failed banner collapses cleanly — no debug text, no fake container.
- **Pro users see no ads** — rewarded, interstitial and banner are all gated on the
  Pro flag (and the banner re-checks it). Never break this.
- **Rewards are callback-gated** — `showRewarded` returns `true` (and the app grants
  miles) **only** after Google's reward callback fires; dismissing early, a failed
  load, or "ads not ready" all grant nothing.
- **Landing is never blocked** — the journey-complete interstitial falls straight
  through to Landing for Pro / not-loaded / no-presenter, with a present-timeout
  safety net.

**Manual steps still required before shipping (cannot be done in code):**

- **App Store Connect → App Privacy:** declare **AdMob's data collection** in the
  privacy questionnaire. The Google Mobile Ads SDK typically collects *Device ID /
  Identifiers*, *Usage Data*, *Diagnostics* and possibly *Coarse Location* (for
  advertising/measurement). Match Google's current **"Data disclosure"** guidance
  for the Mobile Ads SDK. (The app's own data stays on-device; this is about the SDK.)
- **AdMob console → Privacy & messaging:** configure a **GDPR (EEA/UK) consent**
  message and any other regional messages you require. The app already calls UMP at
  launch (`AdService.start()`) and will not request ads until `canRequestAds` is
  true; with no message configured, UMP simply reports "ads allowed".
- **SKAdNetwork:** keep `SKAdNetworkItems` up to date (see §2 TODO).
- **Fill expectations:** for a brand-new app and freshly created ad units, real ads
  may return **low or no fill** at first — especially before the App Store listing is
  live and for the first hours/days after each unit is created. Empty fill in
  TestFlight is normal; all flows degrade gracefully to "no ad".
- **ATT:** not requested by this app. Only add an ATT prompt (UMP ATT message +
  `NSUserTrackingUsageDescription`) if you deliberately decide to — it is *not* part
  of this production-readiness pass.
