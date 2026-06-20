import Foundation

/// A real city from the bundled world catalog (decoded from WorldCities.json).
struct WorldCity: Codable, Hashable, Identifiable {
    let name: String
    let code: String
    let latitude: Double
    let longitude: Double

    var id: String { "\(name)|\(code)" }
    var coordinate: GeoCoordinate { GeoCoordinate(latitude: latitude, longitude: longitude) }
}

/// A country grouping in the world catalog.
struct WorldCountry: Codable, Identifiable, Hashable {
    let country: String
    let countryCode: String
    let cities: [WorldCity]

    var id: String { countryCode }
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
