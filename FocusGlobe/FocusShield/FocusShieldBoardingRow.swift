import SwiftUI

/// The Focus Shield row on the boarding pass — mirrors the ticket's "FOCUS" row
/// (a 34pt badge + label + value) and opens the configurator. Renders nothing on
/// unsupported platforms so the ticket stays uncluttered. Styled with the
/// ticket's own `ink`/`inkSoft` so it matches the dark boarding pass exactly.
struct FocusShieldBoardingRow: View {
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject var service: FocusShieldService
    let ink: Color
    let inkSoft: Color

    @State private var showSheet = false

    var body: some View {
        if service.isSupported {
            VStack(spacing: AppSpacing.sm) {
                Rectangle().fill(ink.opacity(0.08)).frame(height: 1)
                Button {
                    appModel.tapFeedback()
                    showSheet = true
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        ZStack {
                            Circle().fill(accent.opacity(0.20)).frame(width: 34, height: 34)
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(accent)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("FOCUS SHIELD")
                                .font(.system(size: 9, weight: .semibold, design: .rounded)).tracking(0.5)
                                .foregroundStyle(inkSoft)
                            Text(valueText)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(isActiveSelection ? ink : inkSoft)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(inkSoft)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(SoftPressStyle())
            }
            .sheet(isPresented: $showSheet) {
                FocusShieldPickerView(service: service, context: .settings)
                    .environmentObject(appModel)
            }
        }
    }

    private var accent: Color { isActiveSelection ? AppColors.success : inkSoft }

    /// Whether shields will actually engage for this journey.
    private var isActiveSelection: Bool {
        service.authState == .approved && service.isEnabled && service.selectionCount > 0
    }

    private var valueText: String {
        switch service.authState {
        case .approved:
            guard service.isEnabled else { return "Off" }
            let n = service.selectionCount
            return n == 0 ? "Choose apps" : "\(n) blocked"
        case .denied:
            return "Enable in Settings"
        case .notDetermined, .unavailable:
            return "Block distractions"
        }
    }
}
