import Foundation

/// A curated, recognizable place the user can drift to. Destinations are
/// intrinsic (they don't know the origin); the actual journey — distance,
/// duration, category, premium tier — is computed at runtime by `JourneyPlanner`
/// from `currentOrigin → destination`.
struct Destination: Identifiable, Hashable {
    let id: String
    let city: String
    let country: String
    let latitude: Double
    let longitude: Double
    /// Airport-style display code for tags & the boarding pass (e.g. "KYO").
    let code: String
    let mood: RouteMood
    let theme: RouteTheme
    let landmark: Landmark
    /// Postcard / reward name.
    let reward: String

    init(id: String, city: String, country: String,
         lat: Double, lon: Double, code: String,
         mood: RouteMood, theme: RouteTheme, landmark: Landmark,
         reward: String? = nil) {
        self.id = id
        self.city = city
        self.country = country
        self.latitude = lat
        self.longitude = lon
        self.code = code
        self.mood = mood
        self.theme = theme
        self.landmark = landmark
        self.reward = reward ?? city
    }

    var coordinate: GeoCoordinate { GeoCoordinate(latitude: latitude, longitude: longitude) }
}
