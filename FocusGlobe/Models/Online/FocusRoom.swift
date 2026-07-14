import Foundation

/// A private focus room (CKShare-backed). Lives in the owner's private custom
/// zone; participants see it through the shared database.
struct FocusRoom: Identifiable, Equatable, Sendable {
    enum Status: String, Sendable { case lobby, active, ended, closed }
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
    /// The CKShare invitation URL, once the share has been saved.
    var shareURL: URL?

    static let participantLimit = 8
}
