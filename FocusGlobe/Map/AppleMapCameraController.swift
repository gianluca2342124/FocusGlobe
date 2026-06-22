import CoreLocation
import MapKit

/// Camera math for the Apple Maps (MapKit) renderers. Provider-specific (it
/// returns MapKit camera distances/regions), but it mirrors the calm, cinematic
/// intent of the provider-independent `CameraController` used by Google.
enum AppleMapCameraController {

    /// Follow-camera altitude (metres) from the route span. Close and low so the
    /// balloon drifts over real neighbourhoods — never too close, never sluggish.
    static func followDistance(forRouteKm km: Double) -> CLLocationDistance {
        switch km {
        case ..<120:  return 9_500
        case ..<600:  return 13_000
        default:      return 17_000
        }
    }

    /// A pulled-back start altitude for the take-off. We centre on the balloon at
    /// this distance, then zoom IN to `followDistance` — both poses share the same
    /// centre (no lateral fly), so Short…Ultra take off equally fast.
    static func takeoffStartDistance(forRouteKm km: Double) -> CLLocationDistance {
        followDistance(forRouteKm: km) * 3.0
    }

    /// Longitude span (degrees) for a Google-style zoom level at a given view
    /// width, matching Google's 256-pt web-mercator tile model so the Apple map
    /// frames the same area (i.e. doesn't feel too close). Used by backdrops.
    static func longitudeDelta(forZoom zoom: Double, viewWidthPoints: Double) -> CLLocationDegrees {
        let width = max(1.0, viewWidthPoints)
        return min(300.0, 360.0 / pow(2.0, zoom) * (width / 256.0))
    }

    /// The map rect that tightly bounds two coordinates (origin → destination),
    /// used to frame a whole route via `setVisibleMapRect(_:edgePadding:)`.
    static func boundingRect(_ a: GeoCoordinate, _ b: GeoCoordinate) -> MKMapRect {
        let p1 = MKMapPoint(a.cl)
        let p2 = MKMapPoint(b.cl)
        let rect = MKMapRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y),
                             width: abs(p1.x - p2.x), height: abs(p1.y - p2.y))
        // Guard against a zero-size rect (identical points).
        if rect.size.width < 1 || rect.size.height < 1 {
            return MKMapRect(origin: MKMapPoint(a.cl), size: MKMapSize(width: 1, height: 1))
        }
        return rect
    }
}

extension GeoCoordinate {
    /// Bridge to the MapKit/CoreLocation coordinate type.
    var cl: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
