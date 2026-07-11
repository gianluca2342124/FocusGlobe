import SwiftUI

/// The FocusGlobe **Store** — a calm, premium shop for cosmetics, paid with
/// **Focus Coins** (earned by landing flights) or unlocked with Premium.
///
/// Foundation scope: daily rotating items (deterministic locally, refresh
/// countdown to midnight), balloon skins (the existing `BalloonSkin` system —
/// milestone/Pro unlocks preserved, selection preserved), and owned items.
/// Everything renders procedurally; no item requires bundled art.
struct StoreView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.horizontalSizeClass) private var hSize

    private var cardColumns: [GridItem] { Layout.cardColumns(regular: hSize == .regular) }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    header
                    coinsCard
                    dailySection
                    skinsSection
                    ownedSection
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
            ScreenHeader(title: "Store", subtitle: "Cosmetics for your balloon and cabin")
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
                Image(systemName: "circle.hexagongrid.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppColors.gold)
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

    // MARK: Daily items

    private var dailySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                SectionLabel(text: "Today's items")
                Spacer()
                TimelineView(.periodic(from: .now, by: 60)) { ctx in
                    Text("Refreshes in \(refreshLabel(at: ctx.date))")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            LazyVGrid(columns: cardColumns, spacing: AppSpacing.sm) {
                ForEach(StoreItem.dailyItems()) { item in
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
                SectionLabel(text: "Owned")
                LazyVGrid(columns: cardColumns, spacing: AppSpacing.sm) {
                    ForEach(owned) { item in
                        StoreItemCard(item: item)
                    }
                }
            }
        }
    }
}

// MARK: - One Store item card

private struct StoreItemCard: View {
    let item: StoreItem
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter

    private var owned: Bool { appModel.ownsStoreItem(item) }
    private var affordable: Bool { appModel.focusCoins >= item.price }

    var body: some View {
        Button {
            guard !owned else { return }
            if item.isPremium && !appModel.isPro {
                appModel.tapFeedback()
                router.presentPaywall()
            } else if appModel.purchaseStoreItem(item) {
                // purchase feedback plays inside the model
            } else {
                appModel.haptics.tap()   // can't afford yet — quiet nudge
            }
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(item.tint.opacity(0.16))
                    Image(systemName: item.systemImage)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(item.tint)
                }
                .frame(height: 64)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassBackground(cornerRadius: 20, tintOpacity: 0.24, shadowRadius: 8, shadowY: 4)
            .overlay {
                if owned {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(AppColors.success.opacity(0.5), lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(SoftPressStyle(scale: 0.98))
        .accessibilityLabel("\(item.name). \(priceAccessibility)")
    }

    @ViewBuilder private var priceRow: some View {
        if owned {
            Label("Owned", systemImage: "checkmark.circle.fill")
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.success)
        } else if item.isPremium {
            Label("Premium", systemImage: "crown.fill")
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.gold)
        } else {
            HStack(spacing: 4) {
                Image(systemName: "circle.hexagongrid.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("\(item.price)")
                    .font(.system(size: 13.5, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(affordable ? AppColors.gold : AppColors.textTertiary)
        }
    }

    private var priceAccessibility: String {
        if owned { return "Owned." }
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
