import SwiftUI

/// A non-interactive map preview of a route, with the balloon placed mid-journey
/// for a balanced "hero" composition. Reuses the same provider-independent
/// `JourneyMapView`, so the preview matches the live session visually.
struct RoutePreviewMap: View {
    let route: Route
    var progress: Double = 0.4

    var body: some View {
        JourneyMapView(data: JourneyMapData(
            origin: route.origin,
            destination: route.destination,
            vehicle: GeoMath.interpolate(from: route.origin, to: route.destination, fraction: progress),
            progress: progress,
            bearingDegrees: GeoMath.bearingDegrees(from: route.origin, to: route.destination),
            mood: route.mood,
            theme: route.colorTheme,
            followsVehicle: true,
            isMoving: false
        ))
        .allowsHitTesting(false)
    }
}
