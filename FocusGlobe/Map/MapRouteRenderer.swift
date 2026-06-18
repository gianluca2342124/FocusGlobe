import CoreGraphics
import Foundation

/// Provider-independent route geometry. Both the Google renderer and the native
/// fallback map use these helpers, so the route line is computed identically
/// regardless of provider.
enum MapRouteRenderer {

    /// Smooth aerial route as a set of geodesic sample points.
    static func routePoints(from origin: GeoCoordinate,
                            to destination: GeoCoordinate,
                            samples: Int = 96) -> [GeoCoordinate] {
        GeoMath.sampleGeodesic(from: origin, to: destination, count: samples)
    }

    /// The portion of the route already travelled (origin → vehicle).
    static func traveledPoints(from origin: GeoCoordinate,
                               to vehicle: GeoCoordinate,
                               samples: Int = 48) -> [GeoCoordinate] {
        GeoMath.sampleGeodesic(from: origin, to: vehicle, count: samples)
    }
}

/// A simple, uniform-scale geographic projection used by the native fallback
/// map to place coordinates on screen. (The Google renderer uses the SDK's own
/// projection; this exists only so the fallback can draw without any SDK.)
struct GeoProjection {
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double
    let size: CGSize
    let inset: CGFloat

    init(coords: [GeoCoordinate], size: CGSize, inset: CGFloat = 0) {
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        // Pad the bounds so the route never hugs the edges.
        let latPad = max(0.05, (( lats.max() ?? 0) - (lats.min() ?? 0)) * 0.18)
        let lonPad = max(0.05, (( lons.max() ?? 0) - (lons.min() ?? 0)) * 0.18)
        self.minLat = (lats.min() ?? 0) - latPad
        self.maxLat = (lats.max() ?? 0) + latPad
        self.minLon = (lons.min() ?? 0) - lonPad
        self.maxLon = (lons.max() ?? 0) + lonPad
        self.size = size
        self.inset = inset
    }

    func point(for c: GeoCoordinate) -> CGPoint {
        let midLatRad = ((minLat + maxLat) / 2) * .pi / 180
        let lonScale = max(0.15, cos(midLatRad)) // compress longitude toward the poles
        let geoW = max(1e-6, (maxLon - minLon) * lonScale)
        let geoH = max(1e-6, (maxLat - minLat))

        let availW = max(1, size.width - inset * 2)
        let availH = max(1, size.height - inset * 2)
        let scale = min(availW / geoW, availH / geoH)

        let drawW = geoW * scale
        let drawH = geoH * scale
        let offsetX = inset + (availW - drawW) / 2
        let offsetY = inset + (availH - drawH) / 2

        let x = offsetX + ((c.longitude - minLon) * lonScale) * scale
        let y = offsetY + (maxLat - c.latitude) * scale
        return CGPoint(x: x, y: y)
    }
}
