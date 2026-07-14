import Foundation

/// One member of a focus room (their own child record in the shared zone).
struct RoomParticipant: Identifiable, Equatable, Sendable {
    enum Status: String, Sendable { case joined, ready, flying, left }

    let id: String                 // roomPublicID + "_" + publicID
    let roomPublicID: String
    let publicID: String
    var displayName: String
    var balloonSkinID: String
    var countryCode: String?
    let joinedAt: Date
    var status: Status
    var readyAt: Date?
    var activeSessionID: String?
    var lastHeartbeatAt: Date?
}
