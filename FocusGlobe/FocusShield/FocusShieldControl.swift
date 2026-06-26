import SwiftUI

/// The small Focus Shield button shown among the active-journey controls. Opens a
/// sheet to view ON/OFF state, change blocked apps live, or disable for this
/// journey. Renders nothing on unsupported platforms so the control set stays
/// clean.
struct FocusShieldControl: View {
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject var service: FocusShieldService
    var size: CGFloat = 46

    @State private var showSheet = false

    var body: some View {
        if service.isSupported {
            AppIconButton(systemImage: service.isShieldActive ? "shield.fill" : "shield.lefthalf.filled",
                          size: size,
                          tint: service.isShieldActive ? AppColors.success : AppColors.textPrimary,
                          accessibilityLabel: service.isShieldActive ? "Focus Shield active" : "Focus Shield") {
                appModel.tapFeedback()
                showSheet = true
            }
            .sheet(isPresented: $showSheet) {
                FocusShieldPickerView(service: service, context: .activeJourney)
                    .environmentObject(appModel)
            }
        }
    }
}
