import Foundation

/// The journey's starting point — the user's real current location (or a calm
/// default when location is unavailable). Journeys are always
/// `currentOrigin → selectedDestination`, so origin is never baked into a route.
struct JourneyOrigin: Equatable, Hashable {
    var cityName: String
    var code: String
    var coordinate: GeoCoordinate

    /// A graceful default when location permission isn't granted yet.
    static let `default` = JourneyOrigin(
        cityName: "Barcelona",
        code: "BCN",
        coordinate: GeoCoordinate(latitude: 41.3874, longitude: 2.1686)
    )

    /// An airport-style 3-letter code derived from a city name.
    static func code(for city: String) -> String {
        let letters = city.uppercased().filter { $0.isLetter }
        return letters.isEmpty ? "YOU" : String(letters.prefix(3))
    }
}
