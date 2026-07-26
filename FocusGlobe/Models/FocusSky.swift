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

    /// How a Sky is earned. Every non-free requirement is **also** satisfied by
    /// Premium. Free-path requirements (invites / focus minutes / streak days)
    /// are checked against live on-device progress; invite unlocks additionally
    /// persist once the referral pipeline confirms them.
    enum UnlockRequirement: Hashable {
        case free
        case premium                 // Premium only
        case invite(Int)             // invite N friends OR Premium
        case focusMinutes(Int)       // reach N lifetime focus minutes OR Premium
        case streakDays(Int)         // reach an N-day streak OR Premium
    }
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
    /// Legacy field from the retired chapter-tape flight world — kept only so
    /// the catalog entries stay stable; the living-sky renderer ignores it.
    let flightOpening: Int?

    /// The Sky's weather/identity particles inside the living flight sky.
    enum FlightParticle { case none, snow, rain, lanterns }

    /// Which particles this Sky's flight renders (snow/rain fall as weather;
    /// lanterns are gentle local moments).
    var flightParticles: FlightParticle {
        switch id {
        case "kyoto-lanterns":                 return .lanterns
        case "aurora-snowfield", "swiss-alps": return .snow
        case "rainy-tokyo":                    return .rain
        default:                               return .none
        }
    }


    var isDefaultFree: Bool { if case .free = unlockRequirement { return true }; return false }
    /// "Premium-gated" in the loose sense: anything that isn't the free Sky.
    var isPremium: Bool { !isDefaultFree }
    var requiresPremiumOrInvites: Bool { !isDefaultFree }

    /// The invite count this Sky needs on its free path (nil if not invite-based).
    var invitesRequired: Int? {
        if case .invite(let n) = unlockRequirement { return n }
        return nil
    }

    /// A short label for the Sky's free unlock path (used on the unlock sheet).
    var unlockMethodLabel: String {
        switch unlockRequirement {
        case .free:              return "Free"
        case .premium:           return "FocusGlobe PRO only"
        case .invite(let n):     return "Invite \(n) friend\(n == 1 ? "" : "s")"
        case .focusMinutes(let n): return "\(n) focus minutes"
        case .streakDays(let n): return "\(n)-day streak"
        }
    }

    /// Progress on the free path as "current/target", or nil for free / premium-only.
    func unlockProgressText(focusMinutes: Int, streakDays: Int, invites: Int) -> String? {
        switch unlockRequirement {
        case .free, .premium:      return nil
        case .invite(let n):       return "\(min(invites, n))/\(n) friends"
        case .focusMinutes(let n): return "\(min(focusMinutes, n))/\(n) min"
        case .streakDays(let n):   return "\(min(streakDays, n))/\(n) days"
        }
    }

    /// Fractional progress (0…1) on the free path, or nil when none applies.
    func unlockFraction(focusMinutes: Int, streakDays: Int, invites: Int) -> Double? {
        switch unlockRequirement {
        case .free, .premium:      return nil
        case .invite(let n):       return n <= 0 ? 1 : min(1, Double(invites) / Double(n))
        case .focusMinutes(let n): return n <= 0 ? 1 : min(1, Double(focusMinutes) / Double(n))
        case .streakDays(let n):   return n <= 0 ? 1 : min(1, Double(streakDays) / Double(n))
        }
    }

    var isCitySky: Bool { category == .city }
    var isNatureSky: Bool { category == .nature }
    var isCosmicSky: Bool { category == .cosmic }

    var paletteColors: [Color] { moodPalette.map { Color(hex: $0) } }
    var glowColor: Color { Color(hex: glowHex) }

    // MARK: Asset naming (drop-in art; procedural fallbacks always compile)

    /// "rainy-tokyo" → "RainyTokyo": the asset-safe PascalCase base name.
    var assetBaseName: String {
        id.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }
    /// Full-screen background art: `Sky_RainyTokyo_Background_Portrait` /
    /// `…_Landscape`. Missing assets fall back to the procedural scene.
    func backgroundAssetName(landscape: Bool) -> String {
        "Sky_\(assetBaseName)_Background_\(landscape ? "Landscape" : "Portrait")"
    }

    /// The ONE centralized Sky → hero artwork mapping. The base name is keyed to
    /// the marketing name (not the persistent id); `orientedArtworkAssetName`
    /// appends the device composition. Until art ships, every surface falls back
    /// to the live procedural scene — never a blank or a crash. Keep all artwork
    /// names here so no screen hard-codes its own.
    ///
    ///   SkyArtwork_DesertNight · SkyArtwork_FijiLagoon ·
    ///   SkyArtwork_KyotoLanternNight · SkyArtwork_NorthernAurora ·
    ///   SkyArtwork_RainyTokyo · SkyArtwork_SwissAlps ·
    ///   SkyArtwork_StarfallNebula · SkyArtwork_DeepSpace
    var artworkAssetName: String {
        switch id {
        case "sahara-night":     return "SkyArtwork_DesertNight"
        case "fiji-lagoon":      return "SkyArtwork_FijiLagoon"
        case "kyoto-lanterns":   return "SkyArtwork_KyotoLanternNight"
        case "aurora-snowfield": return "SkyArtwork_NorthernAurora"
        case "rainy-tokyo":      return "SkyArtwork_RainyTokyo"
        case "swiss-alps":       return "SkyArtwork_SwissAlps"
        case "galaxy-drift":     return "SkyArtwork_StarfallNebula"
        case "deep-space":       return "SkyArtwork_DeepSpace"
        default:                 return "SkyArtwork_\(assetBaseName)"
        }
    }

    /// The production artwork pair for this Sky:
    /// `SkyArtwork_DesertNight_Portrait` / `…_Landscape`.
    func orientedArtworkAssetName(landscape: Bool) -> String {
        "\(artworkAssetName)_\(landscape ? "Landscape" : "Portrait")"
    }
    /// The take-off ground plate (`Sky_RainyTokyo_Ground`) — shown only during
    /// lift-off, never tiled or repeated.
    var groundAssetName: String { "Sky_\(assetBaseName)_Ground" }

    /// The ritual/backdrop scene this Sky maps to (never nil — falls back gold).
    var scene: SkyScene { SkyScene.all.first { $0.id == visualPresetID } ?? .goldenHour }

    // MARK: Catalog

    // NOTE ON NAMES: `name` is the USER-FACING display name only. The `id`,
    // asset names, persistence keys and backend identifiers never change with a
    // rename — saved selections, analytics, Supabase records, routes and unlock
    // progress all key off `id`. Historical session records store the display
    // name at flight time; `currentDisplayName(forHistorical:)` maps old names
    // forward so Passport stats/badges stay continuous across renames.
    /// The default free Sky — a vast, silent desert night. (Internal id stays
    /// "sahara-night" so saved selections, analytics, routes and unlock progress
    /// remain stable; only the user-facing name is "Desert Night".)
    static let desertNight = FocusSky(
        id: "sahara-night", name: "Desert Night", subtitle: "Free Sky",
        description: "A vast, silent desert night under a star-heavy sky.",
        category: .nature, unlockRequirement: .free,
        moodPalette: [0x0A0A1E, 0x201838, 0x4A2E44, 0x8E5A46], glowHex: 0xE8B080,
        landmark: .desert, accent: .bigStars, stars: 0.8,
        estimatedActivityRange: 40...140, soundscapeID: "wind",
        visualPresetID: "sky-starfield", flightOpening: 3)

    /// The single canonical default: the free Sky (Desert Night). Every default
    /// and every "invalid/removed selection" fallback resolves here.
    static var defaultFree: FocusSky { all.first { $0.isDefaultFree } ?? desertNight }

    // Strategic order: free → early aspirational → varied unlock paths →
    // ultimate premium. Each Sky earns its place a different way.
    static let all: [FocusSky] = [
        desertNight,
        FocusSky(id: "fiji-lagoon", name: "Fiji Lagoon", subtitle: "Nature Sky",
                 description: "Turquoise air over a quiet lagoon, soft islands drifting far below.",
                 category: .nature, unlockRequirement: .focusMinutes(100),
                 moodPalette: [0x0E3A4E, 0x1E6E7E, 0x4FB4B4, 0xBFE8D8], glowHex: 0xA8F0DC,
                 landmark: .island, accent: .none, stars: 0.05,
                 estimatedActivityRange: 60...180, soundscapeID: "ocean",
                 visualPresetID: "sky-golden-hour", flightOpening: 1),
        FocusSky(id: "kyoto-lanterns", name: "Kyoto Lantern Night", subtitle: "City Sky",
                 description: "A calm Japanese evening — lantern glow and quiet temple roofs below.",
                 category: .city, unlockRequirement: .invite(5),
                 moodPalette: [0x1E1638, 0x442A52, 0x8E4658, 0xE09A6E], glowHex: 0xF2AA6A,
                 landmark: .pagoda, accent: .lanterns, stars: 0.25,
                 estimatedActivityRange: 70...200, soundscapeID: "relaxing",
                 visualPresetID: "sky-silent-dawn", flightOpening: 2),
        FocusSky(id: "aurora-snowfield", name: "Northern Aurora", subtitle: "Nature Sky",
                 description: "Curtains of green and violet breathing over silent snow.",
                 category: .nature, unlockRequirement: .focusMinutes(1000),
                 moodPalette: [0x040A18, 0x0C2238, 0x14524E, 0x54E0A8], glowHex: 0x54E0A8,
                 landmark: .aurora, accent: .aurora, stars: 0.7,
                 estimatedActivityRange: 50...170, soundscapeID: "wind",
                 visualPresetID: "sky-starfield", flightOpening: 2),
        FocusSky(id: "rainy-tokyo", name: "Rainy Tokyo", subtitle: "City Sky",
                 description: "Soft rain over a muted neon skyline — cozy, blue, and quiet.",
                 category: .city, unlockRequirement: .streakDays(7),
                 moodPalette: [0x0C1224, 0x1A2440, 0x2E3A60, 0x50548E], glowHex: 0x8FA6D8,
                 landmark: .skyline, accent: .rain, stars: 0.2,
                 estimatedActivityRange: 100...280, soundscapeID: "rain",
                 visualPresetID: "sky-starfield", flightOpening: 0),
        FocusSky(id: "swiss-alps", name: "Swiss Alps", subtitle: "Nature Sky",
                 description: "High snowy peaks in a cold, clean sunrise glow.",
                 category: .nature, unlockRequirement: .streakDays(14),
                 moodPalette: [0x1A2E44, 0x3A5C7C, 0x7C9CB8, 0xE8EEF4], glowHex: 0xF6D9B4,
                 landmark: .mountain, accent: .none, stars: 0.1,
                 estimatedActivityRange: 50...160, soundscapeID: "wind",
                 visualPresetID: "sky-silent-dawn", flightOpening: 2),
        FocusSky(id: "galaxy-drift", name: "Starfall Nebula", subtitle: "Cosmic Sky",
                 description: "Purple-blue nebula mist and distant stars, drifting slowly.",
                 category: .cosmic, unlockRequirement: .premium,
                 moodPalette: [0x0A0620, 0x1C1048, 0x3A2E7E, 0x6E4AE8], glowHex: 0x8F7BE8,
                 landmark: .generic, accent: .planet, stars: 0.9,
                 estimatedActivityRange: 80...240, soundscapeID: "alpha-waves",
                 visualPresetID: "sky-starfield", flightOpening: 2),
        FocusSky(id: "deep-space", name: "Deep Space", subtitle: "Cosmic Sky",
                 description: "Planets, a dense starfield, and complete cosmic silence.",
                 category: .cosmic, unlockRequirement: .focusMinutes(10000),
                 moodPalette: [0x020308, 0x060B18, 0x0E1430, 0x1C2448], glowHex: 0x6E7EC8,
                 landmark: .generic, accent: .planet, stars: 1.0,
                 estimatedActivityRange: 40...150, soundscapeID: "alpha-waves",
                 visualPresetID: "sky-starfield", flightOpening: 0),
    ]

    static func byID(_ id: String?) -> FocusSky? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    /// Display names change; history records keep the name that was current at
    /// flight time. This maps every RETIRED display name to today's, so
    /// Passport stats and badges stay continuous across renames (and removed
    /// Skies keep their historical identity). Unknown names pass through.
    static func currentDisplayName(forHistorical name: String) -> String {
        switch name {
        // The retired Amber Highlands folds forward into the new free Sky.
        case "Golden Hour", "Amber Highlands": return "Desert Night"
        case "Sahara Night":     return "Desert Night"
        case "Kyoto Lanterns":   return "Kyoto Lantern Night"
        case "Aurora Snowfield": return "Northern Aurora"
        case "Galaxy Drift":     return "Starfall Nebula"
        default:                 return name
        }
    }

    /// Every display name (past + present) a Sky has carried — for history
    /// matching (badges/stats) that must survive display renames.
    static func allDisplayNames(for sky: FocusSky) -> [String] {
        switch sky.id {
        // Desert Night inherits Sahara Night's history AND the retired
        // Amber Highlands (folded into the free Sky).
        case "sahara-night":     return ["Desert Night", "Sahara Night", "Amber Highlands", "Golden Hour"]
        case "kyoto-lanterns":   return ["Kyoto Lantern Night", "Kyoto Lanterns"]
        case "aurora-snowfield": return ["Northern Aurora", "Aurora Snowfield"]
        case "galaxy-drift":     return ["Starfall Nebula", "Galaxy Drift"]
        default:                 return [sky.name]
        }
    }

    /// The Sky embedded in a synthetic flight route id (routes are named
    /// "flight-25m-<skyID>" / "flight-infinity-<skyID>"), used to bias the
    /// flight world — resume-safe because the id is persisted with the route.
    static func matching(routeID: String) -> FocusSky? {
        all.first { routeID.hasSuffix($0.id) || routeID.contains("-\($0.id)") }
    }
}

// MARK: - Unlock rules

/// Pure unlock logic for Skies — the free Sky always; Premium unlocks all while
/// active; and inviting 3 friends unlocks **only that specific Sky** (each
/// locked Sky needs its own 3 accepted invites). Pure functions so the
/// backend-driven entitlement slots in without touching call sites.
enum SkyUnlock {
    /// Legacy constant kept for any older reference; per-Sky invite counts now
    /// come from `sky.invitesRequired`.
    static let invitesNeeded = 3

    static func isUnlocked(_ sky: FocusSky, isPro: Bool, unlockedSkyIDs: Set<String>,
                           focusMinutes: Int, streakDays: Int, invites: Int) -> Bool {
        // A Sky earned once on its free path is grandfathered permanently (see
        // `unlockedSkyIDs`), so a later change to the requirement — or a dropped
        // streak — never re-locks a Sky the pilot already reached.
        if unlockedSkyIDs.contains(sky.id) { return true }
        switch sky.unlockRequirement {
        case .free:                return true
        case .premium:             return isPro
        case .invite(let n):       return isPro || invites >= n
        case .focusMinutes(let n): return isPro || focusMinutes >= n
        case .streakDays(let n):   return isPro || streakDays >= n
        }
    }

    /// Whether a Sky's FREE path is currently satisfied (independent of PRO) —
    /// used to capture it into the permanent grandfather set.
    static func freePathMet(_ sky: FocusSky, focusMinutes: Int, streakDays: Int, invites: Int) -> Bool {
        switch sky.unlockRequirement {
        case .free:                return false   // no need to persist the free Sky
        case .premium:             return false   // PRO-only has no free path
        case .invite(let n):       return invites >= n
        case .focusMinutes(let n): return focusMinutes >= n
        case .streakDays(let n):   return streakDays >= n
        }
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

    /// A deterministic ambient count with a truthful product floor: stable for
    /// 15 minutes, distinct per Sky, and gently shaped by local hour, weekday,
    /// season and common study/exam months. Never random per frame.
    static func count(for sky: FocusSky, at date: Date = Date()) -> Int {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let weekday = cal.component(.weekday, from: date)
        let month = cal.component(.month, from: date)
        let dayOfYear = cal.ordinality(of: .day, in: .year, for: date) ?? 1
        let bucket = Int(date.timeIntervalSince1970 / 900)   // 15-minute stability
        var h: UInt64 = 0x9E37_79B9
        for u in sky.id.unicodeScalars { h = (h &* 31) &+ UInt64(u.value) }
        h = h &+ UInt64(dayOfYear) &* 0x27D4_EB2D
        h = h &+ UInt64(bucket) &* 0x517C_C1B7
        h ^= h >> 33; h = h &* 0xFF51_AFD7_ED55_8CCD; h ^= h >> 29

        // The catalog band remains each world's flavour, but every public Sky
        // reads as genuinely inhabited rather than dropping into single digits.
        let bandMidpoint = (sky.estimatedActivityRange.lowerBound
                            + sky.estimatedActivityRange.upperBound) / 2
        let base = 118 + bandMidpoint / 2 + Int(h % 46)

        let hourFactor: Double
        switch hour {
        case 0..<6:   hourFactor = 0.76
        case 6..<9:   hourFactor = 0.94
        case 9..<13:  hourFactor = 1.06
        case 13..<18: hourFactor = 1.00
        case 18..<23: hourFactor = 1.18
        default:      hourFactor = 0.98
        }

        let isWeekend = weekday == 1 || weekday == 7
        let weekendFactor = isWeekend ? (hour >= 18 ? 1.08 : 0.92) : 1.0
        let examSeasonFactor = [4, 5, 6, 10, 11].contains(month) ? 1.10 : 1.0
        let indoorSeasonFactor = [11, 12, 1, 2].contains(month) ? 1.06 : 1.0

        return max(100, Int(Double(base) * hourFactor
            * weekendFactor * examSeasonFactor * indoorSeasonFactor))
    }
}
