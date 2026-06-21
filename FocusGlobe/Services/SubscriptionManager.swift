import Combine
import Foundation
#if canImport(RevenueCat)
import RevenueCat
#endif

/// Centralised subscription state, backed by RevenueCat when the SDK is linked.
///
/// The entire RevenueCat surface is guarded by `#if canImport(RevenueCat)`, so
/// the app compiles and runs **without** the Swift Package — it simply behaves
/// as "not Pro" and falls back to the built-in paywall. Add the package (see
/// REVENUECAT_SETUP.md) to light this up; no other code needs to change.
@MainActor
final class SubscriptionManager: ObservableObject {

    /// The RevenueCat entitlement that unlocks FocusGlobe Pro.
    static let entitlementID = "FocusGlobe Pro"

    /// Public RevenueCat API key. Paste your real key here before release.
    /// Safe to ship (it's a public SDK key), but restrict it in the dashboard.
    static let apiKey = "test_vXvOIAnCJOPeiUjLfuLuFbLNcoo"

    /// `true` when the user holds the FocusGlobe Pro entitlement.
    @Published private(set) var isPro = false
    /// `true` once RevenueCat is linked and configured — i.e. RC is the source of
    /// truth for Pro state and the native paywall/customer center are available.
    @Published private(set) var isAvailable = false

    private var configured = false

    /// Configure RevenueCat once, early in the app lifecycle. No-op (and never
    /// blocks launch) when the SDK isn't linked or the key is a placeholder.
    func configure(apiKey: String = SubscriptionManager.apiKey) {
        guard !configured else { return }
        configured = true
        #if canImport(RevenueCat)
        guard !apiKey.isEmpty, !apiKey.contains("PASTE_") else { return }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
        isAvailable = true
        // Live updates: purchases, renewals, restores, expirations.
        Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(info)
            }
        }
        refresh()   // initial fetch
        #endif
    }

    /// Refresh customer info from RevenueCat. Safe to call anytime; never blocks.
    func refresh() {
        #if canImport(RevenueCat)
        guard isAvailable else { return }
        Task { [weak self] in
            if let info = try? await Purchases.shared.customerInfo() {
                self?.apply(info)
            }
        }
        #endif
    }

    /// Restore purchases. Returns whether Pro is active afterwards.
    func restore() async -> Bool {
        #if canImport(RevenueCat)
        guard isAvailable else { return false }
        if let info = try? await Purchases.shared.restorePurchases() {
            apply(info)
        }
        return isPro
        #else
        return false
        #endif
    }

    #if canImport(RevenueCat)
    private func apply(_ info: CustomerInfo) {
        isPro = info.entitlements[Self.entitlementID]?.isActive == true
    }
    #endif
}
