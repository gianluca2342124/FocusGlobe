# Privacy Notes — FocusGlobe (MVP)

> **Superseded for the shipping app.** This is an early-MVP snapshot. The data model
> below (local-first, no backend, no login, focus history on device) is still
> accurate, but the shipping app now uses **real** location (to set the starting
> city), **AdMob** ads (free users only; Pro is ad-free), and **RevenueCat + Apple**
> purchases. For the current model see **PERSISTENCE_MODEL.md** and
> **APP_STORE_FINAL_CHECKLIST.md** (privacy nutrition labels, ATT, consent).

FocusGlobe is built privacy-first. In the MVP:

- **No login.** There is no account system and no sign-in.
- **No location permission.** The app never asks for or uses the device
  location. Routes are curated locally with fixed coordinates.
- **Focus history stays on device.** Sessions, miles, streak, postcards and
  settings are stored locally via `UserDefaults` (`Services/PersistenceService.swift`).
  Nothing is uploaded; there is no backend.
- **Routes are curated locally.** No Directions, Routes, Places, Geocoding or
  Search APIs are called. The journey path is a simulated geodesic line between
  two local coordinates.
- **Google Maps SDK** is used only to *render* the map (tiles, markers,
  polylines). Map rendering may involve Google's own network requests per
  Google's terms; review Google Maps Platform's privacy/terms before release.
- **Ads are mocked.** `Services/AdService.swift` simulates a rewarded ad with a
  delay; no ad network is contacted and no ad identifiers are read.
- **Analytics is mocked.** `Services/AnalyticsService.swift` only prints events
  to the console in DEBUG; nothing is sent anywhere.
- **Purchases are mocked.** `Services/PurchaseService.swift` simulates Pro
  locally; no StoreKit/receipt data is collected.

## Before adding real ads / analytics / purchases

Any future integration MUST respect privacy and platform requirements:

- Implement **App Tracking Transparency (ATT)** if any SDK accesses the IDFA or
  performs cross-app tracking.
- Complete an accurate **App Privacy "Nutrition Label"** in App Store Connect
  reflecting exactly what each SDK collects.
- Prefer non-personalised ads where possible; gate personalised ads on consent.
- Keep the rule: **ads never appear during a focus session** — only after
  landing.
- Add a Privacy Policy URL and (if needed) a consent flow before shipping ads or
  analytics.
