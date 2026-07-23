import Foundation

/// The single source of truth for **Focus Coin** rewards — the canonical,
/// duration-based earning formula. Coins scale with *actual completed focused
/// minutes* only (never distance, never planned duration), so short, cancelled
/// or Infinite sessions can't be farmed. One pure function, easy to reason about.
///
/// Canonical base reward:
///
///     baseCoins = max(1, ceil(completedFocusedMinutes / 10))
///
/// (5→1, 10→1, 15→2, 20→2, 25→3, 30→3, 45→5, 60→6, 90→9, 120→12 …)
///
/// The base is computed ONCE, for a qualifying journey only. Any x2 Coin Booster,
/// rewarded-ad "Double", or friend-flight multiplier is applied by `AppModel`
/// AFTER this base — reward granting stays idempotent per session.
enum FocusEconomy {
    /// The canonical coin reward for a completed session, from its real focused
    /// seconds. Whole completed minutes → `max(1, ceil(minutes / 10))`.
    /// (Callers award this ONLY for a qualifying journey; a sub-minimum or
    /// cancelled session must pass 0 / never call this for a reward.)
    static func coins(forFocusedSeconds seconds: Int) -> Int {
        let minutes = max(0, seconds) / 60
        return max(1, Int(ceil(Double(minutes) / 10.0)))
    }
}

/// Alias for discoverability — the coin economy is centralized in `FocusEconomy`;
/// `FocusCoinEconomy` refers to the same one calculation.
typealias FocusCoinEconomy = FocusEconomy
