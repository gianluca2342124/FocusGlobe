import Foundation

/// The single source of truth for **Focus Coin** rewards — the canonical,
/// duration-based earning formula. Coins scale with *actual completed focused
/// minutes* only (never distance, never planned duration), so short, cancelled
/// or Infinite sessions can't be farmed. One pure function, easy to reason about.
///
/// Canonical base reward — ONE Coin per completed five minutes of real focus:
///
///     baseCoins = completedFocusedMinutes / 5      (integer floor)
///
/// (4→0, 5→1, 9→1, 10→2, 14→2, 15→3, 30→6, 45→9, 60→12, 90→18, 120→24 …)
///
/// Five minutes is the same unit the app uses everywhere else — it is the
/// qualifying gate, it is the interval the objectives speak in — so the reward
/// finally counts in it too. The previous shape was
/// `max(1, ceil(minutes / 10))`, which paid the same single coin for five
/// minutes and for ten, and quietly floored a sub-minimum session at 1.
///
/// There is deliberately no `max(1, ...)` any more: under five minutes the
/// answer is genuinely zero, and the formula now says so on its own rather than
/// relying on every caller to gate it first.
///
/// The base is computed ONCE, for a qualifying journey only. Any x2 Coin
/// Booster, rewarded-ad "Double", friend-flight multiplier or the PRO journey
/// multiplier is applied by `AppModel` AFTER this base — reward granting stays
/// idempotent per session.
enum FocusEconomy {
    /// The canonical coin reward for a completed session, from its real focused
    /// seconds: whole completed minutes divided by five, rounded down.
    ///
    /// Callers still apply the qualifying gate for everything ELSE a landing
    /// touches (streak, missions, history, unlocks); this function only refuses
    /// to invent a coin that was not earned.
    static func coins(forFocusedSeconds seconds: Int) -> Int {
        let minutes = max(0, seconds) / 60
        return minutes / 5
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
