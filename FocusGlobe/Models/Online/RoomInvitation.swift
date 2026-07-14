import Foundation

/// A room invitation the user can send (wraps the CKShare URL) or has received
/// (an accepted share whose room is now visible in the shared database).
struct RoomInvitation: Identifiable, Equatable, Sendable {
    let id: String                 // roomPublicID
    let room: FocusRoom
    let url: URL?

    var message: String {
        "Join my FocusGlobe flight — we focus together, side by side. \(url?.absoluteString ?? "")"
    }
}
