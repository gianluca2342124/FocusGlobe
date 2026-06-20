import Foundation

/// A concrete journey the user can take now: a curated `destination` paired with
/// the `route` generated from the current origin. Distance is the real
/// great-circle distance (for display); duration/category/premium come from the
/// curated destination (never distance-derived, so durations stay plausible).
struct PlannedJourney: Identifiable, Hashable {
    let destination: JourneyDestination
    let route: Route
    var id: String { destination.id }
    var distanceKm: Double { route.approximateDistanceKm }
    var durationMinutes: Int { destination.focusDurationMinutes }
    var category: RouteCategory { destination.category }
    var isPremium: Bool { destination.isPremium }
}

/// Turns `currentOrigin → curated destination` into a journey. The origin is the
/// user's real location; destinations come from the matched `OriginHub`.
enum JourneyPlanner {

    /// Ambient audio for a mood (kept here so destinations stay declarative).
    static func sound(for mood: RouteMood) -> String {
        switch mood {
        case .ocean:                     return "ocean_calm"
        case .aurora:                    return "aurora_calm"
        case .mountains, .calm, .clouds: return "wind_soft"
        default:                         return "cabin_soft"
        }
    }

    static func route(from origin: JourneyOrigin, to dest: JourneyDestination) -> Route {
        let km = GeoMath.distanceKm(from: origin.coordinate, to: dest.coordinate)
        return Route(
            id: dest.id,
            name: dest.name,
            shortName: dest.name,
            originName: origin.city,
            destinationName: dest.name,
            originLatitude: origin.coordinate.latitude,
            originLongitude: origin.coordinate.longitude,
            destinationLatitude: dest.latitude,
            destinationLongitude: dest.longitude,
            durationMinutes: dest.focusDurationMinutes,
            approximateDistanceKm: km,
            category: dest.category,
            mood: dest.mood,
            rewardName: dest.rewardName,
            isPremium: dest.isPremium,
            colorTheme: dest.theme,
            ambientSoundName: sound(for: dest.mood),
            displayCode: dest.displayCode,
            landmark: dest.landmark
        )
    }

    /// Journeys from `origin` using the matched `hub`, free Short set first.
    /// Destinations within ~5 km of the origin are skipped (you're already there
    /// — e.g. after landing in Castelldefels, it won't offer Castelldefels).
    static func plan(hub: OriginHub, origin: JourneyOrigin, category: RouteCategory?) -> [PlannedJourney] {
        hub.allDestinations
            .filter { category == nil || $0.category == category }
            .map { PlannedJourney(destination: $0, route: route(from: origin, to: $0)) }
            .filter { $0.distanceKm >= 5 }
            .sorted { lhs, rhs in
                if lhs.isPremium != rhs.isPremium { return !lhs.isPremium } // free first
                return lhs.durationMinutes < rhs.durationMinutes
            }
    }

    /// A calm default recommendation: the first free nearby journey.
    static func recommended(hub: OriginHub, origin: JourneyOrigin) -> PlannedJourney? {
        plan(hub: hub, origin: origin, category: .short).first
            ?? plan(hub: hub, origin: origin, category: nil).first
    }
}
