import Foundation

/// A curated, **journey-worthy** travel destination (airport city, regional
/// capital, island, resort, historic town, landmark, major city…). These — not
/// arbitrary nearest municipalities — are what the journey engine offers. Loaded
/// from TravelDestinations.json so the network scales without Swift changes.
struct JourneyDestinationNode: Codable, Hashable, Identifiable {
    let name: String
    let country: String
    let region: String?
    let code: String
    let latitude: Double
    let longitude: Double
    let population: Int?
    let airportCode: String?
    let tourismScore: Int
    let tags: [String]
    let metroGroup: String?
    let premiumWeight: Double?

    var id: String { "\(code)|\(name)" }
    var coordinate: GeoCoordinate { GeoCoordinate(latitude: latitude, longitude: longitude) }

    func hasTag(_ t: String) -> Bool { tags.contains(t) }
    /// Iconic places may appear a little closer than the usual minimum.
    var isIconic: Bool { tourismScore >= 85 }

    // MARK: Deterministic, tag-aware visuals (no per-node art needed)

    private var seed: Int { (name + code).unicodeScalars.reduce(0) { $0 &+ Int($1.value) } }

    var mood: RouteMood {
        if hasTag("island") || hasTag("coast") || hasTag("resort") { return .ocean }
        if hasTag("mountain") { return .mountains }
        if hasTag("lake") { return .calm }
        if hasTag("historic") || hasTag("landmark") { return .sunset }
        if hasTag("capital") || hasTag("majorCity") { return seed % 2 == 0 ? .city : .night }
        return Self.moods[seed % Self.moods.count]
    }

    var landmark: Landmark {
        if hasTag("island") { return .island }
        if hasTag("mountain") { return .mountain }
        if hasTag("coast") || hasTag("resort") || hasTag("lake") { return .coastline }
        if hasTag("historic") || hasTag("landmark") { return .dome }
        if hasTag("capital") || hasTag("majorCity") { return .skyline }
        return Self.landmarks[seed % Self.landmarks.count]
    }

    var theme: RouteTheme { Self.themes[seed % Self.themes.count] }

    private static let moods: [RouteMood] = [.sunset, .ocean, .calm, .city, .mountains, .sunrise, .night, .aurora]
    private static let themes: [RouteTheme] = [.teal, .gold, .indigo, .coral, .mint, .lavender, .slate, .blush]
    private static let landmarks: [Landmark] = [.coastline, .skyline, .mountain, .dome, .forest, .bridge, .island, .tower]
}
