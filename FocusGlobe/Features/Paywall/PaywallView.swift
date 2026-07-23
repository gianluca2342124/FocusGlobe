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

    /// The paywall hero uses the premium **King** balloon via the BalloonSkin
    /// model mapping (so a future asset rename stays safe). Falls back to the
    /// default skin / vector balloon if the image is missing.
    static let heroAssetName = BalloonSkin.skin(id: "king").assetName

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
                        contextHero
                        // The FocusGlobe PRO identity lockup — the real badge, not
                        // a gold title treatment.
                        FocusGlobePROBrand(size: .hero)
                        Text(context.headline)
                            .font(.system(size: Layout.pad(24, 31), weight: .bold, design: .default))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        contextShowcase
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

    // MARK: Contextual hero + showcase (ONE paywall, many entries)

    /// The hero visual per context: the King balloon for broad entries, the
    /// premium collectibles themselves for Sky/skin/interior entries.
    @ViewBuilder private var contextHero: some View {
        switch context {
        case .balloonSkin, .interior, .sky:
            EmptyView()   // their showcase row below IS the hero
        default:
            balloonHero
        }
    }

    /// What actually becomes available — REAL premium content previews, so a
    /// balloon-skin tap never shows Sky imagery (and vice versa).
    @ViewBuilder private var contextShowcase: some View {
        switch context {
        case .sky:
            HStack(spacing: AppSpacing.sm) {
                ForEach(FocusSky.all.filter { $0.isPremium }.prefix(3)) { sky in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LinearGradient(colors: sky.paletteColors,
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(height: 92)
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(.white.opacity(0.16), lineWidth: 1))
                        Text(sky.name)
                            .font(.system(size: 11.5, weight: .bold, design: .default))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
            }
            .padding(.top, 2)
        case .balloonSkin:
            HStack(spacing: AppSpacing.md) {
                ForEach(BalloonSkin.all.filter { $0.isPremium }.prefix(4)) { skin in
                    VStack(spacing: 5) {
                        BalloonView(height: 72, showBurner: false, showGlow: false, skin: skin)
                        Text(skin.name)
                            .font(.system(size: 11, weight: .bold, design: .default))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
            .padding(.vertical, 6)
        case .interior:
            HStack(spacing: AppSpacing.md) {
                ForEach(premiumInteriorShowcase) { item in
                    VStack(spacing: 5) {
                        Group {
                            if let ui = UIImage(named: item.bestAssetName) {
                                Image(uiImage: ui).resizable().scaledToFit()
                            } else {
                                Image(systemName: item.systemImage)
                                    .font(.system(size: 30, weight: .semibold))
                                    .foregroundStyle(item.tint)
                            }
                        }
                        .frame(width: 74, height: 74)
                        Text(item.name)
                            .font(.system(size: 11, weight: .bold, design: .default))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
            }
            .padding(.vertical, 6)
        case .sound:
            HStack(spacing: AppSpacing.sm) {
                ForEach(JourneyAudioOption.all.filter { $0.isPremium }.prefix(3)) { option in
                    Label(option.displayName, systemImage: "music.note")
                        .font(.system(size: 12.5, weight: .bold, design: .default))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Capsule().fill(.white.opacity(0.08)))
                        .overlay(Capsule().strokeBorder(ProBrand.c3.opacity(0.4), lineWidth: 1))
                }
            }
        default:
            EmptyView()
        }
    }

    /// Premium-first cabin showcase; falls back to the highest-priced pieces so
    /// the row always shows REAL catalog items.
    private var premiumInteriorShowcase: [StoreItem] {
        let cabin = StoreItem.all.filter { $0.kind == .cabinDecoration }
        let premium = cabin.filter { $0.isPremium }
        let rest = cabin.filter { !$0.isPremium }.sorted { $0.price > $1.price }
        return Array((premium + rest).prefix(3))
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

    /// Responsive hero height — a large premium visual on phones (~2x the old
    /// size), with a sensible cap so it stays elegant (not huge) on iPad. The
    /// hero lives in a ScrollView, so larger sizes scroll and never clip on the
    /// smallest screens.
    private var heroHeight: CGFloat {
        let w = UIScreen.main.bounds.width
        // Trimmed a little more so the full benefits list sits comfortably above
        // the fold on a normal iPhone, while the hero still reads as a premium
        // illustration (not a thumbnail).
        return min(max(w * 0.34, 120), 170)
    }

    private var balloonHero: some View {
        let h = heroHeight
        return ZStack {
            // Soft, diffused golden atmosphere behind the balloon. A radial that
            // fades fully to clear (no hard circle edge) and is heavily blurred, so
            // it reads as premium light rather than a disc and never looks cut off.
            RadialGradient(colors: [AppColors.gold.opacity(0.42),
                                    AppColors.gold.opacity(0.16),
                                    .clear],
                           center: .center, startRadius: 0, endRadius: h * 0.95)
                .frame(width: h * 1.6, height: h * 1.5)
                .blur(radius: 30)
                .allowsHitTesting(false)
            // Paywall hero balloon — the premium King skin via the model mapping,
            // falling back to the default skin / vector if the asset is missing.
            BalloonView(height: h, showBurner: true, showGlow: false,
                        assetName: Self.heroAssetName)
        }
        .frame(height: h * 1.08)
        .frame(maxWidth: .infinity)
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
            // The primary subscription CTA now wears the PRO multicolor gradient
            // (white label keeps strong contrast). Purchase behaviour unchanged.
            .background(Capsule().fill(ProBrand.gradient))
            // Subtle gloss sweep every few seconds (only on the live CTA).
            .overlay {
                if available && !working {
                    shineSweep.clipShape(Capsule()).allowsHitTesting(false)
                }
            }
            .shadow(color: ProBrand.glow.opacity(0.5), radius: 16, y: 8)
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

/// The ONE Free-vs-PRO comparison used by every paywall context. Eight direct,
/// benefit-led rows (No Ads deliberately second), checkmark / dash values only.
/// It is NOT a boxed table card: it sits straight on the paywall background, and
/// the PRO column is a full-height GOLD bar behind its checkmarks — the strong,
/// conversion-focused emphasis (mirrors the reference layout). The row matching
/// the opening context is highlighted in gold. Free includes only Solo Focus;
/// every other benefit is a PRO unlock, so the PRO column is all checks.
struct PaywallComparisonTable: View {
    /// The benefit row to spotlight (nil = broad entry → nothing highlighted).
    var highlighted: String? = nil

    /// (title, includedInFree). Order is fixed. PRO includes everything.
    private static let rows: [(title: String, free: Bool)] = [
        ("Solo Focus",      true),
        ("No Ads",          false),
        ("Online Mode",     false),
        ("Invite Friends",  false),
        ("Infinite Focus",  false),
        ("Exclusive Skies", false),
        ("Premium Items",   false),
        ("Smart Widgets",   false),
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

            ForEach(Array(Self.rows.enumerated()), id: \.offset) { idx, row in
                let isHi = row.title == highlighted
                HStack(spacing: 0) {
                    Text(row.title)
                        .font(.system(size: Layout.pad(16.5, 19),
                                      weight: isHi ? .heavy : .semibold, design: .default))
                        // The context row is highlighted with a restrained
                        // multicolor fill (never gold).
                        .foregroundStyle(isHi ? AnyShapeStyle(ProBrand.softGradient)
                                              : AnyShapeStyle(Color.white))
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // Free — a dash for everything except Solo Focus.
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
                .padding(.vertical, Layout.pad(11, 13))
                // A hairline between rows, only across the label + Free region
                // (the gold column stays clean).
                .overlay(alignment: .bottom) {
                    if idx < Self.rows.count - 1 {
                        HStack(spacing: 0) {
                            Rectangle().fill(.white.opacity(0.10)).frame(height: 1)
                                .frame(maxWidth: .infinity)
                            Color.clear.frame(width: proWidth)
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(row.title). \(row.free ? "Included in Free and PRO" : "PRO only").")
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
}
