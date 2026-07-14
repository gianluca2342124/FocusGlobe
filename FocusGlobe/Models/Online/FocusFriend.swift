import Foundation

/// An accepted Crew connection, plus the lightweight profile we display.
struct FocusFriend: Identifiable, Equatable, Sendable {
    let id: String                 // connectionID
    let publicID: String           // the other participant
    var displayName: String
    var balloonSkinID: String
    var countryCode: String?
    var since: Date
    /// Live presence, when a real recent heartbeat exists (never fabricated).
    var activePilot: OnlinePilot?
}
