import Foundation

/// A concrete journey: a curated journey-worthy `node` paired with the route
/// generated from the current origin coordinate. Distance is the real
/// great-circle distance; duration is a flight-style focus length.
struct PlannedJourney: Identifiable, Hashable {
    let node: JourneyDestinationNode
    let route: Route

    var id: String { route.id }
    var distanceKm: Double { route.approximateDistanceKm }
    var durationMinutes: Int { route.durationMinutes }
    var category: RouteCategory { route.category }
    var isPremium: Bool { route.isPremium }

    var name: String { node.name }
    var code: String { node.code }
    var mood: RouteMood { node.mood }
    var theme: RouteTheme { node.theme }
    var landmark: Landmark { node.landmark }
    var subtitle: String { node.region ?? node.country }
}

/// The flight-style destination engine. From the current origin coordinate it
/// selects **journey-worthy** destinations from the curated travel network
/// (never arbitrary nearest suburbs), scores them, and assigns a scenic-flight
/// duration. Free journeys are under 1 h; premium journeys are 1 h+.
enum JourneyPlanner {

    /// Scenic-flight duration from real distance (minute precision, not rounded
    /// to 5): ~30–35 min up to ~100 km, scaling up to ~12 h long-haul.
    /// 300 km is never 30 min; 8,000 km is never 30 min.
    static func duration(forKm km: Double) -> Int {
        min(720, max(30, Int((km / 7.0 + 20).rounded())))
    }

    /// Free under an hour; premium at an hour or more.
    static func isPremium(minutes: Int) -> Bool { minutes >= 60 }

    static func category(forMinutes m: Int) -> RouteCategory {
        switch m {
        case ..<60:   return .short
        case ..<150:  return .deep
        case ..<360:  return .long
        default:      return .ultra
        }
    }

    static func sound(for mood: RouteMood) -> String {
        switch mood {
        case .ocean:                     return "ocean_calm"
        case .aurora:                    return "aurora_calm"
        case .mountains, .calm, .clouds: return "wind_soft"
        default:                         return "cabin_soft"
        }
    }

    /// Interest score used to rank/cap candidates so the most journey-worthy
    /// destinations surface first.
    static func score(_ node: JourneyDestinationNode) -> Double {
        var s = Double(node.tourismScore)
        if node.hasTag("island")   { s += 12 }
        if node.hasTag("capital")  { s += 10 }
        if node.hasTag("landmark") { s += 10 }
        if node.hasTag("historic") { s += 8 }
        if node.hasTag("resort")   { s += 6 }
        if node.hasTag("airport") || node.airportCode != nil { s += 6 }
        if node.hasTag("coast") || node.hasTag("mountain") || node.hasTag("lake") { s += 5 }
        if let p = node.population { s += min(15, Double(p) / 250_000) }
        s += node.premiumWeight ?? 0
        return s
    }

    // MARK: Journey generation

    private static func route(from origin: JourneyOrigin, to node: JourneyDestinationNode, km: Double) -> Route {
        let minutes = duration(forKm: km)
        return Route(
            id: node.id,
            name: node.name,
            shortName: node.name,
            originName: origin.city,
            destinationName: node.name,
            originLatitude: origin.coordinate.latitude,
            originLongitude: origin.coordinate.longitude,
            destinationLatitude: node.latitude,
            destinationLongitude: node.longitude,
            durationMinutes: minutes,
            approximateDistanceKm: km,
            category: category(forMinutes: minutes),
            mood: node.mood,
            rewardName: node.name,
            isPremium: isPremium(minutes: minutes),
            colorTheme: node.theme,
            ambientSoundName: sound(for: node.mood),
            displayCode: node.code,
            landmark: node.landmark
        )
    }

    private static func make(_ origin: JourneyOrigin, _ node: JourneyDestinationNode, _ km: Double) -> PlannedJourney {
        PlannedJourney(node: node, route: route(from: origin, to: node, km: km))
    }

    /// All journeys from `origin`, grouped by category. Excludes the origin's own
    /// city/metro (anything closer than ~18 km, or 10 km for iconic places).
    /// Within each category the most journey-worthy surface first, displayed
    /// nearest-first.
    static func plan(from origin: JourneyOrigin) -> [PlannedJourney] {
        let coord = origin.coordinate
        let candidates: [PlannedJourney] = TravelNetworkCatalog.sortedByDistance(from: coord).compactMap { pair in
            let minKm = pair.node.isIconic ? 10.0 : 18.0
            guard pair.km >= minKm else { return nil }
            return make(origin, pair.node, pair.km)
        }
        func top(_ category: RouteCategory, _ cap: Int) -> [PlannedJourney] {
            candidates
                .filter { $0.category == category }
                .sorted { score($0.node) > score($1.node) }
                .prefix(cap)
                .sorted { $0.distanceKm < $1.distanceKm }
        }
        return top(.short, 12) + top(.deep, 12) + top(.long, 12) + top(.ultra, 10)
    }

    /// Journeys from `origin` filtered to one category chip (`nil` = all).
    static func plan(from origin: JourneyOrigin, category: RouteCategory?) -> [PlannedJourney] {
        let all = plan(from: origin)
        guard let category else { return all }
        return all.filter { $0.category == category }
    }

    /// A calm default recommendation: the first free journey.
    static func recommended(from origin: JourneyOrigin) -> PlannedJourney? {
        plan(from: origin, category: .short).first ?? plan(from: origin).first
    }
}
