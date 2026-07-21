import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The FocusGlobe **Store** — a premium collectible shop paid with Focus Coins
/// (earned by landing flights) or unlocked with FocusGlobe PRO.
///
/// Composition (final): the atmospheric Store background stays visible; the
/// upper region is an OPEN-AIR live preview stage (the balloon floats straight
/// over the atmosphere — no dark framing card; Interior shows the REAL Cabin);
/// below it sits a permanently ATTACHED item panel — an immovable bottom-sheet
/// look with a Balloon/Interior selector whose content scrolls internally.
/// Every price, unlock rule, equip/place path and the daily-gift flow is the
/// existing system; only the composition changed.
struct StoreView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Mode: String, CaseIterable { case balloon = "Balloon", interior = "Interior" }
    @State private var mode: Mode = .balloon
    /// The skin being tried on (defaults to the equipped one on appear).
    @State private var previewSkinID: String? = nil
    /// The interior item highlighted in Interior mode (nil = just your cabin).
    @State private var previewItemID: String? = nil
    @State private var showDailyGift = false
    @State private var showGetCoins = false
    @State private var float: CGFloat = 0
    /// Drives the sliding highlight of the Balloon/Interior segmented control.
    @Namespace private var modeNS

    private var previewSkin: BalloonSkin { BalloonSkin.skin(id: previewSkinID ?? appModel.selectedSkin.id) }
    private var previewItem: StoreItem? { previewItemID.flatMap { StoreItem.byID($0) } }

    var body: some View {
        ZStack {
            // The Store's open-air stage sits over the free Desert Night Sky —
            // never the retired Amber Highlands tile, never the pilot's randomly
            // selected Sky — so the balloon and the real Cabin float over the
            // same calm desert night in both preview modes. A static settled
            // frame keeps the shop smooth (the balloon still floats on its own).
            SkyFlightSceneView(sky: .desertNight, elapsed: { 24 }, animated: false)
                .ignoresSafeArea()
            // A soft top/bottom scrim so the header and status text stay readable.
            LinearGradient(colors: [.black.opacity(0.38), .clear, .black.opacity(0.28)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            VStack(spacing: 0) {
                // The header, live preview stage and the selected-item status
                // sit over the dark atmospheric background, so they resolve
                // their tokens in DARK in both appearances (white text stays
                // white). The item panel below reads the true scheme and turns
                // to clean warm paper in Light Mode.
                Group {
                    header
                        .padding(.horizontal, AppSpacing.screen)
                    stage
                        .frame(maxHeight: .infinity)
                    statusRow
                        .padding(.horizontal, AppSpacing.screen)
                        .padding(.bottom, AppSpacing.sm)
                }
                .environment(\.colorScheme, .dark)
                itemPanel
            }
        }
        .focusScreenChrome()
        .onAppear {
            if previewSkinID == nil { previewSkinID = appModel.selectedSkin.id }
            if appModel.canClaimDailyGift {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showDailyGift = true }
            }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) { float = -8 }
        }
        .sheet(isPresented: $showDailyGift) { DailyGiftSheet().environmentObject(appModel) }
        .sheet(isPresented: $showGetCoins) { CoinSpinSheet().environmentObject(appModel) }
        .animation(.snappy(duration: 0.24), value: mode)
    }

    // MARK: Header — title left; compact coins + Get Coins right. No subtitle,
    // no crown (PRO entries live on their own surfaces, not in the Store).

    private var header: some View {
        HStack(alignment: .center, spacing: AppSpacing.xs) {
            Text("Store")
                .font(AppTypography.hero)
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            HStack(spacing: 5) {
                FocusCoinIcon(size: 18)
                Text(Formatters.miles(appModel.focusCoins))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .accessibilityLabel("\(appModel.focusCoins) Focus Coins")
            // No coin IAP exists — this opens the REAL coin source (the
            // rewarded Coin Spin), honestly labelled, never a dead button.
            Button {
                appModel.tapFeedback(); showGetCoins = true
            } label: {
                Text("Get Coins")
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: 0x2B2510))
                    .padding(.horizontal, 13).padding(.vertical, 8)
                    .background(Capsule().fill(AppColors.gold))
            }
            .buttonStyle(SoftPressStyle(scale: 0.96))
            .accessibilityLabel("Get Focus Coins")
        }
        .padding(.top, AppSpacing.xs)
    }

    // MARK: Open-air preview stage (7A) — no dark framing card.

    @ViewBuilder private var stage: some View {
        if mode == .balloon {
            ZStack {
                // Only a soft accent light behind the transparent PNG — the
                // page's own atmosphere IS the backdrop.
                RadialGradient(colors: [previewSkin.theme.accent.opacity(0.30),
                                        previewSkin.theme.accent.opacity(0.08), .clear],
                               center: .center, startRadius: 4, endRadius: 190)
                    .blur(radius: 12)
                BalloonView(height: Layout.pad(164, 215), showBurner: false, showGlow: false,
                            skin: previewSkin)
                    .offset(y: float)
                    .shadow(color: .black.opacity(0.25), radius: 16, y: 10)
                if !appModel.isSkinUnlocked(previewSkin) {
                    lockBadge(premium: previewSkin.isPremium)
                        .offset(x: Layout.pad(56, 74), y: -Layout.pad(64, 84))
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("\(previewSkin.name) balloon preview")
            .transition(.opacity)
        } else {
            // The REAL CabinView (the pilot's actual placed decorations, plus
            // the highlighted item) inside a coherent soft viewport.
            ZStack {
                CabinView(elapsed: { 0 }, seed: 0xC0FFEE, animated: false,
                          focusSky: .desertNight, showPilots: false,
                          equippedItemIDs: previewCabinIDs)
                    .allowsHitTesting(false)
                if let item = previewItem, !appModel.ownsStoreItem(item) {
                    VStack { HStack { Spacer(); lockBadge(premium: item.isPremium).padding(12) }; Spacer() }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .padding(.horizontal, AppSpacing.screen)
            .accessibilityLabel("Cabin interior preview")
            .transition(.opacity)
        }
    }

    /// The cabin's real placed decorations plus the highlighted preview item.
    private var previewCabinIDs: Set<String> {
        var ids = Set(appModel.profile.equippedCabinItemIDs ?? [])
        if let previewItemID { ids.insert(previewItemID) }
        return ids
    }

    private func lockBadge(premium: Bool) -> some View {
        Image(systemName: premium ? "crown.fill" : "lock.fill")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(premium ? AppColors.gold : .white.opacity(0.85))
            .padding(9)
            .background(Circle().fill(.ultraThinMaterial))
            .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))
    }

    // MARK: Selected-item status + primary action (equip / place / buy / PRO)

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
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(equipped ? "Equipped" : unlocked ? "Owned"
                     : skin.isPremium ? "FocusGlobe PRO" : skinProgressText(skin))
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(equipped ? AppColors.success : .white.opacity(0.7))
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer()
            if equipped {
                Label("Flying", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.gold)
            } else if unlocked {
                goldAction("Equip") { appModel.selectSkin(skin); appModel.tapFeedback() }
            } else if skin.isPremium {
                goldAction("Unlock with FocusGlobe PRO") {
                    appModel.tapFeedback(); router.presentPaywall(context: .balloonSkin)
                }
            }
        }
        .shadow(color: .black.opacity(0.4), radius: 6, y: 1)
    }

    @ViewBuilder private var interiorStatus: some View {
        if let item = previewItem {
            let owned = appModel.ownsStoreItem(item)
            let placed = appModel.isCabinItemEquipped(item)
            HStack(spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text(placed ? "In your cabin" : owned ? "Owned"
                         : item.isPremium ? "FocusGlobe PRO" : "Previewing")
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(placed ? AppColors.success : .white.opacity(0.7))
                }
                Spacer()
                if owned, item.kind == .cabinDecoration {
                    goldAction(placed ? "Remove" : "Place") {
                        appModel.toggleCabinItem(item); appModel.tapFeedback()
                    }
                } else if owned {
                    Label("Owned", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.success)
                } else if item.isPremium && !appModel.isPro {
                    goldAction("Unlock with FocusGlobe PRO") {
                        appModel.tapFeedback(); router.presentPaywall(context: .interior)
                    }
                } else {
                    Button {
                        if !appModel.purchaseStoreItem(item) { appModel.haptics.tap() }
                    } label: {
                        HStack(spacing: 5) {
                            FocusCoinIcon(size: 13)
                            Text("\(item.price)")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(Color(hex: 0x2B2510))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(AppColors.gold))
                    }
                    .buttonStyle(SoftPressStyle(scale: 0.96))
                    .accessibilityLabel("Buy \(item.name) for \(item.price) Focus Coins")
                }
            }
            .shadow(color: .black.opacity(0.4), radius: 6, y: 1)
        } else {
            HStack {
                Text("Your cabin")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text("Tap an item to preview it")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .shadow(color: .black.opacity(0.4), radius: 6, y: 1)
        }
    }

    private func goldAction(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.75)
                .foregroundStyle(Color(hex: 0x2B2510))
                .padding(.horizontal, 15).padding(.vertical, 8)
                .background(Capsule().fill(AppColors.gold))
        }
        .buttonStyle(SoftPressStyle(scale: 0.96))
    }

    /// REAL current/required progress for a milestone skin — never a bare
    /// denominator, never fabricated ("12/70 flights", "340/1,000 miles").
    /// One reusable, unit-correct progress label (delegates to the model type so
    /// the card and the stage status row can never disagree).
    private func skinProgressText(_ skin: BalloonSkin) -> String {
        skin.progressLabel(focusMinutes: appModel.lifetimeFocusMinutes,
                           focusMiles: appModel.progress.totalFocusMiles,
                           owned: appModel.isSkinGrandfathered(skin))
    }

    // MARK: The fixed item panel (7C) — an immovable bottom-sheet look.

    private var itemPanel: some View {
        VStack(spacing: AppSpacing.sm) {
            modePicker
                .padding(.top, AppSpacing.md)
            ScrollView {
                if mode == .balloon { balloonGrid } else { interiorContent }
            }
        }
        .padding(.horizontal, AppSpacing.screen)
        .frame(maxWidth: .infinity)
        .frame(height: panelHeight)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 28, bottomLeadingRadius: 0,
                                   bottomTrailingRadius: 0, topTrailingRadius: 28,
                                   style: .continuous)
                .fill(AppColors.storePanel.opacity(0.97))
                .overlay(alignment: .top) {
                    UnevenRoundedRectangle(topLeadingRadius: 28, bottomLeadingRadius: 0,
                                           bottomTrailingRadius: 0, topTrailingRadius: 28,
                                           style: .continuous)
                        .strokeBorder(AppColors.storeCardStroke, lineWidth: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    /// Roughly the lower half on phones; capped on tall/iPad screens so the
    /// preview always keeps a generous share of the atmosphere.
    private var panelHeight: CGFloat {
        #if canImport(UIKit)
        return min(430, UIScreen.main.bounds.height * 0.46)
        #else
        return 420
        #endif
    }

    /// Item grids show THREE per row on a standard iPhone; iPad keeps its wider
    /// adaptive layout so the larger canvas isn't wasted on only three columns.
    private var storeColumns: [GridItem] {
        if hSize == .regular { return Layout.cardColumns(regular: true) }
        return Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm), count: 3)
    }

    /// A premium segmented control: one recessed track with a single gold pill
    /// that GLIDES between Balloon and Interior (matchedGeometryEffect), rather
    /// than two independent buttons flipping colour.
    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(Mode.allCases, id: \.rawValue) { m in
                let isOn = mode == m
                Button {
                    guard mode != m else { return }
                    appModel.tapFeedback()
                    withAnimation(.snappy(duration: 0.28)) { mode = m; previewItemID = nil }
                } label: {
                    Text(m.rawValue)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(isOn ? Color(hex: 0x14120E) : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if isOn {
                                Capsule()
                                    .fill(AppColors.gold)
                                    .shadow(color: AppColors.gold.opacity(0.35), radius: 5, y: 2)
                                    .matchedGeometryEffect(id: "modeSelection", in: modeNS)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(SoftPressStyle(scale: 0.98))
                .accessibilityLabel("\(m.rawValue) collection")
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.dynamic(light: 0x26221D, lightAlpha: 0.06,
                                                 dark: 0xFFFFFF, darkAlpha: 0.06)))
        .overlay(Capsule().strokeBorder(AppColors.storeCardStroke, lineWidth: 1))
    }

    // MARK: Balloon grid — equipped → owned → locked (stable within groups).

    /// The unlocked-skin id snapshot is built HERE, on the MainActor, with a
    /// plain loop (which inherits MainActor isolation) — the `sorted` comparison
    /// below then reads only this immutable Set + static skin properties, so no
    /// MainActor-isolated method is ever called from the nonisolated comparator.
    private var sortedSkins: [BalloonSkin] {
        let equippedID = appModel.selectedSkin.id
        var unlockedIDs = Set<String>()
        for skin in BalloonSkin.all where appModel.isSkinUnlocked(skin) {
            unlockedIDs.insert(skin.id)
        }
        func rank(_ s: BalloonSkin) -> Int {
            if s.id == equippedID { return 0 }
            if unlockedIDs.contains(s.id) { return 1 }
            return 2
        }
        return BalloonSkin.all.sorted { a, b in
            let (ra, rb) = (rank(a), rank(b))
            return ra != rb ? ra < rb : a.sortOrder < b.sortOrder
        }
    }

    private var balloonGrid: some View {
        LazyVGrid(columns: storeColumns, spacing: AppSpacing.sm) {
            ForEach(sortedSkins) { skin in
                SkinCard(skin: skin,
                         unlocked: appModel.isSkinUnlocked(skin),
                         equipped: appModel.selectedSkin.id == skin.id,
                         selected: previewSkin.id == skin.id,
                         statusText: skinCardStatus(skin)) {
                    appModel.haptics.tap()
                    withAnimation(.snappy(duration: 0.2)) { previewSkinID = skin.id }
                }
            }
        }
        .padding(.bottom, AppSpacing.lg)
    }

    private func skinCardStatus(_ skin: BalloonSkin) -> String {
        if appModel.selectedSkin.id == skin.id { return "Equipped" }
        if appModel.isSkinUnlocked(skin) { return "Owned" }
        return skinProgressText(skin)
    }

    // MARK: Interior content — one grid, ordered placed → owned → rest.

    private var sortedInteriorItems: [StoreItem] {
        let items = StoreItem.all.filter { $0.kind == .cabinDecoration || $0.kind == .charm }
        // Snapshot placed/owned state on the MainActor before the nonisolated
        // comparator runs (same isolation rule as `sortedSkins`).
        var placedIDs = Set<String>(), ownedIDs = Set<String>()
        for item in items {
            if appModel.isCabinItemEquipped(item) { placedIDs.insert(item.id) }
            if appModel.ownsStoreItem(item) { ownedIDs.insert(item.id) }
        }
        func rank(_ i: StoreItem) -> Int {
            if placedIDs.contains(i.id) { return 0 }
            if ownedIDs.contains(i.id) { return 1 }
            return 2
        }
        return items.enumerated().sorted { a, b in
            let (ra, rb) = (rank(a.element), rank(b.element))
            return ra != rb ? ra < rb : a.offset < b.offset
        }.map(\.element)
    }

    private var interiorContent: some View {
        LazyVGrid(columns: storeColumns, spacing: AppSpacing.sm) {
            ForEach(sortedInteriorItems) { item in
                StoreItemCard(item: item, selected: previewItemID == item.id) { select(item) }
            }
        }
        .padding(.bottom, AppSpacing.lg)
    }

    private func select(_ item: StoreItem) {
        appModel.haptics.tap()
        withAnimation(.snappy(duration: 0.2)) {
            previewItemID = (previewItemID == item.id) ? nil : item.id
        }
    }
}

// MARK: - One Store item card (selection-first: tapping previews; the stage's
// status row carries the buy/place action, so nothing is hidden or duplicated)

private struct StoreItemCard: View {
    let item: StoreItem
    var featured: Bool = false
    var selected: Bool = false
    let onSelect: () -> Void
    @EnvironmentObject private var appModel: AppModel

    private var owned: Bool { appModel.ownsStoreItem(item) }
    private var affordable: Bool { appModel.focusCoins >= item.price }
    private var equipped: Bool {
        item.kind == .cabinDecoration && appModel.isCabinItemEquipped(item)
    }

    private var artHeight: CGFloat { featured ? Layout.pad(96, 130) : Layout.pad(84, 120) }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                art
                Text(item.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.75)
                priceRow
            }
            .padding(AppSpacing.sm)
            .frame(width: featured ? CGFloat(140) : nil, alignment: .leading)
            .frame(maxWidth: featured ? nil : .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.storeCard(selected: selected)))
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(AppColors.gold.opacity(0.8), lineWidth: 1.6)
                } else if equipped {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(AppColors.gold.opacity(0.5), lineWidth: 1.2)
                } else if owned {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(AppColors.success.opacity(0.4), lineWidth: 1.2)
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(AppColors.storeCardStroke, lineWidth: 1)
                }
            }
        }
        .buttonStyle(SoftPressStyle(scale: 0.97))
        .accessibilityLabel("\(item.name). \(priceAccessibility)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var art: some View {
        ZStack {
            if !hasArt {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(item.tint.opacity(0.14))
            }
            artContent.padding(hasArt ? 6 : 0)
        }
        .frame(height: artHeight)
        .frame(maxWidth: .infinity)
    }

    #if canImport(UIKit)
    /// One lookup per asset name for the LIFETIME of the app (MainActor-only,
    /// so no lock). Also caches misses: without this, permanently-missing
    /// imagesets make UIKit re-search the bundle on EVERY render pass.
    private static var artCache: [String: UIImage?] = [:]
    private var artImage: UIImage? {
        if let hit = Self.artCache[item.bestAssetName] { return hit }
        let ui = UIImage(named: item.bestAssetName)
        Self.artCache[item.bestAssetName] = ui
        return ui
    }
    #endif

    private var hasArt: Bool {
        #if canImport(UIKit)
        return artImage != nil
        #else
        return false
        #endif
    }

    @ViewBuilder private var artContent: some View {
        #if canImport(UIKit)
        if let ui = artImage {
            Image(uiImage: ui).resizable().scaledToFit()
        } else {
            Image(systemName: item.systemImage)
                .font(.system(size: featured ? 38 : 30, weight: .semibold))
                .foregroundStyle(item.tint)
        }
        #else
        Image(systemName: item.systemImage)
            .font(.system(size: featured ? 38 : 30, weight: .semibold))
            .foregroundStyle(item.tint)
        #endif
    }

    @ViewBuilder private var priceRow: some View {
        if equipped {
            Label(item.kind == .cabinDecoration ? "In your cabin" : "Owned",
                  systemImage: "checkmark.seal.fill")
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.gold)
        } else if owned {
            Label("Owned", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.success)
        } else if item.isPremium {
            Label("PRO", systemImage: "crown.fill")
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.gold)
        } else {
            HStack(spacing: 4) {
                FocusCoinIcon(size: 12)
                Text("\(item.price)")
                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(affordable ? AppColors.gold : AppColors.textTertiary)
            }
        }
    }

    private var priceAccessibility: String {
        if equipped { return "In your cabin." }
        if owned { return "Owned." }
        if item.isPremium { return "FocusGlobe PRO item." }
        return "\(item.price) Focus Coins."
    }
}

// MARK: - One balloon-skin card (selection-first; states are explicit)

private struct SkinCard: View {
    let skin: BalloonSkin
    let unlocked: Bool
    let equipped: Bool
    let selected: Bool
    let statusText: String
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: AppSpacing.xs) {
                ZStack(alignment: .topTrailing) {
                    BalloonView(height: Layout.pad(96, 140), showBurner: false, showGlow: false, skin: skin)
                        .opacity(unlocked ? 1 : 0.55)
                        .frame(maxWidth: .infinity)
                    if equipped {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppColors.gold)
                    } else if !unlocked {
                        Image(systemName: skin.isPremium ? "crown.fill" : "lock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(skin.isPremium ? AppColors.gold : AppColors.textSecondary)
                            .padding(5)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                }
                .frame(height: Layout.pad(104, 150))
                VStack(spacing: 1) {
                    Text(skin.name)
                        .font(.system(size: 14.5, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text(statusText)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(equipped ? AppColors.success : AppColors.textTertiary)
                        .monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
            }
            .padding(AppSpacing.sm)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.storeCard(selected: selected)))
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(AppColors.gold.opacity(0.8), lineWidth: 1.6)
                } else if unlocked {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(AppColors.success.opacity(0.25), lineWidth: 1)
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(AppColors.storeCardStroke, lineWidth: 1)
                }
            }
        }
        .buttonStyle(SoftPressStyle(scale: 0.97))
        .accessibilityLabel("\(skin.name) balloon skin. \(statusText)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

// MARK: - Daily gift

/// The once-a-day welcome-back gift: a friendly balloon, a warm line, and a
/// Collect button that grants Focus Coins. Shown at most once per calendar
/// day (persisted); PRO pilots receive it too.
private struct DailyGiftSheet: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var bob: CGFloat = 0

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            VStack(spacing: AppSpacing.md) {
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

    /// The `dailygift` artwork if present; the smiling-balloon mascot otherwise.
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
