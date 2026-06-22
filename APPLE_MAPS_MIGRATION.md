# Apple Maps Migration — FocusGlobe

FocusGlobe's maps now render with **Apple Maps (native MapKit)** by default.
Google Maps remains in the project as a **fallback for this migration phase** —
nothing Google was removed.

## No token / key required

Native iOS **MapKit needs no API key or token**. This migration adds **no**
token logic, **no** MapKit JS, **no** Apple Maps Server API, and **no** new
network calls. Core Location usage description is unchanged.

## Architecture

A thin runtime switch chooses the renderer; every renderer consumes the same
provider-independent `JourneyMapData` / backdrop inputs, so journey planning,
location, timer, rewards, premium, RevenueCat, skins and audio are untouched.

- `FocusGlobeMapProvider` — `.apple` (default) / `.google` / `.fallback`.
  `FocusGlobeMapProvider.current` resolves to `.apple` in release.
- Two wrappers fan out to the provider:
  - `JourneyMapView` (active flight) → `AppleActiveJourneyMapView`.
  - `JourneyBackdropMap` (Home, Choose Journey, Boarding, Onboarding) →
    `AppleBackdropMapView`. `JourneyDiscoveryMap` wraps `JourneyBackdropMap`, so
    Choose Journey migrates automatically.

### New Apple files (Google files left untouched)

- `FocusGlobeMapProvider.swift` — provider abstraction + DEBUG switch.
- `AppleMapStyle.swift` — `MapDisplayStyle` → `MKMapConfiguration` (+ dark).
- `AppleMapCameraController.swift` — camera distances / framing math.
- `AppleMapRouteRenderer.swift` — route / trail / halo / ring overlays + renderers.
- `AppleMapAnnotationRenderer.swift` — `MapImageAnnotation` + balloon/dot/tag views.
- `AppleJourneyBackdropMap.swift` — `AppleBackdropMapView` (origin + route modes).
- `AppleActiveJourneyMapView.swift` — live in-flight renderer.

Markers reuse the existing `VehicleMarkerRenderer` images, so the **selected
balloon skin** (with its `BalloonSkin_Default` → vector fallback and transparent
trimming) is identical to before.

## Screens now on Apple Maps

1. **Home** — dark map, origin halo + radar (centred on the origin via
   `MKMapView.convert`), selected-skin balloon lifted into the upper half, wide
   "not too close" framing, no Google attribution.
2. **Start / location resolving** — same dark backdrop; location logic unchanged.
3. **Choose Journey** — geodesic selected route (dominant), origin/destination
   dots, code tags, subtle nearby tags, radar rings centred on the origin.
4. **Boarding** — dark route backdrop behind the unchanged boarding pass.
5. **Active Journey** — centre-on-balloon → quick zoom-in takeoff, gentle follow,
   Full Route / Recenter / Tilt (camera pitch) / map-style / Pure Mode controls,
   geodesic route + subtle white air trail (no coloured completed line),
   selected-skin balloon.

Landing/postcard was not map-based and is unchanged.

## Default style & map-style controls

Default = `MKStandardMapConfiguration(emphasisStyle: .muted)` forced to dark
cartography (`overrideUserInterfaceStyle = .dark`) with points-of-interest
hidden — calm, premium, dark. The existing style menu maps to MapKit:

| Style       | MapKit |
|-------------|--------|
| Dark / Night / Mono | Standard, muted, forced dark |
| Standard    | Standard, default emphasis |
| Terrain     | Standard + **realistic elevation**, dark + muted |
| Satellite   | Imagery |
| Hybrid      | Hybrid + realistic elevation |

## Known MapKit limitations vs Google

- **No JSON styling.** MapKit can't reproduce Google's custom JSON. We use
  supported configurations + dark override + muted emphasis instead. A separate
  "Mono" cartography doesn't exist → it maps to the dark/muted look.
- **No gradient polylines.** The air trail is a single translucent white line
  (Google faded it via a stroke gradient). Closest native equivalent.
- **Terrain isn't Google terrain.** It's a realistic-elevation standard map kept
  dark/muted. If it ever reads too bright on a device, switch the default
  `.terrain` mapping in `AppleMapStyle` to the plain muted-dark standard.
- **Camera pitch may be clamped** by MapKit at low altitudes; the 3D tilt uses
  `MKMapCamera.pitch` and is best-effort.
- **Follow camera** is animated by setting `mapView.camera` inside a
  `UIView` animation block (to match the balloon's glide duration); if a future
  iOS changes this, it degrades to a per-tick snap (still functional).

## DEBUG provider switch

There is **no user-facing** provider switch. In DEBUG only, set
`FocusGlobeMapProvider.debugOverride = .google` (e.g. from the debugger) to
compare against Google Maps; `= nil` restores the Apple default. Release builds
always use Apple.

## What to test before removing Google Maps

See the validation checklist in the migration task. In short: Home (real +
virtual origin), Start (allowed + denied/fallback), Choose Journey (from a city
and from a previous landing), Boarding preview, Short + Ultra active journeys,
map-style switching, Pure Mode, pause/resume, Pro user with premium skins, and
the missing-balloon-asset fallback. Confirm the radar is centred, the route and
air trail render, the takeoff/follow camera feels right, and no Google map or
attribution appears in the normal flow.

## Future cleanup checklist (a LATER task — not now)

Once Apple Maps is fully verified on device:

1. Remove the GoogleMaps Swift Package dependency from the project.
2. Delete `GoogleJourneyMapView.swift` and the `GoogleBackdropMapView` in
   `JourneyBackdropMap.swift` (and the `#if canImport(GoogleMaps)` branches).
3. Remove the Google API key in `MapConfiguration.swift` and the
   `GMSServices.provideAPIKey` call in `FocusGlobeApp.swift`.
4. Simplify `FocusGlobeMapProvider` to Apple + native fallback only.
5. Drop the legacy `MapStyles` JSON and the old `MapProvider` enum if unused.
