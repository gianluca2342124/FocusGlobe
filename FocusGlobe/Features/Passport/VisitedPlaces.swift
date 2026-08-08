import MapKit
import SwiftUI

/// A place the user has landed at, **derived** from completed journey history.
/// Nothing new is persisted — this is computed on the fly from `AppModel.history`
/// (landed sessions) plus a coordinate looked up from the travel catalog, so it
/// reuses the existing data and never touches persistence.
struct VisitedPlace: Identifiable, Hashable {
    let id: String            // == routeID ("CODE|Name")
    let name: String
    let code: String
    let coordinate: GeoCoordinate
    let visitCount: Int
    let firstVisit: Date
    let lastVisit: Date
    let totalFocusMinutes: Int
    let mood: RouteMood
    let theme: RouteTheme

    // Identity is the routeID, so Hashable/Equatable don't depend on the
    // coordinate/mood/theme types (used as a Map selection tag).
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: VisitedPlace, rhs: VisitedPlace) -> Bool { lhs.id == rhs.id }

    /// Group landed sessions by destination and resolve a coordinate for each.
    /// Places with no resolvable coordinate are dropped (so the map never shows a
    /// bogus pin). Most-recently-visited first.
    static func derive(from history: [FocusSessionRecord]) -> [VisitedPlace] {
        let landed = history.filter { $0.completed }
        guard !landed.isEmpty else { return [] }
        let nodeByID = Dictionary(TravelNetworkCatalog.allNodes.map { ($0.id, $0) },
                                  uniquingKeysWith: { a, _ in a })
        var out: [VisitedPlace] = []
        for (routeID, records) in Dictionary(grouping: landed, by: { $0.routeID }) {
            guard let sample = records.first else { continue }
            // Old records carry the display name from flight time — show today's.
            let name = FocusSky.currentDisplayName(forHistorical: sample.destinationName)
            let code = String(routeID.split(separator: "|").first ?? "")
            let coordinate = nodeByID[routeID]?.coordinate
                ?? TravelNetworkCatalog.allNodes.first { $0.name == name }?.coordinate
                ?? WorldCityCatalog.search(name).first?.city.coordinate
            guard let coordinate else { continue }
            let dates = records.map { $0.date }
            out.append(VisitedPlace(
                id: routeID, name: name,
                code: code.isEmpty ? JourneyOrigin.code(for: name) : code,
                coordinate: coordinate,
                visitCount: records.count,
                firstVisit: dates.min() ?? sample.date,
                lastVisit: dates.max() ?? sample.date,
                totalFocusMinutes: records.reduce(0) { $0 + $1.focusedMinutes },
                mood: sample.mood, theme: sample.theme))
        }
        return out.sorted { $0.lastVisit > $1.lastVisit }
    }

    var subtitle: String {
        let visits = visitCount == 1 ? "1 visit" : "\(visitCount) visits"
        return "\(visits) · last \(Self.dateFmt.string(from: lastVisit))"
    }

    static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = FocusLocalization.currentLocale
        f.setLocalizedDateFormatFromTemplate("dMMMyyyy")
        return f
    }()
}

// MARK: - Passport section

/// The "Visited places" Passport section: a summary card of landed destinations
/// that opens an elegant map with markers + a list. Fully adaptive (Dark/Light).
struct VisitedPlacesSection: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showMap = false

    private var places: [VisitedPlace] { VisitedPlace.derive(from: appModel.history) }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                SectionLabel(text: "Visited places")
                Spacer()
                if !places.isEmpty {
                    Text("\(places.count)")
                        .font(.system(size: 13, weight: .heavy, design: .default))
                        .foregroundStyle(AppColors.brand)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(AppColors.brand.opacity(0.14)))
                }
            }
            if places.isEmpty {
                emptyState
            } else {
                AppGlassCard(padding: AppSpacing.sm) {
                    VStack(spacing: 0) {
                        ForEach(places.prefix(4)) { place in
                            Button { appModel.tapFeedback(); showMap = true } label: {
                                VisitedPlaceRow(place: place)
                            }
                            .buttonStyle(SoftPressStyle(scale: 0.99))
                            if place.id != places.prefix(4).last?.id {
                                Rectangle().fill(AppColors.hairline).frame(height: 1)
                            }
                        }
                    }
                }
                Button { appModel.tapFeedback(); showMap = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "map.fill").font(.system(size: 13, weight: .semibold))
                        Text(places.count > 4 ? "View all \(places.count) on the map" : "View on the map")
                            .font(AppTypography.callout)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, AppSpacing.md).padding(.vertical, 12)
                    .glassBackground(cornerRadius: 14, tintOpacity: 0.16, shadowRadius: 6, shadowY: 3)
                }
                .buttonStyle(SoftPressStyle(scale: 0.99))
            }
        }
        .sheet(isPresented: $showMap) {
            VisitedPlacesMapView(places: places).environmentObject(appModel)
        }
    }

    private var emptyState: some View {
        AppGlassCard {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "map")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.brand)
                Text("Your journal is waiting for its first stamps. Complete an expedition to start your map.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer(minLength: 0)
            }
        }
    }
}

private struct VisitedPlaceRow: View {
    let place: VisitedPlace

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle().fill(place.theme.accent.opacity(0.16)).frame(width: 38, height: 38)
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(place.theme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(place.name)
                        .font(AppTypography.callout).foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                    Image(systemName: "mappin")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppColors.textTertiary)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(AppColors.textPrimary.opacity(0.08)))
                }
                Text(place.subtitle)
                    .font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
            }
            Spacer()
            if place.visitCount > 1 {
                Text("×\(place.visitCount)")
                    .font(.system(size: 13, weight: .heavy, design: .default))
                    .foregroundStyle(place.theme.accent)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Map detail

/// A premium map of every visited place, with a synced list underneath. Selecting
/// a row (or marker) frames that place and shows its visit info. Native MapKit,
/// no route/journey logic touched.
struct VisitedPlacesMapView: View {
    let places: [VisitedPlace]
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var camera: MapCameraPosition = .automatic
    @State private var selected: VisitedPlace?

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground().ignoresSafeArea()
            VStack(spacing: 0) {
                map
                    .frame(maxWidth: .infinity)
                    .frame(height: 340)
                    .clipShape(RoundedRectangle(cornerRadius: 0))
                list
            }
            .ignoresSafeArea(edges: .bottom)

            header
        }
        .presentationDragIndicator(.visible)
        .onAppear { if selected == nil { selected = places.first } }
    }

    private var header: some View {
        HStack {
            Text("Visited places")
                .font(AppTypography.headline).foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 6, y: 1)
            Spacer()
            // Liquid glass, not a flat black disc. Keeps the white glyph because
            // this control floats over the map.
            AppIconButton(systemImage: "xmark", size: 38, tint: .white,
                          accessibilityLabel: "Close") {
                appModel.tapFeedback(); dismiss()
            }
        }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.top, AppSpacing.sm)
    }

    private var map: some View {
        Map(position: $camera, selection: $selected) {
            ForEach(places) { place in
                Marker(place.name, systemImage: "mappin", coordinate: place.coordinate.cl)
                    .tint(place.theme.accent)
                    .tag(place)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .onChange(of: selected) { _, place in frame(place) }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(places) { place in
                    Button {
                        appModel.tapFeedback()
                        selected = place
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            VisitedPlaceRow(place: place)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.textTertiary)
                        }
                        .padding(.horizontal, AppSpacing.screen)
                        .background(selected == place ? AppColors.selectionGold.opacity(0.11) : .clear)
                    }
                    .buttonStyle(SoftPressStyle(scale: 0.995))
                    Rectangle().fill(AppColors.hairline).frame(height: 1)
                        .padding(.leading, AppSpacing.screen)
                }
            }
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.backgroundTop)
    }

    private func frame(_ place: VisitedPlace?) {
        guard let place else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            camera = .region(MKCoordinateRegion(
                center: place.coordinate.cl,
                span: MKCoordinateSpan(latitudeDelta: 6, longitudeDelta: 6)))
        }
    }
}
