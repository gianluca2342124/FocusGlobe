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
    @State private var originPoint: CGPoint?

    private var origin: JourneyOrigin { appModel.originForJourney }

    /// The "back to the previous city" trip, if we came from somewhere.
    private var returnJourney: PlannedJourney? {
        guard let prev = appModel.previousOrigin, prev.city != origin.city else { return nil }
        return JourneyPlanner.returnJourney(from: origin, to: prev)
    }

    /// Journeys for the current origin (filtered by chip), with the return trip
    /// moved to the first position and marked, deduped against the normal list.
    private var journeys: [PlannedJourney] {
        var list = viewModel.journeys(from: origin)
        if let ret = returnJourney,
           viewModel.selectedCategory == nil || viewModel.selectedCategory == ret.category {
            list.removeAll { $0.code == ret.code || $0.name == ret.name }
            list.insert(ret, at: 0)
        }
        return list
    }

    private var current: PlannedJourney? {
        journeys.first { $0.id == selectedID } ?? journeys.first
    }

    var body: some View {
        ZStack {
            mapLayer
            if let originPoint {
                // Full-bleed container so `.position` shares the map's projection
                // coordinate space exactly (no safe-area offset).
                ZStack(alignment: .topLeading) {
                    Color.clear
                    RadarPulse().position(originPoint)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            scrims

            VStack(spacing: AppSpacing.sm) {
                topBar
                categoryChips
                Spacer()
                // No whole-cluster cap here: the destination carousel inside spans
                // the full width on iPad/Mac (more cards visible), while the title
                // and CTA are centred individually below.
                if let current {
                    bottomCluster(current)
                } else if viewModel.selectedCategory != nil {
                    emptyState.clusterMaxWidth()
                } else {
                    preparingState.clusterMaxWidth()
                }
            }
            .padding(.top, AppSpacing.xs)
            // Let the content-rich destination area extend lower into the bottom
            // space on iPad/Mac (unlike the centred pop-up modals).
            .padding(.bottom, Layout.pad(AppSpacing.lg, AppSpacing.sm))
        }
        .focusScreenChrome()
        .sheet(isPresented: $showCityPicker) { LocationPickerView().environmentObject(appModel) }
        .onAppear { viewModel.prepare(from: origin) }
        .onChange(of: origin) { _, newOrigin in viewModel.prepare(from: newOrigin) }
        .onChange(of: viewModel.selectedCategory) { _, _ in
            selectedID = journeys.first?.id
        }
    }

    /// The nearest free destinations, surfaced as a subtle on-map radar.
    private var nearbyPins: [MapPin] {
        JourneyPlanner.plan(from: origin, category: .short)
            .prefix(12)
            .map { MapPin(code: $0.code, coordinate: $0.route.destination) }
    }

    @ViewBuilder private var mapLayer: some View {
        if let current {
            JourneyDiscoveryMap(origin: origin, route: current.route, nearby: nearbyPins,
                                onOriginPoint: setOriginPoint)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: current.id)
        } else {
            JourneyBackdropMap(origin: origin, mode: .origin, showsBalloon: false,
                               onOriginPoint: setOriginPoint)
                .ignoresSafeArea()
        }
    }

    private func setOriginPoint(_ p: CGPoint?) {
        guard let p else { if originPoint != nil { originPoint = nil }; return }
        if let o = originPoint, abs(o.x - p.x) < 1.5, abs(o.y - p.y) < 1.5 { return }
        originPoint = p
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
            // The crown only opens the paywall — hide it once the user is Pro.
            if !appModel.isPro {
                CrownButton(size: 44) { appModel.tapFeedback(); router.presentPaywall() }
            } else {
                Color.clear.frame(width: 44, height: 44)   // keep the title centered
            }
        }
        .padding(.horizontal, AppSpacing.screen)
    }

    @ViewBuilder private var chipItems: some View {
        chip(title: "All", systemImage: "square.grid.2x2", category: nil)
        ForEach(viewModel.categories) { category in
            chip(title: category.displayName, systemImage: category.systemImage, category: category)
        }
    }

    private var categoryChips: some View {
        Group {
            if Layout.isPadIdiom {
                // iPad/Mac: a centred row of larger chips (they fit without scrolling).
                HStack(spacing: AppSpacing.sm) { chipItems }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, AppSpacing.screen)
                    .padding(.vertical, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.xs) { chipItems }
                        .padding(.horizontal, AppSpacing.screen)
                        .padding(.vertical, 2)
                }
            }
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
        VStack(spacing: Layout.pad(AppSpacing.md, AppSpacing.lg)) {
            VStack(spacing: 3) {
                if journey.isReturn {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.uturn.backward").font(.system(size: 10, weight: .bold))
                        Text("RETURN").font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(1.2)
                    }
                    .foregroundStyle(AppColors.brand)
                }
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
            .clusterMaxWidth()   // centred title block on iPad/Mac

            destinationStrip     // full-width carousel (uses the whole screen on iPad/Mac)

            AppPrimaryButton(title: locked(journey) ? "Unlock with Pro" : "Book Journey",
                             systemImage: locked(journey) ? "lock.fill" : "paperplane.fill") {
                select(journey)
            }
            .padding(.horizontal, AppSpacing.screen)
            .clusterMaxWidth()   // centred, tasteful CTA width on iPad/Mac
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
                appModel.tapFeedback()
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
                        appModel.tapFeedback()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { selectedID = journey.id }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.vertical, Layout.pad(2, 10))
        }
    }

    private func locked(_ journey: PlannedJourney) -> Bool { !appModel.isUnlocked(journey.route) }

    private func select(_ journey: PlannedJourney) {
        if appModel.isUnlocked(journey.route) {
            appModel.haptics.tap()
            appModel.uiSound.play(.transition)
            appModel.analytics.log(.routeSelected, ["route": journey.id, "source": "discovery"])
            router.openFocusLoadout(journey.route)
        } else {
            appModel.tapFeedback()
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
                        Image(systemName: journey.isReturn ? "arrow.uturn.backward" : "location.fill")
                            .font(.system(size: 8, weight: .bold))
                        Text(journey.code)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(isSelected ? Color(hex: 0x14181F) : .white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .overlay(Capsule().strokeBorder(journey.isReturn ? AppColors.brand : AppColors.gold, lineWidth: 1.5))
                    Spacer()
                    if isLocked {
                        PremiumBadge(compact: true)
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
            .padding(.horizontal, Layout.pad(AppSpacing.sm + 2, AppSpacing.md))
            .padding(.vertical, Layout.pad(AppSpacing.sm + 2, AppSpacing.lg))   // taller cards on iPad
            .frame(width: Layout.pad(144, 184), alignment: .leading)           // wider + easier to tap on iPad
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
                    .strokeBorder(isSelected ? Color.clear
                                  : (isLocked ? AppColors.gold.opacity(0.55) : AppColors.glassStroke),
                                  lineWidth: isLocked && !isSelected ? 1.5 : 1)
            )
            .shadow(color: (isLocked && !isSelected ? AppColors.gold.opacity(0.25) : .black.opacity(0.3)),
                    radius: 10, y: 5)
        }
        .buttonStyle(SoftPressStyle(scale: 0.97))
    }
}
