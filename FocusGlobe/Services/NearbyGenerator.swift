import Foundation

/// Generates the **free, nearby** destination set around any origin so every
/// user — anywhere in the world — gets ~10 believable 30–35 minute journeys.
///
/// These are curated *scenic archetypes* (coast, hills, old town, lakeside…)
/// scattered at short distances and varied bearings around the origin. They feel
/// like desirable local getaways without claiming to be specific famous cities,
/// so the geography is always plausible. Famous catalog cities remain premium.
enum NearbyGenerator {

    private struct Archetype {
        let name: String
        let code: String
        let mood: RouteMood
        let theme: RouteTheme
        let landmark: Landmark
    }

    /// 12 archetypes → 10 distinct picks per origin (rotated by the origin).
    private static let archetypes: [Archetype] = [
        Archetype(name: "Old Town",          code: "OLD", mood: .sunset,    theme: .gold,     landmark: .skyline),
        Archetype(name: "Coastal Cliffs",    code: "COA", mood: .ocean,     theme: .teal,     landmark: .coastline),
        Archetype(name: "Harbour Bay",       code: "HBR", mood: .ocean,     theme: .indigo,   landmark: .bridge),
        Archetype(name: "Hillside Village",  code: "HIL", mood: .mountains, theme: .mint,     landmark: .mountain),
        Archetype(name: "Sunrise Ridge",     code: "RDG", mood: .sunrise,   theme: .coral,    landmark: .mountain),
        Archetype(name: "Pinewood Trail",    code: "PIN", mood: .calm,      theme: .mint,     landmark: .forest),
        Archetype(name: "Lakeside Calm",     code: "LAK", mood: .calm,      theme: .teal,     landmark: .coastline),
        Archetype(name: "Vineyard Hills",    code: "VIN", mood: .sunset,    theme: .blush,    landmark: .forest),
        Archetype(name: "Lighthouse Point",  code: "LHT", mood: .ocean,     theme: .slate,    landmark: .coastline),
        Archetype(name: "Meadowlands",       code: "MDW", mood: .calm,      theme: .mint,     landmark: .generic),
        Archetype(name: "Riverside",         code: "RVR", mood: .calm,      theme: .indigo,   landmark: .bridge),
        Archetype(name: "Cliffside Lookout", code: "CLF", mood: .sunset,    theme: .coral,    landmark: .coastline),
    ]

    static let count = 10

    /// ~10 nearby short destinations (≈22–76 km → 30–35 min), deterministic per
    /// origin so the set is stable across launches.
    static func nearby(for origin: JourneyOrigin) -> [Destination] {
        let seed = abs(Int((origin.coordinate.latitude * 1000).rounded())
                       &+ Int((origin.coordinate.longitude * 1000).rounded()))
        let start = seed % archetypes.count

        return (0..<count).map { i in
            let arche = archetypes[(start + i) % archetypes.count]
            let distanceKm = 22.0 + Double(i) * 6.0                // 22 … 76 km
            let bearing = Double((seed &* 37 &+ i * (360 / count)) % 360)
            let coord = GeoMath.destinationPoint(from: origin.coordinate,
                                                 distanceKm: distanceKm,
                                                 bearingDegrees: bearing)
            return Destination(
                id: "nearby-\(origin.code)-\(arche.code)",
                city: arche.name,
                country: "Near \(origin.city)",
                lat: coord.latitude, lon: coord.longitude,
                code: arche.code,
                mood: arche.mood, theme: arche.theme, landmark: arche.landmark,
                reward: "\(arche.name) Drift"
            )
        }
    }
}
