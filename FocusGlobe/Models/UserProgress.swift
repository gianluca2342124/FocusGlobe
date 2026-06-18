import Foundation

/// Aggregate progress for the Passport, Home and History screens. Persisted
/// locally; contains no personal data.
struct UserProgress: Codable, Equatable {
    var totalFocusMiles: Int = 0
    var completedRouteIDs: Set<String> = []
    var postcards: [Postcard] = []
    var landings: Int = 0
    var bestFocusSeconds: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    /// Start-of-day of the most recent landing, used for streak math.
    var lastLandingDay: Date? = nil

    static let empty = UserProgress()

    var hasAnyProgress: Bool {
        totalFocusMiles > 0 || landings > 0 || !postcards.isEmpty
    }

    var bestFocusMinutes: Int { bestFocusSeconds / 60 }
}
