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
    private static let offeredPlans: [PlanKind] = [.annual, .monthly]
    private var subs: SubscriptionManager { appModel.subscriptions }

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
                    Text("Start 7 days free trial")
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
            paywallHeader(backAction: {
                appModel.tapFeedback()
                withAnimation(AppMotion.content.respecting(reduceMotion)) {
                    page = .benefit
                }
            }, showsClose: false)

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

            TrialTimeline(compact: viewport.isShort || viewport.isCompact)
                .frame(maxWidth: viewport.isWide ? 620 : 540)

            VStack(spacing: 9) {
                ForEach(Self.offeredPlans) { kind in
                    planCard(kind)
                }
            }
            .frame(maxWidth: viewport.isWide ? 620 : 540)
        }
        .frame(maxWidth: viewport.readableContentWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, viewport.pagePadding)
        .padding(.top, viewport.isShort ? 2 : 8)
        .padding(.bottom, viewport.isShort ? 10 : 16)
    }

    private var trialTitle: some View {
        VStack(spacing: 8) {
            Text("We’ll remind you")
            + Text(" 2 days").foregroundStyle(ProBrand.softGradient)
            + Text("\nbefore your trial ends")
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
        .accessibilityLabel("We’ll remind you 2 days before your trial ends")
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

    private func planCard(_ kind: PlanKind) -> some View {
        let plan = subs.plan(kind)
        let selected = selectedKind == kind
        let unavailable = subs.hasAnyPackage && !(plan?.available ?? false)

        return Button {
            appModel.tapFeedback()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
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
                    if kind == .annual, let monthly = plan?.monthlyEquivalent {
                        Text(monthly)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.62))
                    }
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

    private var effectiveKind: PlanKind? {
        if Self.offeredPlans.contains(selectedKind),
           subs.plan(selectedKind)?.available == true {
            return selectedKind
        }
        return Self.offeredPlans.first { subs.plan($0)?.available == true }
    }

    private var purchaseButtonTitle: String {
        guard let kind = effectiveKind else { return "Products unavailable" }
        // Monthly is exactly "Continue" — never "Continue with Monthly" or any
        // other extended wording.
        return kind == .annual ? "Start 7 days free trial" : "Continue"
    }

    private var trialDisclosure: String {
        effectiveKind == .annual
            ? "7 days free, then the selected plan. Cancel anytime."
            : "The selected plan renews automatically. Cancel anytime."
    }

    private var paywallButtonHeight: CGFloat {
        viewport.isWide ? 58 : (viewport.isShort ? 50 : 54)
    }

    private func syncSelection() {
        guard subs.hasAnyPackage else { return }
        if !Self.offeredPlans.contains(selectedKind)
            || subs.plan(selectedKind)?.available != true,
           let preferred = Self.offeredPlans.first(where: {
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

    var body: some View {
        FocusContinuousCarousel(
            items: items,
            selectedIndex: $selectedIndex,
            spacing: 12,
            maximumCardWidth: 330,
            speed: 34
        ) { item, prominence in
            // No card. These are transparent PNGs (and a vector balloon) and they
            // float directly on the paywall — the rounded panel that used to sit
            // behind each one boxed every collectible into the same silhouette and
            // clipped the artwork it was meant to present. What remains is a soft
            // contact shadow belonging to the object itself.
            VStack(spacing: 8) {
                collectibleArt(item)
                    .frame(maxWidth: .infinity)
                    .frame(height: artHeight)
                    .shadow(color: .black.opacity(0.30), radius: 16, y: 10)
                Text(item.title)
                    .font(.system(size: prominence > 0.55 ? 16 : 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.72 + prominence * 0.28))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .shadow(color: .black.opacity(0.55), radius: 5, y: 2)
            }
            .padding(.horizontal, 6)
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
                    .padding(.horizontal, 10)
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
        FocusContinuousCarousel(
            items: skies,
            selectedIndex: $selectedIndex,
            spacing: 12,
            maximumCardWidth: 330,
            speed: 34
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

    private let steps: [(icon: String, title: String, detail: String, color: Color)] = [
        ("lock.open.fill", "Today", "Unlock all FocusGlobe PRO features.", ProBrand.c1),
        ("bell.fill", "2 days before", "We’ll remind you before your free trial ends.", ProBrand.c2),
        ("star.fill", "Trial end date", "Your selected plan begins. Cancel anytime.", ProBrand.c4),
    ]

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
