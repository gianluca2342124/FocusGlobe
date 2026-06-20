import Foundation

/// A concrete journey: a real destination city paired with the route generated
/// from the current origin coordinate. Distance is the real great-circle
/// distance; duration is derived from distance + category (always plausible).
struct PlannedJourney: Identifiable, Hashable {
    let city: CityEntry
    let route: Route

    var id: String { route.id }
    var distanceKm: Double { route.approximateDistanceKm }
    var durationMinutes: Int { route.durationMinutes }
    var category: RouteCategory { route.category }
    var isPremium: Bool { route.isPremium }

    var name: String { city.city.name }
    var code: String { city.city.code }
    var mood: RouteMood { city.city.mood }
    var theme: RouteTheme { city.city.theme }
    var landmark: Landmark { city.city.landmark }
    var subtitle: String { city.city.region ?? city.country }
}

/// Generates journeys from the **current origin coordinate** to real nearby
/// cities (no hubs, no fixed routes, no generated names). Every city in the
/// catalog is eligible. Short = free nearby (≈30–35 min); Deep/Long/Ultra are
/// premium, with duration that scales with real distance.
enum JourneyPlanner {

    // MARK: Bands

    static func isPremium(_ category: RouteCategory) -> Bool { category != .short }

    /// Plausible focus duration derived **continuously** from real distance
    /// (independent of category, so nearby trips read consistently): ~30–35 min
    /// up to 45 km, scaling up to ~12 h for the longest journeys. A 300 km trip
    /// is never 30 min; an 8,000 km trip is never 30 min.
    static func duration(forKm km: Double) -> Int {
        let raw: Double
        switch km {
        case ..<45:   raw = 30 + km / 45 * 5                          // 30–35
        case ..<180:  raw = 35 + (km - 45) / 135 * 85                 // 35–120
        case ..<900:  raw = 120 + (km - 180) / 720 * 240              // 120–360
        default:      raw = 360 + min(1, (km - 900) / 15000) * 360    // 360–720
        }
        return max(30, Int((raw / 5).rounded() * 5))
    }

    static func sound(for mood: RouteMood) -> String {
        switch mood {
        case .ocean:                     return "ocean_calm"
        case .aurora:                    return "aurora_calm"
        case .mountains, .calm, .clouds: return "wind_soft"
        default:                         return "cabin_soft"
        }
    }

    // MARK: Journey generation

    private static func route(from origin: JourneyOrigin, to entry: CityEntry,
                              km: Double, category: RouteCategory) -> Route {
        let city = entry.city
        return Route(
            id: entry.id,
            name: city.name,
            shortName: city.name,
            originName: origin.city,
            destinationName: city.name,
            originLatitude: origin.coordinate.latitude,
            originLongitude: origin.coordinate.longitude,
            destinationLatitude: city.latitude,
            destinationLongitude: city.longitude,
            durationMinutes: duration(forKm: km),
            approximateDistanceKm: km,
            category: category,
            mood: city.mood,
            rewardName: city.name,
            isPremium: isPremium(category),
            colorTheme: city.theme,
            ambientSoundName: sound(for: city.mood),
            displayCode: city.code,
            landmark: city.landmark
        )
    }

    private static func make(_ origin: JourneyOrigin, _ pair: (entry: CityEntry, km: Double),
                             _ category: RouteCategory) -> PlannedJourney {
        PlannedJourney(city: pair.entry,
                       route: route(from: origin, to: pair.entry, km: pair.km, category: category))
    }

    /// All journeys from `origin`, grouped by category. Short is the nearest
    /// ~8–10 real cities (expanding 45→60→80→120 km to find enough); everything
    /// else is premium Deep/Long/Ultra by real distance. Deterministic order.
    static func plan(from origin: JourneyOrigin) -> [PlannedJourney] {
        let ranked = WorldCityCatalog.sortedByDistance(from: origin.coordinate)
        guard !ranked.isEmpty else { return [] }

        // Short (free): all real towns within 45 km — so every nearby place is
        // free and step-by-step regional travel works. If fewer than 8 exist,
        // expand to 60 then 80 km. Capped at 20 for a tidy strip. Genuinely far
        // cities stay premium (Deep/Long/Ultra).
        var short = ranked.filter { $0.km <= 45 }
        if short.count < 8 { short = ranked.filter { $0.km <= 60 } }
        if short.count < 8 { short = ranked.filter { $0.km <= 80 } }
        short = Array(short.prefix(20))
        let shortIDs = Set(short.map { $0.entry.id })
        let rest = ranked.filter { !shortIDs.contains($0.entry.id) }

        let deep = Array(rest.filter { $0.km < 180 }.prefix(16))
        let long = Array(rest.filter { (180..<900).contains($0.km) }.prefix(16))
        let ultra = Array(rest.filter { $0.km >= 900 }.prefix(12))

        return short.map { make(origin, $0, .short) }
            + deep.map { make(origin, $0, .deep) }
            + long.map { make(origin, $0, .long) }
            + ultra.map { make(origin, $0, .ultra) }
    }

    /// Journeys from `origin` filtered to one category chip (`nil` = all).
    static func plan(from origin: JourneyOrigin, category: RouteCategory?) -> [PlannedJourney] {
        let all = plan(from: origin)
        guard let category else { return all }
        return all.filter { $0.category == category }
    }

    /// A calm default recommendation: the nearest free journey.
    static func recommended(from origin: JourneyOrigin) -> PlannedJourney? {
        plan(from: origin, category: .short).first ?? plan(from: origin).first
    }
}
