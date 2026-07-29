import Foundation

/// Shared, **dependency-free** layer between the FocusGlobe app and its WidgetKit
/// extension. It uses only Foundation types so the very same file can be a member
/// of BOTH targets (the app writes a snapshot; the widgets read it).
///
/// Setup (see WIDGETS_SETUP.md):
///  • Enable the App Group `FocusGlobeShared.appGroupID` on the app target **and**
///    the widget extension target.
///  • Add this file to the widget extension target's membership (it already
///    compiles into the app via the file-system-synchronised group).
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

    // MARK: Final-5 widget data
    /// Total real completed focused seconds (cancelled excluded) — the ONE
    /// authoritative total, shared with the app.
    var totalFocusedSeconds = 0
    /// Distinct local calendar days with ≥1 qualifying (≥300 s) session.
    var activeFocusDays = 0
    /// Whether TODAY already qualifies (drives the Streak Companion's state).
    var focusedToday = false
    /// Local day-ordinals (days since 1970-01-01, local calendar) that are
    /// active — the 26-week Focus Grid is rebuilt from this set on the widget.
    var activeDayOrdinals: [Int] = []
    /// Local day-ordinal → focus-category key ("" = uncategorised) of the MOST
    /// RECENTLY completed qualifying journey that day, so the widget grid tints
    /// each lit day by category (parity with Passport). Missing ⇒ older snapshot
    /// ⇒ the grid falls back to a single accent.
    var activeDayCategories: [Int: String] = [:]
    /// The selected Sky's name + gradient (idle Focus Now / Streak backdrop).
    var selectedSkyName: String?
    /// Lightweight production artwork identifier embedded in the widget target.
    var selectedSkyArtworkName: String?
    var skyTopHex = 0
    var skyBottomHex = 0
    /// Active flight (Focus Now live state). `activeEndDate` drives a native
    /// `Text(timerInterval:)` countdown; nil endDate + `activeInfinite` = ∞.
    var activeFlight = false
    var activeEndDate: Date?
    var activeInfinite = false
    var activeSkyName: String?
    var activeSkyArtworkName: String?
    var activeCategory: String?
    // Badges (Badge Collection)
    var badges: [WidgetBadge] = []
    var badgeUnlockedCount = 0
    var badgeTotal = 0

    var updatedAt = Date(timeIntervalSince1970: 0)

    /// Total focused time as minutes (widget stat).
    var totalFocusedMinutes: Int { totalFocusedSeconds / 60 }

    /// The next locked badge to hint at, if any.
    var nextBadge: WidgetBadge? { badges.first { !$0.earned } }

    /// Laps "around the Earth" earned so far (focus miles are distance-based).
    var aroundEarthLaps: Double {
        Double(totalFocusMiles) / Double(FocusGlobeShared.earthCircumferenceKm)
    }

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
        selectedSkyName: "Desert Night", selectedSkyArtworkName: "WidgetSky_DesertNight",
        skyTopHex: 0x0A0A1E, skyBottomHex: 0x8E5A46,
        updatedAt: Date())
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
        selectedSkyArtworkName = v(.selectedSkyArtworkName, selectedSkyArtworkName)
        skyTopHex = v(.skyTopHex, skyTopHex)
        skyBottomHex = v(.skyBottomHex, skyBottomHex)
        activeFlight = v(.activeFlight, activeFlight)
        activeEndDate = v(.activeEndDate, activeEndDate)
        activeInfinite = v(.activeInfinite, activeInfinite)
        activeSkyName = v(.activeSkyName, activeSkyName)
        activeSkyArtworkName = v(.activeSkyArtworkName, activeSkyArtworkName)
        activeCategory = v(.activeCategory, activeCategory)
        badges = v(.badges, badges)
        badgeUnlockedCount = v(.badgeUnlockedCount, badgeUnlockedCount)
        badgeTotal = v(.badgeTotal, badgeTotal)
        updatedAt = v(.updatedAt, updatedAt)
    }
}

/// Tiny read/write façade over the App Group `UserDefaults`. Safe before the App
/// Group is configured: it falls back to `.standard` (the widget simply shows
/// placeholders until the group links the two processes).
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
