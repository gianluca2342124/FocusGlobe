import Foundation

/// A room invitation the user can send (wraps the one-time server invite URL)
/// or has received (a joined room now visible in their room list).
struct RoomInvitation: Identifiable, Equatable, Sendable {
    let id: String                 // roomPublicID
    let room: FocusRoom
    let url: URL?

    /// Invitation copy WITHOUT the URL — the link travels exclusively as the
    /// single shared item (InviteShareSheet), so it can never appear twice.
    var message: String {
        "Join my FocusGlobe flight — we focus together, side by side."
    }
}
