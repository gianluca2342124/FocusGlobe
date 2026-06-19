import SwiftUI

/// A non-interactive map preview of a route, with the balloon placed mid-journey
/// for a balanced "hero" composition.
///
/// Design decision: previews intentionally use the lightweight **stylised**
/// renderer (`FallbackJourneyMapView`) rather than a live Google map. This keeps
/// Home / Route Selection cheap (no stacked `GMSMapView`s), gives consistent,
/// screenshot-friendly heroes regardless of whether the Google SDK is linked,
/// and reserves the immersive live Google map for the Focus Session — where it
/// matters most. (To make previews use the live provider, swap this for
/// `JourneyMapView(data:)`.)
struct RoutePreviewMap: View {
    let route: Route
    var progress: Double = 0.4

    private var data: JourneyMapData {
        JourneyMapData(
            origin: route.origin,
            destination: route.destination,
            vehicle: GeoMath.interpolate(from: route.origin, to: route.destination, fraction: progress),
            progress: progress,
            bearingDegrees: GeoMath.bearingDegrees(from: route.origin, to: route.destination),
            mood: route.mood,
            theme: route.colorTheme,
            followsVehicle: false,
            isMoving: false
        )
    }

    var body: some View {
        FallbackJourneyMapView(data: data)
            .allowsHitTesting(false)
    }
}
