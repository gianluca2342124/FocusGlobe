import Foundation

/// What onboarding knows about a pilot, handed to the paywall.
///
/// A side channel on the router rather than a new `PaywallContext` case, on
/// purpose: the first-run offer must be the SAME paywall the Home PRO button
/// opens — the same Annual and Monthly products, the same real localized
/// StoreKit prices, the same purchase and restore paths. A second purchase
/// screen is a second place for a price to be wrong. This only changes which
/// argument the one paywall leads with.
///
/// Deliberately carries no identity: a benefit, an ordering, a Sky id and a
/// source. No name, no account id, nothing free-text.
struct PaywallPersonalization: Equatable, Sendable {
    /// The benefit this pilot's own answers put first.
    let leadBenefit: ProBenefit
    /// The full ordering, so the supporting rows agree with the headline.
    let benefitOrder: [ProBenefit]
    /// The Sky the pilot chose, shown as the hero. Seeing the world you just
    /// picked beats a generic reel of ones you did not.
    let skyID: String?
    /// Where the offer came from, for attribution. A stable id, never a label.
    let source: String

    static let onboardingSource = "onboarding"

    init(plan: OnboardingFocusPlan, source: String = PaywallPersonalization.onboardingSource) {
        self.leadBenefit = plan.personalizedBenefitOrder.first ?? .unlimitedTime
        self.benefitOrder = plan.personalizedBenefitOrder
        self.skyID = plan.selectedSkyID
        self.source = source
    }

    /// The headline key for the leading benefit.
    var headlineKey: FocusStringKey { leadBenefit.headlineKey }

    /// The three benefits shown under the headline — the pilot's own top three,
    /// minus any that is already the headline.
    var supportingBenefits: [ProBenefit] {
        Array(benefitOrder.filter { $0 != leadBenefit }.prefix(3))
    }

    /// Analytics properties. Enumerated explicitly so nothing else can be
    /// appended to this payload by accident.
    var analyticsProperties: [String: Any] {
        ["source": source,
         "lead_benefit": leadBenefit.rawValue,
         "sky": skyID ?? ""]
    }
}
