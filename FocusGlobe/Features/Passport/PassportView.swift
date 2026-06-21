import SwiftUI

struct PassportView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter

    private let stampColumns = [GridItem(.flexible(), spacing: AppSpacing.sm),
                                GridItem(.flexible(), spacing: AppSpacing.sm),
                                GridItem(.flexible(), spacing: AppSpacing.sm)]
    private let cardColumns = [GridItem(.flexible(), spacing: AppSpacing.sm),
                               GridItem(.flexible(), spacing: AppSpacing.sm)]

    private var progress: UserProgress { appModel.progress }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    HStack(alignment: .top) {
                        ScreenHeader(title: "Globe Passport",
                                     subtitle: "Your landings, miles and collection")
                        Spacer()
                        CrownButton { appModel.haptics.tap(); router.presentPaywall() }
                    }
                    statsGrid
                    missionsSection
                    postcardsSection
                    routesSection
                    skinsSection
                }
                .padding(AppSpacing.screen)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xxl)
            }
        }
        .focusScreenChrome()
        .onAppear { appModel.analytics.log(.passportOpened) }
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

    @ViewBuilder private var routesSection: some View {
        let journeys = appModel.currentOrigin == nil ? [] : JourneyPlanner.plan(from: appModel.originForJourney)
        if !journeys.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    SectionLabel(text: "Destinations near \(appModel.originForJourney.city)")
                    Spacer()
                    Text("\(journeys.filter { progress.completedRouteIDs.contains($0.id) }.count)/\(journeys.count)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
                LazyVGrid(columns: stampColumns, spacing: AppSpacing.sm) {
                    ForEach(journeys) { journey in
                        DestinationStampTile(
                            journey: journey,
                            completed: progress.completedRouteIDs.contains(journey.id),
                            locked: !appModel.isUnlocked(journey.route))
                    }
                }
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

    private var skinsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionLabel(text: "Balloon skins")
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
                .padding(.vertical, 2)
            }
        }
    }

    private func handleSkinTap(_ skin: BalloonSkin) {
        if appModel.isSkinUnlocked(skin) {
            appModel.selectSkin(skin)
        } else if skin.isPremium {
            appModel.haptics.tap()
            router.presentPaywall()
        } else {
            appModel.haptics.tap()   // locked milestone — keep going to unlock
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
                BalloonView(height: 52, showBurner: unlocked, showGlow: selected, glow: skin.theme.soft)
                    .frame(height: 54)
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
            .frame(width: 112)
            .padding(.vertical, AppSpacing.sm)
            .padding(.horizontal, 6)
            .glassBackground(cornerRadius: AppSpacing.pillRadius, tintOpacity: 0.25, shadowRadius: 8, shadowY: 4)
            .overlay(RoundedRectangle(cornerRadius: AppSpacing.pillRadius, style: .continuous)
                .strokeBorder(selected ? skin.theme.accent.opacity(0.8) : Color.clear, lineWidth: 2))
        }
        .buttonStyle(SoftPressStyle())
    }
}

private struct DestinationStampTile: View {
    let journey: PlannedJourney
    let completed: Bool
    let locked: Bool

    var body: some View {
        if completed {
            ZStack {
                DestinationScene(mood: journey.mood, theme: journey.theme,
                                 landmark: journey.landmark, compact: true)
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(journey.mood.preferredForeground)
                    Text(journey.name)
                        .font(AppTypography.caption)
                        .foregroundStyle(journey.mood.preferredForeground)
                        .lineLimit(1)
                }
                .padding(4)
            }
            .frame(height: 116)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.pillRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppSpacing.pillRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
            .shadow(color: AppColors.shadow, radius: 8, y: 4)
        } else {
            VStack(spacing: 6) {
                Image(systemName: locked ? "lock.fill" : journey.mood.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.textTertiary)
                Text(journey.name)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .lineLimit(1)
                Text(journey.code)
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.textTertiary.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 116)
            .background(RoundedRectangle(cornerRadius: AppSpacing.pillRadius, style: .continuous)
                .fill(AppColors.hairline))
            .overlay(RoundedRectangle(cornerRadius: AppSpacing.pillRadius, style: .continuous)
                .strokeBorder(AppColors.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
        }
    }
}
