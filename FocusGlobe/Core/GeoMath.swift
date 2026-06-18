import Foundation

/// Pure geographic math, fully provider-independent.
///
/// This is deliberately separate from any map SDK so route progress, distance
/// and bearing are computed identically whether we render with Google Maps,
/// Apple Maps, or the built-in fallback map. Migrating the map provider must
/// never require touching this file.
enum GeoMath {

    private static let earthRadiusKm = 6371.0088

    // MARK: - Interpolation

    /// Interpolates a point along the **great-circle** (geodesic) path between
    /// two coordinates. `fraction` is clamped to `0...1`.
    ///
    /// Uses spherical linear interpolation (slerp). For near-identical or
    /// antipodal endpoints it degrades gracefully to a linear blend so the
    /// balloon never jumps or produces NaNs.
    static func interpolate(from start: GeoCoordinate,
                            to end: GeoCoordinate,
                            fraction: Double) -> GeoCoordinate {
        let f = min(max(fraction, 0), 1)

        let lat1 = start.latitude.toRadians
        let lon1 = start.longitude.toRadians
        let lat2 = end.latitude.toRadians
        let lon2 = end.longitude.toRadians

        // Angular distance between the two points.
        let delta = angularDistance(lat1: lat1, lon1: lon1, lat2: lat2, lon2: lon2)

        // Endpoints coincide (or are extremely close) — nothing to interpolate.
        guard delta > 1e-9 else { return start }

        let sinDelta = sin(delta)
        // Guard against the degenerate (antipodal) case where sin(delta) ≈ 0.
        guard sinDelta > 1e-9 else {
            return linearInterpolate(from: start, to: end, fraction: f)
        }

        let a = sin((1 - f) * delta) / sinDelta
        let b = sin(f * delta) / sinDelta

        let x = a * cos(lat1) * cos(lon1) + b * cos(lat2) * cos(lon2)
        let y = a * cos(lat1) * sin(lon1) + b * cos(lat2) * sin(lon2)
        let z = a * sin(lat1) + b * sin(lat2)

        let lat = atan2(z, sqrt(x * x + y * y))
        let lon = atan2(y, x)

        return GeoCoordinate(latitude: lat.toDegrees, longitude: lon.toDegrees)
    }

    /// Simple linear (rhumb-ish) interpolation. Encapsulated so callers never
    /// depend on the interpolation strategy — we can swap geodesic in/out here.
    static func linearInterpolate(from start: GeoCoordinate,
                                  to end: GeoCoordinate,
                                  fraction: Double) -> GeoCoordinate {
        let f = min(max(fraction, 0), 1)
        return GeoCoordinate(
            latitude: start.latitude + (end.latitude - start.latitude) * f,
            longitude: start.longitude + (end.longitude - start.longitude) * f
        )
    }

    // MARK: - Distance

    /// Great-circle distance in kilometres (Haversine).
    static func distanceKm(from start: GeoCoordinate, to end: GeoCoordinate) -> Double {
        let lat1 = start.latitude.toRadians
        let lon1 = start.longitude.toRadians
        let lat2 = end.latitude.toRadians
        let lon2 = end.longitude.toRadians
        return angularDistance(lat1: lat1, lon1: lon1, lat2: lat2, lon2: lon2) * earthRadiusKm
    }

    // MARK: - Bearing

    /// Initial bearing (degrees, 0 = north, clockwise) from `start` to `end`.
    static func bearingDegrees(from start: GeoCoordinate, to end: GeoCoordinate) -> Double {
        let lat1 = start.latitude.toRadians
        let lat2 = end.latitude.toRadians
        let dLon = (end.longitude - start.longitude).toRadians

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x).toDegrees
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    // MARK: - Sampling

    /// Returns `count` coordinates evenly distributed along the geodesic,
    /// inclusive of both endpoints. Used to draw a smooth aerial route line.
    static func sampleGeodesic(from start: GeoCoordinate,
                               to end: GeoCoordinate,
                               count: Int) -> [GeoCoordinate] {
        let n = max(2, count)
        return (0..<n).map { i in
            interpolate(from: start, to: end, fraction: Double(i) / Double(n - 1))
        }
    }

    // MARK: - Private

    private static func angularDistance(lat1: Double, lon1: Double,
                                        lat2: Double, lon2: Double) -> Double {
        let dLat = lat2 - lat1
        let dLon = lon2 - lon1
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * atan2(sqrt(h), sqrt(max(0, 1 - h)))
    }
}

private extension Double {
    var toRadians: Double { self * .pi / 180 }
    var toDegrees: Double { self * 180 / .pi }
}
