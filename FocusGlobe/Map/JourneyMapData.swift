import Foundation

/// Everything the map layer needs to render a journey — and nothing it doesn't.
///
/// This is the contract between the (provider-independent) session logic and
/// any map renderer. It contains only plain data: no SDK types, no view models.
/// The Google, Apple and fallback renderers all consume this identical struct,
/// which is why swapping providers never touches business logic.
struct JourneyMapData: Equatable {
    var origin: GeoCoordinate
    var destination: GeoCoordinate
    var vehicle: GeoCoordinate
    var progress: Double
    var bearingDegrees: Double
    var mood: RouteMood
    var theme: RouteTheme
    /// Whether the camera should gently track the vehicle.
    var followsVehicle: Bool
    /// `true` while the journey is actively moving (not paused).
    var isMoving: Bool
    /// Map presentation (Dark / Standard / Satellite / Hybrid …).
    var style: MapDisplayStyle = .graphite
    /// How the camera frames the journey (follow the balloon vs. full route).
    var cameraMode: JourneyCameraMode = .follow
    /// A gentle 3D tilt of the follow camera (where supported).
    var tilted: Bool = false
    /// Bumped by the session to ask the renderer to (re)apply the camera now —
    /// e.g. after Recenter / Full Route / Tilt taps.
    var cameraToken: Int = 0

    /// The straight-line span of the route, used to pick a sensible zoom.
    var routeDistanceKm: Double {
        GeoMath.distanceKm(from: origin, to: destination)
    }
}

/// How the live camera frames the journey.
enum JourneyCameraMode: Equatable {
    /// Gently track the balloon (Google-Maps-navigation feel, but calm).
    case follow
    /// Pull back to frame the whole route (origin → destination).
    case overview
}
