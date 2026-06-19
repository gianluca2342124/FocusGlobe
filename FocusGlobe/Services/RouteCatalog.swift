import Foundation

/// The curated, fully-local destination catalog.
///
/// Every entry is an aspirational, recognizable **destination**. The journey
/// always begins at the user's real current location, so only the destination
/// is authored here (the `origin*` fields hold an evocative "inspired by"
/// gateway and are never used as the journey's start). Journeys are **30
/// minutes minimum** — no ultra-short sessions. Nothing is fetched from a
/// network or any paid routing API; the path is a simulated geodesic line from
/// the user's location to the destination.
enum RouteCatalog {

    /// All destinations, in display order (shortest → longest focus).
    static let all: [Route] = [
        // MARK: Short Focus (30 min)
        Route(id: "kyoto-lantern-drift", name: "Kyoto Lantern Drift", shortName: "Kyoto",
              originName: "Osaka", destinationName: "Kyoto",
              originLatitude: 34.6937, originLongitude: 135.5023,
              destinationLatitude: 35.0116, destinationLongitude: 135.7681,
              durationMinutes: 30, approximateDistanceKm: 43,
              category: .short, mood: .sunset, rewardName: "Kyoto Lanterns",
              isPremium: false, colorTheme: .coral, ambientSoundName: "cabin_soft"),

        Route(id: "santorini-blue-hour", name: "Santorini Blue Hour", shortName: "Santorini",
              originName: "Athens", destinationName: "Santorini",
              originLatitude: 37.9838, originLongitude: 23.7275,
              destinationLatitude: 36.3932, destinationLongitude: 25.4615,
              durationMinutes: 30, approximateDistanceKm: 233,
              category: .short, mood: .sunset, rewardName: "Aegean Blue Hour",
              isPremium: false, colorTheme: .blush, ambientSoundName: "ocean_calm"),

        Route(id: "amalfi-coastline", name: "Amalfi Coastline", shortName: "Amalfi",
              originName: "Rome", destinationName: "Amalfi",
              originLatitude: 41.9028, originLongitude: 12.4964,
              destinationLatitude: 40.6340, destinationLongitude: 14.6027,
              durationMinutes: 30, approximateDistanceKm: 235,
              category: .short, mood: .ocean, rewardName: "Amalfi Gold",
              isPremium: false, colorTheme: .teal, ambientSoundName: "ocean_calm"),

        // MARK: Deep Focus (45–90 min)
        Route(id: "swiss-alps-crossing", name: "Swiss Alps Crossing", shortName: "Swiss Alps",
              originName: "Zürich", destinationName: "Swiss Alps",
              originLatitude: 47.3769, originLongitude: 8.5417,
              destinationLatitude: 45.9763, destinationLongitude: 7.6586,
              durationMinutes: 45, approximateDistanceKm: 160,
              category: .deep, mood: .mountains, rewardName: "Alpine Hush",
              isPremium: false, colorTheme: .slate, ambientSoundName: "wind_soft"),

        Route(id: "lake-como-reverie", name: "Lake Como Reverie", shortName: "Lake Como",
              originName: "Milan", destinationName: "Lake Como",
              originLatitude: 45.4642, originLongitude: 9.1900,
              destinationLatitude: 45.9869, destinationLongitude: 9.2616,
              durationMinutes: 45, approximateDistanceKm: 60,
              category: .deep, mood: .calm, rewardName: "Como Stillness",
              isPremium: false, colorTheme: .mint, ambientSoundName: "wind_soft"),

        Route(id: "big-sur-coast", name: "Big Sur Coast", shortName: "Big Sur",
              originName: "San Francisco", destinationName: "Big Sur",
              originLatitude: 37.7749, originLongitude: -122.4194,
              destinationLatitude: 36.2704, destinationLongitude: -121.8081,
              durationMinutes: 60, approximateDistanceKm: 230,
              category: .deep, mood: .ocean, rewardName: "Big Sur Gold",
              isPremium: false, colorTheme: .teal, ambientSoundName: "ocean_calm"),

        Route(id: "mount-fuji-ascent", name: "Mount Fuji Ascent", shortName: "Mount Fuji",
              originName: "Tokyo", destinationName: "Mount Fuji",
              originLatitude: 35.6762, originLongitude: 139.6503,
              destinationLatitude: 35.3606, destinationLongitude: 138.7274,
              durationMinutes: 60, approximateDistanceKm: 100,
              category: .deep, mood: .mountains, rewardName: "Fuji Dawn",
              isPremium: false, colorTheme: .lavender, ambientSoundName: "wind_soft"),

        Route(id: "norwegian-fjords", name: "Norwegian Fjords", shortName: "Fjords",
              originName: "Oslo", destinationName: "Norwegian Fjords",
              originLatitude: 59.9139, originLongitude: 10.7522,
              destinationLatitude: 62.1010, destinationLongitude: 7.2060,
              durationMinutes: 90, approximateDistanceKm: 330,
              category: .deep, mood: .aurora, rewardName: "Fjord Mist",
              isPremium: true, colorTheme: .aurora, ambientSoundName: "wind_soft"),

        Route(id: "iceland-coast", name: "Iceland Ring Road", shortName: "Iceland",
              originName: "London", destinationName: "Iceland",
              originLatitude: 51.5074, originLongitude: -0.1278,
              destinationLatitude: 64.1466, destinationLongitude: -21.9426,
              durationMinutes: 90, approximateDistanceKm: 1890,
              category: .deep, mood: .aurora, rewardName: "Black Sand Coast",
              isPremium: true, colorTheme: .teal, ambientSoundName: "ocean_calm"),

        // MARK: Long Focus (2–4 hours)
        Route(id: "sahara-sunrise-crossing", name: "Sahara Sunrise Crossing", shortName: "Sahara",
              originName: "Marrakech", destinationName: "Sahara",
              originLatitude: 31.6295, originLongitude: -7.9811,
              destinationLatitude: 31.0801, destinationLongitude: -4.0133,
              durationMinutes: 120, approximateDistanceKm: 360,
              category: .long, mood: .sunrise, rewardName: "Desert Dawn",
              isPremium: true, colorTheme: .gold, ambientSoundName: "wind_soft"),

        Route(id: "patagonia-wind-route", name: "Patagonia Wind Route", shortName: "Patagonia",
              originName: "Buenos Aires", destinationName: "Patagonia",
              originLatitude: -34.6037, originLongitude: -58.3816,
              destinationLatitude: -49.3314, destinationLongitude: -72.8864,
              durationMinutes: 180, approximateDistanceKm: 2200,
              category: .long, mood: .mountains, rewardName: "Patagonian Wind",
              isPremium: true, colorTheme: .slate, ambientSoundName: "wind_soft"),

        Route(id: "canadian-rockies-drift", name: "Canadian Rockies Drift", shortName: "Rockies",
              originName: "Vancouver", destinationName: "Canadian Rockies",
              originLatitude: 49.2827, originLongitude: -123.1207,
              destinationLatitude: 51.4254, destinationLongitude: -116.1773,
              durationMinutes: 240, approximateDistanceKm: 680,
              category: .long, mood: .mountains, rewardName: "Rockies Stillness",
              isPremium: true, colorTheme: .mint, ambientSoundName: "wind_soft"),

        // MARK: Ultra Focus (6–12 hours)
        Route(id: "northern-lights-drift", name: "Northern Lights Drift", shortName: "Aurora",
              originName: "Reykjavík", destinationName: "Northern Lights",
              originLatitude: 64.1466, originLongitude: -21.9426,
              destinationLatitude: 69.6492, destinationLongitude: 18.9553,
              durationMinutes: 360, approximateDistanceKm: 1690,
              category: .ultra, mood: .aurora, rewardName: "Aurora Veil",
              isPremium: true, colorTheme: .aurora, ambientSoundName: "aurora_calm"),

        Route(id: "pacific-calm-crossing", name: "Pacific Calm Crossing", shortName: "Pacific",
              originName: "Tokyo", destinationName: "Pacific Crossing",
              originLatitude: 35.6762, originLongitude: 139.6503,
              destinationLatitude: 21.3069, destinationLongitude: -157.8583,
              durationMinutes: 480, approximateDistanceKm: 6200,
              category: .ultra, mood: .ocean, rewardName: "Pacific Calm",
              isPremium: true, colorTheme: .teal, ambientSoundName: "ocean_calm"),

        Route(id: "around-the-world", name: "Around the World", shortName: "The World",
              originName: "San Francisco", destinationName: "Around the World",
              originLatitude: 37.7749, originLongitude: -122.4194,
              destinationLatitude: -33.8688, destinationLongitude: 151.2093,
              durationMinutes: 720, approximateDistanceKm: 11930,
              category: .ultra, mood: .night, rewardName: "Around the World",
              isPremium: true, colorTheme: .lavender, ambientSoundName: "cabin_soft"),
    ]

    // MARK: - Lookups & grouping

    static func route(id: String) -> Route? {
        all.first { $0.id == id }
    }

    static func routes(in category: RouteCategory) -> [Route] {
        all.filter { $0.category == category }
    }

    /// Free destinations only — the basic experience available without Pro.
    static var free: [Route] { all.filter { !$0.isPremium } }

    /// A calm, iconic default recommendation for the Home screen.
    static var recommended: Route {
        route(id: "kyoto-lantern-drift") ?? all[0]
    }
}
