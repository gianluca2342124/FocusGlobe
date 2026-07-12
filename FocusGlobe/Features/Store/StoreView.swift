import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The FocusGlobe **Store** — a calm, premium collectible shop paid with
/// **Focus Coins** (earned by landing flights) or unlocked with Premium.
///
/// Category tabs (Today · Balloons · Trails · Cabin) organise a growing catalog;
/// a featured "Today's Finds" row leads the Today tab. Every item renders its
/// bundled art (`StoreItem_<id>`) when present and a premium procedural card
/// otherwise, so nothing depends on assets. Purchase / own / equip all persist.
struct StoreView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.horizontalSizeClass) private var hSize

    @State private var category: ShopCategory = .today

    private var cardColumns: [GridItem] { Layout.cardColumns(regular: hSize == .regular) }

    private enum ShopCategory: String, CaseIterable, Identifiable {
        case today = "Today", balloons = "Balloons", trails = "Trails", cabin = "Cabin"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .today:    return "sparkles"
            case .balloons: return "circle.circle"
            case .trails:   return "wind"
            case .cabin:    return "house.fill"
            }
        }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    header
                    coinsCard
                    categoryChips
                    categoryContent
                }
                .padding(AppSpacing.screen)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xxl)
                .contentMaxWidth()
            }
        }
        .focusScreenChrome()
    }

    // MARK: Header + balance

    private var header: some View {
        HStack(alignment: .top) {
            ScreenHeader(title: "Store", subtitle: "Collectibles for your balloon and cabin")
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

    // MARK: Category chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(ShopCategory.allCases) { cat in
                    categoryChip(cat)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func categoryChip(_ cat: ShopCategory) -> some View {
        let active = category == cat
        return Button {
            appModel.tapFeedback()
            withAnimation(.easeInOut(duration: 0.2)) { category = cat }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: cat.icon).font(.system(size: 12, weight: .bold))
                Text(cat.rawValue).font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundStyle(active ? Color(hex: 0x2B2510) : AppColors.textSecondary)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs + 2)
            .background(
                Capsule().fill(active ? AnyShapeStyle(AppColors.gold)
                                      : AnyShapeStyle(AppColors.textPrimary.opacity(0.06)))
            )
            .overlay(Capsule().strokeBorder(.white.opacity(active ? 0 : 0.08), lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle(scale: 0.95))
    }

    // MARK: Category content

    @ViewBuilder private var categoryContent: some View {
        switch category {
        case .today:    todaySection
        case .balloons: skinsSection
        case .trails:   itemsSection(title: "Trails", items: items(of: [.trail]))
        case .cabin:    itemsSection(title: "Cabin & charms", items: items(of: [.cabinDecoration, .charm]))
        }
    }

    private func items(of kinds: [StoreItem.Kind]) -> [StoreItem] {
        StoreItem.all.filter { kinds.contains($0.kind) }
    }

    // Today: a featured "finds" row (larger cards) + the rest of the catalog.
    private var todaySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    SectionLabel(text: "Today's finds")
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
            ownedSection
        }
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
            SectionLabel(text: "Balloon skins")
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
                SectionLabel(text: "Your collection")
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

    private var artHeight: CGFloat { featured ? CGFloat(120) : CGFloat(66) }

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
        .accessibilityLabel("\(item.name). \(item.rarity.rawValue). \(priceAccessibility)")
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

    // Bundled art wins; otherwise a tinted procedural icon. A rarity chip rides
    // the top-left corner.
    private var art: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(item.tint.opacity(0.16))
            artContent
        }
        .frame(height: artHeight)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .topLeading) { rarityChip.padding(6) }
    }

    @ViewBuilder private var artContent: some View {
        #if canImport(UIKit)
        if let ui = UIImage(named: item.imageAssetName) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else {
            Image(systemName: item.systemImage)
                .font(.system(size: featured ? 40 : 26, weight: .semibold))
                .foregroundStyle(item.tint)
        }
        #else
        Image(systemName: item.systemImage)
            .font(.system(size: featured ? 40 : 26, weight: .semibold))
            .foregroundStyle(item.tint)
        #endif
    }

    private var rarityChip: some View {
        Text(item.rarity.rawValue.uppercased())
            .font(.system(size: 8.5, weight: .heavy, design: .rounded))
            .tracking(0.4)
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Capsule().fill(item.rarity.tint.opacity(0.9)))
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
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

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(skin.theme.accent.opacity(0.14))
                    BalloonView(height: 62, showBurner: false, showGlow: false,
                                skin: skin)
                        .opacity(unlocked ? 1 : 0.45)
                    if !unlocked {
                        Image(systemName: skin.isPremium ? "crown.fill" : "lock.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(skin.isPremium ? AppColors.gold : AppColors.textSecondary)
                            .padding(7)
                            .background(Circle().fill(.ultraThinMaterial))
                            .offset(x: 26, y: -22)
                    }
                }
                .frame(height: 86)
                VStack(spacing: 1) {
                    Text(skin.name)
                        .font(.system(size: 14.5, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                    Text(unlocked ? (selected ? "Flying now" : "Tap to select") : skin.requirementText)
                        .font(AppTypography.micro)
                        .foregroundStyle(selected ? AppColors.success : AppColors.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity)
            .glassBackground(cornerRadius: 20, tintOpacity: 0.24, shadowRadius: 8, shadowY: 4)
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(AppColors.gold.opacity(0.65), lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(SoftPressStyle(scale: 0.98))
        .accessibilityLabel("\(skin.name) balloon skin. \(unlocked ? (selected ? "Selected." : "Tap to select.") : skin.requirementText)")
    }
}
