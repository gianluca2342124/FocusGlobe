import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The FocusGlobe **Store** — a calm, premium collectible shop paid with
/// **Focus Coins** (earned by landing flights) or unlocked with Premium.
///
/// One premium vertical scroll: a daily gift, today's items, balloon skins,
/// cabin items, and a badges teaser — no segmented control hiding products.
/// Every item renders its bundled art (`StoreItem_<id>`) when present and a
/// premium procedural card otherwise, so nothing depends on assets. Purchase /
/// own / equip all persist. (Trails were retired.)
struct StoreView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.horizontalSizeClass) private var hSize

    @State private var showDailyGift = false

    private var cardColumns: [GridItem] { Layout.cardColumns(regular: hSize == .regular) }

    var body: some View {
        ZStack {
            AnimatedTileBackground(assetName: "Background_Store_Tile", overlayOpacity: 0.5)
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    header
                    coinsCard
                    ShopHeroPreview()
                    todayItemsSection
                    skinsSection
                    cabinSection
                    ownedSection
                }
                .padding(AppSpacing.screen)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xxl)
                .contentMaxWidth()
            }
        }
        .focusScreenChrome()
        .onAppear {
            if appModel.canClaimDailyGift {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showDailyGift = true }
            }
        }
        .sheet(isPresented: $showDailyGift) {
            DailyGiftSheet().environmentObject(appModel)
        }
    }

    // MARK: Header + balance

    private var header: some View {
        HStack(alignment: .top) {
            ScreenHeader(title: "Store", subtitle: "Collectibles for your balloon and cabin", showsBack: false)
            Spacer()
            if !appModel.isPro {
                CrownButton { appModel.tapFeedback(); router.presentPaywall() }
            }
        }
    }

    private var coinsCard: some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle().fill(AppColors.gold.opacity(0.16)).frame(width: 46, height: 46)
                FocusCoinIcon(size: 26)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("\(Formatters.miles(appModel.focusCoins)) Focus Coins")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                Text("Earned by landing flights")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
        }
        .padding(AppSpacing.lg)
        .glassBackground(cornerRadius: AppSpacing.cardRadius,
                         tint: AppColors.goldFoil, tintOpacity: 0.12,
                         shadowRadius: 16, shadowY: 8)
    }

    // MARK: Today's items (featured horizontal row, refreshes at midnight)

    private var todayItemsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                SectionLabel(text: "Featured Today")
                Spacer()
                TimelineView(.periodic(from: .now, by: 60)) { ctx in
                    Label("Refreshes in \(refreshLabel(at: ctx.date))", systemImage: "clock")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(StoreItem.dailyItems()) { item in
                        StoreItemCard(item: item, featured: true)
                    }
                }
                .padding(.horizontal, 2).padding(.vertical, 2)
            }
        }
    }

    private var cabinSection: some View {
        itemsSection(title: "Cabin Interior & Charms",
                     items: StoreItem.all.filter { $0.kind == .cabinDecoration || $0.kind == .charm })
    }

    // A gentle bridge to the collectible badges (which live in the Passport).
    private var badgesTeaser: some View {
        Button { appModel.tapFeedback(); router.openPassport() } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "rosette")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColors.gold)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Badges")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Earn collectible badges as you fly")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity)
            .glassBackground(cornerRadius: 18, tintOpacity: 0.22, shadowRadius: 6, shadowY: 3)
        }
        .buttonStyle(SoftPressStyle(scale: 0.99))
    }

    private func itemsSection(title: String, items: [StoreItem]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionLabel(text: title)
            LazyVGrid(columns: cardColumns, spacing: AppSpacing.sm) {
                ForEach(items) { item in
                    StoreItemCard(item: item)
                }
            }
        }
    }

    private func refreshLabel(at date: Date) -> String {
        let secs = StoreItem.secondsUntilRefresh(from: date)
        let h = secs / 3600, m = (secs % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    // MARK: Balloon skins (existing system, preserved)

    private var skinsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionLabel(text: "Balloon Skins")
            LazyVGrid(columns: cardColumns, spacing: AppSpacing.sm) {
                ForEach(BalloonSkin.all) { skin in
                    SkinCard(skin: skin,
                             unlocked: appModel.isSkinUnlocked(skin),
                             selected: appModel.selectedSkin.id == skin.id) {
                        if appModel.isSkinUnlocked(skin) {
                            appModel.selectSkin(skin)
                            appModel.tapFeedback()
                        } else if skin.isPremium {
                            appModel.tapFeedback()
                            router.presentPaywall()
                        } else {
                            appModel.haptics.tap()
                        }
                    }
                }
            }
        }
    }

    // MARK: Owned

    @ViewBuilder private var ownedSection: some View {
        let owned = StoreItem.all.filter { appModel.ownsStoreItem($0) }
        if !owned.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                SectionLabel(text: "Your Collection")
                LazyVGrid(columns: cardColumns, spacing: AppSpacing.sm) {
                    ForEach(owned) { item in
                        StoreItemCard(item: item)
                    }
                }
            }
        }
    }
}

// MARK: - One Store item card (grid + featured sizes)

private struct StoreItemCard: View {
    let item: StoreItem
    var featured: Bool = false
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter

    private var owned: Bool { appModel.ownsStoreItem(item) }
    private var affordable: Bool { appModel.focusCoins >= item.price }

    /// Whether the owned cosmetic is currently visible (equipped trail / placed
    /// cabin decoration). Charms are display-only for now.
    private var equipped: Bool {
        switch item.kind {
        case .trail: return appModel.equippedTrail?.id == item.id
        case .cabinDecoration: return appModel.isCabinItemEquipped(item)
        case .charm: return false
        }
    }

    private var artHeight: CGFloat { featured ? Layout.pad(145, 200) : Layout.pad(112, 165) }

    var body: some View {
        Button(action: act) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                art
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.75)
                    Text(item.subtitle)
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.textTertiary)
                        .lineLimit(1)
                }
                priceRow
            }
            .padding(AppSpacing.md)
            .frame(width: featured ? CGFloat(168) : nil, alignment: .leading)
            .frame(maxWidth: featured ? nil : .infinity, alignment: .leading)
            .glassBackground(cornerRadius: 20, tintOpacity: 0.24, shadowRadius: 8, shadowY: 4)
            .overlay {
                if equipped {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(AppColors.gold.opacity(0.7), lineWidth: 1.5)
                        .shadow(color: AppColors.gold.opacity(0.4), radius: 6)
                } else if owned {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(AppColors.success.opacity(0.5), lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(SoftPressStyle(scale: 0.98))
        .accessibilityLabel("\(item.name). \(priceAccessibility)")
    }

    private func act() {
        if owned {
            switch item.kind {
            case .trail: appModel.equipTrail(item)
            case .cabinDecoration: appModel.toggleCabinItem(item)
            case .charm: appModel.haptics.tap()
            }
        } else if item.isPremium && !appModel.isPro {
            appModel.tapFeedback()
            router.presentPaywall()
        } else if appModel.purchaseStoreItem(item) {
            // purchase feedback plays inside the model
        } else {
            appModel.haptics.tap()   // can't afford yet — quiet nudge
        }
    }

    // Transparent product art floats over a soft palette glow — never a hard
    // coloured box behind the PNG. A tinted procedural icon stands in until the
    // art ships. No rarity labels.
    private var art: some View {
        ZStack {
            if !hasArt {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(item.tint.opacity(0.14))
            }
            artContent
                .padding(hasArt ? 8 : 0)
        }
        .frame(height: artHeight)
        .frame(maxWidth: .infinity)
        .shadow(color: item.tint.opacity(0.3), radius: 12, y: 5)
    }

    private var hasArt: Bool {
        #if canImport(UIKit)
        return UIImage(named: item.bestAssetName) != nil
        #else
        return false
        #endif
    }

    @ViewBuilder private var artContent: some View {
        #if canImport(UIKit)
        if let ui = UIImage(named: item.bestAssetName) {
            // scaledToFit keeps the whole transparent PNG visible and unobstructed.
            Image(uiImage: ui).resizable().scaledToFit()
        } else {
            Image(systemName: item.systemImage)
                .font(.system(size: featured ? 46 : 32, weight: .semibold))
                .foregroundStyle(item.tint)
        }
        #else
        Image(systemName: item.systemImage)
            .font(.system(size: featured ? 46 : 32, weight: .semibold))
            .foregroundStyle(item.tint)
        #endif
    }

    private var ownedStatusText: String {
        switch item.kind {
        case .charm: return "Owned"
        case .trail: return equipped ? "Equipped" : "Tap to equip"
        case .cabinDecoration: return equipped ? "In your cabin" : "Tap to place"
        }
    }

    private var ownedStatusIcon: String {
        if equipped { return "checkmark.seal.fill" }
        return item.kind == .charm ? "checkmark.circle.fill" : "sparkles"
    }

    @ViewBuilder private var priceRow: some View {
        if owned {
            Label(ownedStatusText, systemImage: ownedStatusIcon)
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundStyle(equipped ? AppColors.gold : AppColors.success)
        } else if item.isPremium {
            Label("Premium", systemImage: "crown.fill")
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.gold)
        } else {
            HStack(spacing: 4) {
                FocusCoinIcon(size: 13)
                Text("\(item.price)")
                    .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(affordable ? AppColors.gold : AppColors.textTertiary)
            }
        }
    }

    private var priceAccessibility: String {
        if owned { return "\(ownedStatusText)." }
        if item.isPremium { return "Premium item." }
        return "\(item.price) Focus Coins."
    }
}

// MARK: - One balloon-skin card (selection + unlock semantics preserved)

private struct SkinCard: View {
    let skin: BalloonSkin
    let unlocked: Bool
    let selected: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var float: CGFloat = 0

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.sm) {
                ZStack {
                    // Image-first: the transparent balloon is the protagonist
                    // over a soft diffused glow drawn from the skin's own accent
                    // — no opaque colored box, no hard circular halo.
                    RadialGradient(colors: [skin.theme.accent.opacity(unlocked ? 0.30 : 0.14), .clear],
                                   center: .center, startRadius: 2, endRadius: 130)
                        .blur(radius: 8)
                    BalloonView(height: Layout.pad(134, 190), showBurner: false, showGlow: false, skin: skin)
                        .opacity(unlocked ? 1 : 0.5)
                        .offset(y: float)
                    if !unlocked {
                        Image(systemName: skin.isPremium ? "crown.fill" : "lock.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(skin.isPremium ? AppColors.gold : AppColors.textSecondary)
                            .padding(8)
                            .background(Circle().fill(.ultraThinMaterial))
                            .offset(x: Layout.pad(42, 62), y: -Layout.pad(50, 74))
                    }
                }
                .frame(height: Layout.pad(152, 210))
                VStack(spacing: 2) {
                    Text(skin.name)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text(statusText)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(statusColor)
                        .lineLimit(1).minimumScaleFactor(0.85)
                }
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity)
            .glassBackground(cornerRadius: 22, tintOpacity: 0.2, shadowRadius: 8, shadowY: 4)
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(AppColors.gold.opacity(0.7), lineWidth: 1.6)
                } else if unlocked {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(AppColors.success.opacity(0.3), lineWidth: 1)
                }
            }
        }
        .buttonStyle(SoftPressStyle(scale: 0.98))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) { float = -6 }
        }
        .accessibilityLabel("\(skin.name) balloon skin. \(statusText)")
    }

    // Skins unlock via milestones / invites / Premium (never Focus Coins), so
    // the state line shows Equipped / Owned / Premium / the unlock requirement.
    private var statusText: String {
        if selected { return "Equipped" }
        if unlocked { return "Owned · Tap to fly" }
        if skin.isPremium { return "Premium" }
        return skin.requirementText
    }
    private var statusColor: Color {
        if selected { return AppColors.success }
        if unlocked { return AppColors.textSecondary }
        return AppColors.textTertiary
    }
}

// MARK: - Daily gift

/// The once-a-day welcome-back gift: a friendly balloon, a warm line, and a
/// Collect button that grants +5 Focus Coins. Shown at most once per calendar
/// day (persisted); Premium pilots receive it too.
private struct DailyGiftSheet: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var bob: CGFloat = 0

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            VStack(spacing: AppSpacing.md) {
                HStack {
                    Spacer()
                    Button { appModel.tapFeedback(); dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
                Spacer(minLength: 0)
                giftHero
                Text("Daily Gift")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                Text("Welcome back — your focus coins are ready.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 9) {
                    FocusCoinIcon(size: 30)
                    Text("+\(AppModel.dailyGiftCoins) FocusCoins")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColors.gold)
                }
                .padding(.vertical, 4)
                Spacer(minLength: 0)
                AppPrimaryButton(title: "Collect", systemImage: "gift.fill") {
                    appModel.claimDailyGift()
                    dismiss()
                }
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.lg)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        .presentationDetents([.fraction(0.6), .medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { bob = -9 }
        }
    }

    /// The `dailygift` artwork if present; the smiling-balloon mascot otherwise —
    /// over a soft diffused warm glow with no hard circular edge.
    @ViewBuilder private var giftHero: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [AppColors.gold.opacity(0.3), .clear],
                                     center: .center, startRadius: 2, endRadius: 130))
                .frame(width: 240, height: 240)
                .blur(radius: 12)
            if let ui = UIImage(named: "dailygift") {
                Image(uiImage: ui).resizable().scaledToFit().frame(height: 150).offset(y: bob)
            } else {
                SmilingBalloon().frame(width: 84, height: 104).offset(y: bob)
            }
        }
        .frame(height: 160)
    }
}

/// A cheerful procedural balloon with a soft smile — the daily-gift mascot.
private struct SmilingBalloon: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                BalloonEnvelope()
                    .fill(LinearGradient(colors: [Color(hex: 0xFFD98A), Color(hex: 0xF6B24A)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: w, height: h * 0.82)
                    .position(x: w / 2, y: h * 0.41)
                    .shadow(color: AppColors.gold.opacity(0.4), radius: 12, y: 4)
                // Two happy closed eyes + a gentle smile.
                EyeArc().stroke(Color(hex: 0x8A5A1E), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    .frame(width: w * 0.14, height: h * 0.06).position(x: w * 0.37, y: h * 0.34)
                EyeArc().stroke(Color(hex: 0x8A5A1E), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    .frame(width: w * 0.14, height: h * 0.06).position(x: w * 0.63, y: h * 0.34)
                SmileArc().stroke(Color(hex: 0x8A5A1E), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                    .frame(width: w * 0.28, height: h * 0.10).position(x: w / 2, y: h * 0.46)
            }
        }
    }
}

private struct EyeArc: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                       control: CGPoint(x: rect.midX, y: rect.minY))
        return p
    }
}

private struct SmileArc: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                       control: CGPoint(x: rect.midX, y: rect.maxY))
        return p
    }
}

// MARK: - Shop hero preview (Balloon / Interior)

/// The Store's interactive hero: a large atmospheric preview with two modes —
/// **Balloon** (try on any skin, equip owned ones instantly) and **Interior**
/// (the REAL CabinView rendering the pilot's actual placed decorations, with
/// tap-to-preview for anything not yet owned). Everything routes through the
/// EXISTING systems — `selectSkin`, `isSkinUnlocked`, `toggleCabinItem`,
/// `purchaseStoreItem`, the paywall — so no purchase/equip rule changes here,
/// only presentation. States are explicit: Equipped / Owned / Locked / Preview.
private struct ShopHeroPreview: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Mode: String, CaseIterable { case balloon = "Balloon", interior = "Interior" }
    @State private var mode: Mode = .balloon
    /// The skin being tried on (defaults to the equipped one on appear).
    @State private var previewSkinID: String? = nil
    /// The cabin item highlighted in Interior mode (nil = just your cabin).
    @State private var previewItemID: String? = nil
    @State private var float: CGFloat = 0

    private var previewSkin: BalloonSkin { BalloonSkin.skin(id: previewSkinID ?? appModel.selectedSkin.id) }
    private var previewItem: StoreItem? { previewItemID.flatMap { StoreItem.byID($0) } }
    private var cabinItems: [StoreItem] { StoreItem.all.filter { $0.kind == .cabinDecoration } }

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            modePicker
            Group {
                if mode == .balloon { balloonStage } else { interiorStage }
            }
            .frame(height: Layout.pad(236, 300))
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            statusRow
            thumbStrip
        }
        .padding(AppSpacing.md)
        .glassBackground(cornerRadius: AppSpacing.cardRadius, tintOpacity: 0.22,
                         shadowRadius: 16, shadowY: 8)
        .onAppear {
            if previewSkinID == nil { previewSkinID = appModel.selectedSkin.id }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) { float = -7 }
        }
        .animation(.snappy(duration: 0.22), value: mode)
    }

    // MARK: Mode picker — two quiet capsules, gold when active.

    private var modePicker: some View {
        HStack(spacing: 6) {
            ForEach(Mode.allCases, id: \.rawValue) { m in
                Button {
                    appModel.tapFeedback()
                    withAnimation(.snappy(duration: 0.22)) { mode = m }
                } label: {
                    Text(m.rawValue)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(mode == m ? Color(hex: 0x14120E) : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            Capsule().fill(mode == m ? AppColors.gold : Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(SoftPressStyle(scale: 0.98))
                .accessibilityLabel("\(m.rawValue) preview")
                .accessibilityAddTraits(mode == m ? .isSelected : [])
            }
        }
    }

    // MARK: Balloon stage — the skin, large, over its own soft accent light.

    private var balloonStage: some View {
        ZStack {
            AppColors.neutralDeep
            RadialGradient(colors: [previewSkin.theme.accent.opacity(0.34),
                                    previewSkin.theme.accent.opacity(0.10), .clear],
                           center: .center, startRadius: 4, endRadius: 200)
                .blur(radius: 14)
            BalloonView(height: Layout.pad(168, 220), showBurner: false, showGlow: false,
                        skin: previewSkin)
                .offset(y: float)
        }
        .accessibilityLabel("\(previewSkin.name) balloon preview")
    }

    // MARK: Interior stage — the REAL cabin with the pilot's real decorations
    // (plus the highlighted item so unowned pieces feel tangible before buying).

    private var interiorStage: some View {
        var ids = Set(appModel.profile.equippedCabinItemIDs ?? [])
        if let previewItemID { ids.insert(previewItemID) }
        return ZStack {
            AppColors.neutralDeep
            CabinView(elapsed: { 0 }, seed: 0xC0FFEE, animated: false,
                      focusSky: appModel.selectedSky, showPilots: false,
                      equippedItemIDs: ids)
                .allowsHitTesting(false)
        }
        .accessibilityLabel("Cabin interior preview")
    }

    // MARK: Status + primary action for the highlighted collectible.

    @ViewBuilder private var statusRow: some View {
        if mode == .balloon { balloonStatus } else { interiorStatus }
    }

    private var balloonStatus: some View {
        let skin = previewSkin
        let unlocked = appModel.isSkinUnlocked(skin)
        let equipped = appModel.selectedSkin.id == skin.id
        return HStack(spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 1) {
                Text(skin.name)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(equipped ? "Equipped" : unlocked ? "Owned" : skin.isPremium ? "Premium" : skin.requirementText)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(equipped ? AppColors.success : unlocked ? AppColors.textSecondary : AppColors.textTertiary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer()
            if equipped {
                Label("Flying", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.gold)
            } else if unlocked {
                heroActionButton("Equip") { appModel.selectSkin(skin); appModel.tapFeedback() }
            } else if skin.isPremium {
                heroActionButton("Unlock with Ultra") { appModel.tapFeedback(); router.presentPaywall() }
            }
        }
    }

    @ViewBuilder private var interiorStatus: some View {
        if let item = previewItem {
            let owned = appModel.ownsStoreItem(item)
            let placed = appModel.isCabinItemEquipped(item)
            HStack(spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text(placed ? "In your cabin" : owned ? "Owned" : item.isPremium ? "Premium" : "Previewing")
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(placed ? AppColors.success : AppColors.textSecondary)
                }
                Spacer()
                if owned {
                    heroActionButton(placed ? "Remove" : "Place") {
                        appModel.toggleCabinItem(item); appModel.tapFeedback()
                    }
                } else if item.isPremium && !appModel.isPro {
                    heroActionButton("Unlock with Ultra") { appModel.tapFeedback(); router.presentPaywall() }
                } else {
                    Button {
                        if !appModel.purchaseStoreItem(item) { appModel.haptics.tap() }
                    } label: {
                        HStack(spacing: 5) {
                            FocusCoinIcon(size: 13)
                            Text("\(item.price)")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(Color(hex: 0x14120E))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(AppColors.gold))
                    }
                    .buttonStyle(SoftPressStyle(scale: 0.97))
                    .accessibilityLabel("Buy \(item.name) for \(item.price) Focus Coins")
                }
            }
        } else {
            HStack {
                Text("Your cabin")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text("Tap an item to preview it")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
    }

    private func heroActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: 0x14120E))
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Capsule().fill(AppColors.gold))
        }
        .buttonStyle(SoftPressStyle(scale: 0.97))
    }

    // MARK: Thumbnails — every skin / cabin item, with explicit states.

    @ViewBuilder private var thumbStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                if mode == .balloon {
                    ForEach(BalloonSkin.all) { skin in skinThumb(skin) }
                } else {
                    ForEach(cabinItems) { item in itemThumb(item) }
                }
            }
            .padding(.horizontal, 2).padding(.vertical, 2)
        }
    }

    private func skinThumb(_ skin: BalloonSkin) -> some View {
        let unlocked = appModel.isSkinUnlocked(skin)
        let equipped = appModel.selectedSkin.id == skin.id
        let selected = previewSkin.id == skin.id
        return Button {
            appModel.haptics.tap()
            withAnimation(.snappy(duration: 0.2)) { previewSkinID = skin.id }
        } label: {
            ZStack(alignment: .topTrailing) {
                BalloonView(height: 46, showBurner: false, showGlow: false, skin: skin)
                    .opacity(unlocked ? 1 : 0.55)
                    .frame(width: 62, height: 62)
                if equipped {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppColors.gold)
                } else if !unlocked {
                    Image(systemName: skin.isPremium ? "crown.fill" : "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(skin.isPremium ? AppColors.gold : AppColors.textTertiary)
                        .padding(3)
                        .background(Circle().fill(.ultraThinMaterial))
                }
            }
            .padding(5)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(selected ? 0.10 : 0.04)))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(selected ? AppColors.gold.opacity(0.8) : Color.white.opacity(0.08),
                              lineWidth: selected ? 1.6 : 1))
        }
        .buttonStyle(SoftPressStyle(scale: 0.95))
        .accessibilityLabel("\(skin.name). \(equipped ? "Equipped" : unlocked ? "Owned" : "Locked")")
    }

    private func itemThumb(_ item: StoreItem) -> some View {
        let owned = appModel.ownsStoreItem(item)
        let placed = appModel.isCabinItemEquipped(item)
        let selected = previewItemID == item.id
        return Button {
            appModel.haptics.tap()
            withAnimation(.snappy(duration: 0.2)) {
                previewItemID = selected ? nil : item.id
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Group {
                    #if canImport(UIKit)
                    if let ui = UIImage(named: item.bestAssetName) {
                        Image(uiImage: ui).resizable().scaledToFit()
                    } else {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(item.tint)
                    }
                    #else
                    Image(systemName: item.systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(item.tint)
                    #endif
                }
                .opacity(owned ? 1 : 0.8)
                .frame(width: 62, height: 62)
                .padding(2)
                if placed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppColors.success)
                }
            }
            .padding(5)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(selected ? 0.10 : 0.04)))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(selected ? AppColors.gold.opacity(0.8) : Color.white.opacity(0.08),
                              lineWidth: selected ? 1.6 : 1))
        }
        .buttonStyle(SoftPressStyle(scale: 0.95))
        .accessibilityLabel("\(item.name). \(placed ? "In your cabin" : owned ? "Owned" : "\(item.price) Focus Coins")")
    }
}
