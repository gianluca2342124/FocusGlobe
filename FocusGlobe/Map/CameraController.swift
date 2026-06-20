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

    /// Close follow zoom so the balloon feels like it's drifting over real
    /// neighbourhoods, streets and coastlines — a premium GPS-flight feel
    /// (independent of total route length; the whole route is reachable via the
    /// "Full route" control instead).
    static func followZoom(forDistanceKm km: Double) -> Double {
        switch km {
        case ..<120:  return 15.5   // nearby: streets, beaches, hills
        case ..<600:  return 15.0
        default:      return 14.5   // far: still close, still flying low
        }
    }

    /// A comfortable zoom level (Google-style 1–21) for a route of this span.
    /// Used to *frame the whole route* (overview / previews).
    static func zoom(forDistanceKm km: Double) -> Double {
        switch km {
        case ..<30:    return 10.6
        case ..<80:    return 9.6
        case ..<200:   return 8.3
        case ..<600:   return 7.1
        case ..<1500:  return 6.0
        case ..<4000:  return 5.0
        case ..<8000:  return 4.1
        default:       return 3.3
        }
    }

    /// The pose used while following the vehicle.
    static func followPose(for data: JourneyMapData) -> CameraPose {
        CameraPose(target: data.vehicle, zoom: zoom(forDistanceKm: data.routeDistanceKm))
    }
}
