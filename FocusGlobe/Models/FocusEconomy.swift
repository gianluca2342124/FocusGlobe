import Foundation

/// The single source of truth for **Focus Coin** rewards. Coins scale with
/// *actual completed focus minutes* — never distance or planned duration — so
/// short or infinity sessions can't be farmed. Kept tiny and pure so the
/// economy stays easy to reason about and tune.
enum FocusEconomy {
    /// Max coins a single session can earn (before an optional rewarded-ad double).
    static let perSessionCap = 25

    /// Coins for a completed session, from its real focused seconds:
    /// base = floor(minutes / 10) (min 1), +1 at ≥25 min, +2 at ≥60 min, capped.
    static func coins(forFocusedSeconds seconds: Int) -> Int {
        let minutes = max(0, seconds) / 60
        var coins = max(1, minutes / 10)
        if minutes >= 25 { coins += 1 }
        if minutes >= 60 { coins += 2 }
        return min(perSessionCap, coins)
    }
}
