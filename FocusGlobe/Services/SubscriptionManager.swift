import Combine
import Foundation
#if canImport(RevenueCat)
import RevenueCat
#endif

/// RevenueCat public SDK API keys and the rule for which one to use.
///
/// CRITICAL (build 6): Release / TestFlight / App Store builds MUST use the
/// **Apple App Store** public SDK key (`appl_…`). RevenueCat *intentionally*
/// `fatalError`s a Release build configured with a **Test Store** key (`test_…`)
/// via `checkForSimulatedStoreAPIKeyInRelease` — that was the exact App Review /
/// TestFlight launch crash for 1.0 (builds 2–5). The Apple key also works for
/// Debug, the Simulator, and Sandbox/TestFlight purchases, so it is used for
/// every configuration by default. The Test Store key is available only in DEBUG
/// and only when a developer explicitly sets the `USE_REVENUECAT_TEST_STORE`
/// compilation flag locally — that flag is never defined for Release, so a Test
/// Store key can never reach a distribution build again.
enum RevenueCatKeys {
    /// Apple App Store public SDK key (RevenueCat dashboard → the Apple app).
    /// Used for Release, TestFlight, App Store — and Debug by default.
    static let applePublicSDKKey = "appl_HRfoahxaDYjLOSvdldxaBLhqHdx"

    /// RevenueCat Test Store key — DEBUG-only, opt-in via `USE_REVENUECAT_TEST_STORE`.
    /// Never used in Release.
    static let testStoreKey = "test_vXvOIAnCJOPeiUjLfuLuFbLNcoo"

    /// The key actually handed to `Purchases.configure`. Resolves to the Apple key
    /// everywhere unless a developer opts into the Test Store locally in DEBUG.
    static var activeKey: String {
        #if DEBUG && USE_REVENUECAT_TEST_STORE
        return testStoreKey
        #else
        return applePublicSDKKey
        #endif
    }
}

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

    /// The RevenueCat public SDK key handed to `Purchases.configure`. Resolves via
    /// `RevenueCatKeys.activeKey` — the Apple App Store key (`appl_…`) for
    /// Release / TestFlight / App Store (and Debug by default). Never a Test Store
    /// key in Release, which would make RevenueCat `fatalError` on launch.
    static let apiKey = RevenueCatKeys.activeKey

    /// Dashboard product identifiers (used only to map packages to plans;
    /// purchases use the SDK `Package`, never these strings). These are the clean
    /// products created for the 1.0 resubmission. The legacy `subscription_*`
    /// identifiers are retired and must never be referenced again — the old
    /// products/offering caused the "Products unavailable" App Review rejection.
    static let annualProductID = "focusglobe_pro_annual"
    static let lifetimeProductID = "focusglobe_pro_lifetime"
    static let monthlyProductID = "focusglobe_pro_monthly"

    /// The RevenueCat offering that ships the current products (dashboard
    /// **identifier**, not the display name "Default1"). It is requested
    /// explicitly; the code never falls back to the legacy "default" offering.
    static let offeringID = "default1"

    /// The retired legacy offering identifier. It is never loaded — even if the
    /// dashboard still marks it "Current" — because its old `subscription_*`
    /// products are exactly what caused the "Products unavailable" rejection.
    static let retiredOfferingID = "default"

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

    /// The plan kinds that have a real, purchasable package loaded (display order).
    var availableKinds: [PlanKind] { plans.filter { $0.available }.map { $0.kind } }

    /// `true` once at least one real package is loaded — i.e. the CTA can buy.
    var hasAnyPackage: Bool { !availableKinds.isEmpty }

    /// The best default selection when packages load: annual → monthly → lifetime,
    /// restricted to what's actually available. `nil` if nothing is purchasable.
    var preferredKind: PlanKind? {
        for k in [PlanKind.annual, .monthly, .lifetime] where availableKinds.contains(k) { return k }
        return availableKinds.first
    }

    /// Lightweight, PII-free diagnostics (offering / package / product identifiers
    /// and prices — never user data). Visible in Console on TestFlight/Release so a
    /// "Products unavailable" paywall can be diagnosed without a debugger.
    private func rcLog(_ message: String) { NSLog("[RevenueCat] \(message)") }

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
        // Release safety net: never hand RevenueCat a non-Apple key in a
        // Release / TestFlight / App Store build. A Test Store key (`test_…`)
        // makes RevenueCat itself call `fatalError` (its
        // `checkForSimulatedStoreAPIKeyInRelease` check) — the exact launch crash
        // this build fixes. Rather than crash or bypass RevenueCat's check, we
        // decline to configure and log; the app simply behaves as "not Pro" for
        // that launch. This must never trigger now that `activeKey` is the
        // `appl_` key — it exists only to guarantee we can never ship the crash
        // again. (No bypass flag is used.)
        #if !DEBUG
        guard apiKey.hasPrefix("appl_") else {
            NSLog("[RevenueCat] Skipping configure in Release: expected an Apple App Store key (prefix \"appl_\"). Purchases unavailable this launch.")
            return
        }
        #endif
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
        isAvailable = true
        Task { @MainActor [weak self] in
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
        Task { @MainActor [weak self] in
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
        Task { @MainActor [weak self] in
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
        // Resolve the offering deterministically for the 1.0 resubmission:
        //   1. The clean "default1" offering that ships the current products.
        //   2. Only if that is missing/empty, fall back to `offerings.current` —
        //      and only when it has packages AND is not the retired legacy
        //      "default" offering (whose old subscription_* products caused the
        //      App Review rejection and must never load again).
        // If neither yields real packages, `offering` is nil and the paywall
        // stays honestly "unavailable" — we never fake prices as if real
        // products loaded.
        let requested = offerings.all[Self.offeringID]
        let requestedUsable = (requested?.availablePackages.isEmpty == false) ? requested : nil
        let currentUsable: Offering? = {
            guard let current = offerings.current,
                  !current.availablePackages.isEmpty,
                  current.identifier != Self.retiredOfferingID else { return nil }
            return current
        }()
        let offering = requestedUsable ?? currentUsable

        rcLog("key prefix=\(String(Self.apiKey.prefix(5)))  requested offering=\(Self.offeringID)")
        rcLog("offerings returned all=[\(offerings.all.keys.sorted().joined(separator: ","))]  current=\(offerings.current?.identifier ?? "nil")")
        rcLog("selected offering=\(offering?.identifier ?? "nil")  packages=\(offering?.availablePackages.count ?? 0)")
        if requested == nil || (requested?.availablePackages.isEmpty ?? true) {
            rcLog("default1 offering missing or empty")
        }

        var byKind: [PlanKind: Package] = [:]
        for package in offering?.availablePackages ?? [] {
            let pid = package.storeProduct.productIdentifier
            // Map by the new product identifier first, then by RevenueCat package
            // type as a fallback. Old product IDs are never matched — they no
            // longer exist in App Store Connect or RevenueCat.
            let mapped: PlanKind?
            if pid == Self.annualProductID || package.packageType == .annual {
                mapped = .annual
            } else if pid == Self.lifetimeProductID || package.packageType == .lifetime {
                mapped = .lifetime
            } else if pid == Self.monthlyProductID || package.packageType == .monthly {
                mapped = .monthly
            } else {
                mapped = nil
            }
            rcLog("package pkgID=\(package.identifier) type=\(package.packageType.rawValue) product=\(pid) price=\(package.storeProduct.localizedPriceString) → \(mapped?.rawValue ?? "UNMAPPED")")
            if let mapped {
                byKind[mapped] = package
            } else {
                rcLog("⚠️ unmapped package product=\(pid) type=\(package.packageType.rawValue) — expected focusglobe_pro_monthly / focusglobe_pro_annual / focusglobe_pro_lifetime")
            }
        }
        packagesByKind = byKind

        plans = PlanKind.allCases.map { kind in
            guard let product = byKind[kind]?.storeProduct else {
                // Visual placeholder only — always `available: false`, so it can
                // never be purchased or block a real plan, and carries no product ID.
                return Self.fallbackPlans.first { $0.kind == kind }
                    ?? PlanOption(kind: kind, localizedPrice: "—", monthlyEquivalent: nil, available: false)
            }
            return PlanOption(
                kind: kind,
                localizedPrice: product.localizedPriceString,
                monthlyEquivalent: kind == .annual ? monthlyEquivalent(for: product) : nil,
                available: true)
        }
        rcLog("plans mapped available=[\(availableKinds.map { $0.rawValue }.joined(separator: ","))] preferred=\(preferredKind?.rawValue ?? "none")")
        if !hasAnyPackage {
            rcLog("⚠️ no purchasable packages loaded. RevenueCat offering default1 must contain focusglobe_pro_monthly, focusglobe_pro_annual, focusglobe_pro_lifetime (and those IAPs must be Ready to Submit / Approved in App Store Connect).")
        }
        #if DEBUG
        // App Review diagnostics — DEBUG console only, never shown in the UI.
        rcLog("[AppReview] selected=\(offering?.identifier ?? "nil") packageCount=\(offering?.availablePackages.count ?? 0) mapped=[\(byKind.keys.map { $0.rawValue }.sorted().joined(separator: ","))]")
        #endif
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
