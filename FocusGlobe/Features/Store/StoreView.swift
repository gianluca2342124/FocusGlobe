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
    @Environment(\.focusViewport) private var viewport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Mode: String, CaseIterable { case balloon = "Balloon", interior = "Interior" }
    @State private var mode: Mode = .balloon
    /// The skin being tried on (defaults to the equipped one on appear).
    @State private var previewSkinID: String? = nil
    /// The interior item highlighted in Interior mode (nil = just your cabin).
    @State private var previewItemID: String? = nil
    /// The focused placement flow; it owns replacement selection and only
    /// exposes slots compatible with the selected object.
    @State private var placementItem: StoreItem? = nil
    @State private var float: CGFloat = 0
    /// Drives the sliding highlight of the Balloon/Interior segmented control.
    @Namespace private var modeNS

    private var previewSkin: BalloonSkin { BalloonSkin.skin(id: previewSkinID ?? appModel.selectedSkin.id) }
    private var previewItem: StoreItem? { previewItemID.flatMap { StoreItem.byID($0) } }

    var body: some View {
        ZStack {
            // The Store's open-air stage sits over a calm, Store-ONLY daytime
            // sky — a tranquil blue gradient with a few soft clouds, no stars,
            // mountains, pilots or motion — so the balloon and the real Cabin
            // both float over the same bright afternoon in either preview mode.
            StoreDaytimeSky()
                .ignoresSafeArea()
            // A soft top/bottom scrim so the header and status text (white) stay
            // readable over the bright sky; the middle stays clear so the preview
            // zone shows the full daytime blue.
            LinearGradient(colors: [.black.opacity(0.30), .clear, .black.opacity(0.22)],
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
                    stage
                        .frame(maxHeight: .infinity)
                    statusRow
                        .padding(.bottom, AppSpacing.sm)
                }
                .frame(maxWidth: viewport.storeContentWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, viewport.pagePadding)
                .environment(\.colorScheme, .dark)
                itemPanel
            }
        }
        .focusScreenChrome()
        .onAppear {
            if previewSkinID == nil { previewSkinID = appModel.selectedSkin.id }
            if appModel.canClaimDailyGift {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if router.activeModal == nil { router.present(.dailyGift) }
                }
            }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) { float = -8 }
        }
        // Daily Gift + Coin Spin present through the app-wide modal coordinator.
        // Scoped to `mode` alone — the Balloon/Interior swap — never to a model.
        .animation(AppMotion.control, value: mode)
        .sheet(item: $placementItem) { item in
            CabinPlacementSheet(item: item)
                .environmentObject(appModel)
        }
    }

    // MARK: Header — title left; compact coins + Get Coins right. No subtitle,
    // no crown (PRO entries live on their own surfaces, not in the Store).

    private var header: some View {
        HStack(alignment: .center, spacing: AppSpacing.xs) {
            Text("Store")
                .font(.system(size: viewport.titleSize, weight: .bold, design: .default))
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            HStack(spacing: 5) {
                FocusCoinIcon(size: 18)
                Text(Formatters.miles(appModel.focusCoins))
                    .font(.system(size: 15, weight: .heavy, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .accessibilityLabel("\(appModel.focusCoins) Focus Coins")
            // "Get Coins" is entitlement-aware and NEVER opens the Home rewarded
            // Free Coin Spin. A free pilot is taken to the FocusGlobe PRO paywall
            // (coins/rewards context); a premium pilot goes to their ad-free coin
            // earning flow; a loading entitlement just refreshes (never presumed
            // free, never a double modal). The Home Free Coin Spin is separate.
            Button {
                appModel.tapFeedback(); getCoinsTapped()
            } label: {
                Text("Get Coins")
                    .font(.system(size: 13.5, weight: .bold, design: .default))
                    .foregroundStyle(Color(hex: 0x2B2510))
                    .padding(.horizontal, 13).padding(.vertical, 8)
                    .background(Capsule().fill(AppColors.gold))
            }
            .buttonStyle(SoftPressStyle(scale: 0.96))
            .accessibilityLabel("Get Focus Coins")
        }
        .padding(.top, AppSpacing.xs)
    }

    /// Route "Get Coins" by the REAL entitlement — never the Home Free Coin Spin.
    /// Free → the FocusGlobe PRO paywall (rewards context). Premium → the coin
    /// earning flow (ad-free for PRO; no dedicated coin IAP exists in the app, so
    /// this is the direct earning interface). Loading → a quiet refresh, so a
    /// possibly-premium owner is never flashed the paywall. Guarded against a
    /// double modal.
    private func getCoinsTapped() {
        guard router.activeModal == nil else { return }
        switch appModel.entitlement {
        case .free:     router.presentPaywall(context: .rewards)
        case .premium:  router.present(.coinSpin)
        case .loading:  appModel.refreshSubscriptionStatus()
        }
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
                BalloonView(height: storeBalloonHeight, showBurner: false, showGlow: false,
                            skin: previewSkin)
                    .offset(y: float)
                    .shadow(color: .black.opacity(0.25), radius: 16, y: 10)
                if !appModel.isSkinUnlocked(previewSkin)
                    && (!previewSkin.isPremium || appModel.isConfirmedFree) {
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
                // The pilot's real cabin, looking out through the window on the
                // SAME calm daytime sky as the balloon stage (never the dark night
                // world, which showed as a grey pane).
                CabinView(elapsed: { 0 }, seed: 0xC0FFEE, animated: false,
                          focusSky: nil, showPilots: false,
                          equippedItemIDs: previewCabinIDs,
                          equippedItemPlacements: previewCabinPlacements,
                          windowBackdrop: AnyView(StoreDaytimeSky()))
                    .allowsHitTesting(false)
                if let item = previewItem, !appModel.ownsStoreItem(item) {
                    VStack { HStack { Spacer(); lockBadge(premium: item.isPremium).padding(12) }; Spacer() }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .accessibilityLabel("Cabin interior preview")
            .transition(.opacity)
        }
    }

    /// The selected product is the sole preview focus. With no active product
    /// selection, the stage falls back to the pilot's equipped Cabin. This keeps
    /// Store calibration honest: the highlighted piece uses exactly its final
    /// production transform and is never displaced by an unrelated object.
    private var previewCabinIDs: Set<String> {
        if let previewItemID { return [previewItemID] }
        let equipped = Set(appModel.profile.equippedCabinItemIDs ?? [])
        return equipped
    }

    /// A highlighted product always previews in its canonical preferred slot,
    /// without mutating the pilot's saved layout. Equipped-only fallback uses
    /// the real persisted placements.
    private var previewCabinPlacements: [String: CabinSlot] {
        if let item = previewItem,
           let slot = item.preferredSlot ?? item.allowedSlots.first {
            return [item.id: slot]
        }
        return appModel.cabinPlacements.filter { previewCabinIDs.contains($0.key) }
    }

    private var storeBalloonHeight: CGFloat {
        switch viewport.kind {
        case .compact: 164
        case .regular: 215
        case .wide: 250
        }
    }

    @ViewBuilder private func lockBadge(premium: Bool) -> some View {
        if premium {
            // A premium (PRO) item wears the real multicolor badge, not a gold crown.
            FocusGlobePROBadge(visibleHeight: 17)
        } else {
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(9)
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))
        }
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
                Text(LocalizedStringKey(skin.name))
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(equipped ? "Equipped" : unlocked ? "Owned"
                     : skin.isPremium
                        ? (appModel.entitlement == .loading ? "Checking access…" : "FocusGlobe PRO")
                        : skinProgressText(skin))
                    .font(.system(size: 12.5, weight: .semibold, design: .default))
                    .foregroundStyle(equipped ? AppColors.success : .white.opacity(0.7))
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer()
            if equipped {
                Label("Flying", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .bold, design: .default))
                    .foregroundStyle(AppColors.gold)
            } else if unlocked {
                goldAction("Equip") { appModel.selectSkin(skin); appModel.tapFeedback() }
            } else if skin.isPremium && appModel.isConfirmedFree {
                goldAction("Unlock with FocusGlobe PRO", pro: true) {
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
            let blocked = owned && item.kind == .cabinDecoration && !placed && appModel.isCabinFull
            HStack(spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(LocalizedStringKey(item.name))
                        .font(.system(size: 17, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text(blocked
                         ? "Cabin full — remove one to place this"
                         : placed ? "In your cabin"
                         : owned ? "Owned"
                         : item.isPremium
                            ? (appModel.entitlement == .loading ? "Checking access…" : "FocusGlobe PRO")
                            : "Previewing")
                        .font(.system(size: 12.5, weight: .semibold, design: .default))
                        .foregroundStyle(blocked ? AppColors.gold
                                         : placed ? AppColors.success : .white.opacity(0.7))
                        .lineLimit(1).minimumScaleFactor(0.75)
                }
                Spacer()
                if owned, item.kind == .cabinDecoration {
                    if placed {
                        HStack(spacing: 8) {
                            goldAction("Move") { placementItem = item }
                            Button("Unequip") { appModel.unequipCabinItem(item) }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    } else {
                        goldAction(blocked ? "Replace…" : "Place") {
                            placementItem = item
                        }
                    }
                } else if owned {
                    Label("Owned", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold, design: .default))
                        .foregroundStyle(AppColors.success)
                } else if item.isPremium && appModel.isConfirmedFree {
                    goldAction("Unlock with FocusGlobe PRO", pro: true) {
                        appModel.tapFeedback(); router.presentPaywall(context: .interior)
                    }
                } else if item.isPremium && appModel.entitlement == .loading {
                    ProgressView()
                        .tint(.white)
                        .accessibilityLabel("Checking FocusGlobe PRO access")
                } else {
                    Button {
                        if appModel.purchaseStoreItem(item), item.kind == .cabinDecoration {
                            placementItem = item
                        } else {
                            appModel.haptics.tap()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            FocusCoinIcon(size: 13)
                            Text("\(item.price)")
                                .font(.system(size: 14, weight: .heavy, design: .default))
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
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                Spacer()
                Text("Tap an item to preview it")
                    .font(.system(size: 12.5, weight: .semibold, design: .default))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .shadow(color: .black.opacity(0.4), radius: 6, y: 1)
        }
    }

    /// A pill action button. `pro: true` gives the multicolor PRO gradient (for
    /// "Unlock with FocusGlobe PRO"); otherwise the neutral gold (Equip / Place),
    /// since gold now belongs to owned/coin actions, not subscription branding.
    private func goldAction(_ title: String, pro: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 13.5, weight: .bold, design: .default))
                .lineLimit(1).minimumScaleFactor(0.75)
                .foregroundStyle(pro ? .white : Color(hex: 0x2B2510))
                .padding(.horizontal, 15).padding(.vertical, 8)
                .background(Capsule().fill(pro ? AnyShapeStyle(ProBrand.gradient)
                                              : AnyShapeStyle(AppColors.gold)))
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
        VStack(spacing: 0) {
            VStack(spacing: viewport.cardSpacing) {
                modePicker
                    .padding(.top, AppSpacing.md)
                ScrollView(.vertical) {
                    if mode == .balloon { balloonGrid } else { interiorContent }
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            }
            .frame(maxWidth: viewport.storeContentWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, viewport.pagePadding)
        }
        .frame(maxWidth: .infinity)
        .frame(height: viewport.storePanelHeight)
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

    /// Container-driven adaptive columns: three useful cards on a phone, then
    /// progressively larger cards and more columns as real width becomes available.
    private var storeColumns: [GridItem] {
        [GridItem(.adaptive(minimum: viewport.storeCardMinimumWidth,
                            maximum: viewport.isWide ? 330 : 260),
                  spacing: viewport.cardSpacing)]
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
                    Text(LocalizedStringKey(m.rawValue))
                        .font(.system(size: 14, weight: .bold, design: .default))
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

// MARK: - Cabin placement

/// A bounded placement flow: compatible semantic slots only, no free dragging,
/// no window coordinates and an explicit replacement choice for a fifth item.
private struct CabinPlacementSheet: View {
    let item: StoreItem
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var replacementID: String?
    /// Chosen, not yet committed. Nothing moves until the pilot confirms, so
    /// Cancel genuinely leaves the current placement untouched.
    @State private var selectedSlot: CabinSlot?

    private var moving: Bool { appModel.isCabinItemEquipped(item) }
    private var replacement: StoreItem? { replacementID.flatMap(StoreItem.byID) }
    private var needsReplacement: Bool { !moving && appModel.isCabinFull }

    private var commitTitle: String { moving ? "Move Here" : "Place Item" }

    private var canCommit: Bool {
        guard let slot = selectedSlot, !occupiedSlots.contains(slot) else { return false }
        return !needsReplacement || replacement != nil
    }

    /// Pre-select the sensible slot so the sheet opens ready to confirm: the one
    /// the item already occupies, else its catalogued preferred slot, else the
    /// first slot that is actually free.
    private var defaultSelection: CabinSlot? {
        if let current = appModel.cabinSlot(for: item), item.allowedSlots.contains(current) {
            return current
        }
        if let preferred = item.preferredSlot, item.allowedSlots.contains(preferred),
           !occupiedSlots.contains(preferred) {
            return preferred
        }
        return item.allowedSlots.first { !occupiedSlots.contains($0) }
    }

    private var equippedItems: [StoreItem] {
        StoreItem.cabinDecorations.filter {
            appModel.isCabinItemEquipped($0) && $0.id != item.id
        }
    }

    private var occupiedSlots: Set<CabinSlot> {
        Set(appModel.cabinPlacements.compactMap { id, slot in
            if id == item.id || id == replacementID { return nil }
            return slot
        })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    placementContent.padding(20)
                }
                commitBar
            }
            .background(
                LinearGradient(colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            if selectedSlot == nil { selectedSlot = defaultSelection }
        }
        // Choosing what to replace frees a slot, so a sheet that opened with
        // nothing selectable can become selectable.
        .onChange(of: replacementID) { _, _ in
            if selectedSlot == nil { selectedSlot = defaultSelection }
        }
    }

    private var placementContent: some View {
        // No artwork. The sheet's job is one decision — which slot — and the item
        // is already named in the navigation bar and was just tapped in the Store,
        // so a 190 pt hero plus its glow was pushing the actual slot list below the
        // fold for nothing.
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose where this item should appear in your cabin.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            replacementSection

            slotSection
        }
    }

    private var commitBar: some View {
        AppPrimaryButton(title: commitTitle, systemImage: "checkmark",
                         isEnabled: canCommit) {
            commit()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private func commit() {
        guard canCommit, let slot = selectedSlot else { return }
        appModel.tapFeedback()
        guard appModel.placeCabinItem(item, in: slot, replacing: replacement) else { return }
        dismiss()
    }

    @ViewBuilder private var replacementSection: some View {
        if needsReplacement {
            VStack(alignment: .leading, spacing: 10) {
                Text("Replace one item")
                    .font(.headline)
                Text("Your Cabin holds four decorations. Choose the one that will make room.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 10) {
                    ForEach(equippedItems) { candidate in
                        Button {
                            appModel.tapFeedback()
                            replacementID = candidate.id
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: replacementID == candidate.id
                                      ? "checkmark.circle.fill" : "circle")
                                Text(LocalizedStringKey(candidate.name)).lineLimit(1)
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(replacementID == candidate.id
                                             ? Color(hex: 0x2B2510) : AppColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(replacementID == candidate.id
                                      ? AppColors.selectionGold : AppColors.storeCard(selected: false)))
                        }
                        .buttonStyle(SoftPressStyle(scale: 0.99))
                    }
                }
            }
        }
    }

    @ViewBuilder private var slotSection: some View {
        if !item.allowedSlots.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(moving ? "Move to" : "Place in")
                    .font(.headline)
                VStack(spacing: 0) {
                    ForEach(Array(item.allowedSlots.enumerated()), id: \.element) { index, slot in
                        if index > 0 { RowDivider() }
                        slotRow(slot)
                    }
                    RowDivider()
                    protectedWindowRow
                }
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.storeCard(selected: false)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppColors.hairline, lineWidth: 1))
                .animation(AppMotion.control, value: selectedSlot)
            }
        }
    }

    private func slotRow(_ slot: CabinSlot) -> some View {
        let open = !occupiedSlots.contains(slot)
        let isCurrent = appModel.cabinSlot(for: item) == slot
        let chosen = selectedSlot == slot
        return Button {
            guard open else { return }
            appModel.tapFeedback()
            selectedSlot = slot
        } label: {
            HStack(spacing: 12) {
                Image(systemName: slot.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 26)
                    .foregroundStyle(open ? AppColors.selectionGold : AppColors.textTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(slot.displayName))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(LocalizedStringKey(slot.placementHint))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer(minLength: 8)
                if isCurrent {
                    Text("Current").font(.caption.weight(.bold)).foregroundStyle(AppColors.textSecondary)
                } else if !open {
                    Text("Occupied").font(.caption.weight(.bold)).foregroundStyle(AppColors.textTertiary)
                }
                if open {
                    Image(systemName: chosen ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(chosen ? AppColors.selectionGold
                                         : AppColors.textTertiary.opacity(0.55))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle(scale: 0.99))
        .disabled(!open)
        .opacity(open ? 1 : 0.52)
        .accessibilityLabel("\(slot.displayName). \(slot.placementHint)")
        .accessibilityValue(isCurrent ? "Current position" : (open ? "" : "Occupied by another item"))
        .accessibilityAddTraits(chosen ? [.isSelected] : [])
    }

    /// The window is not a slot in the canonical model at all — it is simply
    /// absent from `CabinSlot`. Saying so as a permanently disabled row is much
    /// clearer than the caption that used to float over the Cabin photo, and it
    /// answers the obvious question ("why can't I put it on the window?") in the
    /// one place the pilot is looking.
    private var protectedWindowRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.portrait")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 26)
                .foregroundStyle(AppColors.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Main Window")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text("Reserved to keep your Sky visible")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "lock.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
        .opacity(0.52)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Main Window. Reserved to keep your Sky visible. Not available.")
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
    @Environment(\.focusViewport) private var viewport

    private var owned: Bool { appModel.ownsStoreItem(item) }
    private var affordable: Bool { appModel.focusCoins >= item.price }
    private var equipped: Bool {
        item.kind == .cabinDecoration && appModel.isCabinItemEquipped(item)
    }

    private var artHeight: CGFloat {
        if featured { return viewport.isWide ? 142 : (viewport.isCompact ? 96 : 126) }
        return viewport.isWide ? 132 : (viewport.isCompact ? 84 : 112)
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                art
                Text(LocalizedStringKey(item.name))
                    .font(.system(size: 14, weight: .bold, design: .default))
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
                .font(.system(size: 11.5, weight: .bold, design: .default))
                .foregroundStyle(AppColors.gold)
        } else if owned {
            Label("Owned", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11.5, weight: .bold, design: .default))
                .foregroundStyle(AppColors.success)
        } else if item.isPremium {
            FocusGlobePROBadge(visibleHeight: 15)
        } else {
            HStack(spacing: 4) {
                FocusCoinIcon(size: 12)
                Text("\(item.price)")
                    .font(.system(size: 12.5, weight: .heavy, design: .default))
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
    @Environment(\.focusViewport) private var viewport

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: AppSpacing.xs) {
                ZStack(alignment: .topTrailing) {
                    BalloonView(height: viewport.isWide ? 154 : (viewport.isCompact ? 96 : 132),
                                showBurner: false, showGlow: false, skin: skin)
                        .opacity(unlocked ? 1 : 0.55)
                        .frame(maxWidth: .infinity)
                    if equipped {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppColors.gold)
                    } else if !unlocked {
                        if skin.isPremium {
                            FocusGlobePROBadge(visibleHeight: 13)
                        } else {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppColors.textSecondary)
                                .padding(5)
                                .background(Circle().fill(.ultraThinMaterial))
                        }
                    }
                }
                .frame(height: viewport.isWide ? 164 : (viewport.isCompact ? 104 : 142))
                VStack(spacing: 1) {
                    Text(LocalizedStringKey(skin.name))
                        .font(.system(size: 14.5, weight: .bold, design: .default))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text(LocalizedStringKey(statusText))
                        .font(.system(size: 11.5, weight: .semibold, design: .default))
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
/// day (persisted); PRO pilots receive it too. Internal (not `private`) so the
/// app-wide `AppModal` coordinator in RootView can present it.
struct DailyGiftSheet: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.focusViewport) private var viewport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob: CGFloat = 0

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            VStack(spacing: viewport.isCompact ? 9 : 12) {
                giftHero
                Text("Daily Gift")
                    .font(.system(size: viewport.isWide ? 30 : 25,
                                  weight: .heavy, design: .default))
                    .foregroundStyle(AppColors.textPrimary)
                Text("Welcome back — your focus coins are ready.")
                    .font(.system(size: viewport.isWide ? 17 : 15,
                                  weight: .medium, design: .default))
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 9) {
                    FocusCoinIcon(size: viewport.isWide ? 34 : 28)
                    Text("+\(AppModel.dailyGiftCoins) Coins")
                        .font(.system(size: viewport.isWide ? 25 : 21,
                                      weight: .heavy, design: .default))
                        .foregroundStyle(AppColors.gold)
                }
                AppPrimaryButton(title: "Collect", systemImage: "gift.fill") {
                    appModel.claimDailyGift()
                    dismiss()
                }
                .frame(minHeight: min(viewport.buttonHeight, 54))
            }
            .padding(.horizontal, viewport.modalPadding)
            .padding(.vertical, viewport.isWide ? 24 : 18)
            .frame(maxWidth: viewport.modalWidth)
            .frame(maxWidth: .infinity)
        }
        .presentationDetents([.fraction(viewport.isWide ? 0.56 : 0.5)])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.resizes)
        .interactiveDismissDisabled(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { bob = -9 }
        }
    }

    /// The `dailygift` artwork if present; the smiling-balloon mascot otherwise.
    @ViewBuilder private var giftHero: some View {
        let heroHeight: CGFloat = viewport.isWide ? 154 : (viewport.isCompact ? 106 : 126)
        ZStack {
            // The falloff has to finish inside the frame, otherwise the Circle
            // clips it mid-gradient and the gift sits on a gold coin-shaped
            // plate. (Was endRadius 130 inside a 106–154 pt circle, so it was
            // cut at roughly half opacity at every size.)
            RadialGradient(colors: [AppColors.gold.opacity(0.3), .clear],
                           center: .center, startRadius: 2, endRadius: heroHeight * 0.58)
                .frame(width: heroHeight * 1.9, height: heroHeight * 1.9)
                .blur(radius: 12)
                .allowsHitTesting(false)
            if let ui = UIImage(named: "dailygift") {
                Image(uiImage: ui).resizable().scaledToFit()
                    .frame(maxWidth: heroHeight, maxHeight: heroHeight * 0.88)
                    .offset(y: bob)
            } else {
                SmilingBalloon()
                    .frame(width: heroHeight * 0.46, height: heroHeight * 0.58)
                    .offset(y: bob)
            }
        }
        .frame(height: heroHeight)
        .padding(.top, viewport.isWide ? 12 : 4)
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

// MARK: - Store-only calm daytime sky

/// The Store's own premium open-air showroom. It uses an authored sky and three
/// transparent cloud plates with glacial depth motion, shared by the balloon and
/// cabin previews. The gradient remains only as a resilient missing-asset
/// fallback.
struct StoreDaytimeSky: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            let live = !reduceMotion && scenePhase == .active
            if live {
                TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { context in
                    showroom(size: geo.size,
                             landscape: landscape,
                             t: context.date.timeIntervalSinceReferenceDate,
                             motionEnabled: true)
                }
            } else {
                showroom(size: geo.size, landscape: landscape, t: 0, motionEnabled: false)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func showroom(size: CGSize, landscape: Bool,
                          t: Double, motionEnabled: Bool) -> some View {
        let suffix = landscape ? "Landscape" : "Portrait"
        let w = size.width
        let h = size.height
        let drift: (Double, Double, CGFloat) -> CGFloat = { phase, rate, amplitude in
            guard motionEnabled else { return 0 }
            return CGFloat(Foundation.sin(t * rate + phase)) * amplitude
        }

        return ZStack {
            LinearGradient(
                colors: [Color(hex: 0x4F9BEA), Color(hex: 0x7FC0F4),
                         Color(hex: 0xBFE2FA), Color(hex: 0xF7E7BE)],
                startPoint: .top, endPoint: .bottom)
            showroomPlate(named: "StoreShowroom_Base_\(suffix)", scale: 1)
            showroomPlate(named: "StoreShowroom_Clouds_Far_\(suffix)", scale: 1.025)
                .offset(x: drift(0.4, 0.005, w * 0.012),
                        y: drift(1.5, 0.004, h * 0.004))
            showroomPlate(named: "StoreShowroom_Clouds_Mid_\(suffix)", scale: 1.055)
                .offset(x: drift(1.7, 0.007, w * 0.025),
                        y: drift(0.8, 0.005, h * 0.006))
            showroomPlate(named: "StoreShowroom_Clouds_Near_\(suffix)", scale: 1.085)
                .offset(x: drift(2.8, 0.009, w * 0.040),
                        y: drift(2.1, 0.006, h * 0.008))
            RadialGradient(colors: [Color.white.opacity(0.34), .clear],
                           center: UnitPoint(x: 0.78, y: 0.15),
                           startRadius: 4, endRadius: max(220, w * 0.52))
            LinearGradient(colors: [.clear, Color(hex: 0xFFF0C9).opacity(0.11)],
                           startPoint: .top, endPoint: .bottom)
        }
        .frame(width: w, height: h)
        .clipped()
    }

    @ViewBuilder
    private func showroomPlate(named name: String, scale: CGFloat) -> some View {
        if let image = UIImage(named: name) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .scaleEffect(scale)
        }
    }
}
