import Foundation

/// A provider-independent camera pose. Renderers translate this into their own
/// camera type (e.g. `GMSCameraPosition` or `MKMapCamera`).
struct CameraPose: Equatable {
    var target: GeoCoordinate
    var zoom: Double
}

/// Computes calm, provider-independent camera behaviour. The goal is a gentle
/// follow — never jumpy — so this picks a stable zoom for the whole journey and
/// keeps the vehicle centred.
enum CameraController {

    /// A comfortable zoom level (Google-style 1–21) for a route of this span.
    static func zoom(forDistanceKm km: Double) -> Double {
        switch km {
        case ..<30:    return 10.0
        case ..<80:    return 9.0
        case ..<200:   return 8.0
        case ..<600:   return 6.8
        case ..<1500:  return 5.6
        case ..<4000:  return 4.6
        case ..<8000:  return 3.7
        default:       return 3.0
        }
    }

    /// The pose used while following the vehicle.
    static func followPose(for data: JourneyMapData) -> CameraPose {
        CameraPose(target: data.vehicle, zoom: zoom(forDistanceKm: data.routeDistanceKm))
    }
}
