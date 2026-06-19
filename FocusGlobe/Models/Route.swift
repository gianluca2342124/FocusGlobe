import Foundation

/// A curated focus **destination** — an aspirational, recognizable place the
/// user drifts to by balloon. The journey always begins at the user's real
/// current location (`JourneyOrigin`), so the `origin*` fields below are no
/// longer the journey's start; they're kept only as authored metadata and for
/// backward-compatible decoding. Nothing here is fetched from a network or a
/// paid routing API; the path is a simulated geodesic line.
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

    /// Curated airport-style code from the destination catalog (e.g. "KYO").
    /// Falls back to a code derived from `shortName` when empty.
    var displayCode: String = ""

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

    /// Airport-style 3-letter destination code (curated when available). The
    /// origin code now comes from `JourneyOrigin`.
    var destinationCode: String { displayCode.isEmpty ? Route.code(shortName) : displayCode }

    static func code(_ name: String) -> String {
        let letters = name.uppercased().filter { $0.isLetter }
        return letters.isEmpty ? "FLY" : String(letters.prefix(3))
    }
}
