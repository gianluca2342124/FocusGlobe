<div align="center">

# 🎈 FocusGlobe

**Float into focus. Stay focused until you land. Leave distractions below.**

A calm, beautiful, map-first focus timer where each session becomes a relaxing
balloon journey across a real map.

</div>

---

## What this is

FocusGlobe turns a focus timer into a journey. You pick a route, take off, and a
soft balloon drifts across a map while you study / work / read — you **land** when
the session completes and earn a postcard for your Globe Passport.

- **Map-first hero experience** with a gently following camera and a balloon that
  glides along a geodesic route line.
- **Routes from 5 minutes to 12 hours** (23 curated routes across Micro, Short,
  Deep, Long and Ultra focus).
- **Premium, calm design** — floating glass islands, soft gradients, rounded
  type, full Light & Dark mode.
- **Pure Mode** — hides everything but the map, the balloon and the time.
- **Rewards** — Focus Miles, streaks, collectible postcards, a Globe Passport.
- **Free-first** with mocked ads (after landing only) and a mock Pro paywall.
- **Private by default** — no login, no location, no backend, no tracking.

> Built to **build and run instantly with zero dependencies** via a gorgeous
> native fallback map, and to switch to **Google Maps** the moment you add the
> SDK package — see [`SETUP.md`](SETUP.md).

---

## How to run

```
open FocusGlobe.xcodeproj   # Xcode 16+, iOS 17+
⌘R
```

It runs immediately with the native stylised map. To enable live Google Maps,
add the SwiftPM package `https://github.com/googlemaps/ios-maps-sdk` (product
`GoogleMaps`) to the FocusGlobe target. Full steps + troubleshooting in
[`SETUP.md`](SETUP.md).

**API key** lives in `FocusGlobe/Map/MapConfiguration.swift` and is provided to
the SDK in `FocusGlobe/App/FocusGlobeApp.swift` (guarded by
`#if canImport(GoogleMaps)`).

---

## Architecture

Clean MVVM with a hard wall between **business logic** and **map rendering**.

```
FocusGlobe/
├─ App/                       # Entry point & root navigation
│  ├─ FocusGlobeApp.swift     #   @main, provides Google key (guarded)
│  └─ RootView.swift          #   NavigationStack + journey cover + paywall sheet
├─ Core/                      # Provider-independent fundamentals
│  ├─ GeoCoordinate.swift     #   the ONLY coordinate type the app speaks
│  ├─ GeoMath.swift           #   geodesic interpolation, distance, bearing
│  ├─ JourneyPhase.swift      #   boarding→takingOff→cruising→approaching→landing
│  ├─ Formatters.swift
│  └─ AppRouter.swift         #   navigation
├─ DesignSystem/              # AppColors, AppTypography, AppSpacing, AppGradients,
│                             # AppGlassCard, AppFloatingIsland, AppButtons,
│                             # AppRouteCard, AppMetricPill, AppChip, BalloonMark, AppLogo
├─ Models/                    # Route, RouteCategory, RouteMood, RouteTheme,
│                             # FocusSessionRecord, Postcard, LandingSummary,
│                             # UserProgress, AppSettings, AppearanceMode, Vehicle
├─ Services/                  # AppModel (source of truth), SessionTimerService,
│                             # PersistenceService, RouteCatalog, Sound, Haptics,
│                             # Analytics (mock), Ad (mock), Purchase (mock)
├─ Map/                       # ← the only provider-aware layer
│  ├─ JourneyMapView.swift        # picks provider via #if canImport(GoogleMaps)
│  ├─ JourneyMapData.swift        # provider-independent data contract
│  ├─ GoogleJourneyMapView.swift  # Google provider (guarded)
│  ├─ FallbackJourneyMapView.swift# native SwiftUI map (no SDK)
│  ├─ AppleJourneyMapView.swift   # future MapKit placeholder
│  ├─ MapRouteRenderer.swift      # route sampling + fallback projection
│  ├─ CameraController.swift      # neutral CameraPose
│  ├─ VehicleMarkerRenderer.swift # rasterises BalloonMark → marker image
│  ├─ MapStyles.swift             # calm Google style JSON (light/dark)
│  └─ MapConfiguration.swift      # API key + provider switch
└─ Features/                  # Home, RouteSelection, Boarding, FocusSession,
                              # Landing, Passport, History, Settings, Paywall
```

See [`MAP_PROVIDER_MIGRATION.md`](MAP_PROVIDER_MIGRATION.md) for exactly what to
change (and what never to touch) when moving to Apple Maps.

---

## What's mocked (MVP)

| Area | Status | File |
|---|---|---|
| Rewarded ads | Mock (2s delay, always succeeds; post-landing only) | `Services/AdService.swift` |
| Purchases / Pro | Mock (local flag, simulated delay) | `Services/PurchaseService.swift` |
| Analytics | Mock (prints in DEBUG) | `Services/AnalyticsService.swift` |
| Ambient sound | Safe no-op until audio files are added | `Services/SoundService.swift` |
| Map (until SDK added) | Native fallback renderer | `Map/FallbackJourneyMapView.swift` |

---

## What's still TODO

- Add the Google Maps SwiftPM package to ship the live map (one-time, documented).
- Add ambient audio files (`wind_soft`, `cabin_soft`, `night_calm`, `rain_soft`,
  `ocean_calm`, `aurora_calm`) — wired by name, currently no-ops.
- Replace mock Ad / Purchase / Analytics with real, privacy-respecting SDKs.
- Background continuation: Live Activity / Dynamic Island / local notification so
  long journeys persist on the Lock Screen (MVP counts accurately in the
  foreground and snaps to the correct time on return).
- Additional balloon skins (data already modelled in `Vehicle.comingSoon`).
- Localisation (Spanish keyword list ready in `APP_STORE_NOTES.md`).

---

## Next 10 steps to App Store readiness

1. **Add the Google Maps SwiftPM package** and verify the live map + key on
   device (restrict the key to your bundle id + Maps SDK for iOS).
2. **Add real ambient audio** and tune fade-in/out per mood.
3. **Integrate StoreKit 2** for Pro (replace `PurchaseService`) with real
   products, prices and restore.
4. **Integrate a rewarded-ad SDK** (e.g. AdMob) behind the existing
   `AdService.showRewardedAd()` contract; add ATT + consent.
5. **Wire privacy-respecting analytics** behind `AnalyticsService.log`.
6. **Background/Lock-Screen continuation** via Live Activities + Dynamic Island,
   plus a local notification at landing.
7. **Add Home Screen & Lock Screen widgets** (current streak / miles / "resume").
8. **Onboarding** (3 calm screens) + an App Store screenshot pipeline using the
   copy in `APP_STORE_NOTES.md`.
9. **Accessibility & localisation pass** (Dynamic Type audit, VoiceOver labels,
   Spanish first).
10. **Polish & ship**: app icon variants, unit tests for `GeoMath`/streak/timer,
    crash-free QA on the full duration range, then submit.

---

## Privacy

No login, no location, no backend, no tracking. Focus history stays on device.
See [`PRIVACY_NOTES.md`](PRIVACY_NOTES.md).
