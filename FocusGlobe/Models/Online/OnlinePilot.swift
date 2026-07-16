import Foundation

/// A real pilot visible in a Sky — decoded from a fresh `SkyPresence` record.
struct OnlinePilot: Identifiable, Equatable, Sendable {
    let id: String                 // publicID
    let sessionID: String
    let displayName: String
    let countryCode: String?
    let balloonSkinID: String
    let skyID: String
    let startedAt: Date
    let expectedEndAt: Date?
    let lastHeartbeatAt: Date
    let isPaused: Bool
    let focusCategory: String
    let allowsFriendRequest: Bool

    var isStale: Bool {
        Date().timeIntervalSince(lastHeartbeatAt) > SupabaseConfig.presenceStaleInterval
    }

    /// Remaining time interpolated locally from `expectedEndAt` — presence is
    /// never written per-second.
    var remainingLabel: String {
        guard let end = expectedEndAt else { return "Infinite focus" }
        let r = max(0, Int(end.timeIntervalSinceNow))
        return r >= 60 ? "\(r / 60) min left" : "landing soon"
    }
}
