import SwiftUI

struct RouteSelectionView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = RouteSelectionViewModel()

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: AppSpacing.md) {
                ScreenHeader(title: "Choose a route",
                             subtitle: "From 5 minutes to 12 hours")
                    .padding(.horizontal, AppSpacing.screen)
                    .padding(.top, AppSpacing.xs)

                categoryChips

                ScrollView {
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(viewModel.filteredRoutes) { route in
                            AppRouteCard(
                                route: route,
                                isLocked: !appModel.isUnlocked(route),
                                highlighted: route.id == appModel.recommendedRoute.id
                            ) {
                                select(route)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.screen)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
        }
        .focusScreenChrome()
    }

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
