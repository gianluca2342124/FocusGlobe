import Foundation

/// The result of a completed journey, shown on the Landing screen.
struct LandingSummary: Equatable, Identifiable {
    let id: UUID            // matches the saved FocusSessionRecord
    let route: Route
    let intention: String?
    let focusedSeconds: Int
    let distanceKm: Double
    let baseMiles: Int
    let postcard: Postcard
    let streak: Int
    let isNewRoute: Bool
    let isNewBest: Bool

    var focusedMinutes: Int { focusedSeconds / 60 }
}
