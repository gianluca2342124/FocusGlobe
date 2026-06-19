import Foundation

/// The curated, fully-local route catalog.
///
/// Every route is hand-authored with real coordinates between recognizable,
/// aspirational destinations. Journeys start at **30 minutes** — no ultra-short
/// sessions. Nothing here is fetched from a network or any paid routing API;
/// the path is a simulated geodesic line between two points.
enum RouteCatalog {

    /// All routes, in display order (shortest → longest).
    static let all: [Route] = [
        // MARK: Short Focus (30 min)
        Route(id: "kyoto-lantern-drift", name: "Kyoto Lantern Drift", shortName: "Kyoto",
              originName: "Kyoto", destinationName: "Nara",
              originLatitude: 35.0116, originLongitude: 135.7681,
              destinationLatitude: 34.6851, destinationLongitude: 135.8048,
              durationMinutes: 30, approximateDistanceKm: 37,
              category: .short, mood: .sunset, rewardName: "Kyoto Lanterns",
              isPremium: false, colorTheme: .coral, ambientSoundName: "cabin_soft"),

        Route(id: "santorini-blue-hour", name: "Santorini Blue Hour", shortName: "Santorini",
              originName: "Santorini", destinationName: "Naxos",
              originLatitude: 36.3932, originLongitude: 25.4615,
              destinationLatitude: 37.1036, destinationLongitude: 25.3766,
              durationMinutes: 30, approximateDistanceKm: 80,
              category: .short, mood: .sunset, rewardName: "Aegean Blue Hour",
              isPremium: false, colorTheme: .blush, ambientSoundName: "ocean_calm"),

        Route(id: "amalfi-coastline", name: "Amalfi Coastline", shortName: "Amalfi",
              originName: "Naples", destinationName: "Amalfi",
              originLatitude: 40.8518, originLongitude: 14.2681,
              destinationLatitude: 40.6340, destinationLongitude: 14.6027,
              durationMinutes: 30, approximateDistanceKm: 38,
              category: .short, mood: .ocean, rewardName: "Amalfi Gold",
              isPremium: false, colorTheme: .teal, ambientSoundName: "ocean_calm"),

        // MARK: Deep Focus (45–90 min)
        Route(id: "swiss-alps-crossing", name: "Swiss Alps Crossing", shortName: "Swiss Alps",
              originName: "Interlaken", destinationName: "Zermatt",
              originLatitude: 46.6863, originLongitude: 7.8632,
              destinationLatitude: 46.0207, destinationLongitude: 7.7491,
              durationMinutes: 45, approximateDistanceKm: 75,
              category: .deep, mood: .mountains, rewardName: "Alpine Hush",
              isPremium: false, colorTheme: .slate, ambientSoundName: "wind_soft"),

        Route(id: "lake-como-reverie", name: "Lake Como Reverie", shortName: "Lake Como",
              originName: "Milan", destinationName: "Bellagio",
              originLatitude: 45.4642, originLongitude: 9.1900,
              destinationLatitude: 45.9869, destinationLongitude: 9.2616,
              durationMinutes: 45, approximateDistanceKm: 60,
              category: .deep, mood: .calm, rewardName: "Como Stillness",
              isPremium: false, colorTheme: .mint, ambientSoundName: "wind_soft"),

        Route(id: "big-sur-coast", name: "Big Sur Coast", shortName: "Big Sur",
              originName: "Monterey", destinationName: "Big Sur",
              originLatitude: 36.6002, originLongitude: -121.8947,
              destinationLatitude: 36.2704, destinationLongitude: -121.8081,
              durationMinutes: 60, approximateDistanceKm: 50,
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
              originName: "Bergen", destinationName: "Geiranger",
              originLatitude: 60.3913, originLongitude: 5.3221,
              destinationLatitude: 62.1010, destinationLongitude: 7.2060,
              durationMinutes: 90, approximateDistanceKm: 230,
              category: .deep, mood: .aurora, rewardName: "Fjord Mist",
              isPremium: true, colorTheme: .aurora, ambientSoundName: "wind_soft"),

        Route(id: "iceland-coast", name: "Iceland Ring Road", shortName: "Iceland",
              originName: "Reykjavík", destinationName: "Vík",
              originLatitude: 64.1466, originLongitude: -21.9426,
              destinationLatitude: 63.4194, destinationLongitude: -19.0060,
              durationMinutes: 90, approximateDistanceKm: 180,
              category: .deep, mood: .aurora, rewardName: "Black Sand Coast",
              isPremium: true, colorTheme: .teal, ambientSoundName: "ocean_calm"),

        // MARK: Long Focus (2–4 hours)
        Route(id: "sahara-sunrise-crossing", name: "Sahara Sunrise Crossing", shortName: "Sahara",
              originName: "Marrakech", destinationName: "Cairo",
              originLatitude: 31.6295, originLongitude: -7.9811,
              destinationLatitude: 30.0444, destinationLongitude: 31.2357,
              durationMinutes: 120, approximateDistanceKm: 3700,
              category: .long, mood: .sunrise, rewardName: "Desert Dawn",
              isPremium: true, colorTheme: .gold, ambientSoundName: "wind_soft"),

        Route(id: "patagonia-wind-route", name: "Patagonia Wind Route", shortName: "Patagonia",
              originName: "Santiago", destinationName: "El Chaltén",
              originLatitude: -33.4489, originLongitude: -70.6693,
              destinationLatitude: -49.3314, destinationLongitude: -72.8864,
              durationMinutes: 180, approximateDistanceKm: 1900,
              category: .long, mood: .mountains, rewardName: "Patagonian Wind",
              isPremium: true, colorTheme: .slate, ambientSoundName: "wind_soft"),

        Route(id: "canadian-rockies-drift", name: "Canadian Rockies Drift", shortName: "Rockies",
              originName: "Vancouver", destinationName: "Banff",
              originLatitude: 49.2827, originLongitude: -123.1207,
              destinationLatitude: 51.1784, destinationLongitude: -115.5708,
              durationMinutes: 240, approximateDistanceKm: 680,
              category: .long, mood: .mountains, rewardName: "Rockies Stillness",
              isPremium: true, colorTheme: .mint, ambientSoundName: "wind_soft"),

        // MARK: Ultra Focus (6–12 hours)
        Route(id: "arctic-aurora-route", name: "Arctic Aurora Route", shortName: "Arctic",
              originName: "Tromsø", destinationName: "Svalbard",
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

        Route(id: "northern-lights-drift", name: "Northern Lights Drift", shortName: "Aurora",
              originName: "Fairbanks", destinationName: "Reykjavík",
              originLatitude: 64.8378, originLongitude: -147.7164,
              destinationLatitude: 64.1466, destinationLongitude: -21.9426,
              durationMinutes: 600, approximateDistanceKm: 5200,
              category: .ultra, mood: .aurora, rewardName: "Aurora Veil",
              isPremium: true, colorTheme: .aurora, ambientSoundName: "aurora_calm"),

        Route(id: "around-the-world", name: "Around the World", shortName: "The World",
              originName: "San Francisco", destinationName: "Sydney",
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

    /// Free routes only — the basic experience available without Pro.
    static var free: [Route] { all.filter { !$0.isPremium } }

    /// A calm, iconic default recommendation for the Home screen.
    static var recommended: Route {
        route(id: "kyoto-lantern-drift") ?? all[0]
    }
}
