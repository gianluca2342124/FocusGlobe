import Foundation

/// A concrete journey: a curated journey-worthy `node` paired with the route
/// generated from the planning base. Distance is real great-circle distance;
/// duration is a flight-style focus length.
struct PlannedJourney: Identifiable, Hashable {
    let node: JourneyDestinationNode
    let route: Route
    /// `true` when this is the "back to the previous city" return trip, so the UI
    /// can mark it (return arrow + subtle accent).
    var isReturn: Bool = false

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

/// The universal, flight-style destination engine.
///
/// From any origin coordinate on Earth it returns a complete, believable set of
/// journeys (free Short + premium Deep/Long/Ultra), selecting **journey-worthy**
/// destinations from the curated travel network — never arbitrary suburbs, never
/// empty. If the origin is too sparse, it plans from the nearest strong travel
/// gateway while still labelling the journey "from <the user's city>".
///
/// Results are cached per origin (main-actor only), so planning is instant after
/// the first compute, and the catalog is decoded once (warmed at launch).
enum JourneyPlanner {

    // MARK: Duration / tier

    /// Scenic-flight duration from real distance (minute precision): ~30–34 min
    /// for 20–40 km, ~38–45 for 100–180 km, ~47–57 for 200–320 km, crossing into
    /// premium around 360 km, capped at 12 h. 300 km or 8,000 km is never 30 min.
    static func duration(forKm km: Double) -> Int {
        min(720, max(30, Int((30 + km / 12.0).rounded())))
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

    /// Interest score so the most journey-worthy destinations surface first.
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

    // MARK: Public API (cached)

    /// Plan cache, keyed by origin. Accessed on the main actor only.
    private static var cache: [String: [PlannedJourney]] = [:]

    private static func cacheKey(_ origin: JourneyOrigin) -> String {
        "\(origin.city)|\(Int((origin.coordinate.latitude * 100).rounded()))|\(Int((origin.coordinate.longitude * 100).rounded()))"
    }

    static func plan(from origin: JourneyOrigin) -> [PlannedJourney] {
        let key = cacheKey(origin)
        if let cached = cache[key] { return cached }
        let started = Date()
        let result = build(from: origin)
        cache[key] = result.journeys
        #if DEBUG
        let ms = Int(Date().timeIntervalSince(started) * 1000)
        let first = result.journeys.first
        let firstDesc = first.map { "\($0.name) \(Int($0.distanceKm))km \($0.durationMinutes)min \($0.isPremium ? "premium" : "free")" } ?? "none"
        print("[JourneyPlanner] origin=\(origin.city) base=\(result.base) source=\(result.source) nodes=\(TravelNetworkCatalog.allNodes.count) free=\(result.freeCount) premium=\(result.premiumCount) first=\(firstDesc)")
        print("[Performance] Planned journeys for \(origin.city) in \(ms) ms")
        #endif
        return result.journeys
    }

    static func plan(from origin: JourneyOrigin, category: RouteCategory?) -> [PlannedJourney] {
        let all = plan(from: origin)
        guard let category else { return all }
        return all.filter { $0.category == category }
    }

    static func recommended(from origin: JourneyOrigin) -> PlannedJourney? {
        plan(from: origin, category: .short).first ?? plan(from: origin).first
    }

    // MARK: Planning

    private struct PlanOutcome {
        let journeys: [PlannedJourney]
        let base: String
        let source: String
        var freeCount: Int { journeys.filter { !$0.isPremium }.count }
        var premiumCount: Int { journeys.filter { $0.isPremium }.count }
    }

    /// Layered coverage: plan directly from the origin; if it yields too few free
    /// journeys, plan from the nearest *rich* gateway (durations from that base),
    /// keeping the user's city as the displayed origin label.
    private static func build(from origin: JourneyOrigin) -> PlanOutcome {
        let direct = journeys(baseCoordinate: origin.coordinate, originLabel: origin.city)
        let directFree = direct.filter { !$0.isPremium }.count
        // Accept the direct plan only when the *free* set is real — a global
        // catalog always supplies plenty of far premium journeys, so total count
        // is never the right gate (that would mask sparse-nearby origins).
        if directFree >= 3 {
            return PlanOutcome(journeys: direct, base: origin.city, source: "direct")
        }
        // Sparse origin (island, remote village, desert, isolated city): plan from
        // the nearest *rich* gateway — a hub that itself has a full neighbourhood —
        // so the traveller still gets a believable free set. Their own city stays
        // the displayed origin; only the planning base moves.
        if let gateway = nearestRichGateway(to: origin.coordinate) {
            let via = journeys(baseCoordinate: gateway.coordinate, originLabel: origin.city)
            let viaFree = via.filter { !$0.isPremium }.count
            if viaFree > directFree || via.count > direct.count {
                return PlanOutcome(journeys: via, base: gateway.name, source: "gateway")
            }
        }
        return PlanOutcome(journeys: direct, base: origin.city, source: "direct")
    }

    /// Build the full grouped journey set from a planning-base coordinate.
    private static func journeys(baseCoordinate coord: GeoCoordinate, originLabel: String) -> [PlannedJourney] {
        let base = JourneyOrigin(city: originLabel, country: "", coordinate: coord)
        let candidates: [PlannedJourney] = TravelNetworkCatalog.sortedByDistance(from: coord).compactMap { pair in
            guard pair.node.name != originLabel else { return nil }   // never land where you took off
            let minKm = pair.node.isIconic ? 10.0 : 18.0
            guard pair.km >= minKm else { return nil }
            return make(base, pair.node, pair.km)
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

    /// The nearest **rich** travel gateway: the closest strong hub (airport /
    /// capital / major city / high-tourism) that itself has several journey-worthy
    /// neighbours within free range. Planning from it guarantees a full free set,
    /// and — because a sparse origin-city is not "rich" — it never just re-plans
    /// the same empty neighbourhood.
    private static func nearestRichGateway(to coord: GeoCoordinate) -> JourneyDestinationNode? {
        let ranked = TravelNetworkCatalog.sortedByDistance(from: coord)
        for pair in ranked {
            let n = pair.node
            guard isStrongHub(n) else { continue }
            if freeNeighbourCount(of: n) >= 4 { return n }
        }
        // Nothing rich anywhere near (extreme remote): fall back to the nearest
        // strong hub of any kind so we still relocate to real ground.
        return ranked.first { isStrongHub($0.node) }?.node
    }

    private static func isStrongHub(_ n: JourneyDestinationNode) -> Bool {
        n.airportCode != nil
            || n.hasTag("capital") || n.hasTag("majorCity") || n.hasTag("regionalHub")
            || n.tourismScore >= 80
    }

    /// How many journey-worthy nodes sit within free (Short) range of `node`.
    private static func freeNeighbourCount(of node: JourneyDestinationNode) -> Int {
        TravelNetworkCatalog.sortedByDistance(from: node.coordinate)
            .prefix(40)
            .filter { $0.node.id != node.id && $0.km >= 12 && duration(forKm: $0.km) < 60 }
            .count
    }

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

    /// A "back to the previous city" trip, using the same real route/duration/
    /// category logic. The previous origin may not be a catalogue node (it can be
    /// the user's real GPS city), so we synthesise a node from it.
    static func returnJourney(from origin: JourneyOrigin, to previous: JourneyOrigin) -> PlannedJourney {
        let km = GeoMath.distanceKm(from: origin.coordinate, to: previous.coordinate)
        let node = JourneyDestinationNode(
            name: previous.city,
            country: previous.country,
            region: previous.country.isEmpty ? nil : previous.country,
            code: previous.code.isEmpty ? Route.code(previous.city) : previous.code,
            latitude: previous.coordinate.latitude,
            longitude: previous.coordinate.longitude,
            population: nil, airportCode: nil, tourismScore: 72,
            tags: ["return"], metroGroup: nil, premiumWeight: nil)
        return PlannedJourney(node: node, route: route(from: origin, to: node, km: km), isReturn: true)
    }

    private static func make(_ origin: JourneyOrigin, _ node: JourneyDestinationNode, _ km: Double) -> PlannedJourney {
        PlannedJourney(node: node, route: route(from: origin, to: node, km: km))
    }

    // MARK: - DEBUG coverage validation

    #if DEBUG
    /// Validates universal coverage across representative origins. Logs results
    /// and asserts the core guarantees. Call once at launch (DEBUG only).
    static func validateCoverage() {
        let origins: [(String, Double, Double)] = [
            ("Barcelona", 41.3851, 2.1734), ("Sitges", 41.2371, 1.8055), ("Toulouse", 43.6047, 1.4442),
            ("Marseille", 43.2965, 5.3698), ("Rome", 41.9028, 12.4964), ("Milan", 45.4642, 9.1900),
            ("Munich", 48.1351, 11.5820), ("London", 51.5074, -0.1278), ("Lisbon", 38.7223, -9.1393),
            ("Santorini", 36.3932, 25.4615), ("Aix-en-Provence", 43.5297, 5.4474),
            ("Miami", 25.7617, -80.1918), ("New York", 40.7128, -74.0060), ("Los Angeles", 34.0522, -118.2437),
            ("Vancouver", 49.2827, -123.1207), ("Cancún", 21.1619, -86.8515),
            ("Dubai", 25.2048, 55.2708), ("Alexandria", 31.2001, 29.9187), ("Cairo", 30.0444, 31.2357),
            ("Marrakech", 31.6295, -7.9811), ("Nairobi", -1.2921, 36.8219), ("Cape Town", -33.9249, 18.4241),
            ("Tokyo", 35.6762, 139.6503), ("Sapporo", 43.0618, 141.3545), ("Singapore", 1.3521, 103.8198),
            ("Bangkok", 13.7563, 100.5018), ("Sydney", -33.8688, 151.2093), ("Perth", -31.9505, 115.8605),
            ("Remote Village", 44.20, 5.30), ("Mountain Forest", 46.50, 11.30),
            ("Island Coord", 39.10, 26.55), ("Desert Coord", 28.00, 0.50)
        ]
        cache.removeAll()
        for (name, lat, lon) in origins {
            let origin = JourneyOrigin(city: name, coordinate: GeoCoordinate(latitude: lat, longitude: lon))
            let js = plan(from: origin)
            let free = js.filter { !$0.isPremium }.count
            let premium = js.filter { $0.isPremium }.count
            let ids = Set(js.map { $0.id })
            assert(!js.isEmpty, "[JourneyPlanner] EMPTY result for \(name)")
            assert(js.count >= 10, "[JourneyPlanner] <10 journeys for \(name): \(js.count)")
            assert(premium >= 1, "[JourneyPlanner] no premium for \(name)")
            assert(ids.count == js.count, "[JourneyPlanner] duplicate destination for \(name)")
            assert(js.allSatisfy { $0.distanceKm >= 9 }, "[JourneyPlanner] same-city destination for \(name)")
            assert(js.allSatisfy { $0.isPremium == ($0.durationMinutes >= 60) }, "[JourneyPlanner] premium/duration mismatch for \(name)")
            if free < 4 { print("[JourneyPlanner] NOTE: \(name) has only \(free) free journeys") }
        }
        cache.removeAll()
        print("[JourneyPlanner] coverage validation complete (\(origins.count) origins)")
    }
    #endif
}
