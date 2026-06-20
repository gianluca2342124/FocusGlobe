import Foundation

/// "Popular" starting-city shortcuts for the picker. These are convenience
/// shortcuts only — they do NOT determine which cities can have journeys (every
/// city in WorldCities.json is eligible as an origin and a destination).
enum OriginPresets {
    static let all: [JourneyOrigin] = [
        o("Barcelona", "Spain", 41.3851, 2.1734, "BCN"),
        o("Madrid", "Spain", 40.4168, -3.7038, "MAD"),
        o("Paris", "France", 48.8566, 2.3522, "PAR"),
        o("London", "United Kingdom", 51.5074, -0.1278, "LON"),
        o("Berlin", "Germany", 52.5200, 13.4050, "BER"),
        o("Rome", "Italy", 41.9028, 12.4964, "ROM"),
        o("Lisbon", "Portugal", 38.7223, -9.1393, "LIS"),
        o("Amsterdam", "Netherlands", 52.3676, 4.9041, "AMS"),
        o("New York", "United States", 40.7128, -74.0060, "NYC"),
        o("Los Angeles", "United States", 34.0522, -118.2437, "LAX"),
        o("San Francisco", "United States", 37.7749, -122.4194, "SFO"),
        o("Tokyo", "Japan", 35.6762, 139.6503, "TYO"),
        o("Dubai", "United Arab Emirates", 25.2048, 55.2708, "DXB"),
        o("Singapore", "Singapore", 1.3521, 103.8198, "SIN"),
        o("Sydney", "Australia", -33.8688, 151.2093, "SYD"),
    ]

    private static func o(_ city: String, _ country: String, _ lat: Double, _ lon: Double, _ code: String) -> JourneyOrigin {
        JourneyOrigin(city: city, country: country, coordinate: GeoCoordinate(latitude: lat, longitude: lon), code: code)
    }
}
