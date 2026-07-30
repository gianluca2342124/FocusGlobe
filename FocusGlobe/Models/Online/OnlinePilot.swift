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
    /// The remaining seconds the SERVER froze when this pilot paused. This is the
    /// authoritative paused countdown — it is the pilot's own data and cannot be
    /// influenced by anyone else's clock or pause. `nil` for an Infinite flight
    /// (nothing to freeze) and for any pilot who is not paused.
    var pausedRemainingSeconds: Int? = nil
    let focusCategory: String
    let allowsFriendRequest: Bool
    /// True when this pilot is backed by a real live flight row (so category
    /// and remaining time are REAL). False while only membership is known —
    /// then the UI omits those fields instead of fabricating them.
    let hasLiveSession: Bool
    /// The pilot's journey-sound id (app's fixed catalog); nil = not shared. It
    /// is validated against the catalog on display, so an unknown value shows
    /// nothing. (PRO is not shared — no trusted server entitlement source.)
    var soundID: String? = nil

    var isStale: Bool {
        Date().timeIntervalSince(lastHeartbeatAt) > SupabaseConfig.presenceStaleInterval
    }

    /// Remaining time interpolated locally from the server-stored
    /// `expectedEndAt` — synchronized across devices, never a free-running
    /// local countdown and never written per-second.
    var remainingLabel: String {
        guard hasLiveSession else { return "" }
        guard let r = remainingSeconds(at: Date()) else { return "Infinite" }
        if isPaused { return r >= 60 ? "Paused · \(r / 60) min left" : "Paused" }
        return r >= 60 ? "\(r / 60) min left" : "landing soon"
    }

    /// The ONE canonical remaining-time calculation for a pilot.
    ///
    /// Derives ONLY from this pilot's own authoritative fields — never from the
    /// local pilot's `isPaused`, `pausedAt`, accumulated pause span, journey
    /// elapsed, or any local resume adjustment. That independence is the whole
    /// point: pausing must be able to freeze exactly one pilot's clock and touch
    /// nobody else's.
    ///
    /// - Paused pilot → the server-frozen `pausedRemainingSeconds`. The value is
    ///   stamped once, on the pause transition, so it holds perfectly still for
    ///   every observer for as long as the pause lasts.
    /// - Running pilot → their own `expectedEndAt` against wall-clock `now`.
    /// - Infinite pilot → `nil` (no deadline).
    func remainingSeconds(at now: Date) -> Int? {
        if isPaused, let frozen = pausedRemainingSeconds { return max(0, frozen) }
        guard let end = expectedEndAt else { return nil }
        return max(0, Int(end.timeIntervalSince(now).rounded()))
    }

    /// The LIVE persistent-bubble countdown, exact to the second: "42:18"
    /// (or "1:02:07" over an hour) derived from the canonical remaining time at
    /// the given tick instant — never a rounded static value. "∞" for an Infinite
    /// pilot; empty when no live session exists (nothing is fabricated). A paused
    /// pilot's value is frozen, so their balloon reads the same on every client.
    func liveCountdown(at now: Date) -> String {
        guard hasLiveSession else { return "" }
        guard let r = remainingSeconds(at: now) else { return "∞" }
        let h = r / 3600, m = (r % 3600) / 60, s = r % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                     : String(format: "%d:%02d", m, s)
    }
}
