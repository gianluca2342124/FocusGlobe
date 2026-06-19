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
                    heroMapCard
                    AppPrimaryButton(title: "Start Journey", systemImage: "paperplane.fill") {
                        appModel.haptics.tap()
                        router.openRouteSelection()
                    }
                    statsStrip
                    tagline
                }
                .padding(AppSpacing.screen)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.lg)
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
        .padding(.top, 2)
    }

    /// The map-first centerpiece: a live preview of the recommended route.
    private var heroMapCard: some View {
        Button {
            appModel.analytics.log(.routeSelected, ["route": recommended.id, "source": "home_hero"])
            router.openBoarding(recommended)
        } label: {
            ZStack(alignment: .bottom) {
                RoutePreviewMap(route: recommended)
                    .frame(height: 312)

                // Legibility scrims.
                LinearGradient(colors: [.black.opacity(0.35), .clear],
                               startPoint: .top, endPoint: .center)
                LinearGradient(colors: [.clear, .black.opacity(0.55)],
                               startPoint: .center, endPoint: .bottom)

                VStack {
                    HStack(alignment: .top) {
                        AppTagChip(title: "Recommended", systemImage: "sparkles")
                        Spacer()
                        AppTagChip(title: recommended.durationLabel, systemImage: "clock")
                    }
                    Spacer()
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(recommended.name)
                                .font(AppTypography.title2)
                                .foregroundStyle(.white)
                            HStack(spacing: 6) {
                                Text(recommended.originName)
                                Image(systemName: "arrow.right").font(.system(size: 10, weight: .bold))
                                Text(recommended.destinationName)
                            }
                            .font(AppTypography.subhead)
                            .foregroundStyle(.white.opacity(0.85))
                        }
                        Spacer()
                        ZStack {
                            Circle().fill(AppGradients.brandButton)
                                .frame(width: 46, height: 46)
                                .shadow(color: AppColors.brand.opacity(0.5), radius: 10, y: 5)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(AppSpacing.md)
            }
            .frame(height: 312)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .strokeBorder(AppColors.glassStroke, lineWidth: 1)
            )
            .shadow(color: AppColors.shadow, radius: 22, x: 0, y: 12)
        }
        .buttonStyle(SoftPressStyle(scale: 0.985))
    }

    private var statsStrip: some View {
        AppGlassCard(padding: AppSpacing.md) {
            HStack(spacing: 0) {
                statItem(systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                         value: Formatters.miles(appModel.progress.totalFocusMiles),
                         label: "Focus miles", accent: AppColors.brand)
                Rectangle().fill(AppColors.hairline).frame(width: 1, height: 34)
                statItem(systemImage: "flame.fill",
                         value: "\(appModel.progress.currentStreak)",
                         label: "Day streak", accent: AppColors.gold)
            }
        }
    }

    private func statItem(systemImage: String, value: String, label: String, accent: Color) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(AppTypography.title2).foregroundStyle(AppColors.textPrimary)
                Text(label).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacing.xs)
    }

    private var tagline: some View {
        Text(viewModel.tagline)
            .font(AppTypography.subhead)
            .foregroundStyle(AppColors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)
    }
}
