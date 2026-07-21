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

    /// One cell of the Free-vs-PRO comparison table.
    private enum PaywallCell { case yes, no, text(String) }

    /// The REAL Free vs FocusGlobe PRO breakdown — actual functionality, not a
    /// row of identical checkmarks. Mirrors the live gates (Online, invites,
    /// Infinite, pause, widgets, ads).
    private let comparisonRows: [(feature: String, free: PaywallCell, pro: PaywallCell)] = [
        ("Solo focus flights",        .yes,             .yes),
        ("Skies",                     .text("Limited"), .text("All")),
        ("Balloons & cabin items",    .text("Starter"), .text("All")),
        ("Focus together (Online)",   .no,              .yes),
        ("Private flights & invites", .no,              .yes),
        ("Set focus durations",       .yes,             .yes),
        ("Infinite duration",         .no,              .yes),
        ("Pause a flight",            .no,              .yes),
        ("Focus sounds & music",      .text("Wind"),    .text("All")),
        ("Home & Lock widgets",       .text("2"),       .text("All")),
        ("Ads",                       .text("Shown"),   .text("None")),
        ("Rewards",                   .text("1×"),      .text("2×")),
    ]

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
                        Text(context.headline)
                            .font(.system(size: Layout.pad(25, 32), weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        contextShowcase
                        if context != .general {
                            Text("+ Unlock so much more with PRO")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        comparisonTable
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
            RadialGradient(colors: [AppColors.gold.opacity(0.14), .clear],
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
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
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
                            .font(.system(size: 11, weight: .bold, design: .rounded))
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
                            .font(.system(size: 11, weight: .bold, design: .rounded))
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
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Capsule().fill(.white.opacity(0.08)))
                        .overlay(Capsule().strokeBorder(AppColors.gold.opacity(0.3), lineWidth: 1))
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

    /// The Free vs FocusGlobe PRO comparison table — the honest breakdown that
    /// replaces the old identical-checkmark list.
    private var comparisonTable: some View {
        VStack(spacing: 0) {
            // Header row.
            HStack(spacing: 0) {
                Text("What you get")
                    .font(.system(size: Layout.pad(12.5, 15), weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Free")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: Layout.pad(58, 70))
                Text("PRO")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.gold)
                    .frame(width: Layout.pad(64, 78))
            }
            .padding(.bottom, 8)
            ForEach(Array(comparisonRows.enumerated()), id: \.offset) { idx, row in
                if idx > 0 {
                    Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
                }
                HStack(spacing: 0) {
                    Text(row.feature)
                        .font(.system(size: Layout.pad(13.5, 16), weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    comparisonCell(row.free, gold: false).frame(width: Layout.pad(58, 70))
                    comparisonCell(row.pro, gold: true).frame(width: Layout.pad(64, 78))
                }
                .padding(.vertical, 8)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .fill(Color.black.opacity(0.22)))
                .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .strokeBorder(AppColors.gold.opacity(0.25), lineWidth: 1))
        )
    }

    @ViewBuilder private func comparisonCell(_ cell: PaywallCell, gold: Bool) -> some View {
        switch cell {
        case .yes:
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(gold ? AppColors.gold : .white.opacity(0.6))
        case .no:
            Image(systemName: "minus")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white.opacity(0.28))
        case .text(let s):
            Text(s)
                .font(.system(size: Layout.pad(11.5, 13.5), weight: .bold, design: .rounded))
                .foregroundStyle(gold ? AppColors.gold : .white.opacity(0.62))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    // MARK: Already Pro

    private var proState: some View {
        VStack(spacing: AppSpacing.sm) {
            Label("FocusGlobe PRO is active", systemImage: "checkmark.seal.fill")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.gold)
            Button { appModel.tapFeedback(); dismiss() } label: {
                Text("Close")
                    .font(AppTypography.headline)
                    .foregroundStyle(Color(hex: 0x2B2620))
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(Capsule().fill(goldGradient))
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
                            .font(.system(size: 17, weight: .bold, design: .rounded))
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
                    .font(.system(size: 17, weight: .bold, design: .rounded))
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
                    .strokeBorder(selected ? AppColors.gold : AppColors.gold.opacity(0.18),
                                  lineWidth: selected ? 2 : 1)
            )
            .shadow(color: selected ? AppColors.gold.opacity(0.35) : .clear, radius: 12, y: 0)
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
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundStyle(Color(hex: 0x2B2620))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(AppColors.gold))
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
                    ProgressView().tint(Color(hex: 0x2B2620))
                } else {
                    Text(available ? buttonTitle(for: kind) : "Products unavailable")
                        .font(AppTypography.headline)
                        .foregroundStyle(Color(hex: 0x2B2620))
                }
            }
            .frame(maxWidth: .infinity).frame(height: 56)
            .background(Capsule().fill(goldGradient))
            // Subtle gloss sweep every few seconds (only on the live CTA).
            .overlay {
                if available && !working {
                    shineSweep.clipShape(Capsule()).allowsHitTesting(false)
                }
            }
            .shadow(color: AppColors.gold.opacity(0.4), radius: 16, y: 8)
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

    private var goldGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xF6D38A), Color(hex: 0xDE9F38)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
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
