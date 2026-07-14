import Foundation

/// A pending Crew request (public database record).
struct FriendRequest: Identifiable, Equatable, Sendable {
    enum Status: String, Sendable { case pending, accepted, declined, cancelled }

    let id: String                 // requestID (deterministic sender_recipient)
    let senderPublicID: String
    let recipientPublicID: String
    let senderDisplayName: String
    let senderBalloonSkinID: String
    let createdAt: Date
    var status: Status

    static func requestID(sender: String, recipient: String) -> String {
        "req_\(sender)_\(recipient)"
    }
    static func connectionID(_ a: String, _ b: String) -> String {
        "conn_\(min(a, b))_\(max(a, b))"
    }
}
