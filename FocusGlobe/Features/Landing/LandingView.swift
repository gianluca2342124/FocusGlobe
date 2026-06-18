import SwiftUI

struct LandingView: View {
    let summary: LandingSummary

    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter

    @State private var earnedMiles: Int
    @State private var adState: AdState = .available
    @State private var balloonRise = false

    private enum AdState { case available, loading, doubled }

    init(summary: LandingSummary) {
        self.summary = summary
        _earnedMiles = State(initialValue: summary.baseMiles)
    }

    var body: some View {
        ZStack {
            AppBackground()
            RadialGradient(colors: [summary.route.colorTheme.soft.opacity(0.35), .clear],
                           center: .top, startRadius: 8, endRadius: 360)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    header
                    PostcardTile(postcard: summary.postcard, isNew: summary.isNewRoute)
                    statsGrid
                    if let intention = summary.intention { intentionCard(intention) }
                    if !appModel.isPro { doubleMilesButton }
                    actions
                }
                .padding(AppSpacing.screen)
                .padding(.top, AppSpacing.xl)
            }
        }
        .focusScreenChrome()
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.1)) {
                balloonRise = true
            }
        }
    }

    private var header: some View {
        VStack(spacing: AppSpacing.sm) {
            BalloonMark(size: 84, glow: summary.route.colorTheme.soft)
                .offset(y: balloonRise ? 0 : 24)
                .opacity(balloonRise ? 1 : 0)
            Text("You landed.")
                .font(AppTypography.hero)
                .foregroundStyle(AppColors.textPrimary)
            Text("\(summary.route.name) · \(summary.route.originName) → \(summary.route.destinationName)")
                .font(AppTypography.subhead)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            if summary.isNewBest {
                AppChip(title: "New personal best", systemImage: "trophy.fill",
                        isSelected: true, accent: AppColors.gold)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var statsGrid: some View {
        let columns = [GridItem(.flexible(), spacing: AppSpacing.sm),
                       GridItem(.flexible(), spacing: AppSpacing.sm)]
        return LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
            LandingStat(value: "\(summary.focusedMinutes)", unit: "min",
                        label: "Focused", systemImage: "hourglass", accent: AppColors.brand)
            LandingStat(value: Formatters.distance(km: summary.distanceKm), unit: "",
                        label: "Distance", systemImage: "ruler", accent: summary.route.colorTheme.accent)
            LandingStat(value: Formatters.miles(earnedMiles), unit: "",
                        label: adState == .doubled ? "Focus miles ×2" : "Focus miles",
                        systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                        accent: AppColors.gold)
            LandingStat(value: "\(summary.streak)", unit: summary.streak == 1 ? "day" : "days",
                        label: "Streak", systemImage: "flame.fill", accent: AppColors.danger)
        }
    }

    private func intentionCard(_ intention: String) -> some View {
        AppGlassCard {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "target")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(summary.route.colorTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("You focused on")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.textTertiary)
                    Text(intention)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textPrimary)
                }
                Spacer()
            }
        }
    }

    private var doubleMilesButton: some View {
        Button {
            Task { await watchAdToDouble() }
        } label: {
            HStack(spacing: AppSpacing.xs) {
                if adState == .loading {
                    ProgressView().tint(AppColors.textPrimary)
                    Text("Playing ad…")
                } else if adState == .doubled {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Miles doubled")
                } else {
                    Image(systemName: "play.rectangle.fill")
                    Text("Watch a short ad to double your miles")
                }
            }
            .font(AppTypography.callout)
            .foregroundStyle(adState == .doubled ? AppColors.success : AppColors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .glassBackground(cornerRadius: 18, tintOpacity: 0.25, shadowRadius: 8, shadowY: 4)
        }
        .buttonStyle(SoftPressStyle())
        .disabled(adState != .available)
    }

    private var actions: some View {
        VStack(spacing: AppSpacing.sm) {
            AppPrimaryButton(title: "Claim Miles", systemImage: "checkmark") {
                appModel.haptics.rewardClaim()
                appModel.analytics.log(.rewardClaimed, ["route": summary.route.id, "miles": earnedMiles])
                router.finishToHome()
            }
            HStack(spacing: AppSpacing.sm) {
                AppSecondaryButton(title: "Another", systemImage: "paperplane") {
                    router.startAnotherJourney()
                }
                AppSecondaryButton(title: "Passport", systemImage: "globe.europe.africa") {
                    router.finishToPassport()
                }
            }
        }
    }

    private func watchAdToDouble() async {
        adState = .loading
        let success = await appModel.watchRewardedAd()
        if success {
            appModel.grantBonusMiles(for: summary)
            appModel.haptics.rewardClaim()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                earnedMiles = summary.baseMiles * 2
                adState = .doubled
            }
        } else {
            adState = .available
        }
    }
}

private struct LandingStat: View {
    let value: String
    let unit: String
    let label: String
    let systemImage: String
    var accent: Color

    var body: some View {
        AppGlassCard(padding: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accent)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(AppTypography.title2)
                        .foregroundStyle(AppColors.textPrimary)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                Text(label)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
