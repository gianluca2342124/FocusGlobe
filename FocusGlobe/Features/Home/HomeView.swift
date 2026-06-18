import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = HomeViewModel()

    private var recommended: Route { appModel.recommendedRoute }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    topBar
                    hero
                    AppPrimaryButton(title: "Start Journey", systemImage: "paperplane.fill") {
                        appModel.haptics.tap()
                        router.openRouteSelection()
                    }
                    recommendedSection
                    statsRow
                    AppSecondaryButton(title: "Browse all routes", systemImage: "map") {
                        router.openRouteSelection()
                    }
                    tagline
                }
                .padding(AppSpacing.screen)
                .padding(.top, AppSpacing.xs)
            }
        }
        .focusScreenChrome()
    }

    private var topBar: some View {
        HStack {
            AppLogo(size: 30)
            Spacer()
            HStack(spacing: AppSpacing.xs) {
                AppIconButton(systemImage: "globe.europe.africa", size: 42,
                              accessibilityLabel: "Passport") { router.openPassport() }
                AppIconButton(systemImage: "clock.arrow.circlepath", size: 42,
                              accessibilityLabel: "History") { router.openHistory() }
                AppIconButton(systemImage: "gearshape", size: 42,
                              accessibilityLabel: "Settings") { router.openSettings() }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.greeting)
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
            Text(viewModel.headline)
                .font(AppTypography.hero)
                .foregroundStyle(AppColors.textPrimary)
            Text(viewModel.subtitle)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, AppSpacing.xs)
    }

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                SectionLabel(text: "Recommended for you")
                Spacer()
            }
            AppRouteCard(route: recommended, isLocked: false, highlighted: true) {
                appModel.analytics.log(.routeSelected, ["route": recommended.id, "source": "home"])
                router.openBoarding(recommended)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: AppSpacing.sm) {
            StatTile(systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                     value: Formatters.miles(appModel.progress.totalFocusMiles),
                     label: "Focus miles",
                     accent: AppColors.brand)
            StatTile(systemImage: "flame.fill",
                     value: "\(appModel.progress.currentStreak)",
                     label: "Day streak",
                     accent: AppColors.gold)
        }
    }

    private var tagline: some View {
        Text(viewModel.tagline)
            .font(AppTypography.subhead)
            .foregroundStyle(AppColors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, AppSpacing.xs)
    }
}

/// A compact stat tile for the Home screen.
struct StatTile: View {
    let systemImage: String
    let value: String
    let label: String
    var accent: Color = AppColors.brand

    var body: some View {
        AppGlassCard(padding: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
                Text(value)
                    .font(AppTypography.title2)
                    .foregroundStyle(AppColors.textPrimary)
                Text(label)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
