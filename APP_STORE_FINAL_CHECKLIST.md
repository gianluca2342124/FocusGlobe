# FocusGlobe — App Store Final Checklist

The last gate before submission. Tick each item; **placeholders that must be
replaced are called out explicitly**. See also APP_STORE_READINESS.md,
APPLE_PLATFORMS_READINESS.md, ADMOB_SETUP.md, REVENUECAT_SETUP.md, WIDGETS_SETUP.md,
AUDIO_SETUP.md, NOTIFICATIONS_STRATEGY.md.

## A. Xcode project

- [ ] **Bundle ID**: `com.focusglobe.app` (app), `com.focusglobe.app.FocusGlobeWidgets` (widget).
- [ ] **Version** (`MARKETING_VERSION`) and **Build** (`CURRENT_PROJECT_VERSION`) bumped for the release.
- [ ] **Signing Team** set on **both** targets (app + widget); automatic signing OK.
- [ ] **Supported Destinations**: iPhone, iPad, **Mac (Designed for iPad)**. `TARGETED_DEVICE_FAMILY = "1,2"` (confirmed). Do **not** enable Mac Catalyst / Apple TV / Vision yet.
- [ ] **App Groups** `group.com.focusglobe.app` enabled on app **and** widget targets (widgets read the shared snapshot).
- [ ] Archive uses the **Release** configuration.
- [ ] **No DEBUG placeholders in Release**: the in-journey banner placeholder + all `[JourneyBanner]` / `[Notifications]` logs are behind `#if DEBUG` (verified). Build Release and confirm none appear.
- [ ] **Test ad IDs not used in Release**: `AdMobConfig` selects Google test units only `#if DEBUG`; Release uses production units (verified in source).

## B. RevenueCat / subscriptions

- [ ] App Store Connect subscription group + products (Annual w/ 7-day trial, Monthly, Lifetime) created and **Ready to Submit**.
- [ ] RevenueCat offering + `pro` entitlement attached to the product IDs; public SDK key in place.
- [ ] Paywall shows **localized** prices (not the disabled placeholders).
- [ ] **Restore Purchases** works (Settings **and** paywall footer).
- [ ] **Sandbox purchase** tested end-to-end (purchase → Pro → restore).
- [ ] **Pro removes ads** (no banner, no interstitial, no rewarded prompts).
- [ ] **Pro unlocks** Long/Ultra journeys, premium skins, premium journey audio, all widgets.

## C. AdMob

- [ ] **App ID** `ca-app-pub-2780304092271589~4583163289` in Info.plist (`GADApplicationIdentifier`).
- [ ] Units exist: rewarded Double Miles, rewarded Daily Boost, interstitial Journey Complete, **banner Journey** (`…/6065307904`).
- [ ] **SKAdNetworkItems** list added to Info.plist (Google's current list).
- [ ] **UMP consent** message configured (GDPR; optional ATT); app requests ads only after `canRequestAds`.
- [ ] Banner shows **only during Active Journey**, **Free users only**; **Pro users never** see a banner or the DEBUG placeholder.
- [ ] **No DEBUG placeholder in Release** (placeholder is `#if DEBUG` only).
- [ ] **app-ads.txt** published on the developer-site/marketing domain for publisher `pub-2780304092271589`.

## D. Privacy / legal

- [x] **Privacy Policy URL** — set in `LegalLinks.privacy` to the real hosted page (Notion). Shown on the paywall footer and at the bottom of Settings. Confirm it loads publicly.
- [x] **Terms of Use URL** — set in `LegalLinks.terms` to the real hosted page (Notion). Shown on the paywall footer and at the bottom of Settings. Confirm it loads publicly.
- [ ] App Store **Privacy "nutrition" labels** filled (AdMob: Identifiers / Usage Data for Third-Party Advertising; app stores focus history on-device; location not collected/transmitted).
- [ ] **Location usage string** present (`NSLocationWhenInUseUsageDescription`, already in build settings).
- [ ] **Notifications**: provisional, no first-launch prompt; copy is warm/non-manipulative (see NOTIFICATIONS_STRATEGY.md).
- [ ] **ATT** only if you actually enable personalised ads (`NSUserTrackingUsageDescription`); otherwise omit.

## E. Assets

- [ ] App icon (all sizes) + accent color.
- [ ] Launch screen (generated).
- [ ] Paywall hero (`PaywallBalloonHero`) and balloon skins present.
- [ ] **Audio** bundled in the **app target only** (`FocusGlobe/Resources2/Audio/Journeys/*.mp3`, ~4.9 MB of loops). Verified **not** in the widget target.
- [ ] **Widget target** has no heavy assets (its `Assets.xcassets` ≈ 32 KB).
- [ ] *Candidate for manual review (do NOT delete blindly):* the app asset catalog is ~17 MB — mostly used balloon-skin PNGs (~1.5 MB each) + `PaywallBalloonHero.PNG` (~2.6 MB). Consider compressing/optimising these PNGs (or HEIC) to shrink the binary; they are **in use**, so optimise rather than remove.

## F. Testing

- [ ] iPhone portrait · iPad portrait · iPad landscape · **Mac (Designed for iPad)**.
- [ ] Widgets (add from gallery; App Group linked).
- [ ] Audio loops play / pause / resume / stop; missing-file fallback never crashes.
- [ ] Subscriptions (sandbox), ads (DEBUG test ads), notifications (schedule/cancel without duplicates; Reminders toggle).
- [ ] Offline / basic failure states (no network: ads fail gracefully, banner collapses in Release / placeholder in DEBUG).
- [ ] Landing flow, streak/passport, route planner, boarding tear, Continue Journey.

## G. App Store Connect listing

- [ ] App name, subtitle, description, keywords.
- [ ] Screenshots: iPhone 6.7"/6.5"/5.5" **and** iPad 12.9"/13" (portrait + landscape).
- [ ] Subscription **review notes** (how to reach the paywall; what Pro unlocks).
- [ ] Demo account if needed (none required — no login).
- [ ] Age rating questionnaire.
- [ ] Support URL (required) and marketing URL (optional).

> The Privacy/Terms URLs in `LegalLinks` now point to the real hosted pages, so no
> legal-URL placeholders remain in code; everything else is configuration in App
> Store Connect / RevenueCat / AdMob.
