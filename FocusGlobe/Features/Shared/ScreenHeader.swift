import SwiftUI

/// A consistent custom header used across pushed screens. We hide the system
/// navigation bar everywhere for a cleaner, more premium feel and provide our
/// own back button + title.
struct ScreenHeader: View {
    let title: String
    var subtitle: String? = nil
    var showsBack: Bool = true
    var trailing: AnyView? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                if showsBack {
                    AppIconButton(systemImage: "chevron.left", size: 42,
                                  accessibilityLabel: "Back") { dismiss() }
                }
                Spacer()
                if let trailing { trailing }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(title))
                    // Modern, bold, clean page titles (SF Rounded) — the serif is
                    // reserved for the Home greeting only.
                    .font(AppTypography.hero)
                    .foregroundStyle(AppColors.textPrimary)
                if let subtitle {
                    Text(LocalizedStringKey(subtitle))
                        .font(AppTypography.subhead)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }
}

extension View {
    /// Standard screen chrome: hide the system nav bar (we draw our own header).
    func focusScreenChrome() -> some View {
        self
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
    }
}

/// A small labelled section title.
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(LocalizedStringKey(text)).textCase(.uppercase)
            .font(AppTypography.micro)
            .tracking(0.8)
            .foregroundStyle(AppColors.textTertiary)
    }
}
