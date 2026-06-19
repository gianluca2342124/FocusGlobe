import Foundation

/// A concrete journey the user can take right now: a `destination` paired with
/// the `route` generated from the current origin (distance, duration, category
/// and premium tier all computed from real coordinates).
struct PlannedJourney: Identifiable, Hashable {
    let destination: Destination
    let route: Route
    var id: String { destination.id }
    var distanceKm: Double { route.approximateDistanceKm }
    var durationMinutes: Int { route.durationMinutes }
    var category: RouteCategory { route.category }
    var isPremium: Bool { route.isPremium }
}

/// Turns `currentOrigin → destination` into a plausible journey.
///
/// Distance is the real great-circle distance. Duration is derived from
/// distance *bands* (never hardcoded), so a far city is never a 30-minute hop.
/// Journeys remain 30 minutes minimum. Long/Ultra journeys are premium by
/// default; nearby journeys are free.
enum JourneyPlanner {

    // MARK: Bands

    /// Duration in minutes from distance, rounded to 5, min 30.
    static func durationMinutes(forKm km: Double) -> Int {
        let raw: Double
        switch km {
        case ..<80:    raw = 30 + (km / 80) * 5                          // 30–35 (nearby)
        case ..<250:   raw = 45 + ((km - 80) / 170) * 15                 // 45–60 (regional)
        case ..<800:   raw = 90 + ((km - 250) / 550) * 30                // 90–120 (deep)
        case ..<2500:  raw = 120 + ((km - 800) / 1700) * 120             // 120–240 (long)
        default:       raw = 240 + min(1, (km - 2500) / 15000) * 480     // 240–720 (ultra)
        }
        return max(30, Int((raw / 5).rounded() * 5))
    }

    static func category(forKm km: Double) -> RouteCategory {
        switch km {
        case ..<250:   return .short
        case ..<800:   return .deep
        case ..<2500:  return .long
        default:       return .ultra
        }
    }

    /// Long & Ultra journeys (> 800 km) are premium; nearby journeys are free.
    static func isPremium(forKm km: Double) -> Bool { km >= 800 }

    /// Ambient audio for a mood (kept here so destinations stay declarative).
    static func sound(for mood: RouteMood) -> String {
        switch mood {
        case .ocean:                   return "ocean_calm"
        case .aurora:                  return "aurora_calm"
        case .mountains, .calm, .clouds: return "wind_soft"
        default:                       return "cabin_soft"
        }
    }

    // MARK: Journey generation

    static func route(from origin: JourneyOrigin, to dest: Destination) -> Route {
        let km = GeoMath.distanceKm(from: origin.coordinate, to: dest.coordinate)
        return Route(
            id: dest.id,
            name: dest.city,
            shortName: dest.city,
            originName: origin.city,
            destinationName: dest.city,
            originLatitude: origin.coordinate.latitude,
            originLongitude: origin.coordinate.longitude,
            destinationLatitude: dest.latitude,
            destinationLongitude: dest.longitude,
            durationMinutes: durationMinutes(forKm: km),
            approximateDistanceKm: km,
            category: category(forKm: km),
            mood: dest.mood,
            rewardName: dest.reward,
            isPremium: isPremium(forKm: km),
            colorTheme: dest.theme,
            ambientSoundName: sound(for: dest.mood),
            displayCode: dest.code
        )
    }

    /// All destinations reachable from `origin`, nearest first, excluding
    /// same-city (< 10 km) results.
    static func plan(from origin: JourneyOrigin) -> [PlannedJourney] {
        DestinationCatalog.all
            .map { PlannedJourney(destination: $0, route: route(from: origin, to: $0)) }
            .filter { $0.distanceKm >= 10 }
            .sorted { $0.distanceKm < $1.distanceKm }
    }

    /// Destinations filtered to a single category (chip). If none match, the
    /// caller simply shows fewer options — never fabricated ones.
    static func plan(from origin: JourneyOrigin, category: RouteCategory?) -> [PlannedJourney] {
        let all = plan(from: origin)
        guard let category else { return all }
        return all.filter { $0.category == category }
    }

    /// A calm default recommendation: the nearest free journey (or the nearest
    /// overall if everything close is premium).
    static func recommended(for origin: JourneyOrigin) -> PlannedJourney? {
        let all = plan(from: origin)
        return all.first { !$0.isPremium } ?? all.first
    }
}
