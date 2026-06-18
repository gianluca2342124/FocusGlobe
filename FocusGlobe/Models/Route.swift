import Foundation

/// A curated, local focus route — an aerial balloon journey between two real
/// coordinates. Routes are fully local and never fetched from a network or a
/// paid routing API; the path is a simulated geodesic line between the two
/// points.
struct Route: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let shortName: String

    let originName: String
    let destinationName: String

    let originLatitude: Double
    let originLongitude: Double
    let destinationLatitude: Double
    let destinationLongitude: Double

    let durationMinutes: Int
    let approximateDistanceKm: Double

    let category: RouteCategory
    let mood: RouteMood
    let rewardName: String
    let isPremium: Bool
    let colorTheme: RouteTheme
    let ambientSoundName: String

    // MARK: - Derived, provider-independent helpers

    var origin: GeoCoordinate {
        GeoCoordinate(latitude: originLatitude, longitude: originLongitude)
    }

    var destination: GeoCoordinate {
        GeoCoordinate(latitude: destinationLatitude, longitude: destinationLongitude)
    }

    /// Total focus duration as a time interval.
    var duration: TimeInterval { TimeInterval(durationMinutes * 60) }

    /// Focus miles awarded for completing the full route. Themed as "miles",
    /// scaled to the route distance so longer focus = more reward.
    var focusMilesReward: Int { Int(approximateDistanceKm.rounded()) }

    var durationLabel: String { Formatters.durationLabel(minutes: durationMinutes) }
    var distanceLabel: String { Formatters.distance(km: approximateDistanceKm) }
}
