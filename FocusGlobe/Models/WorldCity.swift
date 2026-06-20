import Foundation

/// A real city from the bundled world catalog (decoded from WorldCities.json).
/// Visuals (mood/theme/landmark) are derived deterministically from the name so
/// every city has stable, varied scenery without needing per-city art data.
struct WorldCity: Codable, Hashable, Identifiable {
    let name: String
    let code: String
    let latitude: Double
    let longitude: Double
    let region: String?
    let population: Int?

    init(name: String, code: String, latitude: Double, longitude: Double,
         region: String? = nil, population: Int? = nil) {
        self.name = name
        self.code = code
        self.latitude = latitude
        self.longitude = longitude
        self.region = region
        self.population = population
    }

    var id: String { "\(name)|\(code)" }
    var coordinate: GeoCoordinate { GeoCoordinate(latitude: latitude, longitude: longitude) }

    // MARK: Deterministic visuals (stable across launches)

    private var seed: Int { (name + code).unicodeScalars.reduce(0) { $0 &+ Int($1.value) } }

    var mood: RouteMood { Self.moods[seed % Self.moods.count] }
    var theme: RouteTheme { Self.themes[(seed / 7) % Self.themes.count] }
    var landmark: Landmark { Self.landmarks[(seed / 13) % Self.landmarks.count] }

    private static let moods: [RouteMood] = [.sunset, .ocean, .calm, .city, .mountains, .sunrise, .night, .aurora]
    private static let themes: [RouteTheme] = [.teal, .gold, .indigo, .coral, .mint, .lavender, .slate, .blush]
    private static let landmarks: [Landmark] = [.coastline, .skyline, .mountain, .dome, .forest, .bridge, .island, .tower, .canyon, .pagoda]
}

/// A country grouping in the world catalog.
struct WorldCountry: Codable, Identifiable, Hashable {
    let country: String
    let countryCode: String?
    let cities: [WorldCity]

    var id: String { countryCode ?? country }
}

/// A flattened city + its country, used for search and selection.
struct CityEntry: Identifiable, Hashable {
    let city: WorldCity
    let country: String
    let countryCode: String

    var id: String { "\(countryCode)|\(city.id)" }

    var origin: JourneyOrigin {
        JourneyOrigin(city: city.name, country: country, coordinate: city.coordinate, code: city.code)
    }
}
