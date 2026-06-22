import MapKit
import UIKit

/// Builds and styles the Apple Maps overlays (route lines, air trail, origin
/// halo, radar rings). Overlays are tagged via `MKShape.title` so the map's
/// `rendererFor` can colour them per the route theme.
///
/// MapKit limitation: `MKPolylineRenderer` has no per-segment gradient, so the
/// air trail is a single translucent white line (the closest native equivalent
/// to Google's fading trail). See APPLE_MAPS_MIGRATION.md.
enum AppleMapRouteRenderer {

    enum Tag {
        static let routeGlow = "fg.routeGlow"   // soft wide halo under the route
        static let routeCore = "fg.routeCore"   // bright accent core (selection)
        static let routeSoft = "fg.routeSoft"   // faint full route (active flight)
        static let trail     = "fg.trail"       // white air trail behind the balloon
        static let halo      = "fg.halo"        // origin halo
        static let ring      = "fg.ring"        // radar rings (Choose Journey)
    }

    /// A geodesic (great-circle) line — elegantly arced for long routes.
    static func geodesicRoute(from o: GeoCoordinate, to d: GeoCoordinate, tag: String) -> MKGeodesicPolyline {
        var coords = [o.cl, d.cl]
        let line = MKGeodesicPolyline(coordinates: &coords, count: 2)
        line.title = tag
        return line
    }

    /// A short sampled trail polyline (just behind the balloon).
    static func trail(points: [GeoCoordinate]) -> MKPolyline {
        var coords = points.map { $0.cl }
        let line = MKPolyline(coordinates: &coords, count: coords.count)
        line.title = Tag.trail
        return line
    }

    static func circle(center: GeoCoordinate, radiusMeters: CLLocationDistance, tag: String) -> MKCircle {
        let c = MKCircle(center: center.cl, radius: radiusMeters)
        c.title = tag
        return c
    }

    /// The renderer for an overlay, themed by the route's accent / soft colours.
    static func renderer(for overlay: MKOverlay, accent: UIColor, soft: UIColor) -> MKOverlayRenderer {
        if let circle = overlay as? MKCircle {
            let r = MKCircleRenderer(circle: circle)
            switch circle.title {
            case Tag.halo:
                r.fillColor = soft.withAlphaComponent(0.18)
                r.strokeColor = accent.withAlphaComponent(0.55)
                r.lineWidth = 2
            default: // radar rings
                r.fillColor = .clear
                r.strokeColor = accent.withAlphaComponent(0.30)
                r.lineWidth = 1.4
            }
            return r
        }
        if let line = overlay as? MKPolyline {   // also matches MKGeodesicPolyline
            let r = MKPolylineRenderer(polyline: line)
            r.lineCap = .round
            r.lineJoin = .round
            switch line.title {
            case Tag.routeGlow: r.strokeColor = soft.withAlphaComponent(0.20); r.lineWidth = 12
            case Tag.routeCore: r.strokeColor = accent;                         r.lineWidth = 4
            case Tag.routeSoft: r.strokeColor = soft.withAlphaComponent(0.55);  r.lineWidth = 5
            case Tag.trail:     r.strokeColor = UIColor.white.withAlphaComponent(0.30); r.lineWidth = 6
            default:            r.strokeColor = soft.withAlphaComponent(0.5);    r.lineWidth = 4
            }
            return r
        }
        return MKOverlayRenderer(overlay: overlay)
    }
}
