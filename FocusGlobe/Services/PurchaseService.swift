import Foundation

/// A mock in-app purchase service for FocusGlobe Pro.
///
/// TODO: Replace with StoreKit 2 (or RevenueCat) when monetization goes live.
/// Keep the async `purchasePro()` / `restore()` contract so the Paywall and
/// Settings don't need to change. Pro state persists locally for the MVP.
@MainActor
final class PurchaseService {
    private let persistence: PersistenceService

    init(persistence: PersistenceService) {
        self.persistence = persistence
    }

    var isPro: Bool {
        persistence.bool(for: .isPro)
    }

    /// Simulates a successful purchase after a brief delay.
    func purchasePro() async -> Bool {
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        persistence.setBool(true, for: .isPro)
        return true
    }

    /// Simulates restoring purchases. In the mock, this reflects local state.
    func restore() async -> Bool {
        try? await Task.sleep(nanoseconds: 800_000_000)
        return isPro
    }

    /// Debug helper used by the Reset action.
    func clear() {
        persistence.setBool(false, for: .isPro)
    }
}
