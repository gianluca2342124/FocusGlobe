import SwiftUI

/// The reusable "Focus Shield" Settings section — shows authorization / selection
/// status and opens the configurator to set the default blocked apps. Matches the
/// app's SettingsCard look (a `SectionLabel` over a glass card with rows).
struct FocusShieldSettingsSection: View {
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject var service: FocusShieldService
    @State private var showSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionLabel(text: "Focus Shield")
            VStack(spacing: 0) {
                row(icon: "shield.lefthalf.filled",
                    tint: AppColors.success,
                    title: "Block distracting apps during journeys",
                    subtitle: statusText,
                    showChevron: false)
                divider
                Button {
                    appModel.tapFeedback()
                    showSheet = true
                } label: {
                    row(icon: "square.grid.2x2",
                        tint: AppColors.brand,
                        title: "Default blocked apps",
                        subtitle: "Choose apps",
                        showChevron: true)
                }
                .buttonStyle(SoftPressStyle())
                .disabled(!service.isSupported)
            }
            .padding(AppSpacing.md)
            .glassBackground(cornerRadius: AppSpacing.cardRadius)
        }
        .sheet(isPresented: $showSheet) {
            FocusShieldPickerView(service: service, context: .settings)
                .environmentObject(appModel)
        }
    }

    private var statusText: String {
        guard service.isSupported else { return "Available on iPhone and iPad" }
        switch service.authState {
        case .approved:
            let n = service.selectionCount
            let base = n == 0 ? "No apps chosen yet" : "\(n) selected"
            return service.isEnabled ? base : "\(base) · Off"
        case .denied:
            return "Screen Time access needed"
        case .notDetermined, .unavailable:
            return "Tap to set up"
        }
    }

    private var divider: some View {
        Rectangle().fill(AppColors.hairline).frame(height: 1)
    }

    private func row(icon: String, tint: Color, title: String, subtitle: String, showChevron: Bool) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(tint.opacity(0.14)))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(AppTypography.callout).foregroundStyle(AppColors.textPrimary)
                Text(subtitle).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
            }
            Spacer(minLength: 0)
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
