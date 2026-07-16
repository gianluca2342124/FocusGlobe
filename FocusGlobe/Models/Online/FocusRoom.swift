import Foundation

/// A private focus room (Supabase-backed). Members join through one-time
/// invite tokens; all state transitions happen through secure server RPCs.
struct FocusRoom: Identifiable, Equatable, Sendable {
    enum Status: String, Sendable {
        case lobby, active, ended, closed

        /// Maps the server's status vocabulary onto the app's.
        init(serverStatus: String) {
            switch serverStatus {
            case "lobby":     self = .lobby
            case "active":    self = .active
            case "completed": self = .ended
            default:          self = .closed   // closed / expired
            }
        }
    }
    /// Why the room exists — a shared flight, or an invite-unlock campaign.
    enum Purpose: String, Sendable { case flight, skyUnlock }

    let id: String                 // roomPublicID
    let ownerPublicID: String
    var title: String
    var skyID: String
    let createdAt: Date
    var expiresAt: Date?
    var maximumParticipants: Int
    var status: Status
    var allowsLateJoin: Bool
    var purpose: Purpose
    var startedAt: Date?
    /// True when the current user owns this room (lives in the private DB).
    var isOwned: Bool
    /// The one-time server invitation URL (from the create/invite RPC).
    var shareURL: URL?

    static let participantLimit = 8
}
