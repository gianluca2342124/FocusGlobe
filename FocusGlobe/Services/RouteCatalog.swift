import Foundation

/// The curated, fully-local route catalog.
///
/// Every route is hand-authored with real coordinates. Nothing here is fetched
/// from a network, the Directions/Routes API, Places, Geocoding or any paid
/// service — the journey path is a simulated geodesic line between two points.
enum RouteCatalog {

    /// All routes, in display order (shortest → longest).
    static let all: [Route] = [
        // MARK: Micro Focus (5–15 min)
        Route(id: "paris-soft-drift", name: "Paris Soft Drift", shortName: "Paris",
              originName: "Paris", destinationName: "Versailles",
              originLatitude: 48.8566, originLongitude: 2.3522,
              destinationLatitude: 48.8049, destinationLongitude: 2.1204,
              durationMinutes: 5, approximateDistanceKm: 22,
              category: .micro, mood: .sunrise, rewardName: "Paris Dawn",
              isPremium: false, colorTheme: .blush, ambientSoundName: "wind_soft"),

        Route(id: "lisbon-light-drift", name: "Lisbon Light Drift", shortName: "Lisbon",
              originName: "Lisbon", destinationName: "Sintra",
              originLatitude: 38.7223, originLongitude: -9.1393,
              destinationLatitude: 38.7979, destinationLongitude: -9.3907,
              durationMinutes: 5, approximateDistanceKm: 25,
              category: .micro, mood: .sunset, rewardName: "Lisbon Light",
              isPremium: false, colorTheme: .coral, ambientSoundName: "wind_soft"),

        Route(id: "barcelona-morning-drift", name: "Barcelona Morning Drift", shortName: "Barcelona",
              originName: "Barcelona", destinationName: "Montserrat",
              originLatitude: 41.3851, originLongitude: 2.1734,
              destinationLatitude: 41.5931, destinationLongitude: 1.8376,
              durationMinutes: 10, approximateDistanceKm: 40,
              category: .micro, mood: .sunrise, rewardName: "Catalan Morning",
              isPremium: false, colorTheme: .gold, ambientSoundName: "wind_soft"),

        Route(id: "tokyo-cloud-hop", name: "Tokyo Cloud Hop", shortName: "Tokyo",
              originName: "Tokyo", destinationName: "Yokohama",
              originLatitude: 35.6762, originLongitude: 139.6503,
              destinationLatitude: 35.4437, destinationLongitude: 139.6380,
              durationMinutes: 15, approximateDistanceKm: 27,
              category: .micro, mood: .clouds, rewardName: "Tokyo Cloudline",
              isPremium: false, colorTheme: .teal, ambientSoundName: "cabin_soft"),

        // MARK: Short Focus (20–30 min)
        Route(id: "london-evening-drift", name: "London Evening Drift", shortName: "London",
              originName: "London", destinationName: "Windsor",
              originLatitude: 51.5074, originLongitude: -0.1278,
              destinationLatitude: 51.4839, destinationLongitude: -0.6044,
              durationMinutes: 20, approximateDistanceKm: 34,
              category: .short, mood: .sunset, rewardName: "Thames Dusk",
              isPremium: false, colorTheme: .lavender, ambientSoundName: "rain_soft"),

        Route(id: "amsterdam-canal-drift", name: "Amsterdam Canal Drift", shortName: "Amsterdam",
              originName: "Amsterdam", destinationName: "Utrecht",
              originLatitude: 52.3676, originLongitude: 4.9041,
              destinationLatitude: 52.0907, destinationLongitude: 5.1214,
              durationMinutes: 20, approximateDistanceKm: 35,
              category: .short, mood: .calm, rewardName: "Canal Quiet",
              isPremium: false, colorTheme: .teal, ambientSoundName: "rain_soft"),

        Route(id: "new-york-skyline-drift", name: "New York Skyline Drift", shortName: "New York",
              originName: "Manhattan", destinationName: "Montauk",
              originLatitude: 40.7549, originLongitude: -73.9840,
              destinationLatitude: 41.0590, destinationLongitude: -71.9545,
              durationMinutes: 25, approximateDistanceKm: 180,
              category: .short, mood: .city, rewardName: "Skyline Lights",
              isPremium: false, colorTheme: .indigo, ambientSoundName: "city_hum"),

        Route(id: "cape-town-sea-drift", name: "Cape Town Sea Drift", shortName: "Cape Town",
              originName: "Cape Town", destinationName: "Cape Point",
              originLatitude: -33.9249, originLongitude: 18.4241,
              destinationLatitude: -34.3568, destinationLongitude: 18.4970,
              durationMinutes: 25, approximateDistanceKm: 50,
              category: .short, mood: .ocean, rewardName: "Cape Horizon",
              isPremium: false, colorTheme: .teal, ambientSoundName: "ocean_calm"),

        Route(id: "seoul-night-drift", name: "Seoul Night Drift", shortName: "Seoul",
              originName: "Seoul", destinationName: "Incheon",
              originLatitude: 37.5665, originLongitude: 126.9780,
              destinationLatitude: 37.4563, destinationLongitude: 126.7052,
              durationMinutes: 30, approximateDistanceKm: 28,
              category: .short, mood: .night, rewardName: "Han River Night",
              isPremium: false, colorTheme: .indigo, ambientSoundName: "city_hum"),

        // MARK: Deep Focus (45–90 min)
        Route(id: "swiss-alps-drift", name: "Swiss Alps Drift", shortName: "Swiss Alps",
              originName: "Interlaken", destinationName: "Zermatt",
              originLatitude: 46.6863, originLongitude: 7.8632,
              destinationLatitude: 46.0207, destinationLongitude: 7.7491,
              durationMinutes: 45, approximateDistanceKm: 75,
              category: .deep, mood: .mountains, rewardName: "Alpine Hush",
              isPremium: false, colorTheme: .slate, ambientSoundName: "wind_soft"),

        Route(id: "dolomites-calm", name: "Dolomites Calm", shortName: "Dolomites",
              originName: "Bolzano", destinationName: "Cortina",
              originLatitude: 46.4983, originLongitude: 11.3548,
              destinationLatitude: 46.5405, destinationLongitude: 12.1357,
              durationMinutes: 45, approximateDistanceKm: 60,
              category: .deep, mood: .mountains, rewardName: "Dolomite Calm",
              isPremium: false, colorTheme: .mint, ambientSoundName: "wind_soft"),

        Route(id: "iceland-coast-drift", name: "Iceland Coast Drift", shortName: "Iceland",
              originName: "Reykjavík", destinationName: "Vík",
              originLatitude: 64.1466, originLongitude: -21.9426,
              destinationLatitude: 63.4194, destinationLongitude: -19.0060,
              durationMinutes: 50, approximateDistanceKm: 180,
              category: .deep, mood: .ocean, rewardName: "Black Sand Coast",
              isPremium: true, colorTheme: .teal, ambientSoundName: "ocean_calm"),

        Route(id: "kyoto-autumn-drift", name: "Kyoto Autumn Drift", shortName: "Kyoto",
              originName: "Kyoto", destinationName: "Nara",
              originLatitude: 35.0116, originLongitude: 135.7681,
              destinationLatitude: 34.6851, destinationLongitude: 135.8048,
              durationMinutes: 60, approximateDistanceKm: 37,
              category: .deep, mood: .sunset, rewardName: "Kyoto Maple",
              isPremium: false, colorTheme: .coral, ambientSoundName: "cabin_soft"),

        Route(id: "big-sur-coast-drift", name: "Big Sur Coast Drift", shortName: "Big Sur",
              originName: "Monterey", destinationName: "San Simeon",
              originLatitude: 36.6002, originLongitude: -121.8947,
              destinationLatitude: 35.6444, destinationLongitude: -121.1890,
              durationMinutes: 60, approximateDistanceKm: 120,
              category: .deep, mood: .ocean, rewardName: "Big Sur Gold",
              isPremium: false, colorTheme: .teal, ambientSoundName: "ocean_calm"),

        Route(id: "norwegian-fjords-drift", name: "Norwegian Fjords Drift", shortName: "Fjords",
              originName: "Bergen", destinationName: "Geiranger",
              originLatitude: 60.3913, originLongitude: 5.3221,
              destinationLatitude: 62.1010, destinationLongitude: 7.2060,
              durationMinutes: 75, approximateDistanceKm: 230,
              category: .deep, mood: .mountains, rewardName: "Fjord Mist",
              isPremium: true, colorTheme: .teal, ambientSoundName: "wind_soft"),

        Route(id: "santorini-blue-hour", name: "Santorini Blue Hour", shortName: "Santorini",
              originName: "Santorini", destinationName: "Heraklion",
              originLatitude: 36.3932, originLongitude: 25.4615,
              destinationLatitude: 35.3387, destinationLongitude: 25.1442,
              durationMinutes: 90, approximateDistanceKm: 125,
              category: .deep, mood: .sunset, rewardName: "Aegean Blue Hour",
              isPremium: true, colorTheme: .blush, ambientSoundName: "ocean_calm"),

        // MARK: Long Focus (2–4 hours)
        Route(id: "sahara-sunrise-crossing", name: "Sahara Sunrise Crossing", shortName: "Sahara",
              originName: "Marrakech", destinationName: "Cairo",
              originLatitude: 31.6295, originLongitude: -7.9811,
              destinationLatitude: 30.0444, destinationLongitude: 31.2357,
              durationMinutes: 120, approximateDistanceKm: 3700,
              category: .long, mood: .sunrise, rewardName: "Desert Dawn",
              isPremium: true, colorTheme: .gold, ambientSoundName: "wind_soft"),

        Route(id: "patagonia-wind-route", name: "Patagonia Wind Route", shortName: "Patagonia",
              originName: "Santiago", destinationName: "Ushuaia",
              originLatitude: -33.4489, originLongitude: -70.6693,
              destinationLatitude: -54.8019, destinationLongitude: -68.3030,
              durationMinutes: 180, approximateDistanceKm: 2420,
              category: .long, mood: .mountains, rewardName: "Patagonian Wind",
              isPremium: true, colorTheme: .slate, ambientSoundName: "wind_soft"),

        Route(id: "canadian-rockies-drift", name: "Canadian Rockies Drift", shortName: "Rockies",
              originName: "Vancouver", destinationName: "Banff",
              originLatitude: 49.2827, originLongitude: -123.1207,
              destinationLatitude: 51.1784, destinationLongitude: -115.5708,
              durationMinutes: 240, approximateDistanceKm: 600,
              category: .long, mood: .mountains, rewardName: "Rockies Stillness",
              isPremium: true, colorTheme: .mint, ambientSoundName: "wind_soft"),

        // MARK: Ultra Focus (6–12 hours)
        Route(id: "arctic-quiet-route", name: "Arctic Quiet Route", shortName: "Arctic",
              originName: "Tromsø", destinationName: "Longyearbyen",
              originLatitude: 69.6492, originLongitude: 18.9553,
              destinationLatitude: 78.2232, destinationLongitude: 15.6267,
              durationMinutes: 360, approximateDistanceKm: 960,
              category: .ultra, mood: .aurora, rewardName: "Arctic Silence",
              isPremium: true, colorTheme: .aurora, ambientSoundName: "aurora_calm"),

        Route(id: "pacific-calm-crossing", name: "Pacific Calm Crossing", shortName: "Pacific",
              originName: "Tokyo", destinationName: "Honolulu",
              originLatitude: 35.6762, originLongitude: 139.6503,
              destinationLatitude: 21.3069, destinationLongitude: -157.8583,
              durationMinutes: 480, approximateDistanceKm: 6200,
              category: .ultra, mood: .ocean, rewardName: "Pacific Calm",
              isPremium: true, colorTheme: .teal, ambientSoundName: "ocean_calm"),

        Route(id: "aurora-long-drift", name: "Aurora Long Drift", shortName: "Aurora",
              originName: "Fairbanks", destinationName: "Reykjavík",
              originLatitude: 64.8378, originLongitude: -147.7164,
              destinationLatitude: 64.1466, destinationLongitude: -21.9426,
              durationMinutes: 600, approximateDistanceKm: 5200,
              category: .ultra, mood: .aurora, rewardName: "Aurora Veil",
              isPremium: true, colorTheme: .aurora, ambientSoundName: "aurora_calm"),

        Route(id: "around-the-clouds", name: "Around the Clouds", shortName: "Clouds",
              originName: "San Francisco", destinationName: "Sydney",
              originLatitude: 37.7749, originLongitude: -122.4194,
              destinationLatitude: -33.8688, destinationLongitude: 151.2093,
              durationMinutes: 720, approximateDistanceKm: 11930,
              category: .ultra, mood: .clouds, rewardName: "Around the Clouds",
              isPremium: true, colorTheme: .lavender, ambientSoundName: "cabin_soft"),
    ]

    // MARK: - Lookups & grouping

    static func route(id: String) -> Route? {
        all.first { $0.id == id }
    }

    static func routes(in category: RouteCategory) -> [Route] {
        all.filter { $0.category == category }
    }

    /// Free routes only — the basic experience available without Pro.
    static var free: [Route] { all.filter { !$0.isPremium } }

    /// A calm default recommendation for the Home screen (a free, short drift).
    static var recommended: Route {
        route(id: "kyoto-autumn-drift") ?? all[0]
    }
}
