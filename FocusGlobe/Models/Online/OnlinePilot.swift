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
    /// True when this pilot is backed by a real live flight row (so category
    /// and remaining time are REAL). False while only membership is known —
    /// then the UI omits those fields instead of fabricating them.
    let hasLiveSession: Bool

    var isStale: Bool {
        Date().timeIntervalSince(lastHeartbeatAt) > SupabaseConfig.presenceStaleInterval
    }

    /// Remaining time interpolated locally from the server-stored
    /// `expectedEndAt` — synchronized across devices, never a free-running
    /// local countdown and never written per-second.
    var remainingLabel: String {
        guard hasLiveSession else { return "" }
        guard let end = expectedEndAt else { return "Infinite" }
        let r = max(0, Int(end.timeIntervalSinceNow))
        return r >= 60 ? "\(r / 60) min left" : "landing soon"
    }
}
