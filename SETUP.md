# FocusGlobe — Setup & Run

FocusGlobe is a native SwiftUI iOS app. It is designed to **build and run out of
the box with zero dependencies** — and to light up live Google Maps the moment
you add the SDK package.

---

## Requirements

- **Xcode 16 or newer** (the project uses the modern file-system-synchronized
  project format and a few iOS 17 APIs).
- **iOS 17.0+** deployment target.
- A Mac. No CocoaPods, no command-line setup required.

---

## 1. Run immediately (no setup)

1. Open `FocusGlobe.xcodeproj` in Xcode.
2. Select the **FocusGlobe** scheme and an iPhone simulator (e.g. iPhone 15).
3. Press **Run** (⌘R).

The app launches with a **fully native, stylised "fallback" map** — a calm
aerial canvas (mood gradient, soft graticule, drifting clouds, the route line
and the moving balloon). Every screen, the timer, rewards, passport, history and
settings all work. This is so you can experience the whole product instantly.

> The map provider is selected at compile time. Without the Google Maps SDK
> linked, `JourneyMapView` renders `FallbackJourneyMapView`. Add the SDK
> (below) and it automatically switches to `GoogleJourneyMapView`.

---

## 2. Live Google Maps (pre-wired)

The **GoogleMaps Swift Package is already declared in the project** (`ios-maps-sdk`,
linked to the FocusGlobe target). On first open, Xcode resolves it automatically
(File ▸ Packages ▸ Resolve if needed). Once resolved, `#if canImport(GoogleMaps)`
is true and the **live session renders the real Google map** — no manual steps.

- The API key is in `FocusGlobe/Map/MapConfiguration.swift` and is provided to
  the SDK in `FocusGlobeApp.swift`.
- If package resolution fails (e.g. offline), the app still **builds and runs on
  the aurora fallback** because the Google code is guarded by `#if canImport`.
  Resolve the package (with network) to get the live map.
- To change the SDK version, use the package UI in Xcode (it's pinned to
  `upToNextMajor 8.4.0`).

---

## Where the API key goes (summary)

| What | Where |
|------|-------|
| The key value | `FocusGlobe/Map/MapConfiguration.swift` |
| Provided to SDK | `FocusGlobe/App/FocusGlobeApp.swift` (`GMSServices.provideAPIKey`) |
| Provider switch | `FocusGlobe/Map/JourneyMapView.swift` (`#if canImport(GoogleMaps)`) |

### Recommended for release: move the key out of source

The key is inline for MVP convenience. Maps SDK keys ship inside the app binary
regardless, but you should still:

1. In **Google Cloud Console**, restrict the key to the **Maps SDK for iOS** API
   and to this app's **bundle identifier** (`com.focusglobe.app` by default —
   change it to your own).
2. Optionally move the literal into an untracked `Secrets.xcconfig`:
   ```
   GOOGLE_MAPS_API_KEY = your_key_here
   ```
   add `INFOPLIST_KEY_...` / a build setting, read it via `Bundle.main`, and add
   `Secrets.xcconfig` to `.gitignore` (already present, commented).

---

## Troubleshooting: the map is blank

1. **Did you add the package?** Without `GoogleMaps`, you'll (correctly) see the
   stylised fallback map, not a blank screen. A *blank/gray* Google map means the
   SDK is linked but tiles aren't loading.
2. **Key restrictions.** In Google Cloud Console confirm:
   - "Maps SDK for iOS" is **enabled** for the project.
   - The key's **iOS app restriction** matches your bundle id (or is unrestricted
     while testing).
   - **Billing** is enabled on the Google Cloud project (required even for the
     free tier).
3. **Key is loaded.** On launch, `GMSServices.provideAPIKey` runs. If the key is
   invalid, the SDK prints an error to the Xcode console — check there.
4. **Network.** The simulator needs internet access to fetch tiles.
5. **Clean build.** Product ▸ Clean Build Folder (⇧⌘K), then run again.

### Verify the key is loaded
- Run the app, open a journey. If real map tiles appear, the key works.
- If you see a console message like `Google Maps SDK ... API key`, the key is
  being read but rejected — fix the restrictions/billing above.

---

## Brand assets (logo & balloon PNGs)

**The balloon hero ships as a real asset.** `BalloonFront.imageset` contains a
generated front-view balloon (`BalloonFront.png`, transparent, with the warm
burner glow), so `BalloonView` uses a raster hero everywhere (Takeoff, Boarding,
Landing, Paywall) and Xcode shows **no asset warnings**.

| Asset | Location | Used for |
|------|----------|----------|
| Front-view balloon | `FocusGlobe/Assets.xcassets/BalloonFront.imageset/BalloonFront.png` | Hero balloon via `BalloonView` |
| Logo / wordmark | *(optional)* add an image named `BrandLogo` to the catalog | App wordmark via `AppLogo` |

- **To use your official balloon render:** replace `BalloonFront.png` with your
  PNG (keep the **exact** name `BalloonFront.png`, lowercase `.png`, one file).
  Don't add a second file or a different extension — a stray `.PNG`/`.jpeg` or a
  duplicate is what triggers the "unassigned / invalid" asset warning. Or just
  drag your PNG onto the imageset in Xcode. To regenerate the placeholder:
  `python3 Tools/make_balloon.py`.
- **Logo:** the wordmark renders in code (crisp, no asset needed). To use a
  custom logo image, add one named `BrandLogo` to the asset catalog —
  `AppLogo` switches to it automatically.

> Use the **front-view** balloon (with basket + burner glow). The top-down
> balloon render is intentionally not used; the live map marker is derived from
> the front-view identity in code.

The map marker and small chips always use the crisp in-code vector balloon
(`BalloonMark`) so they stay sharp at any zoom and theme correctly.

## Appearance

FocusGlobe is **dark-first**: the first launch starts in Dark Mode. Users can
switch to Light or System in **Settings ▸ Appearance**, and the choice persists.

## Notes

- **No location permission** is requested in v1 (routes are curated locally).
- **Bundle identifier:** `com.focusglobe.app` — change it in the target's
  *Signing & Capabilities* and update your key restriction to match.
- **App icon:** generated by `Tools/make_icon.py` (pure Python, no dependencies).
  Re-run `python3 Tools/make_icon.py` to regenerate
  `FocusGlobe/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`.
- **Gestures on the journey map are intentionally disabled** (it's a focus
  screen) — the camera gently follows the balloon.
