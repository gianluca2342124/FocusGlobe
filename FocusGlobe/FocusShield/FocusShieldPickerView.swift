// PARKED for v1.0 distribution — compiles only with the `FOCUS_SHIELD_ENABLED`
// Swift flag (intentionally unset). See FOCUS_SHIELD_PARKED.md.
#if FOCUS_SHIELD_ENABLED
import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Where a Focus Shield configurator sheet is being shown from — tunes which
/// extra controls appear (e.g. "Disable for this flight" only mid-flight).
enum FocusShieldContext {
    case settings
    case activeJourney
}

#if canImport(FamilyControls)

/// The premium Focus Shield configuration sheet — wraps Apple's
/// `FamilyActivityPicker` in FocusGlobe's dark-glass identity, handles the
/// authorization flow, shows the selected count, and saves the selection.
struct FocusShieldPickerView: View {
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject var service: FocusShieldService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var context: FocusShieldContext = .settings

    @State private var selection = FamilyActivitySelection()
    @State private var showPicker = false
    @State private var requesting = false

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: AppSpacing.md) {
                        if !service.isSupported {
                            unavailableCard
                        } else {
                            switch service.authState {
                            case .approved:                 approvedContent
                            case .denied:                   deniedCard
                            case .notDetermined, .unavailable: permissionCard
                            }
                        }
                        privacyNote
                    }
                    .padding(AppSpacing.screen)
                    .settingsMaxWidth()
                }
            }
        }
        .onAppear {
            service.refreshAuthorization()
            selection = service.currentSelection()
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .onChange(of: showPicker) { _, shown in
            // Save when the system picker dismisses (selection committed).
            if !shown { service.updateSelection(selection) }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Focus Shield")
                    .font(AppTypography.title).foregroundStyle(AppColors.textPrimary)
                Text(context == .activeJourney ? "Block apps until landing" : "Block distractions during flights")
                    .font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(AppColors.glassTint.opacity(0.5)))
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.top, AppSpacing.lg)
        .padding(.bottom, AppSpacing.sm)
    }

    // MARK: Approved — the configurator

    private var approvedContent: some View {
        VStack(spacing: AppSpacing.md) {
            if context == .settings { enableToggleCard }
            chooseAppsCard
            if context == .activeJourney { activeJourneyCard }
        }
    }

    private var enableToggleCard: some View {
        card {
            Toggle(isOn: Binding(get: { service.isEnabled },
                                 set: { service.setEnabled($0); appModel.tapFeedback() })) {
                rowLabel(icon: "shield.lefthalf.filled",
                         tint: AppColors.success,
                         title: "Block apps during flights",
                         subtitle: "Blocked apps stay locked until you land.")
            }
            .tint(AppColors.success)
        }
    }

    private var chooseAppsCard: some View {
        card {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                rowLabel(icon: "apps.iphone",
                         tint: AppColors.selectionGold,
                         title: "Blocked apps",
                         subtitle: countLabel(service.selectionCount))
                AppPrimaryButton(title: service.selectionCount == 0 ? "Choose apps" : "Change blocked apps",
                                 systemImage: "square.grid.2x2") {
                    appModel.tapFeedback()
                    FocusShieldLog.event("focus_shield_picker_opened")
                    showPicker = true
                }
            }
        }
    }

    private var activeJourneyCard: some View {
        card {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                rowLabel(icon: service.isShieldActive ? "shield.fill" : "shield.slash",
                         tint: service.isShieldActive ? AppColors.success : AppColors.textTertiary,
                         title: service.isShieldActive ? "Shield is active" : "Shield is off for this flight",
                         subtitle: service.isShieldActive
                            ? "Changes apply immediately."
                            : "Apps aren't blocked right now.")
                if service.isShieldActive {
                    AppSecondaryButton(title: "Disable for this flight", systemImage: "shield.slash") {
                        appModel.tapFeedback()
                        service.disableForActiveJourney()
                    }
                }
            }
        }
    }

    // MARK: Permission states

    private var permissionCard: some View {
        card {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                shieldGlyph
                Text("Block distractions during flights")
                    .font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                Text("Focus Shield needs Screen Time permission to block distracting apps during your FocusGlobe flights.")
                    .font(AppTypography.callout).foregroundStyle(AppColors.textSecondary)
                AppPrimaryButton(title: "Enable Focus Shield", systemImage: "shield.fill", isLoading: requesting) {
                    requesting = true
                    Task { @MainActor in
                        await service.requestAuthorization()
                        requesting = false
                        if service.authState == .approved { selection = service.currentSelection() }
                    }
                }
                Button("Not now") { dismiss() }
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var deniedCard: some View {
        card {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                shieldGlyph
                Text("Screen Time access is off")
                    .font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                Text("To block apps during flights, enable Screen Time access for FocusGlobe in Settings.")
                    .font(AppTypography.callout).foregroundStyle(AppColors.textSecondary)
                #if canImport(UIKit)
                AppPrimaryButton(title: "Open Settings", systemImage: "gear") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                #endif
                Button("Not now") { dismiss() }
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var unavailableCard: some View {
        card {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                shieldGlyph
                Text("Available on iPhone and iPad")
                    .font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                Text("Focus Shield uses Screen Time, which isn't available on this device.")
                    .font(AppTypography.callout).foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    // MARK: Pieces

    private var shieldGlyph: some View {
        Image(systemName: "shield.lefthalf.filled")
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(AppColors.success)
            .frame(width: 56, height: 56)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppColors.success.opacity(0.14)))
    }

    private var privacyNote: some View {
        Text("FocusGlobe never sees which apps you choose — your selection stays private on this device.")
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.xs)
    }

    private func rowLabel(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.14)))
            VStack(alignment: .leading, spacing: 1) {
                Text(LocalizedStringKey(title)).font(AppTypography.callout).foregroundStyle(AppColors.textPrimary)
                Text(LocalizedStringKey(subtitle)).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
            }
            Spacer(minLength: 0)
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassBackground(cornerRadius: AppSpacing.cardRadius)
    }

    /// Already resolved, unlike the other `rowLabel` arguments.
    ///
    /// The default branch used to be `"\(n) selected"` — an interpolated
    /// String, so neither a catalog key nor translatable, and a Spanish pilot
    /// blocking three apps read "3 selected". One plural covers every count and
    /// agrees with "apps" in the languages that inflect.
    private func countLabel(_ n: Int) -> String {
        n == 0 ? FocusLocalization.string("None selected yet")
               : FocusLocalization.string("%lld selected", n)
    }
}

#else

/// Fallback when FamilyControls isn't available in the SDK at all.
struct FocusShieldPickerView: View {
    var service: FocusShieldService
    var context: FocusShieldContext = .settings
    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            Text("Focus Shield is available on iPhone and iPad.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(AppSpacing.xl)
        }
    }
}

#endif

#endif
