# FocusGlobe — App Store Readiness

A pre-submission checklist plus a record of the launch-polish guarantees that are
already handled **in code**. Nothing here changes pricing, RevenueCat, the
rewarded/interstitial ad logic, the UMP consent flow, the widgets, or the journey
systems — it's the final wiring + the manual steps only you can do in App Store
Connect / AdMob / RevenueCat.

---

## 1. Already handled in code (verify, don't re-implement)

| Area | Guarantee | Where |
|------|-----------|-------|
| **Ads gated by consent** | No ad (rewarded, interstitial **or** the banner) is requested before UMP consent is resolved and `canRequestAds` is true. The banner observes `AdService` (`@Published canRequestAds`) and appears reactively once ads are allowed. | `AdService.finishConsent()` / `canRequestAds`; `JourneyBannerAd` |
| **Pro sees no ads** | Rewarded, interstitial and the in-journey **banner** are all suppressed for Pro. | `showRewarded(isPro:)`, `presentJourneyCompleteInterstitial(isPro:)`, `JourneyBannerAd` (`!isPro` at the call site + re-checked) |
| **Banner placement** | Small adaptive banner shows **only during an active journey, free users only**, below the time/distance readouts — never over the balloon, controls or pause. Zero height until an ad loads. | `JourneyBannerAd`, `FocusSessionView.bottomReadouts` |
| **No ads elsewhere** | No banners on Home/Choose/Boarding/Passport/Settings/Landing; no app-open/native ads. | (only `JourneyBannerAd`, inside the journey) |
| **Test vs prod ad IDs** | DEBUG builds use Google's official **test** ad units (rewarded, interstitial, **banner**); RELEASE uses the real units. | `AdMobConfig` (`#if DEBUG`) |
| **Graceful ad failure** | No SDK / not loaded / no presenter → Landing still appears, banner just stays hidden. App never blocks or crashes. | `AdService`, `JourneyBannerAd` (`#if canImport`) |
| **Notification permission** | Requested **provisionally** (no prompt) only when the user opens Passport or Settings — never after a journey, never at first launch. Explicit Reminders toggle still does a normal opt-in. | `AppModel.requestNotificationPermissionForEngagement()`, `NotificationService` |
| **Audio never crashes** | Missing journey audio → distinct procedural fallback; missing UI earcon → soft system sound. Files load lazily, by name, on first use. | `SoundService`, `UISoundService` |
| **Audio app-size** | Audio is **only** in the main app target (see AUDIO_SETUP.md). Widgets bundle no audio. | `AUDIO_SETUP.md`, widget target |
| **No debug labels in RELEASE** | The Home location-code chip and all `print("[Performance]…")` lines are `#if DEBUG`. | `HomeView`, `AppModel` |
| **Restore** | "Restore Purchases" in Settings **and** the paywall footer; both call `AppModel.restorePurchases()`. | `SettingsView`, `PaywallView` |
| **Privacy / Terms links** | Present in the paywall footer; URLs centralised + configurable (no bundled legal text). | `LegalLinks`, `PaywallView` |

---

## 2. Manual steps before you submit

### 2.1 Legal links (required)
Replace the placeholders in **`FocusGlobe/Services/LegalLinks.swift`**:
- `LegalLinks.privacy` → your real, reachable **Privacy Policy** URL.
- `LegalLinks.terms` → your real **Terms of Use (EULA)** URL.

App Review rejects dead links, and auto-renewable subscriptions require a working
Terms/EULA link in the purchase flow. (Apple's standard EULA is acceptable — link
to `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/` if you have
no custom terms.) **Do not** ship the `focusglobe.app/...` placeholders.

### 2.2 App Store Connect — subscriptions & IAP
- Create the subscription group and products that back RevenueCat:
  **Annual** (with 7-day free trial), **Monthly**, and the **Lifetime** non-consumable.
- Fill localized display names, prices, and the subscription review screenshot.
- Add the **Privacy Policy URL** at the app level and the **Terms (EULA)** in the
  subscription localization.
- See REVENUECAT_SETUP.md for the exact product/entitlement identifiers.

### 2.3 RevenueCat
- Create the **offering** with the Annual / Monthly / Lifetime packages and the
  `pro` (or your chosen) **entitlement**; attach the App Store product IDs.
- Put the RevenueCat **public SDK key** where REVENUECAT_SETUP.md documents.
- Confirm the paywall shows **localized** prices (not the disabled placeholders).

### 2.4 AdMob
- Ad units (create/confirm in the AdMob dashboard; IDs live in `AdMobConfig`):
  - iOS Rewarded – Double Miles `…/2338881545`
  - iOS Rewarded – Daily Mission Boost `…/1025799876`
  - iOS Interstitial – Journey Complete `…/3081117578`
  - **iOS Banner – Journey `…/6065307904`** ← new this release
- **app-ads.txt:** publish `app-ads.txt` at the root of your developer-site domain
  (the one in your App Store Connect "Marketing URL"/developer site) containing the
  Google line for publisher `pub-2780304092271589`, so the inventory is authorized.
- **Info.plist (app target):** `GADApplicationIdentifier =
  ca-app-pub-2780304092271589~4583163289`, plus Google's current `SKAdNetworkItems`
  list. See ADMOB_SETUP.md §2.
- **UMP / Privacy & messaging:** create the GDPR consent message (and optional ATT
  message). The app resolves consent at launch and only then requests ads.

### 2.5 App Privacy details (App Store Connect → App Privacy)
- Declare what AdMob collects for your configuration (typically *Identifiers* and
  *Usage Data* used for **Third-Party Advertising**/**Analytics**; "Device ID"
  linked to advertising). Match it to your UMP/ATT choices.
- The app itself stores focus history **on device** and uses location only to set
  the starting city (not collected/transmitted) — reflect that too.

### 2.6 Capabilities (one-time, Xcode)
- **App Groups** `group.com.focusglobe.app` on the app **and** widget targets (WIDGETS_SETUP.md).
- **Background Modes → Audio** if you want journey audio to continue backgrounded (AUDIO_SETUP.md).
- **URL scheme** `focusglobe` for widget deep links (WIDGETS_SETUP.md).

### 2.7 Assets & store listing
- App icon (all sizes), 6.7" / 6.5" / 5.5" + iPad screenshots, description,
  keywords, support URL, age rating.
- If you enable an ATT message, add `NSUserTrackingUsageDescription`.

---

## 3. Pre-submission test pass

- [ ] **DEBUG run** shows Google **test** ads (rewarded, journey-complete
      interstitial, and the in-journey banner) — never production traffic.
- [ ] **Free user:** small banner appears during a journey, below the readouts,
      not covering the balloon/controls/pause; disappears on landing.
- [ ] **Pro user:** **no** banner, **no** interstitial, **no** rewarded prompts
      anywhere (purchase or restore Pro, then start a journey).
- [ ] **Restore Purchases** works from both Settings and the paywall footer.
- [ ] **Privacy** and **Terms** links open the real pages.
- [ ] **Notifications:** no permission prompt after landing; opening Passport or
      Settings starts provisional reminders; the Settings Reminders toggle works.
- [ ] **No "Taking off" screen** — booking goes straight into the live journey.
- [ ] **Home globe** shows the zoomed-out 3D Earth centred on your origin with the
      balloon visible (real location, virtual origin after landing, or fallback).
- [ ] Audio missing (fresh build, no audio files) → app still runs; procedural
      ambience + system earcons; no crash.
- [ ] **Widgets** build and show data once the App Group is enabled.
- [ ] Archive a **RELEASE** build: confirm production ad IDs, no debug chips/logs.
- [ ] TestFlight: external testers can install, purchase (sandbox), and restore.

---

## 4. Notes
- The Google Mobile Ads / UMP and Google Maps packages are **SDK-guarded**; the
  app compiles and runs without them (ads simply don't show). Linking them in
  Xcode "lights up" the real behaviour. See ADMOB_SETUP.md.
- This release's code changes: reliable Home globe camera, shared premium tap
  earcon, provisional notification timing, removal of the takeoff screen, the
  free-user in-journey banner, a slightly smaller paywall hero, and centralised
  legal links. No change to pricing, purchase/restore, existing ad logic, UMP,
  widgets, or journey/audio systems.
