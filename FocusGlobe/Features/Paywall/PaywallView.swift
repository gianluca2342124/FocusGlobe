import Combine
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// FocusGlobe's single contextual PRO experience. Page one explains the exact
/// benefit the pilot touched; page two explains the trial and is the only page
/// capable of starting a RevenueCat purchase.
struct PaywallView: View {
    var context: PaywallContext = .general

    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.focusViewport) private var viewport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var page: Page = .benefit
    @State private var selectedKind: PlanKind = .annual
    @State private var selectedHeroIndex = 0

    private enum Page { case benefit, trial }
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
            appModel.analytics.log(.paywallOpened)
            subs.loadOfferings()
            syncSelection()
            selectedHeroIndex = context.initialHeroIndex
            // The first-run offer IS the offer page: one product, one CTA, no
            // benefit/trial two-step. Onboarding has already made the pitch.
            if context.isOnboardingOffer { page = .trial }
        }
        .onChange(of: subs.plans) { _, _ in syncSelection() }
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

            if appModel.isPro {
                proState
            } else {
                Button {
                    appModel.tapFeedback()
                    withAnimation(AppMotion.content.respecting(reduceMotion)) {
                        page = .trial
                    }
                } label: {
                    Text(showsTrialCopy ? "Start My Free Trial" : "See Plans")
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
    }

    @ViewBuilder private var contextualHero: some View {
        switch context {
        case .sky:
            PaywallSkyCarousel(selectedIndex: $selectedHeroIndex)
        case .balloonSkin, .interior:
            PaywallCollectibleCarousel(selectedIndex: $selectedHeroIndex)
        default:
            PaywallContextHero(context: context)
        }
    }

    // MARK: - Page two

    private var trialPage: some View {
        VStack(spacing: 0) {
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

            if appModel.isPro {
                proState
            } else {
                purchaseFooter
            }
        }
    }

    private var trialContent: some View {
        VStack(spacing: viewport.isWide ? 24 : (viewport.isShort ? 13 : 18)) {
            trialTitle

            // The timeline describes a free trial, so it appears ONLY when this
            // account is actually getting one for the product being bought.
            if showsTrialCopy {
                TrialTimeline(compact: viewport.isShort || viewport.isCompact,
                              trialDays: effectivePlan?.introOffer?.periodValue ?? 3)
                    .frame(maxWidth: viewport.isWide ? 620 : 540)
            }

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
        }
        .frame(maxWidth: viewport.readableContentWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, viewport.pagePadding)
        .padding(.top, viewport.isShort ? 2 : 8)
        .padding(.bottom, viewport.isShort ? 10 : 16)
    }

    /// Leads with the free trial ONLY when there is one. An ineligible account
    /// (or a monthly selection) sees a plain product headline instead of a
    /// promise the App Store would refuse to honour.
    private var trialTitle: some View {
        Group {
            if showsTrialCopy {
                Text(trialHeadlineDuration).foregroundStyle(ProBrand.softGradient)
                + Text("\nFree Trial")
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
        .accessibilityLabel(showsTrialCopy
                            ? "\(trialHeadlineDuration) free trial"
                            : "Unlock FocusGlobe PRO")
    }

    /// "3-Day" — built from the product's REAL introductory period.
    private var trialHeadlineDuration: String {
        guard let offer = effectivePlan?.introOffer else { return "Free" }
        let unit = offer.periodUnit.prefix(1).uppercased() + String(offer.periodUnit.dropFirst())
        return "\(offer.periodValue)-\(unit)"
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
        if plan.offersFreeTrial {
            return "\(plan.introOffer?.localizedDuration ?? "") free, then billed yearly"
        }
        switch kind {
        case .annual:
            return plan.monthlyEquivalent.map { "Billed yearly · \($0)" } ?? "Billed yearly"
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
                            Text("Best Value")
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

    private func paywallHeader(
        backAction: (() -> Void)?,
        showsClose: Bool
    ) -> some View {
        HStack {
            if let backAction {
                AppIconButton(systemImage: "chevron.left", size: viewport.navigationControlSize,
                              tint: .white, accessibilityLabel: "Back", action: backAction)
            } else {
                Color.clear.frame(width: viewport.navigationControlSize,
                                  height: viewport.navigationControlSize)
            }
            Spacer()
            if showsClose {
                AppIconButton(systemImage: "xmark", size: viewport.navigationControlSize,
                              tint: .white, accessibilityLabel: "Close") {
                    appModel.tapFeedback()
                    dismiss()
                }
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

    private var proState: some View {
        VStack(spacing: 10) {
            Label("Your PRO is active", systemImage: "checkmark.seal.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColors.success)
            Button("Close") { dismiss() }
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: viewport.buttonHeight)
                .background(Capsule().fill(ProBrand.primaryButton))
                .buttonStyle(SoftPressStyle())
        }
        .frame(maxWidth: viewport.modalWidth)
        .padding(.horizontal, viewport.pagePadding)
        .padding(.bottom, viewport.pagePadding)
    }

    private var background: some View {
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
        if showsTrialCopy { return "Start My Free Trial" }
        switch kind {
        case .annual:   return "Continue with Annual"
        case .monthly:  return "Continue with Monthly"
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
                dismiss()
            }
        }
    }

    private func restore() {
        appModel.tapFeedback()
        Task { @MainActor in
            let ok = await appModel.restorePurchases()
            if ok { dismiss() }
        }
    }
}

// MARK: - Context heroes

private struct PaywallContextHero: View {
    let context: PaywallContext
    @Environment(\.focusViewport) private var viewport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false

    var body: some View {
        ZStack {
            #if canImport(UIKit)
            if let image = UIImage(named: context.heroAssetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(viewport.isWide ? 10 : 5)
                    .offset(y: floating ? -5 : 5)
                    .shadow(color: .black.opacity(0.24), radius: 12, y: 6)
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

// MARK: - Trial and comparison

private struct TrialTimeline: View {
    let compact: Bool
    /// The REAL introductory period, so the day numbers match the offer the App
    /// Store will actually apply rather than a hardcoded schedule.
    var trialDays: Int = 3

    private var steps: [(icon: String, title: String, detail: String, color: Color)] {
        let endDay = max(2, trialDays)
        let reminderDay = max(2, endDay - 1)
        return [
            ("lock.open.fill", "Today", "Unlock all FocusGlobe PRO features.", ProBrand.c1),
            ("bell.fill", "Day \(reminderDay)", "We’ll remind you before your free trial ends.", ProBrand.c2),
            ("star.fill", "Day \(endDay)", "Your subscription begins. Cancel anytime.", ProBrand.c4),
        ]
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

    private static let rows: [String] = [
        "No Ads",
        "Online & Friends",
        "Unlimited Time  ∞",
        "Exclusive Skies",
        "Exclusive Skins & Items",
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

            ForEach(Array(Self.rows.enumerated()), id: \.offset) { index, title in
                row(title)
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

    private func row(_ title: String) -> some View {
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

            Image(systemName: "minus")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.white.opacity(0.24))
                .frame(width: freeWidth)

            Image(systemName: "checkmark")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: proWidth)
        }
        .frame(height: viewport.isCompact ? 39 : 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). PRO only.")
    }
}
