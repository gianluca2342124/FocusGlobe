import SwiftUI

struct PassportView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter

    @Environment(\.horizontalSizeClass) private var hSize

    // Adaptive: 2 columns on an iPhone, more and larger tiles on iPad/Mac
    // (paired with a centred max content width below).
    private var cardColumns: [GridItem] { Layout.cardColumns(regular: hSize == .regular) }

    private var progress: UserProgress { appModel.progress }

    // MARK: Derived flight stats (from the on-device session history)

    private var completedFlights: [FocusSessionRecord] { appModel.history.filter { $0.completed } }
    private var totalFocusMinutes: Int { completedFlights.reduce(0) { $0 + $1.focusedSeconds } / 60 }
    private var totalDistanceKm: Double { completedFlights.reduce(0) { $0 + $1.distanceKm } }
    private var flightsCompleted: Int { max(progress.landings, completedFlights.count) }
    private var skiesDiscovered: Int { Set(completedFlights.map { $0.destinationName }).count }
    private var totalSkies: Int { max(SkyScene.all.count, skiesDiscovered) }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    HStack(alignment: .top) {
                        ScreenHeader(title: "Passport",
                                     subtitle: "Your flights, focus and discoveries")
                        Spacer()
                        // The crown only opens the paywall — hide it once Pro.
                        if !appModel.isPro {
                            CrownButton { appModel.tapFeedback(); router.presentPaywall() }
                        }
                    }
                    statsGrid
                    achievementsSection
                    focusCategoriesSection
                    recentStampsSection
                    WidgetsGallerySection()
                    missionsSection
                    flightSoundSection
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

    // MARK: Headline stats

    private var statsGrid: some View {
        LazyVGrid(columns: cardColumns, spacing: AppSpacing.sm) {
            StatTile(systemImage: "hourglass",
                     value: totalFocusMinutes > 0 ? Formatters.durationLabel(minutes: totalFocusMinutes) : "—",
                     label: "Total focus time", accent: AppColors.brand)
            StatTile(systemImage: "paperplane.fill",
                     value: "\(flightsCompleted)", label: "Flights completed", accent: AppColors.gold)
            StatTile(systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                     value: totalDistanceKm > 0 ? Formatters.distance(km: totalDistanceKm) : "—",
                     label: "Distance traveled", accent: AppColors.teal)
            StatTile(systemImage: "flame.fill",
                     value: "\(progress.currentStreak)", label: "Day streak", accent: AppColors.danger)
            StatTile(systemImage: "trophy.fill",
                     value: progress.bestFocusSeconds > 0 ? Formatters.durationLabel(minutes: max(1, progress.bestFocusMinutes)) : "—",
                     label: "Best focus", accent: AppColors.gold)
            StatTile(systemImage: "moon.stars.fill",
                     value: "\(skiesDiscovered)/\(totalSkies)", label: "Skies discovered", accent: AppColors.brand)
        }
    }

    // MARK: Achievements

    private var achievements: [Achievement] {
        let flights = flightsCompleted
        let mins = totalFocusMinutes
        let best = progress.bestFocusMinutes
        let streak = max(progress.currentStreak, progress.longestStreak)
        let skies = skiesDiscovered
        return [
            Achievement("airplane.departure", "First flight", flights >= 1, AppColors.brand),
            Achievement("5.circle.fill", "5 flights", flights >= 5, AppColors.brand),
            Achievement("25.circle.fill", "25 flights", flights >= 25, AppColors.gold),
            Achievement("flame.fill", "3-day streak", streak >= 3, AppColors.danger),
            Achievement("bolt.heart.fill", "7-day streak", streak >= 7, AppColors.danger),
            Achievement("hourglass.bottomhalf.filled", "Deep focus", best >= 60, AppColors.success),
            Achievement("clock.badge.checkmark.fill", "10 hours", mins >= 600, AppColors.gold),
            Achievement("moon.stars.fill", "Sky collector", skies >= SkyScene.all.count, AppColors.teal),
        ]
    }

    private var achievementsSection: some View {
        let earned = achievements.filter { $0.earned }.count
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                SectionLabel(text: "Achievements")
                Spacer()
                Text("\(earned)/\(achievements.count)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.gold)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(AppColors.gold.opacity(0.16)))
                    .overlay(Capsule().strokeBorder(AppColors.gold.opacity(0.4), lineWidth: 1))
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: AppSpacing.sm)],
                      spacing: AppSpacing.sm) {
                ForEach(achievements) { badge in
                    AchievementBadge(badge: badge)
                }
            }
        }
    }

    // MARK: Focus categories (by the focus you packed)

    private var focusCategories: [(title: String, count: Int, accent: Color)] {
        var counts: [String: Int] = [:]
        for r in completedFlights {
            let key = (r.intention?.isEmpty == false) ? r.intention! : "Open focus"
            counts[key, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }.map { pair in
            let accent = FocusPreset.all.first { $0.title == pair.key }?.accent ?? AppColors.brand
            return (pair.key, pair.value, accent)
        }
    }

    private var focusCategoriesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionLabel(text: "Focus categories")
            AppGlassCard {
                let cats = focusCategories
                if cats.isEmpty {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "bag")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColors.brand)
                        Text("Pack a focus on your next flight to build your mix.")
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer(minLength: 0)
                    }
                } else {
                    let maxCount = max(1, cats.map { $0.count }.max() ?? 1)
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(cats, id: \.title) { cat in
                            CategoryBar(title: cat.title, count: cat.count,
                                        fraction: Double(cat.count) / Double(maxCount), accent: cat.accent)
                        }
                    }
                }
            }
        }
    }

    // MARK: Recent stamps (collectible postcards)

    @ViewBuilder private var recentStampsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionLabel(text: "Recent stamps")
            if progress.postcards.isEmpty {
                emptyCollection
            } else {
                LazyVGrid(columns: cardColumns, spacing: AppSpacing.sm) {
                    ForEach(progress.postcards.prefix(6)) { postcard in
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
                Text("Complete a flight to earn your first stamp.")
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
                            .foregroundStyle(Color(hex: 0x2B2620))
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

    // MARK: Flight ambience

    /// The looping ambience that plays during a flight, as colourful sound cards.
    /// Wind is free; the rest require active Pro (locked cards open the paywall).
    /// The master Sound toggle (Settings) stays the on/off switch.
    private var flightSoundSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionLabel(text: "Flight ambience")
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

// MARK: - Achievement badge

private struct Achievement: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let earned: Bool
    let accent: Color
    init(_ icon: String, _ title: String, _ earned: Bool, _ accent: Color) {
        self.icon = icon; self.title = title; self.earned = earned; self.accent = accent
    }
}

private struct AchievementBadge: View {
    let badge: Achievement

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(badge.earned ? badge.accent.opacity(0.18) : AppColors.textTertiary.opacity(0.10))
                    .frame(width: 46, height: 46)
                Image(systemName: badge.earned ? badge.icon : "lock.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(badge.earned ? badge.accent : AppColors.textTertiary)
            }
            Text(badge.title)
                .font(AppTypography.micro)
                .foregroundStyle(badge.earned ? AppColors.textPrimary : AppColors.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .glassBackground(cornerRadius: AppSpacing.cardRadius, tintOpacity: 0.22, shadowRadius: 6, shadowY: 3)
        .opacity(badge.earned ? 1 : 0.75)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(badge.title). \(badge.earned ? "Earned" : "Locked").")
    }
}

// MARK: - Focus category bar

private struct CategoryBar: View {
    let title: String
    let count: Int
    let fraction: Double
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }
            MissionProgressBar(fraction: fraction, color: accent)
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

// MARK: - Flight ambience card

/// A large, colourful "sound disc" card for the flight-audio picker. Each sound
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
                .foregroundStyle(Color(hex: 0x2B2620))
                .padding(6)
                .background(Circle().fill(AppColors.gold))
        }
    }

    private var statusText: String {
        if selected { return "Playing on flights" }
        if option.isPremium { return unlocked ? "Ultra" : "Unlock with Ultra" }
        return "Free"
    }
}
