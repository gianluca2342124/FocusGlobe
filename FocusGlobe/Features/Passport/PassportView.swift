import SwiftUI

/// The **Passport** — a premium *flight logbook* / travel journal. It reads
/// top-to-bottom as a collectible record: a warm hero summary (the journal
/// cover), refined flight stats, today's flight objectives, discovered skies
/// (stamps), recent landings, flight ambience, widgets and collectible badges.
///
/// Presentation only — every number is derived from the on-device session
/// history / `UserProgress`; nothing here writes persistence, analytics or
/// mission state (beyond the existing claim action).
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
    private var flightsCompleted: Int { max(progress.landings, completedFlights.count) }
    private var skiesDiscovered: Int { Set(completedFlights.map { $0.destinationName }).count }
    private var totalSkies: Int { max(SkyScene.all.count, skiesDiscovered) }

    /// Friends who accepted an invite, across every Sky.
    private var friendsInvited: Int {
        (appModel.profile.inviteProgressBySkyID ?? [:]).values.reduce(0, +)
    }

    /// Most-visited destination across completed flights (a "home sky").
    private var favoriteSky: String? {
        guard !completedFlights.isEmpty else { return nil }
        var counts: [String: Int] = [:]
        for r in completedFlights { counts[r.destinationName, default: 0] += 1 }
        return counts.max { $0.value < $1.value }?.key
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    header
                    statsGrid
                    achievementsSection
                    missionsSection
                    flightSoundSection
                    WidgetsGallerySection()
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

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            ScreenHeader(title: "Passport", subtitle: "Your flight logbook", showsBack: false)
            Spacer()
            // The crown only opens the paywall — hide it once Pro.
            if !appModel.isPro {
                CrownButton { appModel.tapFeedback(); router.presentPaywall() }
            }
        }
    }

    // MARK: Hero logbook summary (the journal cover)

    /// "Pilot {name}" when the profile has a name; the plain logbook otherwise.
    private var pilotLine: String {
        if let name = appModel.profile.name, !name.isEmpty { return "Pilot \(name)" }
        return "Flight logbook"
    }

    private var heroLogbookCard: some View {
        let focus = totalFocusMinutes
        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Label(pilotLine, systemImage: "book.closed.fill")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.gold)
                    .lineLimit(1)
                Spacer()
                if progress.currentStreak > 0 {
                    StreakPill(days: progress.currentStreak)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Total focus in the air")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Text(focus > 0 ? Formatters.durationLabel(minutes: focus) : "Ready for takeoff")
                    .font(.system(size: Layout.pad(40, 48), weight: .bold, design: .serif))
                    .foregroundStyle(AppColors.textPrimary)
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
            }
            heroSecondaryRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .glassBackground(cornerRadius: AppSpacing.cardRadius,
                         tint: AppColors.goldFoil, tintOpacity: 0.13,
                         shadowRadius: 22, shadowY: 12)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                .strokeBorder(AppColors.gold.opacity(0.32), lineWidth: 1)
        )
    }

    private var heroSecondaryRow: some View {
        HStack(spacing: AppSpacing.sm) {
            heroChip(icon: "paperplane.fill", value: "\(flightsCompleted)",
                     label: "flights", tint: AppColors.gold)
            heroChip(icon: "circle.hexagongrid.circle.fill",
                     value: Formatters.miles(appModel.focusCoins),
                     label: "Focus Coins", tint: AppColors.teal)
            heroChip(icon: "moon.stars.fill", value: "\(skiesDiscovered)",
                     label: "skies", tint: AppColors.brand)
        }
    }

    private func heroChip(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(label)
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs + 2)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.textPrimary.opacity(0.05))
        )
    }

    // MARK: Headline stats

    private var statsGrid: some View {
        LazyVGrid(columns: cardColumns, spacing: AppSpacing.sm) {
            StatTile(systemImage: "hourglass",
                     value: totalFocusMinutes > 0 ? Formatters.durationLabel(minutes: totalFocusMinutes) : "—",
                     label: "Total focus", accent: AppColors.brand)
            StatTile(systemImage: "paperplane.fill",
                     value: "\(flightsCompleted)", label: "Flights", accent: AppColors.gold)
            StatTile(systemImage: "flame.fill",
                     value: "\(progress.currentStreak)", label: "Day streak", accent: AppColors.danger)
            StatTile(systemImage: "trophy.fill",
                     value: progress.bestFocusSeconds > 0 ? Formatters.durationLabel(minutes: max(1, progress.bestFocusMinutes)) : "—",
                     label: "Best focus", accent: AppColors.gold)
            StatTile(systemImage: "heart.fill",
                     value: favoriteSky ?? "—", label: "Favorite sky", accent: AppColors.terracotta)
            StatTile(systemImage: "circle.hexagongrid.circle.fill",
                     value: Formatters.miles(progress.totalFocusMiles),
                     label: "Focus Coins earned", accent: AppColors.teal)
        }
    }

    // MARK: Recent landings (the last pages of the journal)

    @ViewBuilder private var recentLandingsSection: some View {
        let recent = Array(completedFlights.sorted { $0.date > $1.date }.prefix(3))
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                SectionLabel(text: "Recent landings")
                VStack(spacing: AppSpacing.xs + 2) {
                    ForEach(recent) { record in
                        recentLandingRow(record)
                    }
                }
            }
        }
    }

    private func recentLandingRow(_ record: FocusSessionRecord) -> some View {
        HStack(spacing: AppSpacing.sm) {
            MiniBalloonView(size: 22, showGlow: false)
            VStack(alignment: .leading, spacing: 1) {
                Text(record.destinationName)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                Text("\(Formatters.durationLabel(minutes: max(1, record.focusedMinutes))) focused")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            Text(record.date.formatted(.relative(presentation: .named)))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .glassBackground(cornerRadius: 16, shadowRadius: 10, shadowY: 5)
    }

    // MARK: Today's objectives (daily missions)

    private var missionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                SectionLabel(text: "Today's objectives")
                Spacer()
                if appModel.dailyMissionsComplete {
                    Label("All done", systemImage: "checkmark.seal.fill")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.success)
                }
            }
            VStack(spacing: AppSpacing.sm) {
                ForEach(appModel.dailyMissions) { mission in
                    MissionObjectiveCard(mission: mission)
                }
            }
            missionRewardFooter
        }
    }

    @ViewBuilder private var missionRewardFooter: some View {
        if appModel.canClaimDailyMissionReward {
            Button {
                appModel.claimDailyMissionReward()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "gift.fill").font(.system(size: 14, weight: .bold))
                    Text("Claim +\(appModel.dailyMissionRewardMiles) Focus Coins")
                        .font(AppTypography.callout)
                }
                .foregroundStyle(Color(hex: 0x2B2620))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule().fill(AppColors.gold))
                .shadow(color: AppColors.gold.opacity(0.4), radius: 10, y: 5)
            }
            .buttonStyle(SoftPressStyle())
        } else if appModel.dailyMissionsComplete {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 12, weight: .bold))
                Text("Daily bonus claimed — see you tomorrow.")
                    .font(AppTypography.caption)
            }
            .foregroundStyle(AppColors.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
        }
    }

    // MARK: Focus mix (by the focus you packed)

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
            SectionLabel(text: "Focus mix")
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
                    VStack(spacing: AppSpacing.md) {
                        ForEach(cats, id: \.title) { cat in
                            CategoryBar(title: cat.title, count: cat.count,
                                        fraction: Double(cat.count) / Double(maxCount), accent: cat.accent)
                        }
                    }
                }
            }
        }
    }

    // MARK: Discovered skies (collectible stamps)

    @ViewBuilder private var discoveredSkiesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                SectionLabel(text: "Discovered skies")
                Spacer()
                if !progress.postcards.isEmpty {
                    Text("\(progress.postcards.count)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColors.gold)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(AppColors.gold.opacity(0.14)))
                }
            }
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

    // MARK: Achievements (collectible badges)

    private func visited(_ name: String) -> Bool {
        completedFlights.contains { $0.destinationName == name }
    }
    private func visitedCount(_ name: String) -> Int {
        completedFlights.filter { $0.destinationName == name }.count
    }
    private func flewAtHour(_ test: (Int) -> Bool) -> Bool {
        completedFlights.contains { test(Calendar.current.component(.hour, from: $0.date)) }
    }

    private var achievements: [Achievement] {
        let flights = flightsCompleted
        let mins = totalFocusMinutes
        let best = progress.bestFocusMinutes
        let streak = max(progress.currentStreak, progress.longestStreak)
        let coins = progress.totalFocusMiles
        let ownsCabin = StoreItem.all.contains { $0.kind == .cabinDecoration && appModel.ownsStoreItem($0) }
        let skinsOwned = BalloonSkin.all.filter { appModel.isSkinUnlocked($0) }.count
        return [
            Achievement("airplane.departure", "First Flight", flights >= 1, AppColors.brand),
            Achievement("25.circle.fill", "25-Min Pilot", best >= 25, AppColors.brand),
            Achievement("hourglass.bottomhalf.filled", "1 Hour Focused", best >= 60, AppColors.success),
            Achievement("5.circle.fill", "5 Flights", flights >= 5, AppColors.brand),
            Achievement("10.circle.fill", "10 Flights", flights >= 10, AppColors.gold),
            Achievement("airplane.circle.fill", "25 Flights", flights >= 25, AppColors.gold),
            Achievement("clock.fill", "100 Focus Minutes", mins >= 100, AppColors.teal),
            Achievement("clock.badge.checkmark.fill", "500 Focus Minutes", mins >= 500, AppColors.teal),
            Achievement("infinity.circle.fill", "1,000 Focus Minutes", mins >= 1000, AppColors.gold),
            Achievement("flame.fill", "3-Day Streak", streak >= 3, AppColors.danger),
            Achievement("bolt.heart.fill", "7-Day Streak", streak >= 7, AppColors.danger),
            Achievement("flame.circle.fill", "14-Day Streak", streak >= 14, AppColors.danger),
            Achievement("moon.stars.fill", "Night Owl", flewAtHour { $0 >= 22 || $0 < 4 }, AppColors.brand),
            Achievement("sunrise.fill", "Early Bird", flewAtHour { $0 >= 4 && $0 < 8 }, AppColors.gold),
            Achievement("sun.max.fill", "Golden Hour Regular", visitedCount("Golden Hour") >= 5, AppColors.gold),
            Achievement("building.2.fill", "Paris Pilot", visited("Paris Sunset"), AppColors.terracotta),
            Achievement("beach.umbrella.fill", "Fiji Pilot", visited("Fiji Lagoon"), AppColors.teal),
            Achievement("lantern", "Kyoto Lantern", visited("Kyoto Lanterns"), AppColors.gold),
            Achievement("sparkles", "Aurora Explorer", visited("Aurora Snowfield"), AppColors.success),
            Achievement("moon.fill", "Moon Visitor", visited("Moon Garden"), AppColors.brand),
            Achievement("moon.stars.circle.fill", "Deep Space Pilot", visited("Deep Space"), AppColors.teal),
            Achievement("circle.hexagongrid.circle.fill", "Focus Coin Saver", coins >= 100, AppColors.gold),
            Achievement("leaf.fill", "Cabin Decorator", ownsCabin, AppColors.success),
            Achievement("circle.grid.2x2.fill", "Skin Collector", skinsOwned >= 3, AppColors.brand),
            Achievement("person.2.fill", "Friend Flight", friendsInvited >= 1, AppColors.success),
            Achievement("crown.fill", "Premium Pilot", appModel.isPro, AppColors.gold),
            Achievement("arrow.uturn.up.circle.fill", "Comeback Pilot",
                        progress.longestStreak > progress.currentStreak && progress.currentStreak >= 1,
                        AppColors.terracotta),
        ]
    }

    private var achievementsSection: some View {
        let earned = achievements.filter { $0.earned }.count
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                SectionLabel(text: "Badges")
                Spacer()
                Text("\(earned)/\(achievements.count)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.gold)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(AppColors.gold.opacity(0.16)))
                    .overlay(Capsule().strokeBorder(AppColors.gold.opacity(0.4), lineWidth: 1))
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: AppSpacing.sm)],
                      spacing: AppSpacing.sm) {
                ForEach(achievements) { badge in
                    AchievementBadge(badge: badge)
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

/// A collectible stamp-style badge: a warm ringed disc, earned in full colour and
/// locked as a muted seal.
private struct AchievementBadge: View {
    let badge: Achievement

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(badge.earned ? badge.accent.opacity(0.18) : AppColors.textTertiary.opacity(0.08))
                    .frame(width: 52, height: 52)
                Circle()
                    .strokeBorder(badge.earned ? badge.accent.opacity(0.55) : AppColors.hairline,
                                  lineWidth: badge.earned ? 1.5 : 1)
                    .frame(width: 52, height: 52)
                Image(systemName: badge.earned ? badge.icon : "lock.fill")
                    .font(.system(size: 19, weight: .bold))
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
        .glassBackground(cornerRadius: AppSpacing.cardRadius,
                         tint: badge.earned ? badge.accent : AppColors.glassTint,
                         tintOpacity: badge.earned ? 0.14 : 0.20,
                         shadowRadius: 6, shadowY: 3)
        .overlay {
            if badge.earned {
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .strokeBorder(badge.accent.opacity(0.28), lineWidth: 1)
            }
        }
        .opacity(badge.earned ? 1 : 0.7)
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(accent)
            }
            MissionProgressBar(fraction: fraction, color: accent)
        }
    }
}

// MARK: - Mission objective card

/// A premium "flight objective" card: a tinted rounded icon badge, the title, a
/// slim progress bar, and a clear completed state (gold seal + warm ring).
private struct MissionObjectiveCard: View {
    let mission: DailyMission

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(mission.accent.accent.opacity(mission.isComplete ? 0.22 : 0.16))
                    .frame(width: 44, height: 44)
                Image(systemName: mission.isComplete ? "checkmark" : mission.systemImage)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(mission.isComplete ? AppColors.success : mission.accent.accent)
            }
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(mission.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    if mission.isComplete {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppColors.gold)
                    } else {
                        Text(mission.progressText)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
                MissionProgressBar(fraction: mission.fraction,
                                   color: mission.isComplete ? AppColors.gold : mission.accent.accent)
            }
        }
        .padding(AppSpacing.md)
        .glassBackground(cornerRadius: 18,
                         tint: mission.isComplete ? AppColors.goldFoil : AppColors.glassTint,
                         tintOpacity: mission.isComplete ? 0.14 : 0.28,
                         shadowRadius: 8, shadowY: 4)
        .overlay {
            if mission.isComplete {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(AppColors.gold.opacity(0.3), lineWidth: 1)
            }
        }
    }
}

/// A refined slim progress bar used by missions and the focus mix.
private struct MissionProgressBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(AppColors.hairline)
                Capsule()
                    .fill(
                        LinearGradient(colors: [color.opacity(0.75), color],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: max(6, geo.size.width * CGFloat(min(1, max(0, fraction)))))
            }
        }
        .frame(height: 7)
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
        selected ? "Playing on flights" : "Tap to select"
    }
}
