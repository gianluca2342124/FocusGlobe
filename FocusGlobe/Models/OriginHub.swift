import Foundation

/// A supported origin city with a curated set of **real** destinations. The user
/// is matched to the nearest hub; their actual city is still shown as the origin
/// label, but the destinations come from the hub. If no hub is near, the app
/// shows a clean "preparing journeys for your area" state — never fake places.
struct OriginHub: Identifiable, Hashable {
    let id: String
    let cityName: String
    let countryName: String
    let latitude: Double
    let longitude: Double
    /// Nearby place names that should also resolve to this hub (soft hints).
    let aliases: [String]
    let code: String
    let shortDestinations: [JourneyDestination]
    let premiumDestinations: [JourneyDestination]

    var coordinate: GeoCoordinate { GeoCoordinate(latitude: latitude, longitude: longitude) }
    var allDestinations: [JourneyDestination] { shortDestinations + premiumDestinations }

    var origin: JourneyOrigin {
        JourneyOrigin(city: cityName, country: countryName, coordinate: coordinate, code: code)
    }
}
