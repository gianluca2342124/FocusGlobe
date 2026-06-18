# Map Provider Migration — Google Maps → Apple Maps / MapKit

> **Google Maps is the temporary MVP provider. Keep all business logic
> provider-independent so we can migrate to Apple Maps / MapKit later.**

This document explains how FocusGlobe is architected so the map layer can be
swapped with minimal, well-contained changes.

---

## Current vs future

| | Provider | File |
|---|---|---|
| **Current (MVP)** | Google Maps SDK for iOS | `Map/GoogleJourneyMapView.swift` |
| **Always-available** | Native SwiftUI fallback (no SDK) | `Map/FallbackJourneyMapView.swift` |
| **Future** | Apple Maps / MapKit | `Map/AppleJourneyMapView.swift` (placeholder) |

The active provider is chosen **at compile time** in
`Map/JourneyMapView.swift`:

```swift
#if canImport(GoogleMaps)
    GoogleJourneyMapView(data: data)
#else
    FallbackJourneyMapView(data: data)
#endif
```

---

## The contract: `JourneyMapData`

Every renderer consumes the same plain-data struct — `Map/JourneyMapData.swift`:

```swift
struct JourneyMapData: Equatable {
    var origin: GeoCoordinate
    var destination: GeoCoordinate
    var vehicle: GeoCoordinate
    var progress: Double
    var bearingDegrees: Double
    var mood: RouteMood
    var theme: RouteTheme
    var followsVehicle: Bool
    var isMoving: Bool
}
```

There are **no SDK types** in this struct (no `GMSCoordinate`,
`CLLocationCoordinate2D`, etc.). The app speaks only `GeoCoordinate`
(`Core/GeoCoordinate.swift`). Only a renderer translates `GeoCoordinate` into
its SDK's native coordinate type, and only inside its own file.

---

## What is provider-independent (DO NOT touch during migration)

These contain the product and never import a map SDK:

- **Geo math** — `Core/GeoMath.swift` (geodesic interpolation, distance, bearing,
  sampling).
- **Journey phase** — `Core/JourneyPhase.swift`.
- **Route data** — `Models/Route.swift`, `Services/RouteCatalog.swift`.
- **Timer engine** — `Services/SessionTimerService.swift`.
- **Session logic / progress / rewards / streak** —
  `Features/FocusSession/FocusSessionViewModel.swift`, `Services/AppModel.swift`,
  `Models/UserProgress.swift`, `Models/FocusSessionRecord.swift`,
  `Models/LandingSummary.swift`.
- **Route geometry helpers** — `Map/MapRouteRenderer.swift` (sampling +
  fallback projection). Provider-independent on purpose.
- **Camera math** — `Map/CameraController.swift` (returns a neutral `CameraPose`;
  renderers translate it to their camera type).
- **Vehicle art** — `DesignSystem/BalloonMark.swift`, rasterised by
  `Map/VehicleMarkerRenderer.swift`.
- **All Features/, DesignSystem/, the rest of Models/ and Services/.**

The Focus Session view binds to the view model and asks for `vm.mapData`; it
does not know or care which provider draws it.

---

## What to replace during migration

1. **Implement `AppleJourneyMapView`** (`Map/AppleJourneyMapView.swift`).
   A SwiftUI `Map` sketch is already in that file as comments. It must:
   - draw the full route using `MapRouteRenderer.routePoints(from:to:)`,
   - draw the travelled portion using
     `MapRouteRenderer.traveledPoints(from:to:)`,
   - place a `BalloonMark` annotation at `data.vehicle`,
   - frame/follow using `CameraController` (translate `CameraPose.zoom` to a
     MapKit camera `distance`),
   - style with `.mapStyle(.standard(... pointsOfInterest: .excludingAll))`.

2. **Flip the switch** in `Map/JourneyMapView.swift`. Either:
   - replace the `#if canImport(GoogleMaps)` branch with
     `AppleJourneyMapView(data:)`, or
   - introduce a small runtime/`MapProvider` switch and select Apple.

3. **Remove the Google package** (optional) and delete
   `Map/GoogleJourneyMapView.swift` + `Map/MapStyles.swift` (Google-specific
   style JSON). `Map/MapConfiguration.swift`'s Google key becomes unused.

4. **Remove `GMSServices.provideAPIKey`** from `App/FocusGlobeApp.swift` (it is
   already guarded by `#if canImport(GoogleMaps)`).

That's the entire surface area. No journey, timer, reward, route, persistence,
analytics, design-system or navigation code changes.

---

## Why this works

- One coordinate type (`GeoCoordinate`) everywhere; SDK types never leak.
- One data contract (`JourneyMapData`) consumed identically by all renderers.
- Geometry and camera math live outside the renderers and are reused by them.
- The renderer is the *only* SDK-aware unit, and it's a single file behind a
  single compile-time switch.
