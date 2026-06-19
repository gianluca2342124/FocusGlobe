import SwiftUI

struct RouteSelectionView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = RouteSelectionViewModel()

    private var featured: Route { appModel.recommendedRoute }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                ScreenHeader(title: "Choose a journey",
                             subtitle: "From a 5-minute drift to a 12-hour crossing")
                    .padding(.horizontal, AppSpacing.screen)
                    .padding(.top, AppSpacing.xs)
                    .padding(.bottom, AppSpacing.md)

                ScrollView {
                    VStack(spacing: AppSpacing.md) {
                        featuredHero
                            .padding(.horizontal, AppSpacing.screen)

                        categoryChips

                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(viewModel.filteredRoutes) { route in
                                AppRouteCard(
                                    route: route,
                                    isLocked: !appModel.isUnlocked(route),
                                    highlighted: route.id == featured.id
                                ) {
                                    select(route)
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.screen)
                    }
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
        }
        .focusScreenChrome()
    }

    // MARK: - Featured hero

    private var featuredHero: some View {
        Button {
            select(featured)
        } label: {
            ZStack(alignment: .bottom) {
                RoutePreviewMap(route: featured, progress: 0.42)
                    .frame(height: 208)

                LinearGradient(colors: [.black.opacity(0.3), .clear],
                               startPoint: .top, endPoint: .center)
                LinearGradient(colors: [.clear, .black.opacity(0.6)],
                               startPoint: .center, endPoint: .bottom)

                VStack {
                    HStack {
                        AppTagChip(title: "Featured", systemImage: "sparkles")
                        Spacer()
                        AppTagChip(title: featured.durationLabel, systemImage: "clock")
                    }
                    Spacer()
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(featured.name)
                                .font(AppTypography.title2)
                                .foregroundStyle(.white)
                            Text("\(featured.originName) → \(featured.destinationName)")
                                .font(AppTypography.caption)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color(hex: 0x14181F))
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(.white))
                            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                    }
                }
                .padding(AppSpacing.md)
            }
            .frame(height: 208)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .strokeBorder(AppColors.glassStroke, lineWidth: 1)
            )
            .shadow(color: AppColors.shadow, radius: 18, x: 0, y: 10)
        }
        .buttonStyle(SoftPressStyle(scale: 0.985))
    }

    // MARK: - Categories

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                chip(title: "All", systemImage: "square.grid.2x2", category: nil)
                ForEach(viewModel.categories) { category in
                    chip(title: category.displayName, systemImage: category.systemImage, category: category)
                }
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.vertical, 2)
        }
    }

    private func chip(title: String, systemImage: String, category: RouteCategory?) -> some View {
        Button {
            appModel.haptics.tap()
            withAnimation(.snappy(duration: 0.25)) {
                viewModel.selectedCategory = category
            }
        } label: {
            AppChip(title: title, systemImage: systemImage,
                    isSelected: viewModel.selectedCategory == category)
        }
        .buttonStyle(SoftPressStyle())
    }

    private func select(_ route: Route) {
        if appModel.isUnlocked(route) {
            appModel.analytics.log(.routeSelected, ["route": route.id, "source": "selection"])
            router.openBoarding(route)
        } else {
            appModel.haptics.tap()
            router.presentPaywall()
        }
    }
}
