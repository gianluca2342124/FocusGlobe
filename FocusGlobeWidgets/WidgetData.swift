import Foundation

// ============================================================================
//  Widget-target copy of the shared data models.
//
//  WHY A COPY: the app's canonical file lives at
//  `FocusGlobe/Shared/WidgetSharedData.swift`, which belongs to the **app**
//  target's file-system-synchronised group. With Xcode 16 synchronised groups a
//  single file can't auto-belong to two targets, so this mirror lives inside the
//  `FocusGlobeWidgets/` group and compiles into the **widget extension** target.
//
//  The two files are byte-for-byte equivalent **types** (the App Group exchanges
//  Codable JSON keyed by field name, so identical structs interop perfectly).
//  Keep them in sync. Do NOT also add the app's `WidgetSharedData.swift` to the
//  widget target — that would redefine these types. See WIDGETS_SETUP.md.
// ============================================================================

enum FocusGlobeShared {
    /// App Group identifier — must be enabled (identical) on both targets so the
    /// widget process can read what the app writes.
    static let appGroupID = "group.com.focusglobe.app"
    /// Custom URL scheme used by widget deep links (`focusglobe://…`).
    static let urlScheme = "focusglobe"
    /// Approximate equatorial circumference of the Earth, for "around Earth" math.
    static let earthCircumferenceKm = 40_075
    /// Bonus miles granted for completing all daily goals (mirrors the app).
    static let dailyGoalRewardMiles = 50

    fileprivate static let snapshotKey = "fg.widget.snapshot.v1"
}

/// One daily goal, flattened for the widgets.
struct WidgetGoal: Codable, Hashable {
    var title: String
    var systemImage: String
    var current: Double
    var target: Double

    var isComplete: Bool { current >= target }
    var fraction: Double { target <= 0 ? 1 : min(1, current / target) }
}

/// A badge, flattened for the Badge Collection widget.
struct WidgetBadge: Codable, Hashable {
    var name: String
    var icon: String
    var earned: Bool
}

/// A small, read-only snapshot of app state the widgets render. Written by the
/// app whenever the underlying data changes; read by the widget timeline.
struct WidgetSnapshot: Codable, Hashable {
    var isPro = false

    // Origin / location
    var originCity: String?
    var originCode: String?

    // Passport / lifetime stats
    var totalFocusMiles = 0
    var landings = 0
    var currentStreak = 0
    var longestStreak = 0
    var bestFocusMinutes = 0
    var postcardCount = 0

    // Collection
    var selectedSkinName: String?

    // Resume / current journey
    var hasResumable = false
    var resumeOriginCity: String?
    var resumeOriginCode: String?
    var resumeDestinationCity: String?
    var resumeDestinationCode: String?
    var resumeRemainingSeconds: Int?
    var resumeRouteKm: Int?
    var resumeProgress: Double?

    // Longest completed route
    var longestRouteOrigin: String?
    var longestRouteDestination: String?
    var longestRouteKm: Int?
    var longestRouteDurationMinutes: Int?

    // Daily goals
    var goals: [WidgetGoal] = []
    var goalsCompleted = 0
    var goalsTotal = 0
    var canClaimReward = false

    // MARK: Final-5 widget data (keep in sync with the app's WidgetSharedData)
    var totalFocusedSeconds = 0
    var activeFocusDays = 0
    var focusedToday = false
    var activeDayOrdinals: [Int] = []
    /// Local day-ordinal → focus-category key ("" = uncategorised) of the MOST
    /// RECENTLY completed qualifying journey that day (parity with Passport).
    var activeDayCategories: [Int: String] = [:]
    var selectedSkyName: String?
    var skyTopHex = 0
    var skyBottomHex = 0
    var activeFlight = false
    var activeEndDate: Date?
    var activeInfinite = false
    var activeSkyName: String?
    var activeCategory: String?
    var badges: [WidgetBadge] = []
    var badgeUnlockedCount = 0
    var badgeTotal = 0

    var updatedAt = Date(timeIntervalSince1970: 0)

    /// Laps "around the Earth" earned so far (focus miles are distance-based).
    var aroundEarthLaps: Double {
        Double(totalFocusMiles) / Double(FocusGlobeShared.earthCircumferenceKm)
    }

    var totalFocusedMinutes: Int { totalFocusedSeconds / 60 }
    var nextBadge: WidgetBadge? { badges.first { !$0.earned } }

    /// Rich sample data for previews / the widget gallery.
    static let placeholder = WidgetSnapshot(
        isPro: true,
        originCity: "San Francisco", originCode: "SFO",
        totalFocusMiles: 12_022, landings: 18, currentStreak: 4, longestStreak: 9,
        bestFocusMinutes: 90, postcardCount: 12,
        selectedSkinName: "King",
        hasResumable: true,
        resumeOriginCity: "San Francisco", resumeOriginCode: "SFO",
        resumeDestinationCity: "Los Angeles", resumeDestinationCode: "LAX",
        resumeRemainingSeconds: 2_520, resumeRouteKm: 559, resumeProgress: 0.55,
        longestRouteOrigin: "Lisbon", longestRouteDestination: "Reykjavík",
        longestRouteKm: 2_480, longestRouteDurationMinutes: 50,
        goals: [
            WidgetGoal(title: "Complete one flight", systemImage: "paperplane.fill", current: 1, target: 1),
            WidgetGoal(title: "Focus 30 minutes", systemImage: "timer", current: 18, target: 30),
            WidgetGoal(title: "Unlock a new badge", systemImage: "rosette", current: 0, target: 1),
            WidgetGoal(title: "Earn 10 Focus Coins", systemImage: "circle.hexagongrid.fill", current: 10, target: 10),
        ],
        goalsCompleted: 2, goalsTotal: 4, canClaimReward: false,
        totalFocusedSeconds: 41_400, activeFocusDays: 37, focusedToday: true,
        activeDayOrdinals: WidgetSnapshot.sampleOrdinals,
        selectedSkyName: "Desert Night", skyTopHex: 0x0A0A1E, skyBottomHex: 0x8E5A46,
        badges: [
            WidgetBadge(name: "First Flight", icon: "airplane.departure", earned: true),
            WidgetBadge(name: "10 Flights", icon: "10.circle.fill", earned: true),
            WidgetBadge(name: "7-Day Streak", icon: "bolt.heart.fill", earned: true),
            WidgetBadge(name: "500 Focus Minutes", icon: "clock.badge.checkmark.fill", earned: true),
            WidgetBadge(name: "1,000 Focus Minutes", icon: "infinity.circle.fill", earned: false),
            WidgetBadge(name: "14-Day Streak", icon: "flame.circle.fill", earned: false),
        ],
        badgeUnlockedCount: 4, badgeTotal: 6,
        updatedAt: Date())

    /// A pleasant, deterministic set of recent active-day ordinals for previews.
    static let sampleOrdinals: [Int] = {
        let todayOrd = Int((Date().timeIntervalSince1970 / 86_400).rounded(.down))
        // A believable ~5-days-a-week pattern over the last ~12 weeks.
        return (0..<84).compactMap { d in (d % 7 != 5 && d % 7 != 6 && d % 3 != 2) ? todayOrd - d : nil }
    }()
}

extension WidgetSnapshot {
    /// A resilient decoder: every field falls back to its default when missing or
    /// malformed, so a snapshot written by an older (or newer) app version always
    /// decodes — it never throws, never crashes, never wipes the widget as the
    /// schema evolves. Encoding stays synthesized (always writes the full schema).
    init(from decoder: Decoder) throws {
        self.init()
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else { return }
        func v<T: Decodable>(_ key: CodingKeys, _ def: T) -> T {
            (try? c.decode(T.self, forKey: key)) ?? def
        }
        isPro = v(.isPro, isPro)
        originCity = v(.originCity, originCity)
        originCode = v(.originCode, originCode)
        totalFocusMiles = v(.totalFocusMiles, totalFocusMiles)
        landings = v(.landings, landings)
        currentStreak = v(.currentStreak, currentStreak)
        longestStreak = v(.longestStreak, longestStreak)
        bestFocusMinutes = v(.bestFocusMinutes, bestFocusMinutes)
        postcardCount = v(.postcardCount, postcardCount)
        selectedSkinName = v(.selectedSkinName, selectedSkinName)
        hasResumable = v(.hasResumable, hasResumable)
        resumeOriginCity = v(.resumeOriginCity, resumeOriginCity)
        resumeOriginCode = v(.resumeOriginCode, resumeOriginCode)
        resumeDestinationCity = v(.resumeDestinationCity, resumeDestinationCity)
        resumeDestinationCode = v(.resumeDestinationCode, resumeDestinationCode)
        resumeRemainingSeconds = v(.resumeRemainingSeconds, resumeRemainingSeconds)
        resumeRouteKm = v(.resumeRouteKm, resumeRouteKm)
        resumeProgress = v(.resumeProgress, resumeProgress)
        longestRouteOrigin = v(.longestRouteOrigin, longestRouteOrigin)
        longestRouteDestination = v(.longestRouteDestination, longestRouteDestination)
        longestRouteKm = v(.longestRouteKm, longestRouteKm)
        longestRouteDurationMinutes = v(.longestRouteDurationMinutes, longestRouteDurationMinutes)
        goals = v(.goals, goals)
        goalsCompleted = v(.goalsCompleted, goalsCompleted)
        goalsTotal = v(.goalsTotal, goalsTotal)
        canClaimReward = v(.canClaimReward, canClaimReward)
        totalFocusedSeconds = v(.totalFocusedSeconds, totalFocusedSeconds)
        activeFocusDays = v(.activeFocusDays, activeFocusDays)
        focusedToday = v(.focusedToday, focusedToday)
        activeDayOrdinals = v(.activeDayOrdinals, activeDayOrdinals)
        activeDayCategories = v(.activeDayCategories, activeDayCategories)
        selectedSkyName = v(.selectedSkyName, selectedSkyName)
        skyTopHex = v(.skyTopHex, skyTopHex)
        skyBottomHex = v(.skyBottomHex, skyBottomHex)
        activeFlight = v(.activeFlight, activeFlight)
        activeEndDate = v(.activeEndDate, activeEndDate)
        activeInfinite = v(.activeInfinite, activeInfinite)
        activeSkyName = v(.activeSkyName, activeSkyName)
        activeCategory = v(.activeCategory, activeCategory)
        badges = v(.badges, badges)
        badgeUnlockedCount = v(.badgeUnlockedCount, badgeUnlockedCount)
        badgeTotal = v(.badgeTotal, badgeTotal)
        updatedAt = v(.updatedAt, updatedAt)
    }
}

/// Tiny read/write façade over the App Group `UserDefaults`. Safe before the App
/// Group is configured: it falls back to `.standard` (the widget simply shows
/// placeholders until the group links the two processes — it never crashes).
enum WidgetStore {
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: FocusGlobeShared.appGroupID) ?? .standard
    }

    static func read() -> WidgetSnapshot {
        guard let data = defaults.data(forKey: FocusGlobeShared.snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return WidgetSnapshot() }
        return snapshot
    }

    static func write(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: FocusGlobeShared.snapshotKey)
    }
}
