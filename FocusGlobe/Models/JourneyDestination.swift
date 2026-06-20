import Foundation

/// A real, curated destination reachable from an origin hub. The focus duration
/// is a *curated* session length mapped to a journey fantasy (not literal travel
/// time), but it is always plausible and consistent: Short = 30–35 min (free),
/// everything longer is premium.
struct JourneyDestination: Identifiable, Hashable {
    let id: String
    let name: String
    let displayCode: String
    let latitude: Double
    let longitude: Double
    let category: RouteCategory
    let focusDurationMinutes: Int
    let mood: RouteMood
    let theme: RouteTheme
    let landmark: Landmark
    let rewardName: String
    let subtitle: String

    /// Anything beyond the free Short band is premium.
    var isPremium: Bool { category != .short }
    var coordinate: GeoCoordinate { GeoCoordinate(latitude: latitude, longitude: longitude) }

    init(name: String, code: String, lat: Double, lon: Double,
         category: RouteCategory, minutes: Int, mood: RouteMood, theme: RouteTheme,
         landmark: Landmark, subtitle: String, reward: String? = nil) {
        self.id = JourneyDestination.slug(name)
        self.name = name
        self.displayCode = code
        self.latitude = lat
        self.longitude = lon
        self.category = category
        self.focusDurationMinutes = minutes
        self.mood = mood
        self.theme = theme
        self.landmark = landmark
        self.rewardName = reward ?? name
        self.subtitle = subtitle
    }

    /// A stable, ascii id from a place name (e.g. "Vilanova i la Geltrú" →
    /// "vilanova-i-la-geltru"). Shared names across hubs collapse to one id by
    /// design (a place is a place).
    static func slug(_ s: String) -> String {
        let folded = s.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US"))
        let mapped = folded.map { ch -> Character in (ch.isLetter || ch.isNumber) ? ch : "-" }
        return String(String(mapped).split(separator: "-").joined(separator: "-"))
    }
}
