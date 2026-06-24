# FocusGlobe — Apple Platforms Readiness (iPad & Mac)

FocusGlobe is a **Universal** app (iPhone + iPad) that also runs on Apple Silicon
Mac as a "Designed for iPad" app. This file documents the configuration and the
manual validation steps. No app logic, monetization, RevenueCat, maps
architecture, audio, widgets, or notifications behaviour was changed for this —
only layout/scale, one map-performance setting, the Mac environment-object crash
fix, and the project's supported destinations.

## Confirmed project settings (FocusGlobe app target)

- **`TARGETED_DEVICE_FAMILY = 1,2`** in **both Debug and Release** ✅
  (Previously the app target was `1` = iPhone-only, which made iPad render a
  *scaled iPhone* UI in the compact size class and Mac run phone-like. Now it's a
  real iPad app and reports the regular size class on iPad.)
- **iPad orientations enabled**: `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad`
  = Portrait, Portrait-Upside-Down, Landscape-Left, Landscape-Right. iPhone stays
  **portrait-only** (the base `INFOPLIST_KEY_UISupportedInterfaceOrientations`).
- The **widget extension** is unchanged (already `1,2`).

> **If iPad/Mac still shows the old "compatibility / phone-like" mode after pulling:**
> it's a stale build. Quit the app, **delete Derived Data**
> (Xcode ▸ Settings ▸ Locations ▸ Derived Data → arrow → delete the FocusGlobe
> folder, or `rm -rf ~/Library/Developer/Xcode/DerivedData/FocusGlobe-*`),
> clean the build folder (⇧⌘K), and rebuild. Also delete the app from the
> Simulator/device once so the new device-family install replaces the old one.

## Supported Destinations (Xcode ▸ target ▸ General)

Enable exactly these:
- **iPhone**
- **iPad**
- **Mac (Designed for iPad)**

Do **NOT** enable yet:
- **Mac Catalyst** (would need SDK/Signing/App-Group re-work; not validated)
- **Apple TV**, **Apple Vision**

`TARGETED_DEVICE_FAMILY = 1,2` already makes the iPad app available on Apple
Silicon Macs as "Designed for iPad"; no Catalyst is required for that.

## What changed in code (layout/scale only)

- **`FocusGlobe/DesignSystem/Responsive.swift`** — `Layout` now scales by:
  - **Size class** (`contentMaxWidth` / `settingsMaxWidth` / `paywallMaxWidth` /
    `clusterMaxWidth`): centres content within a **generous tablet width** only
    when the horizontal size class is *regular* (iPad/Mac). On iPhone — and in
    narrow iPad multitasking — it's a no-op (full width), so iPhone is unchanged.
  - **Idiom** (`Layout.isPadIdiom` / `Layout.pad(phone, tablet)`): scales **fonts,
    controls and panels** up on iPad/Mac. Idiom is used (not size class) because
    size class is unreliable inside sheets and reports compact there.
- Tablet sizing applied: shared CTA buttons, Home title/cluster, Passport grids +
  cards, Settings/Paywall/Streak/Landing panels, Route destination cards, the
  focus ritual balloon/tokens, and the Active-Journey readouts/pause/banner.
- **Mac paywall crash fixed**: `PaywallView` (and the journey cover + the
  Streak/Location sheets) are presented with explicit `.environmentObject(appModel)`
  /`.environmentObject(router)`, because sheet/cover environment propagation is
  unreliable on Mac ("Designed for iPad"). This removes
  `Fatal error: No ObservableObject of type AppModel found`.
- **iPad/Mac map performance**: the *live journey* map uses **flat elevation** on
  iPad/Mac (`AppleMapStyle.apply(..., preferFlatElevation:)`), so it appears
  immediately instead of progressively streaming heavy 3D buildings. iPhone keeps
  the realistic 3D look; the Home globe is unchanged. The route overview → zoom →
  follow flow, controls and route line are untouched.
- **In-journey banner**: measures its real container width (correct on Mac /
  resizable windows) and caps to a tasteful centred width. In **DEBUG**, if the
  Google **test** banner fails or doesn't call back within ~3 s, a visible
  "Test banner placeholder" fills the exact slot (proves layout). In **RELEASE**
  there is **no** placeholder — a failure collapses cleanly. Pro users see
  nothing (real ad or placeholder). DEBUG uses Google's test banner unit; RELEASE
  uses `ca-app-pub-2780304092271589/6065307904`.

## Test matrix

Per screen check: no clipped content, no off-screen cards, controls usable, text
readable at arm's length. Screens: Home · Route Selection · Pre-boarding ritual ·
Boarding · Active Journey · Landing · Passport · Settings · Paywall · Streak modal.

1. **iPhone portrait** — must match the previous premium baseline (unchanged).
2. **iPad portrait** (e.g. iPad Air 13") — large, readable panels; multi-column grids.
3. **iPad landscape** — uses the width; centred panels, not a lonely phone column.
4. **iPad Stage Manager** — drag-resize; layouts reflow; banner re-measures; no clip.
5. **Mac (Designed for iPad)** — run "My Mac (Designed for iPad)"; resize small↔large;
   **open the paywall (it must not crash)**; start a journey (map appears promptly).

Also confirm: Free users see the in-journey banner (real DEBUG test ad **or** the
DEBUG placeholder); **Pro users see no banner/placeholder**; Double Miles rewarded
and the journey-complete interstitial still work; no ads in boarding/ritual/paywall;
audio and notifications still function; widgets still build.

## Recommended iPad App Store screenshots (capture before submission)

12.9"/13" iPad, landscape and portrait: Home (globe), Active Journey, Route
Selection, Passport, Paywall. (App Store Connect requires iPad screenshots once
the app declares iPad support.)

## Known limitations

- **Mac Catalyst** is intentionally off (see above). "Designed for iPad" is the
  supported Mac mode for now.
- Live-resizing a banner already on screen keeps its initial size until the next
  journey (cosmetic only; it's re-measured per journey).
- iPhone remains portrait-only by design.

See WIDGETS_SETUP.md (App Group / widget build), ADMOB_SETUP.md, REVENUECAT_SETUP.md,
and APP_STORE_READINESS.md for the rest of the submission checklist. App Group is
`group.com.focusglobe.app` on both the app and widget targets.
