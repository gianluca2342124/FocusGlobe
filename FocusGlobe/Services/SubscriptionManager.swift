import Combine
import Foundation
#if canImport(RevenueCat)
import RevenueCat
#endif

/// The three plans shown on the custom paywall.
enum PlanKind: String, CaseIterable, Identifiable {
    case annual, lifetime, monthly
    var id: String { rawValue }

    var title: String {
        switch self {
        case .annual:   return "Annually"
        case .lifetime: return "Lifetime"
        case .monthly:  return "Monthly"
        }
    }
}

/// A provider-independent snapshot of one plan for the paywall UI. Built from a
/// RevenueCat `Package`/`StoreProduct` (localized price) when available, else a
/// disabled fallback so the paywall always renders.
struct PlanOption: Identifiable, Equatable {
    let kind: PlanKind
    var localizedPrice: String       // e.g. "18,99 €" (App Store localized)
    var monthlyEquivalent: String?   // annual only, e.g. "1,58 €/month"
    var available: Bool              // true when a real product is loaded
    var id: PlanKind { kind }
}

/// Centralised subscription state, backed by RevenueCat when the SDK is linked.
///
/// The RevenueCat surface is guarded by `#if canImport(RevenueCat)`, so the app
/// compiles and runs even without the SDK (plans fall back to disabled
/// placeholders and the app behaves as "not Pro"). All purchase/restore actions
/// go through the SDK's `Package`/`StoreProduct` — no REST API IDs are used.
@MainActor
final class SubscriptionManager: ObservableObject {

    /// The entitlement identifier checked inside `CustomerInfo.entitlements`.
    /// This must match the entitlement **identifier** in the RevenueCat dashboard
    /// (the user-facing name). As a safety net we also treat *any* active
    /// entitlement as Pro, since FocusGlobe ships a single entitlement.
    static let entitlementID = "FocusGlobe Pro"

    /// Public RevenueCat API key. Paste your real key here before release.
    static let apiKey = "test_vXvOIAnCJOPeiUjLfuLuFbLNcoo"

    /// Dashboard product identifiers (used only to map packages to plans;
    /// purchases use the SDK `Package`, never these strings).
    static let annualProductID = "subscription_annually"
    static let lifetimeProductID = "subscription_lifetime"
    static let monthlyProductID = "subscription_monthly"

    @Published private(set) var isPro = false
    @Published private(set) var isAvailable = false      // RC configured
    @Published private(set) var isLoading = false        // loading offerings
    @Published private(set) var isPurchasing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var plans: [PlanOption] = SubscriptionManager.fallbackPlans

    static let fallbackPlans: [PlanOption] = [
        PlanOption(kind: .annual,   localizedPrice: "18,99 €", monthlyEquivalent: "1,58 €/month", available: false),
        PlanOption(kind: .lifetime, localizedPrice: "35,99 €", monthlyEquivalent: nil,            available: false),
        PlanOption(kind: .monthly,  localizedPrice: "3,99 €",  monthlyEquivalent: nil,            available: false),
    ]

    func plan(_ kind: PlanKind) -> PlanOption? { plans.first { $0.kind == kind } }

    private var configured = false

    #if canImport(RevenueCat)
    private var packagesByKind: [PlanKind: Package] = [:]
    #endif

    // MARK: Configuration

    /// Configure RevenueCat once, early in the app lifecycle. Non-blocking.
    func configure(apiKey: String = SubscriptionManager.apiKey) {
        guard !configured else { return }
        configured = true
        #if canImport(RevenueCat)
        guard !apiKey.isEmpty, !apiKey.contains("PASTE_") else { return }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
        isAvailable = true
        Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(info)
            }
        }
        refreshCustomerInfo()
        loadOfferings()
        #endif
    }

    // MARK: Offerings / pricing

    func loadOfferings() {
        #if canImport(RevenueCat)
        guard isAvailable else { return }
        isLoading = true
        Task { [weak self] in
            do {
                let offerings = try await Purchases.shared.offerings()
                self?.applyOfferings(offerings)
            } catch {
                self?.isLoading = false   // calm: keep fallback plans, no alert
            }
        }
        #endif
    }

    func refreshCustomerInfo() {
        #if canImport(RevenueCat)
        guard isAvailable else { return }
        Task { [weak self] in
            if let info = try? await Purchases.shared.customerInfo() { self?.apply(info) }
        }
        #endif
    }

    // MARK: Purchase / restore

    /// Purchase the selected plan via its RevenueCat `Package`. Returns whether
    /// Pro is active afterwards. Cancellation is not treated as an error.
    func purchase(_ kind: PlanKind) async -> Bool {
        #if canImport(RevenueCat)
        guard isAvailable, let package = packagesByKind[kind] else {
            errorMessage = "Products unavailable. Please try again later."
            return false
        }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return false }
            apply(result.customerInfo)
            return isPro
        } catch {
            errorMessage = "Purchase couldn't be completed. Please try again."
            return false
        }
        #else
        return false
        #endif
    }

    /// Restore purchases with the user's Apple account, then refresh state.
    func restorePurchases() async -> Bool {
        #if canImport(RevenueCat)
        guard isAvailable else { return false }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            if !isPro { errorMessage = "No active purchases found to restore." }
            return isPro
        } catch {
            errorMessage = "Restore couldn't be completed. Please try again."
            return false
        }
        #else
        return false
        #endif
    }

    // MARK: RevenueCat plumbing

    #if canImport(RevenueCat)
    private func applyOfferings(_ offerings: Offerings) {
        // Prefer the current offering; fall back to the "default" offering.
        let offering = offerings.current ?? offerings.all["default"]
        var byKind: [PlanKind: Package] = [:]
        for package in offering?.availablePackages ?? [] {
            let pid = package.storeProduct.productIdentifier
            if pid == Self.annualProductID || package.packageType == .annual {
                byKind[.annual] = package
            } else if pid == Self.lifetimeProductID || package.packageType == .lifetime {
                byKind[.lifetime] = package
            } else if pid == Self.monthlyProductID || package.packageType == .monthly {
                byKind[.monthly] = package
            }
        }
        packagesByKind = byKind

        plans = PlanKind.allCases.map { kind in
            guard let product = byKind[kind]?.storeProduct else {
                return Self.fallbackPlans.first { $0.kind == kind }
                    ?? PlanOption(kind: kind, localizedPrice: "—", monthlyEquivalent: nil, available: false)
            }
            return PlanOption(
                kind: kind,
                localizedPrice: product.localizedPriceString,
                monthlyEquivalent: kind == .annual ? monthlyEquivalent(for: product) : nil,
                available: true)
        }
        isLoading = false
    }

    /// Localized 1/12 of the annual price, using the product's own currency/locale.
    private func monthlyEquivalent(for product: StoreProduct) -> String? {
        let monthly = product.price / Decimal(12)
        guard let formatter = product.priceFormatter,
              let text = formatter.string(from: NSDecimalNumber(decimal: monthly)) else { return nil }
        return "\(text)/month"
    }

    private func apply(_ info: CustomerInfo) {
        if let entitlement = info.entitlements[Self.entitlementID] {
            isPro = entitlement.isActive
        } else {
            // Single-entitlement app: any active entitlement means Pro. This keeps
            // us correct even if the dashboard identifier differs from the name.
            isPro = !info.entitlements.active.isEmpty
        }
    }
    #endif
}
