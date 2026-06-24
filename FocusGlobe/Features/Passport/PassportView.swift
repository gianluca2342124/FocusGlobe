import SwiftUI

struct PassportView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter

    @Environment(\.horizontalSizeClass) private var hSize

    // Adaptive: 2 columns on an iPhone, more and larger tiles on iPad/Mac
    // (paired with a centred max content width below).
    private var cardColumns: [GridItem] { Layout.cardColumns(regular: hSize == .regular) }

    private var progress: UserProgress { appModel.progress }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    HStack(alignment: .top) {
                        ScreenHeader(title: "Passport",
                                     subtitle: "Your landings, miles and collection")
                        Spacer()
                        // The crown only opens the paywall — hide it once Pro.
                        if !appModel.isPro {
                            CrownButton { appModel.tapFeedback(); router.presentPaywall() }
                        }
                    }
                    statsGrid
                    skinsSection
                    missionsSection
                    postcardsSection
                    journeySoundSection
                }
                .padding(AppSpacing.screen)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xxl)
                .contentMaxWidth()   // centred column on iPad/Mac; full-width on iPhone
            }
        }
        .focusScreenChrome()
        .onAppear {
            appModel.analytics.log(.passportOpened)
            // Calm moment to ask for notification permission (provisional, no
            // prompt) — never after a journey, never at first launch.
            appModel.requestNotificationPermissionForEngagement()
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: cardColumns, spacing: AppSpacing.sm) {
            StatTile(systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                     value: Formatters.miles(progress.totalFocusMiles),
                     label: "Focus miles", accent: AppColors.brand)
            StatTile(systemImage: "mappin.and.ellipse",
                     value: "\(progress.landings)", label: "Landings", accent: AppColors.gold)
            StatTile(systemImage: "hourglass",
                     value: progress.bestFocusSeconds > 0 ? Formatters.durationLabel(minutes: max(1, progress.bestFocusMinutes)) : "—",
                     label: "Best focus", accent: AppColors.success)
            StatTile(systemImage: "flame.fill",
                     value: "\(progress.currentStreak)", label: "Day streak", accent: AppColors.danger)
        }
    }

    @ViewBuilder private var postcardsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionLabel(text: "Your postcards")
            if progress.postcards.isEmpty {
                emptyCollection
            } else {
                LazyVGrid(columns: cardColumns, spacing: AppSpacing.sm) {
                    ForEach(progress.postcards) { postcard in
                        PostcardTile(postcard: postcard, compact: true)
                    }
                }
            }
        }
    }

    private var emptyCollection: some View {
        AppGlassCard {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.brand)
                Text("Complete a journey to unlock your first postcard.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
            }
        }
    }

    // MARK: Daily missions

    private var missionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                SectionLabel(text: "Today's missions")
                Spacer()
                if appModel.dailyMissionsComplete {
                    Label("All done", systemImage: "checkmark.seal.fill")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.success)
                }
            }
            AppGlassCard {
                VStack(spacing: AppSpacing.md) {
                    ForEach(appModel.dailyMissions) { mission in
                        MissionRow(mission: mission)
                    }
                    if appModel.canClaimDailyMissionReward {
                        Button {
                            appModel.claimDailyMissionReward()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "gift.fill").font(.system(size: 14, weight: .bold))
                                Text("Claim +\(appModel.dailyMissionRewardMiles) miles")
                                    .font(AppTypography.callout)
                            }
                            .foregroundStyle(Color(hex: 0x14181F))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Capsule().fill(AppColors.gold))
                        }
                        .buttonStyle(SoftPressStyle())
                    } else if appModel.dailyMissionsComplete {
                        Text("Daily bonus claimed — see you tomorrow.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: Balloon skins

    private var unlockedSkinCount: Int {
        BalloonSkin.all.filter { appModel.isSkinUnlocked($0) }.count
    }

    /// A prominent, collectible-feeling gallery — one of the main reasons to keep
    /// flying. Lives in its own gold-tinted panel above the postcards.
    private var skinsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Balloon skins")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Collect & equip your balloon")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Text("\(unlockedSkinCount)/\(BalloonSkin.all.count)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.gold)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(AppColors.gold.opacity(0.16)))
                    .overlay(Capsule().strokeBorder(AppColors.gold.opacity(0.4), lineWidth: 1))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(BalloonSkin.all) { skin in
                        SkinTile(skin: skin,
                                 unlocked: appModel.isSkinUnlocked(skin),
                                 selected: appModel.selectedSkin.id == skin.id,
                                 progress: appModel.unlockProgress(for: skin)) {
                            handleSkinTap(skin)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                .fill(LinearGradient(colors: [AppColors.gold.opacity(0.14), AppColors.brand.opacity(0.10)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .strokeBorder(AppColors.gold.opacity(0.25), lineWidth: 1))
        )
    }

    private func handleSkinTap(_ skin: BalloonSkin) {
        if appModel.isSkinUnlocked(skin) {
            appModel.selectSkin(skin)
        } else if skin.isPremium {
            appModel.tapFeedback()
            router.presentPaywall()
        } else {
            appModel.haptics.tap()   // locked milestone — keep going to unlock
        }
    }

    // MARK: Journey sound

    /// The looping ambience that plays during a journey, as colourful sound cards.
    /// Wind is free; the rest require active Pro (locked cards open the paywall).
    /// The master Sound toggle (Settings) stays the on/off switch.
    private var journeySoundSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionLabel(text: "Journey sound")
            LazyVGrid(columns: cardColumns, spacing: AppSpacing.sm) {
                ForEach(JourneyAudioOption.all) { option in
                    JourneySoundCard(option: option,
                                     theme: audioTheme(option),
                                     unlocked: appModel.isAudioUnlocked(option),
                                     selected: appModel.selectedJourneyAudio.id == option.id) {
                        if appModel.isAudioUnlocked(option) {
                            appModel.selectJourneyAudio(option)
                        } else {
                            appModel.tapFeedback()
                            router.presentPaywall()
                        }
                    }
                }
            }
        }
    }

    /// A distinct accent per sound so each card has its own personality.
    private func audioTheme(_ option: JourneyAudioOption) -> RouteTheme {
        switch option.id {
        case "wind":        return .teal
        case "focus-music": return .indigo
        case "alpha-waves": return .lavender
        case "rain":        return .slate
        case "ocean":       return .aurora
        case "relaxing":    return .mint
        case "jazz":        return .coral
        default:            return .teal
        }
    }
}

// MARK: - Mission row

private struct MissionRow: View {
    let mission: DailyMission

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle().fill(mission.accent.accent.opacity(0.16)).frame(width: 34, height: 34)
                Image(systemName: mission.isComplete ? "checkmark" : mission.systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(mission.isComplete ? AppColors.success : mission.accent.accent)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(mission.title)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Text(mission.progressText)
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.textTertiary)
                }
                MissionProgressBar(fraction: mission.fraction, color: mission.accent.accent)
            }
        }
    }
}

private struct MissionProgressBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(AppColors.hairline)
                Capsule().fill(color)
                    .frame(width: max(5, geo.size.width * fraction))
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Skin tile

private struct SkinTile: View {
    let skin: BalloonSkin
    let unlocked: Bool
    let selected: Bool
    let progress: Double?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.xs) {
                // Fixed frame + no glow/burner so every skin renders at the same
                // visual size (selection is shown by the ring + shadow + check).
                BalloonView(height: 52, showBurner: false, showGlow: false, skin: skin)
                    .frame(width: 84, height: 58)
                    .opacity(unlocked ? 1 : 0.42)
                    .grayscale(unlocked ? 0 : 0.7)
                    .overlay(alignment: .topTrailing) {
                        if !unlocked && skin.isPremium {
                            PremiumBadge(compact: true)
                        } else if !unlocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppColors.textTertiary)
                        } else if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppColors.success)
                        }
                    }
                Text(skin.name)
                    .font(AppTypography.caption)
                    .foregroundStyle(unlocked ? AppColors.textPrimary : AppColors.textTertiary)
                    .lineLimit(1)
                Text(unlocked ? (selected ? "Selected" : "Tap to use") : skin.requirementText)
                    .font(AppTypography.micro)
                    .foregroundStyle(selected ? AppColors.success
                                     : (skin.isPremium && !unlocked ? AppColors.gold : AppColors.textTertiary))
                if let progress, !unlocked {
                    MissionProgressBar(fraction: progress, color: skin.theme.accent)
                        .padding(.horizontal, 4)
                }
            }
            .frame(width: 116)
            .padding(.vertical, AppSpacing.sm)
            .padding(.horizontal, 6)
            .glassBackground(cornerRadius: AppSpacing.pillRadius, tintOpacity: 0.25, shadowRadius: 8, shadowY: 4)
            .overlay(RoundedRectangle(cornerRadius: AppSpacing.pillRadius, style: .continuous)
                .strokeBorder(selected ? skin.theme.accent : Color.clear, lineWidth: 2.5))
            .shadow(color: selected ? skin.theme.accent.opacity(0.45) : .clear, radius: 12, y: 2)
        }
        .buttonStyle(SoftPressStyle())
    }
}

// MARK: - Journey sound card

/// A large, colourful "sound disc" card for the journey-audio picker. Each sound
/// has its own gradient personality; the selected card shows a bright ring +
/// check, and locked premium cards show a gold crown (and open the paywall).
private struct JourneySoundCard: View {
    let option: JourneyAudioOption
    let theme: RouteTheme
    let unlocked: Bool
    let selected: Bool
    let action: () -> Void

    private var locked: Bool { option.isPremium && !unlocked }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle().fill(.white.opacity(0.18))
                        Image(systemName: option.systemImage)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 42, height: 42)
                    Spacer()
                    statusBadge
                }
                Spacer(minLength: AppSpacing.sm)
                Text(option.displayName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(statusText)
                    .font(AppTypography.micro)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(AppSpacing.md)
            .frame(height: Layout.pad(118, 142), alignment: .topLeading)   // roomier on iPad
            .frame(maxWidth: .infinity)
            .background(cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .strokeBorder(.white.opacity(selected ? 0.9 : 0.12), lineWidth: selected ? 2.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous))
            .shadow(color: theme.accent.opacity(selected ? 0.5 : 0.22), radius: selected ? 14 : 8, y: 5)
        }
        .buttonStyle(SoftPressStyle(scale: 0.98))
    }

    private var cardBackground: some View {
        ZStack {
            LinearGradient(colors: [theme.accent.opacity(0.9), theme.soft.opacity(0.55)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Color.black.opacity(0.16)   // keep the white text legible on any accent
        }
    }

    @ViewBuilder private var statusBadge: some View {
        if selected {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
        } else if locked {
            Image(systemName: "crown.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: 0x14181F))
                .padding(6)
                .background(Circle().fill(AppColors.gold))
        }
    }

    private var statusText: String {
        if selected { return "Playing on journeys" }
        if option.isPremium { return unlocked ? "Pro" : "Unlock with Pro" }
        return "Free"
    }
}
