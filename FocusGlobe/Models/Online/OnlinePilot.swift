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
    /// Display-level PRO badge shared by the pilot's own client. nil = unknown
    /// (older client / pre-migration row) — the UI shows nothing, never a fake.
    var isPro: Bool? = nil
    /// The pilot's journey-sound id (app's fixed catalog); nil = not shared.
    var soundID: String? = nil

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

    /// The LIVE persistent-bubble countdown, exact to the second: "42:18"
    /// (or "1:02:07" over an hour) derived from the server-canonical end at the
    /// given tick instant — never a rounded static value. "∞" for an Infinite
    /// pilot; empty when no live session exists (nothing is fabricated).
    func liveCountdown(at now: Date) -> String {
        guard hasLiveSession else { return "" }
        guard let end = expectedEndAt else { return "∞" }
        let r = max(0, Int(end.timeIntervalSince(now).rounded()))
        let h = r / 3600, m = (r % 3600) / 60, s = r % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                     : String(format: "%d:%02d", m, s)
    }
}
