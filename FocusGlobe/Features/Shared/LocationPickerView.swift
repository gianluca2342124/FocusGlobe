import SwiftUI

/// A calm picker for the journey's starting city. Used as the clean fallback
/// when real location is unavailable, and (in DEBUG) as an easy simulator
/// override. Choosing "Use my current location" clears any manual override.
struct LocationPickerView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: AppSpacing.sm) {
                        currentLocationRow
                        Text("OR CHOOSE A CITY")
                            .font(AppTypography.micro)
                            .tracking(0.8)
                            .foregroundStyle(AppColors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, AppSpacing.sm)
                        ForEach(OriginPresets.all, id: \.self) { preset in
                            cityRow(preset)
                        }
                    }
                    .padding(AppSpacing.screen)
                }
            }
            .navigationTitle("Starting city")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var currentLocationRow: some View {
        Button {
            appModel.useCurrentLocation()
            dismiss()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                iconBadge("location.fill", tint: AppColors.brand)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Use my current location")
                        .font(AppTypography.callout).foregroundStyle(AppColors.textPrimary)
                    Text(currentLocationSubtitle)
                        .font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                }
                Spacer()
                if !appModel.isUsingManualOrigin { selectedCheck }
            }
            .padding(AppSpacing.md)
            .glassBackground(cornerRadius: 16, tintOpacity: 0.2, shadowRadius: 8, shadowY: 4)
        }
        .buttonStyle(SoftPressStyle())
    }

    private var currentLocationSubtitle: String {
        switch appModel.locationState {
        case .resolved(let o): return "\(o.city)\(o.country.isEmpty ? "" : ", \(o.country)")"
        case .resolving:       return "Locating…"
        case .denied:          return "Location access is off — enable it in Settings"
        case .unavailable, .idle: return "Detect where you are"
        }
    }

    private func cityRow(_ preset: JourneyOrigin) -> some View {
        let isSelected = appModel.isUsingManualOrigin && appModel.currentOrigin?.city == preset.city
        return Button {
            appModel.setManualOrigin(preset)
            dismiss()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Text(preset.code)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(width: 44, height: 32)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(AppColors.brand.opacity(0.14)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.city).font(AppTypography.callout).foregroundStyle(AppColors.textPrimary)
                    Text(preset.country).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                }
                Spacer()
                if isSelected { selectedCheck }
            }
            .padding(AppSpacing.md)
            .glassBackground(cornerRadius: 16, tintOpacity: 0.16, shadowRadius: 6, shadowY: 3)
        }
        .buttonStyle(SoftPressStyle())
    }

    private var selectedCheck: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(AppColors.success)
    }

    private func iconBadge(_ systemImage: String, tint: Color) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.14)))
    }
}
