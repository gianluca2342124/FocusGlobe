import Foundation
import SwiftUI

// MARK: - Sky (the core destination system)

/// A **Sky** — the place/atmosphere the user focuses in. Skies are the heart of
/// FocusGlobe: Home is a full-screen Sky selector, the boarding pass names the
/// chosen Sky, and the flight world is biased toward its mood.
///
/// User-facing term is always "Sky"/"Skies" (never room / map / world).
/// The catalog is data-only, so adding Skies later is a one-entry change.
struct FocusSky: Identifiable, Hashable {
    enum Category: String { case city, nature, cosmic }
    enum UnlockRequirement { case free, premiumOrInvites }
    /// A tasteful signature accent drawn in the full-screen preview.
    enum Accent { case none, moon, aurora, planet, lanterns, rain, bigStars }

    let id: String
    let name: String
    let subtitle: String
    let description: String
    let category: Category
    let unlockRequirement: UnlockRequirement
    /// Optional art assets — previews are fully procedural when these are absent,
    /// so the catalog never depends on bundled images.
    var previewImageName: String? = nil
    var thumbnailImageName: String? = nil
    /// Top → bottom full-screen preview gradient (3–4 stops).
    let moodPalette: [UInt]
    /// Warm light source colour for the preview glow.
    let glowHex: UInt
    /// Silhouette drawn low in the preview (reuses the postcard landmark art).
    let landmark: Landmark
    let accent: Accent
    /// Star density for the preview (0 = none, 1 = dense night).
    let stars: Double
    /// Ambient-activity band this Sky tends to sit in (drives `SkyActivity`).
    let estimatedActivityRange: ClosedRange<Int>
    /// Default soundscape (a `JourneyAudioOption` id) suggested for this Sky.
    let soundscapeID: String
    /// Closest existing ritual/backdrop preset (a `SkyScene` id) — the safe
    /// fallback mapping until every Sky has a bespoke visual preset.
    let visualPresetID: String
    /// Which flight-world opening sequence best matches this Sky (0…3, see
    /// `FlightWorldSequence.openings`); `nil` keeps the seeded random opening.
    let flightOpening: Int?

    var isDefaultFree: Bool { unlockRequirement == .free }
    var isPremium: Bool { unlockRequirement == .premiumOrInvites }
    var requiresPremiumOrInvites: Bool { unlockRequirement == .premiumOrInvites }
    var isCitySky: Bool { category == .city }
    var isNatureSky: Bool { category == .nature }
    var isCosmicSky: Bool { category == .cosmic }

    var paletteColors: [Color] { moodPalette.map { Color(hex: $0) } }
    var glowColor: Color { Color(hex: glowHex) }

    /// The ritual/backdrop scene this Sky maps to (never nil — falls back gold).
    var scene: SkyScene { SkyScene.all.first { $0.id == visualPresetID } ?? .goldenHour }

    // MARK: Catalog

    static let goldenHour = FocusSky(
        id: "golden-hour", name: "Golden Hour", subtitle: "Free Sky",
        description: "Warm sunset light over peaceful mountains — the home of every first flight.",
        category: .nature, unlockRequirement: .free,
        moodPalette: [0x2E2350, 0x9A4A56, 0xF29B5C, 0xF6C08A], glowHex: 0xFFC873,
        landmark: .mountain, accent: .none, stars: 0.08,
        estimatedActivityRange: 140...320, soundscapeID: "wind",
        visualPresetID: "sky-golden-hour", flightOpening: 1)

    static let all: [FocusSky] = [
        goldenHour,
        FocusSky(id: "paris-sunset", name: "Paris Sunset", subtitle: "City Sky",
                 description: "A romantic warm dusk over the rooftops, the tower resting far below.",
                 category: .city, unlockRequirement: .premiumOrInvites,
                 moodPalette: [0x33234E, 0x8E4A66, 0xE08A6A, 0xF2BE8C], glowHex: 0xF6B27A,
                 landmark: .tower, accent: .none, stars: 0.12,
                 estimatedActivityRange: 90...260, soundscapeID: "jazz",
                 visualPresetID: "sky-golden-hour", flightOpening: 1),
        FocusSky(id: "fiji-lagoon", name: "Fiji Lagoon", subtitle: "Nature Sky",
                 description: "Turquoise air over a quiet lagoon, soft islands drifting far below.",
                 category: .nature, unlockRequirement: .premiumOrInvites,
                 moodPalette: [0x0E3A4E, 0x1E6E7E, 0x4FB4B4, 0xBFE8D8], glowHex: 0xA8F0DC,
                 landmark: .island, accent: .none, stars: 0.05,
                 estimatedActivityRange: 60...180, soundscapeID: "ocean",
                 visualPresetID: "sky-golden-hour", flightOpening: 1),
        FocusSky(id: "kyoto-lanterns", name: "Kyoto Lanterns", subtitle: "City Sky",
                 description: "A calm Japanese evening — lantern glow and quiet temple roofs below.",
                 category: .city, unlockRequirement: .premiumOrInvites,
                 moodPalette: [0x1E1638, 0x442A52, 0x8E4658, 0xE09A6E], glowHex: 0xF2AA6A,
                 landmark: .pagoda, accent: .lanterns, stars: 0.25,
                 estimatedActivityRange: 70...200, soundscapeID: "relaxing",
                 visualPresetID: "sky-silent-dawn", flightOpening: 2),
        FocusSky(id: "aurora-snowfield", name: "Aurora Snowfield", subtitle: "Nature Sky",
                 description: "Curtains of green and violet breathing over silent snow.",
                 category: .nature, unlockRequirement: .premiumOrInvites,
                 moodPalette: [0x040A18, 0x0C2238, 0x14524E, 0x54E0A8], glowHex: 0x54E0A8,
                 landmark: .aurora, accent: .aurora, stars: 0.7,
                 estimatedActivityRange: 50...170, soundscapeID: "wind",
                 visualPresetID: "sky-starfield", flightOpening: 2),
        FocusSky(id: "moon-garden", name: "Moon Garden", subtitle: "Cosmic Sky",
                 description: "A vast pale moon and quiet night clouds, lit in cream.",
                 category: .cosmic, unlockRequirement: .premiumOrInvites,
                 moodPalette: [0x0E1428, 0x1E2A44, 0x3A4A66, 0x8A98B4], glowHex: 0xEDF2FB,
                 landmark: .generic, accent: .moon, stars: 0.55,
                 estimatedActivityRange: 60...190, soundscapeID: "relaxing",
                 visualPresetID: "sky-starfield", flightOpening: 3),
        FocusSky(id: "galaxy-drift", name: "Galaxy Drift", subtitle: "Cosmic Sky",
                 description: "Purple-blue nebula mist and distant stars, drifting slowly.",
                 category: .cosmic, unlockRequirement: .premiumOrInvites,
                 moodPalette: [0x0A0620, 0x1C1048, 0x3A2E7E, 0x6E4AE8], glowHex: 0x8F7BE8,
                 landmark: .generic, accent: .planet, stars: 0.9,
                 estimatedActivityRange: 80...240, soundscapeID: "alpha-waves",
                 visualPresetID: "sky-starfield", flightOpening: 2),
        FocusSky(id: "deep-space", name: "Deep Space", subtitle: "Cosmic Sky",
                 description: "Planets, a dense starfield, and complete cosmic silence.",
                 category: .cosmic, unlockRequirement: .premiumOrInvites,
                 moodPalette: [0x020308, 0x060B18, 0x0E1430, 0x1C2448], glowHex: 0x6E7EC8,
                 landmark: .generic, accent: .planet, stars: 1.0,
                 estimatedActivityRange: 40...150, soundscapeID: "alpha-waves",
                 visualPresetID: "sky-starfield", flightOpening: 0),
        FocusSky(id: "rainy-tokyo", name: "Rainy Tokyo", subtitle: "City Sky",
                 description: "Soft rain over a muted neon skyline — cozy, blue, and quiet.",
                 category: .city, unlockRequirement: .premiumOrInvites,
                 moodPalette: [0x0C1224, 0x1A2440, 0x2E3A60, 0x50548E], glowHex: 0x8FA6D8,
                 landmark: .skyline, accent: .rain, stars: 0.2,
                 estimatedActivityRange: 100...280, soundscapeID: "rain",
                 visualPresetID: "sky-starfield", flightOpening: 0),
        FocusSky(id: "swiss-alps", name: "Swiss Alps", subtitle: "Nature Sky",
                 description: "High snowy peaks in a cold, clean sunrise glow.",
                 category: .nature, unlockRequirement: .premiumOrInvites,
                 moodPalette: [0x1A2E44, 0x3A5C7C, 0x7C9CB8, 0xE8EEF4], glowHex: 0xF6D9B4,
                 landmark: .mountain, accent: .none, stars: 0.1,
                 estimatedActivityRange: 50...160, soundscapeID: "wind",
                 visualPresetID: "sky-silent-dawn", flightOpening: 2),
        FocusSky(id: "sahara-night", name: "Sahara Night", subtitle: "Nature Sky",
                 description: "Warm dunes under a huge, star-heavy desert night.",
                 category: .nature, unlockRequirement: .premiumOrInvites,
                 moodPalette: [0x0A0A1E, 0x201838, 0x4A2E44, 0x8E5A46], glowHex: 0xE8B080,
                 landmark: .desert, accent: .bigStars, stars: 0.8,
                 estimatedActivityRange: 40...140, soundscapeID: "wind",
                 visualPresetID: "sky-starfield", flightOpening: 3),
        FocusSky(id: "santorini-dawn", name: "Santorini Dawn", subtitle: "City Sky",
                 description: "A Mediterranean sunrise — cream domes far below, ocean glow ahead.",
                 category: .city, unlockRequirement: .premiumOrInvites,
                 moodPalette: [0x2C2452, 0x8A5C88, 0xF0A88E, 0xF6CCB2], glowHex: 0xFFB79E,
                 landmark: .dome, accent: .none, stars: 0.06,
                 estimatedActivityRange: 60...190, soundscapeID: "ocean",
                 visualPresetID: "sky-silent-dawn", flightOpening: 1),
    ]

    static func byID(_ id: String?) -> FocusSky? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    /// The Sky embedded in a synthetic flight route id (routes are named
    /// "flight-25m-<skyID>" / "flight-infinity-<skyID>"), used to bias the
    /// flight world — resume-safe because the id is persisted with the route.
    static func matching(routeID: String) -> FocusSky? {
        all.first { routeID.hasSuffix($0.id) || routeID.contains("-\($0.id)") }
    }
}

// MARK: - Unlock rules

/// Pure unlock logic for Skies — free Sky always; Premium unlocks all; inviting
/// 3 friends unlocks all. Kept as pure functions so a future backend-driven
/// entitlement can slot in without touching call sites.
enum SkyUnlock {
    static let invitesNeeded = 3

    static func isUnlocked(_ sky: FocusSky, isPro: Bool, acceptedInvites: Int) -> Bool {
        if sky.isDefaultFree { return true }
        if isPro { return true }
        return acceptedInvites >= invitesNeeded
    }
}

// MARK: - Ambient Sky activity

/// **Simulated** ambient activity for a Sky — a calm, deterministic count that
/// makes Skies feel alive. `isLive` is `false` until a real backend provides
/// counts; the UI must treat this as *Sky activity*, never as verified real
/// users. Designed so a server-backed provider can replace it 1:1 later.
enum SkyActivity {
    /// Whether counts come from a live backend. Always false for now.
    static let isLive = false

    /// A deterministic ambient count inside the Sky's activity band: stable for
    /// ~10 minutes at a time, gently different per Sky and hour of day, with
    /// evenings running busier. Never random per frame.
    static func count(for sky: FocusSky, at date: Date = Date()) -> Int {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let bucket = Int(date.timeIntervalSince1970 / 600)   // 10-minute stability
        var h: UInt64 = 0x9E37_79B9
        for u in sky.id.unicodeScalars { h = (h &* 31) &+ UInt64(u.value) }
        h = h &+ UInt64(bucket) &* 0x517C_C1B7
        h ^= h >> 33; h = h &* 0xFF51_AFD7_ED55_8CCD; h ^= h >> 29
        let span = sky.estimatedActivityRange.upperBound - sky.estimatedActivityRange.lowerBound
        let base = sky.estimatedActivityRange.lowerBound + Int(h % UInt64(max(1, span)))
        // Evenings breathe higher; small hours lower — still inside a sane band.
        let evening = (hour >= 19 || hour < 1) ? 1.18 : (hour < 7 ? 0.72 : 1.0)
        return max(8, Int(Double(base) * evening))
    }
}
