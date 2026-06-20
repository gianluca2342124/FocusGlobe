import Foundation

/// The global network of curated journey-worthy destinations, loaded from
/// TravelDestinations.json. The journey engine selects from *this* network
/// (never arbitrary nearest municipalities), so destinations always feel like a
/// premium flight, and it works from any coordinate on Earth.
enum TravelNetworkCatalog {

    static let allNodes: [JourneyDestinationNode] = load()

    /// All nodes with their distance from `coordinate`, nearest first.
    static func sortedByDistance(from coordinate: GeoCoordinate) -> [(node: JourneyDestinationNode, km: Double)] {
        allNodes
            .map { (node: $0, km: GeoMath.distanceKm(from: coordinate, to: $0.coordinate)) }
            .sorted { $0.km < $1.km }
    }

    private static func load() -> [JourneyDestinationNode] {
        guard let url = Bundle.main.url(forResource: "TravelDestinations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([JourneyDestinationNode].self, from: data),
              !decoded.isEmpty else {
            return fallback
        }
        return decoded
    }

    /// Minimal embedded fallback so the engine never breaks if the JSON is
    /// missing. Real data lives in TravelDestinations.json.
    private static let fallback: [JourneyDestinationNode] = [
        JourneyDestinationNode(name: "Barcelona", country: "Spain", region: "Catalonia", code: "BCN",
            latitude: 41.3851, longitude: 2.1734, population: 1620000, airportCode: "BCN",
            tourismScore: 95, tags: ["majorCity", "coast", "landmark", "airport"], metroGroup: "Barcelona", premiumWeight: nil),
        JourneyDestinationNode(name: "Madrid", country: "Spain", region: "Madrid", code: "MAD",
            latitude: 40.4168, longitude: -3.7038, population: 3300000, airportCode: "MAD",
            tourismScore: 92, tags: ["capital", "majorCity", "airport"], metroGroup: "Madrid", premiumWeight: nil),
        JourneyDestinationNode(name: "Paris", country: "France", region: "Île-de-France", code: "PAR",
            latitude: 48.8566, longitude: 2.3522, population: 2100000, airportCode: "CDG",
            tourismScore: 98, tags: ["capital", "majorCity", "landmark", "airport"], metroGroup: "Paris", premiumWeight: nil),
        JourneyDestinationNode(name: "London", country: "United Kingdom", region: "England", code: "LON",
            latitude: 51.5074, longitude: -0.1278, population: 9000000, airportCode: "LHR",
            tourismScore: 97, tags: ["capital", "majorCity", "landmark", "airport"], metroGroup: "London", premiumWeight: nil),
        JourneyDestinationNode(name: "Rome", country: "Italy", region: "Lazio", code: "ROM",
            latitude: 41.9028, longitude: 12.4964, population: 2800000, airportCode: "FCO",
            tourismScore: 96, tags: ["capital", "majorCity", "historic", "landmark", "airport"], metroGroup: "Rome", premiumWeight: nil)
    ]
}
