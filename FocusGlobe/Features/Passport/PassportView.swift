import SwiftUI

struct PassportView: View {
    @EnvironmentObject private var appModel: AppModel

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
                    ScreenHeader(title: "Globe Passport",
                                 subtitle: "Your landings, miles and collection")
                    statsGrid
                    postcardsSection
                    routesSection
                    vehiclesSection
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

    private var vehiclesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionLabel(text: "Vehicles")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    VehicleTile(vehicle: .skyBalloon, owned: true)
                    ForEach(Vehicle.comingSoon) { vehicle in
                        VehicleTile(vehicle: vehicle, owned: false)
                    }
                }
                .padding(.vertical, 2)
            }
        }
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

private struct VehicleTile: View {
    let vehicle: Vehicle
    let owned: Bool

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            BalloonView(height: 54, showBurner: owned, showGlow: false)
                .frame(height: 56)
                .opacity(owned ? 1 : 0.4)
                .grayscale(owned ? 0 : 0.6)
                .overlay(alignment: .topTrailing) {
                    if !owned {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
            Text(vehicle.name)
                .font(AppTypography.caption)
                .foregroundStyle(owned ? AppColors.textPrimary : AppColors.textTertiary)
                .lineLimit(1)
            Text(owned ? "Owned" : "Soon")
                .font(AppTypography.micro)
                .foregroundStyle(owned ? AppColors.success : AppColors.textTertiary)
        }
        .frame(width: 104)
        .padding(.vertical, AppSpacing.sm)
        .glassBackground(cornerRadius: AppSpacing.pillRadius, tintOpacity: 0.25, shadowRadius: 8, shadowY: 4)
    }
}
