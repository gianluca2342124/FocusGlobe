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
    var bestFocusMinutes = 0
    var postcardCount = 0

    // Resume / current journey
    var hasResumable = false
    var resumeOriginCity: String?
    var resumeDestinationCity: String?
    var resumeRemainingSeconds: Int?
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

    var updatedAt = Date(timeIntervalSince1970: 0)

    /// Laps "around the Earth" earned so far (focus miles are distance-based).
    var aroundEarthLaps: Double {
        Double(totalFocusMiles) / Double(FocusGlobeShared.earthCircumferenceKm)
    }

    /// Rich sample data for previews / the widget gallery.
    static let placeholder = WidgetSnapshot(
        isPro: true,
        originCity: "Barcelona", originCode: "BCN",
        totalFocusMiles: 12_022, landings: 18, currentStreak: 4,
        bestFocusMinutes: 90, postcardCount: 12,
        hasResumable: true, resumeOriginCity: "Paris",
        resumeDestinationCity: "Rome", resumeRemainingSeconds: 900, resumeProgress: 0.55,
        longestRouteOrigin: "Lisbon", longestRouteDestination: "Reykjavík",
        longestRouteKm: 2_480, longestRouteDurationMinutes: 50,
        goals: [
            WidgetGoal(title: "Complete a journey", systemImage: "paperplane.fill", current: 1, target: 1),
            WidgetGoal(title: "Focus 30 minutes", systemImage: "timer", current: 18, target: 30),
            WidgetGoal(title: "Visit a new place", systemImage: "mappin.and.ellipse", current: 0, target: 1),
            WidgetGoal(title: "Earn 60 miles", systemImage: "sparkles", current: 60, target: 60),
        ],
        goalsCompleted: 2, goalsTotal: 4, canClaimReward: false,
        updatedAt: Date())
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
