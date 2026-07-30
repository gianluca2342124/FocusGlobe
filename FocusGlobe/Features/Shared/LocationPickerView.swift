import SwiftUI

/// A scalable starting-city picker: "Use my current location", a Popular
/// section, then all countries — with global search by city, country, or code.
/// Backed by `WorldCityCatalog` (WorldCities.json), so it supports hundreds of
/// real cities without Swift changes.
struct LocationPickerView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    Section { currentLocationRow }
                    Section("Popular") {
                        ForEach(OriginPresets.all, id: \.self) { o in
                            cityRow(name: o.city, country: o.country, code: o.code, origin: o)
                        }
                    }
                    ForEach(WorldCityCatalog.countries) { country in
                        Section(country.country) {
                            ForEach(country.cities) { city in
                                cityRow(name: city.name, country: country.country, code: city.code,
                                        origin: JourneyOrigin(city: city.name, country: country.country,
                                                              coordinate: city.coordinate, code: city.code))
                            }
                        }
                    }
                } else {
                    let results = WorldCityCatalog.search(query)
                    if results.isEmpty {
                        Text("No cities found").foregroundStyle(AppColors.textTertiary)
                    } else {
                        ForEach(results) { entry in
                            cityRow(name: entry.city.name, country: entry.country,
                                    code: entry.city.code, origin: entry.origin)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search city, country, or code")
            .navigationTitle("Starting city")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private var currentLocationRow: some View {
        Button {
            appModel.useCurrentLocation()
            dismiss()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "location.fill")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(AppColors.brand)
                    .frame(width: 42, height: 30)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AppColors.brand.opacity(0.14)))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Use my current location").foregroundStyle(AppColors.textPrimary)
                    Text(currentLocationSubtitle).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                }
                Spacer()
                if !appModel.canReturnToRealLocation { selectedCheck }
            }
        }
        .buttonStyle(SoftPressStyle(scale: 0.99))
    }

    private var currentLocationSubtitle: String {
        switch appModel.locationState {
        case .resolved(let o): return "\(o.city)\(o.country.isEmpty ? "" : ", \(o.country)")"
        case .resolving:       return "Locating…"
        case .denied:          return "Location access is off"
        case .unavailable, .idle: return "Detect where you are"
        }
    }

    private func cityRow(name: String, country: String, code: String, origin: JourneyOrigin) -> some View {
        Button {
            appModel.setManualOrigin(origin)
            dismiss()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.brand)
                    .frame(width: 42, height: 30)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AppColors.brand.opacity(0.12)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).foregroundStyle(AppColors.textPrimary)
                    Text(country).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                }
                Spacer()
                if isSelected(origin) { selectedCheck }
            }
        }
        .buttonStyle(SoftPressStyle(scale: 0.99))
    }

    private func isSelected(_ origin: JourneyOrigin) -> Bool {
        guard let current = appModel.currentOrigin else { return false }
        return current.city == origin.city && current.code == origin.code
    }

    private var selectedCheck: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(AppColors.success)
    }
}
