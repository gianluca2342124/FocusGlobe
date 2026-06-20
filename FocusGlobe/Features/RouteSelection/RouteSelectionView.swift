import SwiftUI

/// Destination selection, FocusFlight-style: a full-screen real Google map shows
/// the journey from the current origin to the selected real destination (origin
/// halo + route + amber destination tag, no balloon yet). Floating category
/// chips on top; a horizontal destination strip + white CTA at the bottom. All
/// destinations are real cities generated from the origin coordinate.
struct RouteSelectionView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = RouteSelectionViewModel()
    @State private var selectedID: String?
    @State private var showCityPicker = false

    private var origin: JourneyOrigin { appModel.originForJourney }
    private var journeys: [PlannedJourney] { viewModel.journeys(from: origin) }
    private var current: PlannedJourney? {
        journeys.first { $0.id == selectedID } ?? journeys.first
    }

    var body: some View {
        ZStack {
            mapLayer
            scrims

            VStack(spacing: AppSpacing.sm) {
                topBar
                categoryChips
                Spacer()
                if let current {
                    bottomCluster(current)
                } else if viewModel.selectedCategory != nil {
                    emptyState
                } else {
                    preparingState
                }
            }
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.lg)
        }
        .focusScreenChrome()
        .sheet(isPresented: $showCityPicker) { LocationPickerView() }
        .onAppear { viewModel.prepare(from: origin) }
        .onChange(of: origin) { _, newOrigin in viewModel.prepare(from: newOrigin) }
        .onChange(of: viewModel.selectedCategory) { _, _ in
            selectedID = journeys.first?.id
        }
    }

    @ViewBuilder private var mapLayer: some View {
        if let current {
            JourneyDiscoveryMap(origin: origin, route: current.route)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: current.id)
        } else {
            JourneyBackdropMap(origin: origin, mode: .origin, showsBalloon: false)
                .ignoresSafeArea()
        }
    }

    private var scrims: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 160)
            Spacer()
            LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .top, endPoint: .bottom)
                .frame(height: 380)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var topBar: some View {
        HStack {
            AppIconButton(systemImage: "chevron.left", size: 44, tint: .white,
                          accessibilityLabel: "Back") { dismiss() }
            Spacer()
            VStack(spacing: 1) {
                Text("Choose a journey").font(AppTypography.headline).foregroundStyle(.white)
                Text("from \(origin.city)").font(AppTypography.caption).foregroundStyle(.white.opacity(0.7))
            }
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

    private func bottomCluster(_ journey: PlannedJourney) -> some View {
        VStack(spacing: AppSpacing.md) {
            VStack(spacing: 3) {
                Text(journey.name)
                    .font(AppTypography.title2).foregroundStyle(.white)
                Text(journey.subtitle)
                    .font(AppTypography.caption).foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Label(Formatters.durationLabel(minutes: journey.durationMinutes), systemImage: "clock")
                    Text("·")
                    Label(Formatters.distance(km: journey.distanceKm), systemImage: "ruler")
                    Text("·")
                    Label(journey.mood.displayName, systemImage: journey.mood.systemImage)
                }
                .font(AppTypography.caption)
                .foregroundStyle(.white.opacity(0.85))
            }
            .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
            .padding(.horizontal, AppSpacing.screen)

            destinationStrip

            AppPrimaryButton(title: locked(journey) ? "Unlock with Pro" : "Book Journey",
                             systemImage: locked(journey) ? "lock.fill" : "paperplane.fill") {
                select(journey)
            }
            .padding(.horizontal, AppSpacing.screen)
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.xs) {
            Text("No destinations in this range")
                .font(AppTypography.headline).foregroundStyle(.white)
            Text("Try another category — nearby places appear under Short.")
                .font(AppTypography.caption).foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.bottom, AppSpacing.md)
    }

    private var preparingState: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "map")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text("Journeys are being prepared for your area")
                .font(AppTypography.headline).foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("Choose a starting city to begin exploring.")
                .font(AppTypography.caption).foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            AppPrimaryButton(title: "Choose starting city", systemImage: "mappin.and.ellipse") {
                appModel.haptics.tap()
                showCityPicker = true
            }
            .padding(.top, AppSpacing.xs)
        }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.bottom, AppSpacing.md)
    }

    private var destinationStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(journeys) { journey in
                    DestinationCard(journey: journey,
                                    isSelected: journey.id == current?.id,
                                    isLocked: locked(journey)) {
                        appModel.haptics.tap()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { selectedID = journey.id }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.vertical, 2)
        }
    }

    private func locked(_ journey: PlannedJourney) -> Bool { !appModel.isUnlocked(journey.route) }

    private func select(_ journey: PlannedJourney) {
        if appModel.isUnlocked(journey.route) {
            appModel.analytics.log(.routeSelected, ["route": journey.id, "source": "discovery"])
            router.openBoarding(journey.route)
        } else {
            appModel.haptics.tap()
            router.presentPaywall()
        }
    }
}

/// A compact destination card for the horizontal strip. Selected = white card;
/// otherwise dark glass. Mirrors the FocusFlight destination cards.
private struct DestinationCard: View {
    let journey: PlannedJourney
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: 5) {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill").font(.system(size: 8, weight: .bold))
                        Text(journey.code)
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
                    Text(journey.name)
                        .font(AppTypography.callout)
                        .foregroundStyle(isSelected ? Color(hex: 0x14181F) : .white)
                        .lineLimit(1)
                    Text(Formatters.durationLabel(minutes: journey.durationMinutes))
                        .font(AppTypography.caption)
                        .foregroundStyle(isSelected ? Color(hex: 0x14181F).opacity(0.65) : .white.opacity(0.7))
                }
            }
            .padding(AppSpacing.sm + 2)
            .frame(width: 144, alignment: .leading)
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
