import Foundation

/// The result of a completed journey, shown on the Landing screen.
struct LandingSummary: Equatable, Identifiable {
    let id: UUID            // matches the saved FocusSessionRecord
    let route: Route
    /// The city the journey departed from (the user's live location).
    let originName: String
    let intention: String?
    let focusedSeconds: Int
    let distanceKm: Double
    let baseMiles: Int
    let postcard: Postcard
    let streak: Int
    let isNewRoute: Bool
    let isNewBest: Bool
    /// `true` when this landing pushed the daily streak up (new day), so Landing
    /// can play a one-time streak micro-celebration.
    var streakIncreased: Bool = false
    /// `true` when `baseMiles` already includes the PRO journey multiplier, so
    /// Landing can say so. It is a statement about THIS reward, not a live
    /// entitlement read — a summary shown after an expiry must not retroactively
    /// claim a badge the coins were never granted under.
    var proMultiplierApplied: Bool = false

    var focusedMinutes: Int { focusedSeconds / 60 }
}
