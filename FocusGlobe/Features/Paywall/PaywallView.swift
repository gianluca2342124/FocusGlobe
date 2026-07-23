import Combine
import SwiftUI
import UIKit

/// The custom FocusGlobe premium paywall — a dark/gold luxury screen that drives
/// RevenueCat purchases underneath (via `AppModel.subscriptions`). This is the
/// single premium surface for every trigger (crown, Ultra lock, premium skins,
/// go-Pro). It never uses the RevenueCatUI template paywall.
///
/// Prices are the App Store localized prices from RevenueCat (never hardcoded);
/// the fallback placeholders only appear in the disabled "products unavailable"
/// state.
struct PaywallView: View {
    /// WHY this paywall opened — one reusable view renders the right headline
    /// and hero per context (never a duplicated paywall implementation).
    var context: PaywallContext = .general

    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedKind: PlanKind = .annual
    /// Drives the periodic gloss sweep across the purchase CTA (off-screen at rest).
    @State private var shineX: CGFloat = -0.5
    private let shineTimer = Timer.publish(every: 3.6, on: .main, in: .common).autoconnect()

    // Privacy / Terms links are centralised and configurable in `LegalLinks`
    // (replace the placeholder URLs there before release — see APP_STORE_READINESS.md).

    private var subs: SubscriptionManager { appModel.subscriptions }

    var body: some View {
        ZStack {
            staticBackground
            // The close button, plans and the gold CTA are pinned so the purchase
            // button is always visible without scrolling on every iPhone. Only the
            // hero + benefits live in a flexible scroll area (they compress to fit
            // on normal devices and scroll only on the very smallest screens).
            VStack(spacing: AppSpacing.sm) {
                closeRow
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.sm) {
                        // The FocusGlobe PRO identity lockup FIRST — native bold
                        // wordmark + the real PRO badge (no gold balloon anymore).
                        FocusGlobePROBrand(size: .hero)
                        Text(context.headline)
                            .font(.system(size: Layout.pad(24, 31), weight: .bold, design: .default))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        // The contextual hero image (mapped from the context). Omits
                        // cleanly when its asset hasn't shipped — never a gold balloon,
                        // never an empty box.
                        contextHeroImage
                        if context != .general {
                            Text("+ Unlock so much more with PRO")
                                .font(.system(size: 13, weight: .semibold, design: .default))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        PaywallComparisonTable(highlighted: context.comparisonHighlight)
                    }
                    .padding(.bottom, AppSpacing.xs)
                }
                if appModel.isPro { proState } else { purchaseSection }
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, AppSpacing.md)
            .paywallMaxWidth()   // premium centred panel on iPad/Mac; full-width on iPhone
        }
        // The paywall is a fixed dark/gold luxury surface. Lock it to the dark
        // rendering so it looks identical in Light Mode — materials, tints and the
        // gold never lighten. (This is the one screen exempt from Light Mode.)
        .environment(\.colorScheme, .dark)
        .onAppear {
            appModel.analytics.log(.paywallOpened)
            subs.loadOfferings()
            syncSelection()
        }
        // When offerings/prices finish loading, move the selection onto a plan that
        // actually has a package, so the CTA becomes enabled instead of sitting on
        // an unavailable default.
        .onChange(of: subs.plans) { _, _ in syncSelection() }
    }

    // MARK: Background — a STABLE dark atmosphere on the #181721 neutral.
    // No motion, no looping blobs: the hero and the gold plans are the visual.

    private var staticBackground: some View {
        ZStack {
            LinearGradient(colors: [AppColors.neutralRaised, AppColors.neutralBase, AppColors.neutralDeep],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [ProBrand.glow.opacity(0.16), .clear],
                           center: .top, startRadius: 10, endRadius: 420)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: Contextual hero image (ONE paywall, many entries)

    /// The contextual hero art, resolved through the centralized
    /// `PaywallContext.heroAssetName` mapping (`PaywallHero_…`). Rendered
    /// `scaledToFit` at a compact max height that leaves room for the table + CTA
    /// on the smallest iPhone. If the asset hasn't shipped it is omitted cleanly —
    /// no empty box, no SF Symbol, and never the old golden balloon.
    @ViewBuilder private var contextHeroImage: some View {
        #if canImport(UIKit)
        if let ui = UIImage(named: context.heroAssetName) {
            let cap = min(max(UIScreen.main.bounds.width * 0.30, 108), 150)
            Image(uiImage: ui)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: cap)
                .padding(.vertical, 2)
                .accessibilityHidden(true)
        }
        #endif
    }

    // MARK: Header

    private var closeRow: some View {
        HStack {
            Spacer()
            AppIconButton(systemImage: "xmark", size: 36, tint: .white, accessibilityLabel: "Close") {
                appModel.tapFeedback(); dismiss()
            }
        }
        .padding(.top, AppSpacing.xs)
    }


    // MARK: Already Pro

    private var proState: some View {
        VStack(spacing: AppSpacing.sm) {
            Label("Your PRO is active", systemImage: "checkmark.seal.fill")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.success)
            Button { appModel.tapFeedback(); dismiss() } label: {
                Text("Close")
                    .font(AppTypography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(Capsule().fill(ProBrand.gradient))
            }
            .buttonStyle(SoftPressStyle())
        }
    }

    // MARK: Plans + purchase

    /// The plans OFFERED to new purchasers: Annual (hero) + Monthly only.
    /// Lifetime is retired from the purchase UI — existing Lifetime owners keep
    /// their entitlement (any active entitlement = Pro) and Restore Purchases
    /// continues to recognise it; nothing about ownership is revoked.
    private static let offeredPlans: [PlanKind] = [.annual, .monthly]

    private var purchaseSection: some View {
        VStack(spacing: AppSpacing.sm) {
            ForEach(Self.offeredPlans) { kind in planCard(kind) }

            purchaseButton
                .padding(.top, 4)

            if let message = subs.errorMessage {
                Text(message)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.danger)
                    .multilineTextAlignment(.center)
            }

            // ONE compact footer line — Restore Purchases • Privacy • Terms —
            // each independently tappable. RevenueCat restore is unchanged.
            HStack(spacing: 6) {
                Button { restore() } label: {
                    Text("Restore Purchases")
                }
                .buttonStyle(SoftPressStyle())
                Text("•").foregroundStyle(.white.opacity(0.35))
                Link("Privacy", destination: LegalLinks.privacy)
                Text("•").foregroundStyle(.white.opacity(0.35))
                Link("Terms", destination: LegalLinks.terms)
            }
            .font(AppTypography.caption)
            .foregroundStyle(.white.opacity(0.7))
            .padding(.top, 4)
        }
    }

    private func planCard(_ kind: PlanKind) -> some View {
        let plan = subs.plan(kind)
        let selected = selectedKind == kind
        // Only dim/disable an unavailable plan when *other* plans are purchasable,
        // so a partial offering clearly shows which plans can be bought. Before any
        // package loads, cards stay as neutral previews (no sad all-dimmed state).
        let dimmed = subs.hasAnyPackage && !(plan?.available ?? false)
        return Button {
            appModel.tapFeedback()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedKind = kind }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(kind.title)
                            .font(.system(size: 17, weight: .bold, design: .default))
                            .foregroundStyle(.white)
                        if kind == .annual { discountBadge }
                    }
                    if let sub = planSubtitle(kind, plan) {
                        Text(sub)
                            .font(AppTypography.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                Spacer()
                Text(plan?.localizedPrice ?? "—")
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, AppSpacing.sm)
            .padding(.horizontal, AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.pillRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: AppSpacing.pillRadius, style: .continuous)
                        .fill(Color.black.opacity(selected ? 0.10 : 0.28)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.pillRadius, style: .continuous)
                    .strokeBorder(selected ? AnyShapeStyle(ProBrand.borderGradient)
                                           : AnyShapeStyle(Color.white.opacity(0.16)),
                                  lineWidth: selected ? 2 : 1)
            )
            .shadow(color: selected ? ProBrand.glow.opacity(0.35) : .clear, radius: 12, y: 0)
        }
        .buttonStyle(SoftPressStyle(scale: 0.99))
        .opacity(dimmed ? 0.45 : 1)
        .disabled(dimmed)
    }

    private func planSubtitle(_ kind: PlanKind, _ plan: PlanOption?) -> String? {
        switch kind {
        case .annual:   return plan?.monthlyEquivalent
        case .lifetime: return "Pay once."
        case .monthly:  return nil
        }
    }

    private var discountBadge: some View {
        Text("-60%")
            .font(.system(size: 10, weight: .heavy, design: .default))
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(ProBrand.c1))   // savings green (PRO spectrum, not gold)
    }

    private var purchaseButton: some View {
        // Drive the CTA from the plan it will actually buy (`effectiveKind`): the
        // user's selection when it has a package, otherwise the preferred available
        // plan. So the CTA is enabled and shows real copy whenever ANY real package
        // is loaded — it can only read "Products unavailable" when zero packages
        // exist, never while a purchasable plan is on screen.
        let kind = effectiveKind
        let available = kind != nil
        let working = subs.isPurchasing
        return Button { purchase() } label: {
            ZStack {
                if working {
                    ProgressView().tint(.white)
                } else {
                    Text(available ? buttonTitle(for: kind) : "Products unavailable")
                        .font(AppTypography.headline)
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 56)
            // The primary subscription CTA is a premium, restrained near-solid
            // royal-blue — NOT the multicolor spectrum (reserved for the badge,
            // the PRO column and selected outlines). White label keeps strong
            // contrast on the dark navy; a subtle lower shadow gives depth.
            // Purchase behaviour unchanged.
            .background(Capsule().fill(ProBrand.primaryButton))
            .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
            // Subtle gloss sweep every few seconds (only on the live CTA).
            .overlay {
                if available && !working {
                    shineSweep.clipShape(Capsule()).allowsHitTesting(false)
                }
            }
            .shadow(color: ProBrand.ctaBlue.opacity(0.45), radius: 16, y: 8)
            .opacity(available ? 1 : 0.5)
        }
        .buttonStyle(SoftPressStyle())
        .disabled(!available || working)
        .onReceive(shineTimer) { _ in triggerShine() }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { triggerShine() }
        }
    }

    /// A diagonal highlight band that sweeps across the CTA, brightening the gold.
    private var shineSweep: some View {
        GeometryReader { geo in
            let w = geo.size.width
            LinearGradient(colors: [.clear, .white.opacity(0.55), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: w * 0.45, height: geo.size.height * 2)
                .rotationEffect(.degrees(20))
                .position(x: w * shineX, y: geo.size.height / 2)
                .blendMode(.plusLighter)
        }
    }

    private func triggerShine() {
        shineX = -0.5
        withAnimation(.easeInOut(duration: 1.05)) { shineX = 1.5 }
    }

    /// The plan the CTA actually purchases: the current selection when it has a
    /// loaded package, else the first OFFERED plan with a package (annual →
    /// monthly). Restricted to `offeredPlans`, so the CTA can never sell the
    /// retired Lifetime plan. `nil` only when no offered package exists — so the
    /// CTA stays enabled and truthful even for the brief partial-offering frame
    /// before `syncSelection` moves the highlighted card onto an available plan.
    private var effectiveKind: PlanKind? {
        if Self.offeredPlans.contains(selectedKind), subs.plan(selectedKind)?.available == true {
            return selectedKind
        }
        return Self.offeredPlans.first { subs.plan($0)?.available == true }
    }

    private func buttonTitle(for kind: PlanKind?) -> String {
        kind == .annual ? "Start 7 days free trial" : "Continue"
    }


    // MARK: Actions

    /// Keep the selection on a purchasable plan. Once offerings load, if the
    /// current selection has no package but another plan does, move to the
    /// preferred available one (annual → monthly → lifetime). This ensures the CTA
    /// is enabled whenever any package exists, instead of sitting disabled on an
    /// unavailable default. No-op until at least one package is available, so the
    /// user's manual choice is never overridden once real plans are on screen.
    private func syncSelection() {
        guard subs.hasAnyPackage else { return }
        if !Self.offeredPlans.contains(selectedKind) || subs.plan(selectedKind)?.available != true,
           let preferred = Self.offeredPlans.first(where: { subs.plan($0)?.available == true }) {
            selectedKind = preferred
        }
    }

    private func purchase() {
        // Buy the plan the CTA is actually offering (the selection, or the
        // preferred available plan if the selection has no package yet). Guarded so
        // a tap with zero packages loaded is a no-op rather than a failed purchase.
        guard let kind = effectiveKind else { return }
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

// MARK: - Shared Free-vs-PRO comparison

/// The ONE Free-vs-PRO comparison used by every paywall context. Nine direct,
/// benefit-led rows (No Ads deliberately second), checkmark / dash values only.
/// It is NOT a boxed table card: it sits straight on the paywall background, and
/// the PRO column is a full-height MULTICOLOR wash behind its checkmarks — the
/// strong, conversion-focused emphasis. The row matching the opening context is
/// highlighted with the PRO spectrum. Free includes only Solo Mode; every other
/// benefit is a PRO unlock, so the PRO column is all checks.
struct PaywallComparisonTable: View {
    /// The benefit row to spotlight (nil = broad entry → nothing highlighted).
    var highlighted: String? = nil

    /// (title, includedInFree). Order is fixed. PRO includes everything.
    private static let rows: [(title: String, free: Bool)] = [
        ("Solo Mode",         true),
        ("No Ads",            false),
        ("Online Mode",       false),
        ("Invite Friends",    false),
        ("Infinite Focus  ∞", false),
        ("Exclusive Skies",   false),
        ("Premium Skins",     false),
        ("Premium Items",     false),
        ("Exclusive Widgets", false),
    ]

    private var freeWidth: CGFloat { Layout.pad(56, 68) }
    private var proWidth: CGFloat { Layout.pad(80, 96) }

    var body: some View {
        VStack(spacing: 0) {
            // Column captions — no boxed header, no "What you get".
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Text("FREE")
                    .font(.system(size: 12, weight: .heavy, design: .default)).tracking(0.5)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: freeWidth)
                // The real PRO badge crowns the column (no "PRO" text).
                FocusGlobePROBadge(visibleHeight: Layout.pad(15, 18))
                    .frame(width: proWidth)
            }
            .padding(.top, Layout.pad(12, 15))
            .padding(.bottom, Layout.pad(10, 12))

            // Rows and dividers are SIBLINGS in the VStack(spacing: 0): each row is
            // a fixed-height cell (content vertically centred), and a divider is its
            // OWN 1-pt row placed BETWEEN cells — so a separator can never cross a
            // label baseline, and it always sits exactly midway between two rows.
            ForEach(Array(Self.rows.enumerated()), id: \.offset) { idx, row in
                comparisonRow(row)
                if idx < Self.rows.count - 1 { rowDivider }
            }
        }
        // The full-height PRO column, trailing-aligned behind the checks — a
        // subtle vertical MULTICOLOR wash (low opacity so the white checks stay
        // perfectly readable) with a restrained gradient outline + soft glow.
        // Integrated onto the paywall, no boxed table card, no gold.
        .background(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(ProBrand.columnWash)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(ProBrand.borderGradient, lineWidth: 1).opacity(0.6))
                .frame(width: proWidth)
                .shadow(color: ProBrand.glow.opacity(0.35), radius: 20, y: 8)
        }
    }

    /// A consistent fixed row height, so every label / Free / PRO value is
    /// vertically centred and every divider lands exactly halfway between rows.
    private var rowHeight: CGFloat { Layout.pad(46, 52) }

    @ViewBuilder private func comparisonRow(_ row: (title: String, free: Bool)) -> some View {
        let isHi = row.title == highlighted
        HStack(spacing: 0) {
            Text(row.title)
                .font(.system(size: Layout.pad(16.5, 19),
                              weight: isHi ? .heavy : .semibold, design: .default))
                // The context row is highlighted with a restrained multicolor fill.
                .foregroundStyle(isHi ? AnyShapeStyle(ProBrand.softGradient)
                                      : AnyShapeStyle(Color.white))
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
            // Free — a dash for everything except Solo Mode.
            Image(systemName: row.free ? "checkmark" : "minus")
                .font(.system(size: Layout.pad(16, 18), weight: .heavy))
                .foregroundStyle(row.free ? .white.opacity(0.55) : .white.opacity(0.22))
                .frame(width: freeWidth)
            // PRO — a crisp white check over the soft multicolor column.
            Image(systemName: "checkmark")
                .font(.system(size: Layout.pad(17, 20), weight: .heavy))
                .foregroundStyle(.white)
                .shadow(color: ProBrand.deepNavy.opacity(0.35), radius: 2, y: 1)
                .frame(width: proWidth)
        }
        .frame(height: rowHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.title). \(row.free ? "Included in Free and PRO" : "PRO only").")
    }

    /// A 1-pt separator that spans ONLY the label + Free region and stops before
    /// the PRO column, so it never crosses the gradient bar or any checkmark.
    private var rowDivider: some View {
        HStack(spacing: 0) {
            Rectangle().fill(.white.opacity(0.10)).frame(height: 1)
                .frame(maxWidth: .infinity)
            Color.clear.frame(width: proWidth)
        }
    }
}
