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

    /// What FocusGlobe PRO multiplies a completed JOURNEY's coins by.
    ///
    /// This is the single number behind the paywall's "2x Coins" row, and it is
    /// deliberately here rather than inline at the award site so the paywall, the
    /// leave-flight confirmation and the Landing screen can all quote the same
    /// figure without any of them re-deriving it.
    ///
    /// It applies to JOURNEY rewards only. Spins, rewarded videos, daily
    /// missions, gifts, referrals and restored balances are unaffected — see
    /// `AppModel.completeJourney`, which is the one place it is used.
    static let proJourneyMultiplier = 2

    /// The final coins for a landing: whatever a FREE pilot would have banked
    /// for this identical flight, doubled for PRO.
    ///
    /// The multiplier is applied OUTSIDE the free per-journey ceiling on purpose.
    /// Folding it in would let the cap quietly eat the benefit on long or
    /// boosted flights, and a PRO pilot would find their "2x" was sometimes 1.4x
    /// with no explanation. This way the promise holds exactly, always.
    static func journeyCoins(creditedForFree: Int, isPro: Bool) -> Int {
        creditedForFree * (isPro ? proJourneyMultiplier : 1)
    }
}

/// Alias for discoverability — the coin economy is centralized in `FocusEconomy`;
/// `FocusCoinEconomy` refers to the same one calculation.
typealias FocusCoinEconomy = FocusEconomy
