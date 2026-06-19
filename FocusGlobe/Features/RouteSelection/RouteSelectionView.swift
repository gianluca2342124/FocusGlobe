import SwiftUI

/// Route discovery, recomposed in the FocusFlight grammar: a full-screen map
/// shows the selected journey (origin → destination code tags + balloon),
/// floating category chips sit on top, and a horizontal destination strip with
/// a single white CTA sits at the bottom. Map-first, not list-first.
struct RouteSelectionView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = RouteSelectionViewModel()
    @State private var selected: Route?

    private var current: Route { selected ?? appModel.recommendedRoute }

    var body: some View {
        ZStack {
            JourneyDiscoveryMap(origin: appModel.origin, route: current)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: current.id)

            scrims

            VStack(spacing: AppSpacing.sm) {
                topBar
                categoryChips
                Spacer()
                bottomCluster
            }
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.lg)
        }
        .focusScreenChrome()
        .onAppear { if selected == nil { selected = appModel.recommendedRoute } }
        .onChange(of: viewModel.selectedCategory) { _, _ in
            if let first = viewModel.filteredRoutes.first { selected = first }
        }
    }

    private var scrims: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 160)
            Spacer()
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                .frame(height: 360)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var topBar: some View {
        HStack {
            AppIconButton(systemImage: "chevron.left", size: 44, tint: .white,
                          accessibilityLabel: "Back") { dismiss() }
            Spacer()
            Text("Choose a journey")
                .font(AppTypography.headline)
                .foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, AppSpacing.screen)
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
            withAnimation(.snappy(duration: 0.25)) { viewModel.selectedCategory = category }
        } label: {
            AppChip(title: title, systemImage: systemImage,
                    isSelected: viewModel.selectedCategory == category)
        }
        .buttonStyle(SoftPressStyle())
    }

    private var bottomCluster: some View {
        VStack(spacing: AppSpacing.md) {
            VStack(spacing: 3) {
                Text(current.name)
                    .font(AppTypography.title2)
                    .foregroundStyle(.white)
                HStack(spacing: 8) {
                    Label(current.durationLabel, systemImage: "clock")
                    Text("·")
                    Label(dynamicDistanceLabel, systemImage: "ruler")
                    Text("·")
                    Label(current.mood.displayName, systemImage: current.mood.systemImage)
                }
                .font(AppTypography.caption)
                .foregroundStyle(.white.opacity(0.85))
            }
            .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
            .padding(.horizontal, AppSpacing.screen)

            destinationStrip

            AppPrimaryButton(title: lockedSelection ? "Unlock with Pro" : "Book Journey",
                             systemImage: lockedSelection ? "lock.fill" : "paperplane.fill") {
                select(current)
            }
            .padding(.horizontal, AppSpacing.screen)
        }
    }

    private var dynamicDistanceLabel: String {
        Formatters.distance(km: GeoMath.distanceKm(from: appModel.origin.coordinate,
                                                   to: current.destination))
    }

    private var destinationStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(viewModel.filteredRoutes) { route in
                    DestinationCard(route: route,
                                    isSelected: route.id == current.id,
                                    isLocked: !appModel.isUnlocked(route)) {
                        appModel.haptics.tap()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { selected = route }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.vertical, 2)
        }
    }

    private var lockedSelection: Bool { !appModel.isUnlocked(current) }

    private func select(_ route: Route) {
        if appModel.isUnlocked(route) {
            appModel.analytics.log(.routeSelected, ["route": route.id, "source": "discovery"])
            router.openBoarding(route)
        } else {
            appModel.haptics.tap()
            router.presentPaywall()
        }
    }
}

/// A compact destination card for the horizontal strip. Selected = white card;
/// otherwise dark glass. Mirrors the FocusFlight destination cards.
private struct DestinationCard: View {
    let route: Route
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: 5) {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill").font(.system(size: 8, weight: .bold))
                        Text(route.destinationCode)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(isSelected ? Color(hex: 0x14181F) : .white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .overlay(Capsule().strokeBorder(AppColors.gold, lineWidth: 1.5))
                    Spacer()
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(isSelected ? Color(hex: 0x14181F).opacity(0.6) : .white.opacity(0.7))
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(route.shortName)
                        .font(AppTypography.callout)
                        .foregroundStyle(isSelected ? Color(hex: 0x14181F) : .white)
                        .lineLimit(1)
                    Text(route.durationLabel)
                        .font(AppTypography.caption)
                        .foregroundStyle(isSelected ? Color(hex: 0x14181F).opacity(0.65) : .white.opacity(0.7))
                }
            }
            .padding(AppSpacing.sm + 2)
            .frame(width: 138, alignment: .leading)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white)
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black.opacity(0.25)))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : AppColors.glassStroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        }
        .buttonStyle(SoftPressStyle(scale: 0.97))
    }
}
