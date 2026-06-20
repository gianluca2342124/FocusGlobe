import Foundation

/// A scalable, JSON-backed catalog of real cities grouped by country. Supports
/// hundreds/thousands of cities without changing Swift code — just expand
/// `WorldCities.json`. Search matches city name, country name, and city code.
enum WorldCityCatalog {

    /// All countries (alphabetical), loaded once from the bundled JSON.
    static let countries: [WorldCountry] = loadCountries()

    /// All cities flattened with their country (for search).
    static let allCities: [CityEntry] = countries.flatMap { country in
        country.cities.map { CityEntry(city: $0, country: country.country, countryCode: country.countryCode) }
    }

    /// Search by city name, country name, or city code (case-insensitive).
    static func search(_ query: String, limit: Int = 80) -> [CityEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        let matches = allCities.filter {
            $0.city.name.lowercased().contains(q)
                || $0.country.lowercased().contains(q)
                || $0.city.code.lowercased().contains(q)
        }
        // Prefer name-prefix matches, then the rest.
        let prefix = matches.filter { $0.city.name.lowercased().hasPrefix(q) }
        let others = matches.filter { !$0.city.name.lowercased().hasPrefix(q) }
        return Array((prefix + others).prefix(limit))
    }

    // MARK: - Loading

    private static func loadCountries() -> [WorldCountry] {
        guard let url = Bundle.main.url(forResource: "WorldCities", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([WorldCountry].self, from: data),
              !decoded.isEmpty else {
            return fallback
        }
        return decoded.sorted { $0.country < $1.country }
    }

    /// Used only if the JSON is missing — derived from the supported hubs so the
    /// picker always works.
    private static let fallback: [WorldCountry] = {
        Dictionary(grouping: HubCatalog.all, by: { $0.countryName })
            .map { country, hubs in
                WorldCountry(country: country,
                             countryCode: String(country.prefix(2)).uppercased(),
                             cities: hubs.map { WorldCity(name: $0.cityName, code: $0.code,
                                                          latitude: $0.latitude, longitude: $0.longitude) })
            }
            .sorted { $0.country < $1.country }
    }()
}
