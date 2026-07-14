import Foundation

/// A Crew request (public database record, SENDER-owned and immutable).
///
/// Ownership-safe model: the recipient never modifies this record. They answer
/// by creating their own `FriendResponse` record (deterministic ID, recipient-
/// owned), and each side then keeps a private `CrewMember` record in its own
/// private database. Request state is DERIVED from request + response — no
/// record is ever mutated by the non-owner.
struct FriendRequest: Identifiable, Equatable, Sendable {
    let id: String                 // requestID (deterministic sender_recipient)
    let senderPublicID: String
    let recipientPublicID: String
    let senderDisplayName: String
    let senderBalloonSkinID: String
    let createdAt: Date

    static func requestID(sender: String, recipient: String) -> String {
        "req_\(sender)_\(recipient)"
    }
    /// The recipient's answer record — deterministic, so duplicates collapse.
    static func responseID(for requestID: String) -> String {
        "resp_\(requestID)"
    }
}
