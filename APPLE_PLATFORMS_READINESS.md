# FocusGlobe — Apple Platforms Readiness (iPad & Mac)

FocusGlobe's layouts are now adaptive across iPhone (portrait + landscape), iPad
(portrait + landscape), resizable iPad Stage Manager windows, and Apple Silicon
Mac running the iPad app. This is **layout-only** work — no app logic, monetization,
RevenueCat, maps architecture, audio, widgets, or notifications behaviour changed.

## How adaptivity works (code)

A single shared helper drives it: **`FocusGlobe/DesignSystem/Responsive.swift`**
(`Layout` + view modifiers), composed with the existing `readableWidth`.

- **Max-width centering** (`contentMaxWidth`, `settingsMaxWidth`, `paywallMaxWidth`,
  `clusterMaxWidth`, `readableWidth`): content is centred within a comfortable band
  on large displays. Every cap is wider than an iPhone-portrait content width, so
  **iPhone portrait is unchanged** (the modifier is a no-op); iPhone landscape,
  iPad and Mac get a centred, intentional panel instead of a stretched sheet.
- **Adaptive grids** (`Layout.cardColumns(...)`): `GridItem(.adaptive(...))` yields
  ~2 columns on a phone and more on iPad/Mac, reflowing automatically in resizable
  windows. Used by Passport (stats / postcards / sounds).
- **Measured widths**: the active-journey banner measures its real container width
  (works in resizable windows / Mac) and caps itself (`Layout.bannerMaxWidth`) so
  it stays tasteful and centred, never spanning a huge window.

Screens touched: Home, Route Selection, Active Journey, Passport, Settings, Paywall
(centred bands / adaptive grids). Landing already used `readableWidth`; Boarding's
ticket and the Pre-boarding ritual were already width-capped and centred.

No `UIDevice.current.userInterfaceIdiom` branching is used — sizing is driven by
available width / size, so it degrades gracefully on any window size.

## Test matrix (Simulator + device)

Check each screen for no clipped content, no off-screen cards, usable controls:
Home · Route Selection · Pre-boarding ritual · Boarding · Active Journey · Landing ·
Passport · Settings · Paywall.

1. **iPhone portrait** — must look exactly as before (premium baseline).
2. **iPhone landscape** — rotate; content should centre, not spread to the edges.
3. **iPad portrait** and **iPad landscape** — centred panels, multi-column grids.
4. **iPad Stage Manager** — drag the window edge to resize; layouts reflow, the
   journey banner re-measures, nothing clips.
5. **Apple Silicon Mac** — run the iPad app ("My Mac (Designed for iPad)"); resize
   the window small and large.

Also confirm: Free users see the in-journey banner (DEBUG test ad) and **Pro users
never** do; Double Miles rewarded and the journey-complete interstitial still work;
no ads in boarding / focus ritual / paywall; audio and notifications still function.

## Enabling iPad support (if not already on)

Target **FocusGlobe ▸ General ▸ Supported Destinations / Deployment Info**:
- Ensure **iPad** is a supported destination (and "iPhone").
- **Device Orientation**: keep iPhone as desired; for iPad, allow Portrait +
  Landscape Left/Right (and Upside Down) so rotation/Stage Manager behave.
- iPad multitasking: leave "Requires full screen" **unchecked** so the app
  participates in Split View / Stage Manager (the layouts support it).

## Testing the iPad app on Apple Silicon Mac

No project change required for "Designed for iPad":
- In App Store Connect / TestFlight the iPad build is offered on Apple Silicon Macs
  automatically unless you opt out (**App Store Connect ▸ Pricing and Availability ▸
  "Also available on Mac"** / the "Designed for iPad" toggle).
- Locally: select the **"My Mac (Designed for iPad)"** run destination in Xcode and
  run, then resize the window.

## Enabling Mac Catalyst later (optional, manual)

Mac Catalyst is **not** enabled in the project (left off to avoid an unverified
build). To enable it when you're ready:

1. Target **FocusGlobe ▸ General ▸ Supported Destinations ▸ +** → **Mac (Mac
   Catalyst)**. Choose "Scale Interface to Match iPad" (simplest) or "Optimize for Mac".
2. **Signing & Capabilities**: select the **Mac** destination and set a **Signing
   Team**; re-add **App Groups** (`group.com.focusglobe.app`) for the Mac destination.
3. Audit SDKs for Catalyst support:
   - **Google Mobile Ads / UserMessagingPlatform** and **RevenueCat** — verify the
     linked versions support Mac Catalyst, or guard their usage (the AdMob layer is
     already `#if canImport(GoogleMobileAds)`-guarded, so it compiles without them).
   - Map/MapKit, AVFoundation audio, UserNotifications, WidgetKit are Catalyst-safe.
4. Build the **Mac Catalyst** destination and fix any per-platform `#if targetEnvironment(macCatalyst)` needs (e.g., window sizing). Don't ship until it builds and runs clean.

## Signing Team & App Groups (per target)

- **FocusGlobe (app)** — Signing Team required; App Group `group.com.focusglobe.app`.
- **FocusGlobeWidgetsExtension (widget)** — Signing Team required; the **same** App
  Group `group.com.focusglobe.app` (so the widget reads the shared snapshot).
- If you enable **Mac Catalyst**, repeat the team + App Group for the Mac destination.

See WIDGETS_SETUP.md (App Group / widget build), ADMOB_SETUP.md, REVENUECAT_SETUP.md,
and APP_STORE_READINESS.md for the rest of the submission checklist.
