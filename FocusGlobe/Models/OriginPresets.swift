import Foundation

/// Hand-picked starting cities for the "Choose starting city" picker (a clean
/// fallback when location is unavailable) and the DEBUG location override.
enum OriginPresets {
    static let all: [JourneyOrigin] = [
        JourneyOrigin(city: "Barcelona", country: "Spain",
                      coordinate: GeoCoordinate(latitude: 41.3851, longitude: 2.1734), code: "BCN"),
        JourneyOrigin(city: "Madrid", country: "Spain",
                      coordinate: GeoCoordinate(latitude: 40.4168, longitude: -3.7038), code: "MAD"),
        JourneyOrigin(city: "Paris", country: "France",
                      coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522), code: "PAR"),
        JourneyOrigin(city: "London", country: "United Kingdom",
                      coordinate: GeoCoordinate(latitude: 51.5074, longitude: -0.1278), code: "LON"),
        JourneyOrigin(city: "Berlin", country: "Germany",
                      coordinate: GeoCoordinate(latitude: 52.5200, longitude: 13.4050), code: "BER"),
        JourneyOrigin(city: "Rome", country: "Italy",
                      coordinate: GeoCoordinate(latitude: 41.9028, longitude: 12.4964), code: "ROM"),
        JourneyOrigin(city: "New York", country: "United States",
                      coordinate: GeoCoordinate(latitude: 40.7128, longitude: -74.0060), code: "NYC"),
        JourneyOrigin(city: "San Francisco", country: "United States",
                      coordinate: GeoCoordinate(latitude: 37.7749, longitude: -122.4194), code: "SFO"),
        JourneyOrigin(city: "Tokyo", country: "Japan",
                      coordinate: GeoCoordinate(latitude: 35.6762, longitude: 139.6503), code: "TYO"),
        JourneyOrigin(city: "Singapore", country: "Singapore",
                      coordinate: GeoCoordinate(latitude: 1.3521, longitude: 103.8198), code: "SIN"),
        JourneyOrigin(city: "Sydney", country: "Australia",
                      coordinate: GeoCoordinate(latitude: -33.8688, longitude: 151.2093), code: "SYD"),
    ]
}
