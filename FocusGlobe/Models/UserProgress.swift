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

    /// Day-key (yyyy-MM-dd) on which the daily-missions completion bonus was last
    /// claimed, so it can only be claimed once per day. Optional so older saved
    /// progress keeps decoding.
    var missionRewardDay: String? = nil

    init() {}

    static let empty = UserProgress()

    var hasAnyProgress: Bool {
        totalFocusMiles > 0 || landings > 0 || !postcards.isEmpty
    }

    var bestFocusMinutes: Int { bestFocusSeconds / 60 }

    private enum CodingKeys: String, CodingKey {
        case totalFocusMiles, completedRouteIDs, postcards, landings
        case bestFocusSeconds, currentStreak, longestStreak, lastLandingDay
        case missionRewardDay
    }

    /// Decode each aggregate independently so one missing field in an older
    /// build cannot zero Coins, landings, streaks and Passport data together.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalFocusMiles = max(0, try c.decodeIfPresent(Int.self, forKey: .totalFocusMiles) ?? 0)
        completedRouteIDs = (try? c.decodeIfPresent(Set<String>.self, forKey: .completedRouteIDs)) ?? []
        postcards = (try? c.decodeIfPresent([Postcard].self, forKey: .postcards)) ?? []
        landings = max(0, try c.decodeIfPresent(Int.self, forKey: .landings) ?? 0)
        bestFocusSeconds = max(0, try c.decodeIfPresent(Int.self, forKey: .bestFocusSeconds) ?? 0)
        currentStreak = max(0, try c.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0)
        longestStreak = max(currentStreak,
                            try c.decodeIfPresent(Int.self, forKey: .longestStreak) ?? 0)
        lastLandingDay = try c.decodeIfPresent(Date.self, forKey: .lastLandingDay)
        missionRewardDay = try c.decodeIfPresent(String.self, forKey: .missionRewardDay)
    }
}
