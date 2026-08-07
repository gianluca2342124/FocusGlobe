import Combine
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif


/// Which sky the paywall stands in.
///
/// NOT a paywall variant — the products, the carousel, the comparison table, the
/// CTAs, the eligibility rules and the purchase path are identical either way.
/// It swaps the backdrop and nothing else, so the first run can end on the same
/// page the Home PRO button opens without the sky changing underneath the pilot
/// mid-flow.
enum PaywallBackdrop {
    case standard
    case onboarding
}

/// FocusGlobe's single contextual PRO experience. Page one explains the exact
/// benefit the pilot touched; page two explains the trial and is the only page
/// capable of starting a RevenueCat purchase.
struct PaywallView: View {
    var context: PaywallContext = .general
    var backdrop: PaywallBackdrop = .standard
    /// How this paywall goes away.
    ///
    /// `nil` — every existing call site — means it was PRESENTED, so SwiftUI's
    /// `dismiss` closes it. Onboarding renders it inline for visual continuity,
    /// and an inline view has nothing to dismiss: `DismissAction` would be a
    /// no-op and the close button, the post-purchase exit and the
    /// entitlement-resolved exit would all silently do nothing. Supplying this
    /// hands those three exits somewhere real to go.
    var onClose: (() -> Void)? = nil

    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.focusViewport) private var viewport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var page: Page = .benefit
    @State private var selectedKind: PlanKind = .annual
    @State private var selectedHeroIndex = 0

    private enum Page { case benefit, trial }

    /// The ONE exit. Every path that used to call `dismiss()` goes through here
    /// so a presented paywall and an inline one cannot diverge.
    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }
    private var subs: SubscriptionManager { appModel.subscriptions }

    /// Which subscriptions this entry point may sell.
    ///
    /// Onboarding sells the ANNUAL plan alone. That page leads with the free-trial
    /// timeline, and the monthly product has no introductory offer — letting it be
    /// selected there meant the whole screen promised a trial while one selectable
    /// product charged immediately. Every other paywall keeps both, and the monthly
    /// product itself is untouched in RevenueCat.
    private var offeredPlans: [PlanKind] {
        context.isOnboardingOffer ? [.annual] : [.annual, .monthly]
    }

    private var effectivePlan: PlanOption? { effectiveKind.flatMap { subs.plan($0) } }

    /// A free trial may be described ONLY when the exact plan being purchased
    /// carries a real free-trial intro offer AND this account is confirmed
    /// eligible. Anything else — monthly selected, ineligible account, eligibility
    /// still resolving, offer withdrawn — reads as an immediate purchase.
    private var showsTrialCopy: Bool { effectivePlan?.offersFreeTrial ?? false }

    /// The plan on THIS paywall that carries the free trial (annual today), and
    /// whether a trial is on offer at all.
    ///
    /// Distinct from `showsTrialCopy` on purpose. The title and the day timeline
    /// describe the OFFER, so they must stay put when the pilot toggles to
    /// Monthly — the timeline disappearing mid-selection is what made the screen
    /// feel unstable. The CTA and its disclosure still follow `showsTrialCopy`,
    /// because those two must always describe the exact product being charged.
    private var trialOfferPlan: PlanOption? {
        offeredPlans.compactMap { subs.plan($0) }.first { $0.offersFreeTrial }
    }

    private var trialOfferAvailable: Bool { trialOfferPlan != nil }

    /// The CTA that advances from the benefit page to the plan page.
    ///
    /// It states a price, so it may only state one it can prove. Every
    /// precondition is carried by `trialOfferPlan` — a real loaded product, a
    /// real free-trial introductory offer, and a StoreKit-confirmed eligibility
    /// for THIS Apple ID — plus `localizedZeroPrice`, which is zero formatted by
    /// that product's own price formatter. That is why there is no "$" anywhere
    /// here: on a euro storefront it renders "Try for 0,00 €", and on a
    /// storefront whose product has not loaded it renders nothing of the sort.
    ///
    /// Anything less than all four — offer withdrawn, account ineligible,
    /// eligibility still resolving, offerings still loading — falls back to a
    /// claim that is true in every one of those cases.
    private var benefitCTATitle: String {
        guard let zero = trialOfferPlan?.localizedZeroPrice else { return "See PRO Plans" }
        return "Try for \(zero)"
    }

    private var trialDuration: String {
        effectivePlan?.introOffer?.localizedDuration ?? "3 days"
    }

    var body: some View {
        ZStack {
            background
            Group {
                switch page {
                case .benefit: benefitPage
                case .trial: trialPage
                }
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity.combined(with: .move(edge: .leading))
            ))
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            guard appModel.entitlement == .free else {
                close()
                return
            }
            appModel.analytics.log(.paywallOpened)
            subs.loadOfferings()
            syncSelection()
            selectedHeroIndex = context.initialHeroIndex
            // The first-run offer IS the offer page: one product, one CTA, no
            // benefit/trial two-step. Onboarding has already made the pitch.
            if context.isOnboardingOffer { page = .trial }
        }
        .onChange(of: subs.plans) { _, _ in syncSelection() }
        .onChange(of: appModel.entitlement) { _, access in
            if access != .free { close() }
        }
    }

    // MARK: - Page one

    private var benefitPage: some View {
        VStack(spacing: 0) {
            paywallHeader(backAction: nil, showsClose: true)

            ScrollView(showsIndicators: false) {
                VStack(spacing: viewport.isWide ? 20 : 13) {
                    FocusGlobePROBrand(size: .compact)

                    VStack(spacing: 7) {
                        Text(context.benefitTitle)
                            .font(.system(
                                size: viewport.isWide ? 43 : (viewport.isCompact ? 31 : 37),
                                weight: .bold
                            ))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)

                        Text(context.supportingCopy)
                            .font(.system(size: viewport.bodySize, weight: .medium))
                            .foregroundStyle(.white.opacity(0.68))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 570)
                    }

                    contextualHero
                        .frame(height: viewport.paywallHeroHeight)

                    Text("+ Unlock so much more with PRO")
                        .font(.system(
                            size: viewport.isWide ? 22 : (viewport.isCompact ? 17 : 19),
                            weight: .bold
                        ))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    PaywallComparisonTable(highlighted: context.comparisonHighlight)
                        .frame(maxWidth: viewport.isWide ? 650 : 560)
                }
                .frame(maxWidth: viewport.readableContentWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, viewport.pagePadding)
                .padding(.bottom, 18)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)

            Button {
                appModel.tapFeedback()
                withAnimation(AppMotion.content.respecting(reduceMotion)) {
                    page = .trial
                }
            } label: {
                Text(benefitCTATitle)
                    .font(.system(size: viewport.isWide ? 19 : 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: paywallButtonHeight)
                    .background(Capsule().fill(ProBrand.primaryButton))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1))
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityHint("Shows trial timing and subscription options. No purchase is made.")
            .frame(maxWidth: viewport.modalWidth)
            .padding(.horizontal, viewport.pagePadding)
            .padding(.bottom, max(12, viewport.pagePadding * 0.65))
        }
    }

    @ViewBuilder private var contextualHero: some View {
        switch context {
        case .sky:
            PaywallSkyCarousel(selectedIndex: $selectedHeroIndex)
        case .balloonSkin, .interior:
            PaywallCollectibleCarousel(selectedIndex: $selectedHeroIndex)
        case .general, .onboarding:
            // The broad pitch has no single subject, so one still was always
            // going to under-sell it — a reel of what PRO actually opens up is
            // the argument. In practice only `.general` reaches this: the
            // onboarding offer jumps straight to the trial page and never
            // renders a hero. It is listed anyway because the two share this
            // context's asset and argument, so if that page ever appears it must
            // not silently fall back to the still.
            PaywallShowcaseCarousel(selectedIndex: $selectedHeroIndex)
        default:
            PaywallContextHero(context: context)
        }
    }

    // MARK: - Page two

    private var trialPage: some View {
        VStack(spacing: 0) {
            // The trial page has NO close control, inline or presented. It is
            // the page a pilot lands on after asking to see the price, and its
            // only exit is Back — deliberately, so the price is never dismissed
            // by a stray tap in the corner. Page one keeps its X.
            paywallHeader(backAction: context.isOnboardingOffer ? nil : {
                appModel.tapFeedback()
                withAnimation(AppMotion.content.respecting(reduceMotion)) {
                    page = .benefit
                }
            }, showsClose: context.isOnboardingOffer)

            ViewThatFits(in: .vertical) {
                trialContent
                ScrollView(showsIndicators: false) {
                    trialContent
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            // Take the whole gap between the header and the footer, so the header
            // stays pinned at the very top rather than sitting directly on top of
            // a centred block.
            .frame(maxHeight: .infinity)

            purchaseFooter
        }
    }

    private var trialContent: some View {
        // Spacers, not bigger paddings. A `Spacer` contributes 0 to the IDEAL
        // height, so `ViewThatFits` still measures this stack compactly and still
        // falls back to the ScrollView on a short screen — but when it does fit,
        // the groups distribute over the whole remaining height instead of
        // huddling into a centred card under the header.
        VStack(spacing: viewport.isWide ? 24 : (viewport.isShort ? 13 : 18)) {
            Spacer(minLength: 0)

            trialTitle

            // Shown whenever a trial is on offer for this account — NOT gated on
            // the current selection, so switching to Monthly no longer removes it.
            // Monthly's own row still reads "Billed immediately", which is where
            // the per-product truth belongs.
            if trialOfferAvailable {
                TrialTimeline(compact: viewport.isShort || viewport.isCompact,
                              trialDays: trialOfferPlan?.introOffer?.totalDays ?? 7)
                    .frame(maxWidth: viewport.isWide ? 620 : 540)
            }

            Spacer(minLength: 0)

            if context.isOnboardingOffer {
                annualOfferPanel
                    .frame(maxWidth: viewport.isWide ? 620 : 540)
            } else {
                VStack(spacing: 9) {
                    ForEach(offeredPlans) { kind in
                        planCard(kind)
                    }
                }
                .frame(maxWidth: viewport.isWide ? 620 : 540)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: viewport.readableContentWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, viewport.pagePadding)
        .padding(.top, viewport.isShort ? 2 : 8)
        .padding(.bottom, viewport.isShort ? 10 : 16)
    }

    /// The original headline, restored. Still guarded by `trialOfferAvailable`
    /// so an account with no trial is never promised one — but it no longer
    /// changes when the pilot switches plan.
    private var trialTitle: some View {
        Group {
            if trialOfferAvailable {
                Text("We’ll remind you")
                + Text(" 2 days").foregroundStyle(ProBrand.softGradient)
                + Text("\nbefore your trial ends")
            } else {
                Text("Unlock\n")
                + Text("FocusGlobe PRO").foregroundStyle(ProBrand.softGradient)
            }
        }
        .font(.system(
            size: viewport.isWide ? 40 : (viewport.isCompact ? 29 : 35),
            weight: .bold
        ))
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .lineSpacing(2)
        .minimumScaleFactor(0.75)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trialOfferAvailable
                            ? "We’ll remind you 2 days before your trial ends"
                            : "Unlock FocusGlobe PRO")
    }

    /// The onboarding offer: ONE annual plan, stated plainly. No selector, so the
    /// monthly product cannot be bought from the screen that promises a trial.
    /// When the annual package fails to load this says so rather than showing a
    /// placeholder price or quietly falling back to monthly.
    @ViewBuilder private var annualOfferPanel: some View {
        let plan = subs.plan(.annual)
        VStack(spacing: 6) {
            Text("FocusGlobe PRO Annual")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.72))

            if let plan, plan.available {
                // The annual billing price is the prominent number.
                Text(plan.localizedPrice + "/year")
                    .font(.system(size: viewport.isCompact ? 26 : 30, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(showsTrialCopy
                     ? "after the \(trialDuration) free trial"
                     : "billed immediately")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.66))

                if let monthly = plan.monthlyEquivalent {
                    // Secondary, and deliberately quieter than the annual price.
                    Text("Only " + monthly)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            } else {
                Text("Plans are unavailable right now.")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Text("Please check your connection and try again.")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, viewport.isShort ? 14 : 18)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.06)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(ProBrand.borderGradient, lineWidth: 2)
        )
    }

    private var purchaseFooter: some View {
        // The trial timeline already states the billing story; no redundant status
        // badge is inserted above the CTA.
        // Slightly looser spacing keeps the CTA and legal text from crowding the
        // bottom edge on short screens.
        VStack(spacing: 10) {
            Button { purchase() } label: {
                ZStack {
                    if subs.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(purchaseButtonTitle)
                            .font(.system(size: viewport.isWide ? 19 : 17, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: paywallButtonHeight)
                .background(Capsule().fill(ProBrand.primaryButton))
                .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1))
                .opacity(effectiveKind == nil ? 0.5 : 1)
            }
            .buttonStyle(SoftPressStyle())
            .disabled(effectiveKind == nil || subs.isPurchasing)

            if let message = subs.errorMessage {
                Text(message)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(AppColors.danger)
                    .multilineTextAlignment(.center)
            }

            Text(trialDisclosure)
                .font(.system(size: 11.5, weight: .regular))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                Button("Restore Purchases") { restore() }
                Text("•")
                Link("Privacy", destination: LegalLinks.privacy)
                Text("•")
                Link("Terms", destination: LegalLinks.terms)
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: viewport.isWide ? 620 : 540)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, viewport.pagePadding)
        .padding(.bottom, max(10, viewport.pagePadding * 0.55))
    }

    /// One line of honest billing detail per plan.
    ///
    /// Free-trial wording appears only for a plan that genuinely carries a
    /// free-trial introductory offer this account is eligible for — which today
    /// is annual only, and only for an eligible Apple ID.
    private func planSubtitle(_ kind: PlanKind, plan: PlanOption?) -> String {
        guard let plan, plan.available else { return "Unavailable" }
        switch kind {
        case .annual:
            // The conversion anchor, and nothing else. The full annual price is
            // already the prominent number on the trailing edge of this very
            // row, so "Billed yearly" here was spending the one line the row has
            // on a fact stated eight points away — and burying the number that
            // actually does the persuading.
            //
            // `monthlyEquivalent` is the real annual price divided by twelve and
            // run through THAT product's own formatter, so the currency, symbol
            // placement and separators are the storefront's, never assembled
            // here. Nothing about it is hardcoded.
            return plan.monthlyEquivalent.map { "Only \($0)" } ?? "Billed yearly"
        case .monthly:
            return "Billed immediately. Cancel anytime."
        case .lifetime:
            return "One payment. Yours forever."
        }
    }

    private func planCard(_ kind: PlanKind) -> some View {
        let plan = subs.plan(kind)
        let selected = selectedKind == kind
        let unavailable = subs.hasAnyPackage && !(plan?.available ?? false)

        return Button {
            appModel.tapFeedback()
            withAnimation(AppMotion.control.respecting(reduceMotion)) {
                selectedKind = kind
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(selected ? ProBrand.c2 : .white.opacity(0.38))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(kind.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                        if kind == .annual {
                            Text("-60%")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(ProBrand.c1))
                        }
                    }
                    // Per-plan billing truth. The monthly product has no
                    // introductory offer, so it can never inherit trial wording
                    // from the page it happens to be sitting on.
                    Text(planSubtitle(kind, plan: plan))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                Text(plan?.localizedPrice ?? "—")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 18)
            .frame(height: viewport.isWide ? 66 : (viewport.isShort ? 56 : 60))
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.black.opacity(selected ? 0.06 : 0.22)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        selected ? AnyShapeStyle(ProBrand.borderGradient)
                                 : AnyShapeStyle(Color.white.opacity(0.13)),
                        lineWidth: selected ? 2 : 1
                    )
            )
        }
        .buttonStyle(SoftPressStyle(scale: 0.99))
        .opacity(unavailable ? 0.42 : 1)
        .disabled(unavailable)
    }

    // MARK: - Shared chrome and actions

    /// Onboarding wants quieter chrome: there the offer is the last step of a
    /// flow the pilot is moving through, not a modal they have been dropped
    /// into, and a full-size control reads as "get out of here" at exactly the
    /// wrong moment. Applies to BOTH header controls — a small X on page one
    /// beside a full-size chevron on page two would just look like two different
    /// paywalls. Every other entry point is unchanged.
    private var chromeControlSize: CGFloat {
        backdrop == .onboarding ? viewport.navigationControlSize * 0.74
                                : viewport.navigationControlSize
    }

    private var chromeControlOpacity: Double {
        backdrop == .onboarding ? 0.62 : 1
    }

    private func paywallHeader(
        backAction: (() -> Void)?,
        showsClose: Bool
    ) -> some View {
        HStack {
            if let backAction {
                AppIconButton(systemImage: "chevron.left", size: chromeControlSize,
                              tint: .white.opacity(chromeControlOpacity),
                              accessibilityLabel: "Back", action: backAction)
                    // Same rule as the X: the glyph shrinks, the target does
                    // not. This is the trial page's ONLY exit, so it has to stay
                    // a full 46–58 pt control however small it looks.
                    .frame(width: viewport.navigationControlSize,
                           height: viewport.navigationControlSize)
            } else {
                Color.clear.frame(width: viewport.navigationControlSize,
                                  height: viewport.navigationControlSize)
            }
            Spacer()
            if showsClose {
                AppIconButton(systemImage: "xmark", size: chromeControlSize,
                              tint: .white.opacity(chromeControlOpacity),
                              accessibilityLabel: "Close") {
                    appModel.tapFeedback()
                    close()
                }
                // The tap target stays a full control even when the glyph is
                // smaller, so shrinking it visually never makes it harder to hit.
                .frame(width: viewport.navigationControlSize,
                       height: viewport.navigationControlSize)
            } else {
                Color.clear.frame(width: viewport.navigationControlSize,
                                  height: viewport.navigationControlSize)
            }
        }
        .frame(maxWidth: viewport.isWide ? 1040 : 760)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, viewport.pagePadding)
        .padding(.top, max(6, viewport.pagePadding * 0.25))
        .padding(.bottom, 4)
    }

    @ViewBuilder private var background: some View {
        switch backdrop {
        case .onboarding: OnboardingBackdrop()
        case .standard:   standardBackground
        }
    }

    private var standardBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x111329), AppColors.neutralBase, Color(hex: 0x080A16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [context.accent.opacity(0.22), .clear],
                center: page == .benefit ? .top : .bottomTrailing,
                startRadius: 10,
                endRadius: viewport.isWide ? 760 : 500
            )
            RadialGradient(
                colors: [ProBrand.glow.opacity(0.12), .clear],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// The plan the CTA will actually buy — always the one the UI is showing.
    private var effectiveKind: PlanKind? {
        if offeredPlans.contains(selectedKind), subs.plan(selectedKind)?.available == true {
            return selectedKind
        }
        return offeredPlans.first { subs.plan($0)?.available == true }
    }

    /// The CTA names the product it will charge for, and only says "free trial"
    /// when there genuinely is one for this account.
    private var purchaseButtonTitle: String {
        guard let kind = effectiveKind else { return "Products unavailable" }
        switch kind {
        case .annual:
            // `showsTrialCopy` is the eligibility of the EXACT plan being
            // charged, so this can never promise a free trial to an account the
            // App Store would bill immediately.
            return showsTrialCopy ? "Try PRO for FREE" : "Continue with Annual"
        // Monthly has no introductory offer and is charged today, so it is
        // exactly "Continue" — never "Continue with Monthly", and never trial
        // language, whatever the annual product is offering alongside it.
        case .monthly:  return "Continue"
        case .lifetime: return "Unlock FocusGlobe PRO"
        }
    }

    /// The disclosure under the CTA, matched to the SAME product.
    private var trialDisclosure: String {
        guard let plan = effectivePlan else {
            return "Subscriptions renew automatically. Cancel anytime."
        }
        let price = plan.localizedPrice + perPeriodSuffix(plan.kind)
        if showsTrialCopy {
            return "No charge today. Then " + price + ". Cancel anytime."
        }
        return price + ", billed immediately. Cancel anytime."
    }

    private func perPeriodSuffix(_ kind: PlanKind) -> String {
        switch kind {
        case .annual:   return "/year"
        case .monthly:  return "/month"
        case .lifetime: return ""
        }
    }

    private var paywallButtonHeight: CGFloat {
        viewport.isWide ? 58 : (viewport.isShort ? 50 : 54)
    }

    private func syncSelection() {
        guard subs.hasAnyPackage else { return }
        if !offeredPlans.contains(selectedKind)
            || subs.plan(selectedKind)?.available != true,
           let preferred = offeredPlans.first(where: {
               subs.plan($0)?.available == true
           }) {
            selectedKind = preferred
        }
    }

    private func purchase() {
        guard page == .trial, let kind = effectiveKind else { return }
        Task { @MainActor in
            let ok = await subs.purchase(kind)
            if ok {
                appModel.haptics.rewardClaim()
                close()
            }
        }
    }

    private func restore() {
        appModel.tapFeedback()
        Task { @MainActor in
            let ok = await appModel.restorePurchases()
            if ok { close() }
        }
    }
}

// MARK: - Context heroes

private struct PaywallContextHero: View {
    let context: PaywallContext
    @Environment(\.focusViewport) private var viewport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false

    /// Where a hero stops being a cut-out object and becomes a scene.
    ///
    /// The two kinds want opposite treatments. A transparent cut-out floats free
    /// and must NOT be boxed — a border around one draws a rectangle through
    /// empty pixels, which is exactly the card treatment that was stripped off
    /// these paywalls earlier. A full-bleed landscape scene has real rectangular
    /// edges, and leaving those edges hard is what makes the new wide art read as
    /// dropped in rather than designed in.
    ///
    /// Read from the asset instead of listed per context, so new horizontal
    /// artwork picks the frame up the moment it lands in the catalogue and no
    /// code has to follow the art. The gap is wide: every cut-out hero currently
    /// ships between 0.64 and 1.22, and genuinely horizontal art starts at 1.5.
    private static let landscapeThreshold: CGFloat = 1.35

    var body: some View {
        ZStack {
            #if canImport(UIKit)
            if let image = UIImage(named: context.heroAssetName) {
                hero(image)
            } else {
                fallback
            }
            #else
            fallback
            #endif
        }
        .frame(maxWidth: viewport.isWide ? 720 : 590)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                floating = true
            }
        }
    }

    #if canImport(UIKit)
    @ViewBuilder private func hero(_ image: UIImage) -> some View {
        let aspect = image.size.height > 0 ? image.size.width / image.size.height : 1
        if aspect >= Self.landscapeThreshold {
            framedScene(image, aspect: aspect)
        } else {
            floatingCutout(image)
        }
    }

    /// The wide artwork, presented as a framed piece: soft continuous corners,
    /// a hairline edge, depth under it and a slow accent bloom behind it.
    private func framedScene(_ image: UIImage, aspect: CGFloat) -> some View {
        let radius: CGFloat = viewport.isWide ? 30 : (viewport.isCompact ? 22 : 26)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return Image(uiImage: image)
            .resizable()
            // Pin the frame to the ARTWORK's own ratio. The corners then land on
            // the picture itself rather than on a box that merely contains it,
            // and nothing is ever cropped to make the shape fit.
            .aspectRatio(aspect, contentMode: .fit)
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.13), lineWidth: 1))
            // Only the bloom is on the clock, so the picture itself is never
            // rebuilt for it. `paused:` parks it flat under Reduce Motion.
            .background {
                TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: reduceMotion)) { ctx in
                    shape
                        .fill(context.accent.opacity(0.18 + 0.10 * Self.breath(ctx.date)))
                        .blur(radius: 30)
                        .scaleEffect(0.97)
                }
            }
            // One tight shadow for depth against the paywall; the bloom above
            // supplies the colour, so this stays neutral and restrained.
            .shadow(color: .black.opacity(0.44), radius: 20, y: 12)
            .padding(.horizontal, viewport.isCompact ? 2 : 8)
            .padding(.vertical, 4)
    }

    /// The original treatment, unchanged: transparent objects float, never boxed.
    private func floatingCutout(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .padding(viewport.isWide ? 10 : 5)
            .offset(y: floating ? -5 : 5)
            .shadow(color: .black.opacity(0.24), radius: 12, y: 6)
    }
    #endif

    /// A 6-second 0→1→0 ramp. Deliberately not a sine: this drives a blurred
    /// glow's opacity across a 0.10 range, where the difference is invisible and
    /// the arithmetic stays in the standard library.
    static func breath(_ date: Date) -> Double {
        let period = 6.0
        let t = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: period) / period
        return t < 0.5 ? t * 2 : (1 - t) * 2
    }

    private var fallback: some View {
        Image(systemName: context.systemImage)
            .font(.system(size: viewport.isWide ? 92 : 72, weight: .light))
            .foregroundStyle(context.accent)
            .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
    }
}

private enum PaywallCollectible: Identifiable {
    case skin(BalloonSkin)
    case item(StoreItem)

    var id: String {
        switch self {
        case .skin(let skin): return "skin.\(skin.id)"
        case .item(let item): return "item.\(item.id)"
        }
    }

    var title: String {
        switch self {
        case .skin(let skin): return skin.name
        case .item(let item): return item.name
        }
    }
}

private struct PaywallCollectibleCarousel: View {
    @Binding var selectedIndex: Int
    @Environment(\.focusViewport) private var viewport

    private let items: [PaywallCollectible] =
        BalloonSkin.all.filter(\.isPremium).map(PaywallCollectible.skin)
        + StoreItem.all.filter(\.isPremium).map(PaywallCollectible.item)

    /// One art box for BOTH media types, derived from the hero height the
    /// carousel is actually given. A balloon is drawn at a fixed point size while
    /// a cabin PNG scales to fit, so without a shared box the two read at wildly
    /// different scales as they pass the centre.
    private var artHeight: CGFloat { max(120, viewport.paywallHeroHeight - 58) }

    /// Balloon skins and cabin items are BOTH square source assets, so each one
    /// renders exactly this wide. Pinning the width explicitly (rather than
    /// letting the card box decide) is what lets the box be narrower than the
    /// art, which is the only way to close the gap: the visible separation is
    /// never just `spacing`, it is `spacing` plus the neighbour's depth
    /// scale-down, and no amount of shrinking the box helps while the box is
    /// also what sizes the picture.
    private var artWidth: CGFloat { artHeight * 0.86 }

    var body: some View {
        // The box is deliberately ~94% of the artwork, so neighbouring pieces
        // close to a ~3 pt gap at every size class while each one still renders
        // at full natural size. Nothing clips: these cards have no background,
        // and the carousel only clips at its own bounds. Spacing and speed are
        // inherited from the engine.
        FocusContinuousCarousel(
            items: items,
            selectedIndex: $selectedIndex,
            maximumCardWidth: artWidth * 0.94,
            cardWidthFraction: 0.9,
            minimumCardWidth: 110
        ) { item, prominence in
            // No card. These are transparent PNGs (and a vector balloon) and they
            // float directly on the paywall — the rounded panel that used to sit
            // behind each one boxed every collectible into the same silhouette and
            // clipped the artwork it was meant to present. What remains is a soft
            // contact shadow belonging to the object itself.
            VStack(spacing: 8) {
                collectibleArt(item)
                    .frame(width: artWidth, height: artHeight)
                    .shadow(color: .black.opacity(0.30), radius: 16, y: 10)
                    // Decoration: VoiceOver reads the collectible's NAME below,
                    // not a nameless moving image.
                    .accessibilityHidden(true)
                Text(item.title)
                    .font(.system(size: prominence > 0.55 ? 16 : 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.72 + prominence * 0.28))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .shadow(color: .black.opacity(0.55), radius: 5, y: 2)
            }
            .padding(.horizontal, 2)
        }
    }

    @ViewBuilder private func collectibleArt(_ item: PaywallCollectible) -> some View {
        switch item {
        case .skin(let skin):
            BalloonView(height: artHeight * 0.86, showBurner: false, showGlow: false, skin: skin)
        case .item(let item):
            #if canImport(UIKit)
            if let image = UIImage(named: item.bestAssetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    // Vertical inset only. The horizontal 10 pt that used to sit
                    // here was dead box on top of the card's own padding — it
                    // shrank the object AND widened the gap to its neighbour.
                    .padding(.vertical, artHeight * 0.07)
            } else {
                Image(systemName: item.systemImage)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(item.tint)
            }
            #else
            Image(systemName: item.systemImage)
                .font(.system(size: 56, weight: .medium))
                .foregroundStyle(item.tint)
            #endif
        }
    }
}

private struct PaywallSkyCarousel: View {
    @Binding var selectedIndex: Int
    @EnvironmentObject private var appModel: AppModel

    /// ONLY the four PRO-exclusive Skies may be promoted here — a progression Sky
    /// (Fiji, Northern Aurora, Deep Space) is not something PRO buys, so showing
    /// it would be a false promise. Single source of truth: `FocusSky.proExclusive`.
    private var skies: [FocusSky] {
        FocusSky.proExclusive
    }

    var body: some View {
        // A Sky is a landscape and keeps a wider box than a collectible. Its
        // preview FILLS that box (no transparency), so the visible gap here is
        // exactly `spacing` — 5 pt, the middle of the 4-6 pt target for
        // landscapes. Speed is inherited from the engine.
        FocusContinuousCarousel(
            items: skies,
            selectedIndex: $selectedIndex,
            spacing: 5,
            maximumCardWidth: 300,
            cardWidthFraction: 0.60,
            minimumCardWidth: 180
        ) { sky, prominence in
            ZStack {
                // Static artwork, not a live scene graph: four of these are on
                // screen at once, and the conveyor is the only thing that moves.
                SkyStillPreview(sky: sky)

                LinearGradient(colors: [.clear, .black.opacity(0.46)],
                               startPoint: .center, endPoint: .bottom)

                BalloonView(
                    height: 54 + 18 * prominence,
                    showBurner: true,
                    showGlow: prominence > 0.55,
                    skin: appModel.selectedSkin
                )
                .offset(y: 10 - 6 * prominence)
                .accessibilityHidden(true)

                VStack {
                    Spacer()
                    Text(sky.name)
                        .font(.system(size: prominence > 0.55 ? 16 : 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.bottom, 12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.09 + prominence * 0.11), lineWidth: 1))
        }
    }
}

// MARK: - Flagship showcase (general PRO)

/// One slide of the general paywall's reel.
///
/// Four different kinds of thing — a Sky, a feature, a balloon skin, a cabin
/// object — deliberately share ONE card shape, one caption block and one
/// ground. That is the whole trick: mixed content only reads as random when
/// each piece brings its own presentation with it.
enum PaywallShowcaseSlide: Identifiable {
    case sky(FocusSky)
    case feature(key: String, title: String, asset: String)
    case skin(BalloonSkin)
    case item(StoreItem)

    var id: String {
        switch self {
        case .sky(let sky):           return "sky.\(sky.id)"
        case .feature(let key, _, _): return "feature.\(key)"
        case .skin(let skin):         return "skin.\(skin.id)"
        case .item(let item):         return "item.\(item.id)"
        }
    }

    var title: String {
        switch self {
        case .sky(let sky):             return sky.name
        case .feature(_, let title, _): return title
        case .skin(let skin):           return skin.name
        case .item(let item):           return item.name
        }
    }

    /// Which bucket this slide came from. The interleave is defined in terms of
    /// this, and so is the check that no two neighbours share it.
    enum Category: String { case sky, feature, skin, item }

    var category: Category {
        switch self {
        case .sky:     return .sky
        case .feature: return .feature
        case .skin:    return .skin
        case .item:    return .item
        }
    }

    /// The small line above the name. It is what makes a starfield, a balloon
    /// and a pair of headphones on one conveyor feel like a single offer being
    /// presented rather than three unrelated pictures going past.
    var kicker: String {
        switch self {
        case .sky:     return "EXCLUSIVE SKY"
        case .feature: return "PRO FEATURE"
        case .skin:    return "BALLOON SKIN"
        case .item:    return "CABIN ITEM"
        }
    }
}

/// The general/onboarding paywall's hero: everything PRO opens up, on the same
/// clock-driven conveyor the Sky and collectible paywalls already use.
struct PaywallShowcaseCarousel: View {
    @Binding var selectedIndex: Int
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.focusViewport) private var viewport

    /// The PRO features shown in the GENERAL reel.
    ///
    /// Online Mode alone. Infinite Time and Pause a Flight were removed from
    /// this surface: both are timer *modifiers* whose artwork reads as a screen
    /// rather than as a thing you get, and next to four Skies, four balloons and
    /// three cabin objects they made the flagship reel look like a features list
    /// instead of a catalogue. Their assets and their own dedicated paywalls
    /// (`.infinite`, `.pause`) are untouched — this is the general reel's
    /// composition, not a change to what PRO includes.
    private static let features: [PaywallShowcaseSlide] = [
        .feature(key: "online", title: "Online Mode", asset: "PaywallHero_OnlineMode"),
    ]

    /// The canonical buckets, in presentation order. Every promotional surface
    /// that shows "what PRO opens up" reads these lists, so the reel can never
    /// drift from the real catalog.
    static var buckets: [[PaywallShowcaseSlide]] {
        [
            BalloonSkin.all.filter(\.isPremium).map(PaywallShowcaseSlide.skin),
            FocusSky.proExclusive.map(PaywallShowcaseSlide.sky),
            StoreItem.all.filter(\.isPremium).map(PaywallShowcaseSlide.item),
            Self.features,
        ]
    }

    /// Curated, not concatenated — and computed in ONE place rather than being
    /// spelled out slide by slide in the view body.
    ///
    /// Deterministic: the flagship page looks identical every time it opens,
    /// which a shuffle could not promise and which makes the layout reviewable.
    static var slides: [PaywallShowcaseSlide] { interleaved(buckets) }

    private var slides: [PaywallShowcaseSlide] { Self.slides }

    /// One slide from each non-empty bucket per round, buckets that run out
    /// simply dropping away. With the current catalog — 4 skins, 4 Skies, 3
    /// items, 1 feature — that yields skin → Sky → item → Online → skin → Sky →
    /// item → … : categories alternate, nothing repeats back to back, and the
    /// distribution is as even as unequal bucket sizes allow.
    static func interleaved(_ buckets: [[PaywallShowcaseSlide]]) -> [PaywallShowcaseSlide] {
        var result: [PaywallShowcaseSlide] = []
        var cursors = Array(repeating: 0, count: buckets.count)
        var placed = true
        while placed {
            placed = false
            for (bucket, contents) in buckets.enumerated() where cursors[bucket] < contents.count {
                result.append(contents[cursors[bucket]])
                cursors[bucket] += 1
                placed = true
            }
        }
        return result
    }

    #if DEBUG
    /// The reel's one visual promise: no two neighbours share a category — and
    /// that includes the wrap from the last slide back to the first, because the
    /// conveyor loops and a seam is just another adjacency.
    ///
    /// Asserted rather than eyeballed because it is a property of the CATALOG,
    /// not of this file: adding a fifth cabin item or retiring a Sky changes the
    /// bucket sizes, and the tail of an uneven round-robin is exactly where a run
    /// of three items would appear.
    static func _selfCheck() -> String? {
        let reel = slides
        guard reel.count > 1 else { return nil }
        for index in reel.indices {
            let next = reel[(index + 1) % reel.count]
            if reel[index].category == next.category {
                return "showcase reel repeats \(reel[index].category.rawValue) at \(index)"
            }
        }
        if Set(reel.map(\.id)).count != reel.count { return "showcase reel duplicates a slide" }
        return nil
    }
    #endif

    private var cardRadius: CGFloat { viewport.isCompact ? 24 : 28 }
    private var balloonHeight: CGFloat { viewport.paywallHeroHeight * 0.60 }

    var body: some View {
        // Spacing and speed are the engine's shared values — these cards are
        // opaque and fill their box, so the visible gap IS the 5 pt, the middle
        // of the landscape target the Sky carousel already sits at.
        FocusContinuousCarousel(
            items: slides,
            selectedIndex: $selectedIndex,
            spacing: 5,
            maximumCardWidth: 340,
            cardWidthFraction: 0.64,
            minimumCardWidth: 190
        ) { slide, prominence in
            card(slide, prominence: prominence)
        }
    }

    private func card(_ slide: PaywallShowcaseSlide, prominence: Double) -> some View {
        let shape = RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
        return ZStack {
            // One ground under every slide. A Sky covers it completely; objects
            // and features sit on it. This is what keeps four kinds of artwork
            // looking like pages of the same catalogue.
            LinearGradient(colors: [Color(hex: 0x1A2030), Color(hex: 0x0B0E15)],
                           startPoint: .top, endPoint: .bottom)

            art(slide, prominence: prominence)

            // The caption always gets its own darkness, whatever is behind it.
            LinearGradient(colors: [.clear, .black.opacity(0.62)],
                           startPoint: UnitPoint(x: 0.5, y: 0.52), endPoint: .bottom)

            VStack(spacing: 1) {
                Spacer(minLength: 0)
                Text(slide.kicker)
                    .font(.system(size: 9.5, weight: .heavy))
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.42 + prominence * 0.30))
                    .lineLimit(1)
                Text(slide.title)
                    .font(.system(size: prominence > 0.55 ? 16 : 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.09 + prominence * 0.13), lineWidth: 1))
        .shadow(color: .black.opacity(0.34), radius: 14, y: 8)
    }

    @ViewBuilder private func art(_ slide: PaywallShowcaseSlide, prominence: Double) -> some View {
        switch slide {
        case .sky(let sky):
            // A Sky IS the scene, so it fills the card edge to edge with the
            // pilot's own balloon flying in it — the same treatment the Sky
            // paywall uses, so the two surfaces stay recognisably related.
            ZStack {
                SkyStillPreview(sky: sky)
                BalloonView(height: 48 + 14 * prominence,
                            showBurner: true,
                            showGlow: prominence > 0.55,
                            skin: appModel.selectedSkin)
                    .offset(y: 2 - 6 * prominence)
                    .accessibilityHidden(true)
            }

        case .feature(_, _, let asset):
            featureArt(asset)

        case .skin(let skin):
            spotlit {
                BalloonView(height: balloonHeight, showBurner: false, showGlow: false, skin: skin)
                    .shadow(color: .black.opacity(0.34), radius: 14, y: 10)
            }

        case .item(let item):
            spotlit { itemArt(item) }
        }
    }

    /// A soft pool of light under an isolated object, so a transparent cut-out
    /// has something to stand on instead of hanging in a flat rectangle. The
    /// bottom inset keeps it clear of the caption.
    private func spotlit<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            RadialGradient(colors: [.white.opacity(0.10), .clear],
                           center: UnitPoint(x: 0.5, y: 0.44), startRadius: 4, endRadius: 150)
            content()
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 44)
        }
    }

    /// Wide feature artwork, presented SQUARE.
    ///
    /// The Online Mode hero is a 1670×950 (≈16:9) capture of a real flight. Shown
    /// at its own ratio it was the odd one out on a reel of square-ish balloons,
    /// Skies and cabin objects — either letterboxed into dead space or blurred
    /// out to the card edges. Here it is centre-cropped into a square that sits
    /// on the same ground every other slide uses, so the four kinds of artwork
    /// finally read as one catalogue.
    ///
    /// Centre alignment is correct for this specific asset rather than a default:
    /// "YOU", the remaining time and the ring of other pilots are all in the
    /// middle third, and it is the far-left and far-right columns of names the
    /// crop discards. `.fill` + `.clipped()` crops the VIEW; the source asset is
    /// never modified, and the dedicated Online paywall still shows it whole.
    @ViewBuilder private func featureArt(_ asset: String) -> some View {
        #if canImport(UIKit)
        if let image = UIImage(named: asset) {
            GeometryReader { geo in
                // The caption band owns the bottom of the card, so the square is
                // measured against what is left above it — never against the
                // full height, which would slide it under the title.
                let captionBand: CGFloat = 42
                let side = max(0, min(geo.size.width - 22,
                                      geo.size.height - captionBand - 14))
                let radius = max(10, cardRadius - 8)
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: side, height: side)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(.white.opacity(0.11), lineWidth: 1))
                    .shadow(color: .black.opacity(0.42), radius: 12, y: 7)
                    .position(x: geo.size.width / 2,
                              y: (geo.size.height - captionBand) / 2)
            }
        }
        #endif
    }

    @ViewBuilder private func itemArt(_ item: StoreItem) -> some View {
        #if canImport(UIKit)
        if let image = UIImage(named: item.bestAssetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .shadow(color: .black.opacity(0.34), radius: 14, y: 10)
        } else {
            Image(systemName: item.systemImage)
                .font(.system(size: 54, weight: .medium))
                .foregroundStyle(item.tint)
        }
        #else
        Image(systemName: item.systemImage)
            .font(.system(size: 54, weight: .medium))
            .foregroundStyle(item.tint)
        #endif
    }
}

// MARK: - Trial and comparison

private struct TrialTimeline: View {
    let compact: Bool
    /// The REAL introductory period, so the day numbers match the offer the App
    /// Store will actually apply rather than a hardcoded schedule.
    var trialDays: Int = 3

    /// Milestones, not arithmetic.
    ///
    /// The labels used to be "Today / Day 5 / Day 7", which asked the reader to
    /// do the subtraction and — on a three-day offer — printed two day numbers
    /// two apart under a title that says "2 days before". Naming the moments
    /// instead says the same true thing without a single number that could
    /// disagree with the App Store.
    private var steps: [(icon: String, title: String, detail: String, color: Color)] {
        var result: [(icon: String, title: String, detail: String, color: Color)] = [
            ("lock.open.fill", "Today", "Enjoy all PRO features and content", ProBrand.c1)
        ]
        // A trial shorter than three days has no "2 days before" to speak of,
        // and claiming one would contradict the reminder the app schedules.
        if trialDays > 2 {
            result.append(("bell.fill", "2 days before",
                           "We notify you about your trial end", ProBrand.c2))
        }
        result.append(("star.fill", "Trial end date",
                       "Your annual subscription begins", ProBrand.c4))
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle().fill(step.color)
                            Image(systemName: step.icon)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: compact ? 36 : 40, height: compact ? 36 : 40)

                        if index < steps.count - 1 {
                            Rectangle()
                                .fill(LinearGradient(
                                    colors: [step.color, steps[index + 1].color],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .frame(width: 4, height: compact ? 36 : 46)
                        }
                    }

                    VStack(alignment: .leading, spacing: compact ? 3 : 5) {
                        Text(step.title)
                            .font(.system(size: compact ? 17 : 19, weight: .bold))
                            .foregroundStyle(.white)
                        Text(step.detail)
                            .font(.system(size: compact ? 13 : 14.5, weight: .regular))
                            .foregroundStyle(.white.opacity(0.66))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)

                    Spacer(minLength: 0)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct PaywallComparisonTable: View {
    var highlighted: String? = nil
    @Environment(\.focusViewport) private var viewport

    /// One canonical benefit list, shared by every paywall that shows this table.
    ///
    /// A row now carries its own FREE availability instead of the column being
    /// hardcoded to a dash. That is what lets the table open with something the
    /// pilot ALREADY has: a comparison whose free column is empty top to bottom
    /// reads as a list of things withheld rather than as a comparison.
    struct Row: Identifiable {
        let title: String
        /// Whether the FREE column shows a checkmark rather than a dash.
        var inFree: Bool = false
        var id: String { title }
    }

    static let rows: [Row] = [
        // The core timer is free, has always been free, and saying so first
        // costs nothing and makes every row under it more credible.
        Row(title: "Focus Timer", inFree: true),
        Row(title: "No Ads"),
        Row(title: "Online & Friends"),
        Row(title: "Unlimited Time  ∞"),
        Row(title: "Exclusive Skies"),
        Row(title: "Exclusive Skins & Items"),
        Row(title: "2x Coins in trips"),
    ]

    private var freeWidth: CGFloat { viewport.isCompact ? 52 : 66 }
    private var proWidth: CGFloat { viewport.isCompact ? 68 : 84 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Text("FREE")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: freeWidth)
                FocusGlobePROBadge(visibleHeight: 16)
                    .frame(width: proWidth)
            }
            .padding(.vertical, 8)

            ForEach(Array(Self.rows.enumerated()), id: \.element.id) { index, item in
                row(item)
                if index < Self.rows.count - 1 {
                    HStack(spacing: 0) {
                        Rectangle().fill(.white.opacity(0.09)).frame(height: 1)
                        Color.clear.frame(width: proWidth)
                    }
                }
            }
        }
        .background(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(ProBrand.columnWash)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(ProBrand.borderGradient, lineWidth: 1).opacity(0.55))
                .frame(width: proWidth)
                .shadow(color: ProBrand.glow.opacity(0.28), radius: 16, y: 6)
        }
    }

    private func row(_ item: Row) -> some View {
        let title = item.title
        let isHighlighted = title == highlighted
        return HStack(spacing: 0) {
            Text(title)
                .font(.system(size: viewport.isCompact ? 14.5 : 16.5,
                              weight: isHighlighted ? .bold : .semibold))
                .foregroundStyle(isHighlighted
                    ? AnyShapeStyle(ProBrand.softGradient)
                    : AnyShapeStyle(Color.white))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, alignment: .leading)

            // The same checkmark glyph in both columns when a benefit is genuinely
            // in both — a different tick for FREE would read as a lesser version
            // of the feature rather than the same one.
            Image(systemName: item.inFree ? "checkmark" : "minus")
                .font(.system(size: item.inFree ? 16 : 15, weight: .heavy))
                .foregroundStyle(.white.opacity(item.inFree ? 0.78 : 0.24))
                .frame(width: freeWidth)

            Image(systemName: "checkmark")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: proWidth)
        }
        .frame(height: viewport.isCompact ? 39 : 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.inFree ? "\(title). Free and PRO." : "\(title). PRO only.")
    }
}
