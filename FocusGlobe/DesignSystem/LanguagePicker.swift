import SwiftUI

/// The one language control, used by both Settings and the welcome screen.
///
/// One component rather than two on purpose: the two entry points must agree on
/// what is offered, and — more importantly — on when NOTHING should be offered.
/// Both render nothing at all while `AppLanguage.offersLanguageChoice` is false,
/// so a pilot can never be shown a language FocusGlobe cannot actually deliver.
struct LanguagePicker: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.focusStrings) private var strings
    /// `compact` is the welcome-screen treatment (a small inline capsule row);
    /// `row` is the Settings treatment (a menu on a standard settings row).
    enum Style { case compact, row }
    var style: Style = .row

    var body: some View {
        if AppLanguage.offersLanguageChoice {
            switch style {
            case .row:     settingsRow
            case .compact: compactRow
            }
        }
    }

    // MARK: Settings

    private var settingsRow: some View {
        Menu {
            languageOptions
        } label: {
            SettingsRow(systemImage: "globe",
                        title: strings(.obWelcomeLanguage),
                        subtitle: currentLabel,
                        trailing: AnyView(
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.textTertiary)
                        ))
        }
        .accessibilityLabel(Text(strings(.obWelcomeLanguage)))
        .accessibilityValue(Text(currentLabel))
    }

    // MARK: Welcome screen

    private var compactRow: some View {
        Menu {
            languageOptions
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 13, weight: .semibold))
                Text(currentLabel)
                    .font(AppTypography.caption)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(AppColors.textSecondary)
            // Padding BEFORE the frame: growing first and insetting afterwards
            // pushes the content wider than the capsule that is meant to
            // contain it.
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(Capsule(style: .continuous).stroke(AppColors.hairline, lineWidth: 1))
            )
        }
        .accessibilityLabel(Text(strings(.obWelcomeLanguage)))
        .accessibilityValue(Text(currentLabel))
    }

    // MARK: Shared

    /// One option list for both styles, so the two entry points can never drift
    /// into offering different languages.
    private var languageOptions: some View {
        Picker(selection: languageBinding) {
            Text(AppLanguage.system.label(strings)).tag(AppLanguage.system)
            ForEach(AppLanguage.selectable) { language in
                Text(language.label(strings)).tag(language)
            }
        } label: { EmptyView() }
    }

    /// What the pilot chose, not what it resolved to. Showing "English" to
    /// someone who selected System would be a quiet lie about their setting.
    private var currentLabel: String {
        appModel.language.label(strings)
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(get: { appModel.language },
                set: { language in
                    // `setLanguage` already logs the app-wide change. The
                    // compact style is the welcome screen's control, and a
                    // language chosen BEFORE any question is a different funnel
                    // fact from one changed later in Settings.
                    if style == .compact, language != appModel.language {
                        appModel.analytics.log(.onboardingLanguageChanged,
                                               ["language": language.analyticsID])
                    }
                    appModel.setLanguage(language)
                })
    }
}
