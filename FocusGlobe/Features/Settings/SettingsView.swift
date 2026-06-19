import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @State private var showResetConfirm = false
    @State private var restoreMessage: String?

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    ScreenHeader(title: "Settings")

                    appearanceSection
                    mapSection
                    experienceSection
                    proSection
                    privacySection
                    #if DEBUG
                    developerSection
                    #endif
                    versionFooter
                }
                .padding(AppSpacing.screen)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xxl)
            }
        }
        .focusScreenChrome()
        .onAppear { appModel.analytics.log(.settingsOpened) }
        .confirmationDialog("Reset all local data?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset everything", role: .destructive) { appModel.resetAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears your history, miles, streak and postcards on this device.")
        }
    }

    // MARK: Sections

    private var appearanceSection: some View {
        SettingsCard(title: "Appearance") {
            HStack(spacing: 6) {
                ForEach(AppearanceMode.allCases) { mode in
                    appearanceOption(mode)
                }
            }
        }
    }

    private func appearanceOption(_ mode: AppearanceMode) -> some View {
        let selected = appModel.settings.appearance == mode
        return Button {
            appModel.haptics.tap()
            appModel.settings.appearance = mode
        } label: {
            VStack(spacing: 5) {
                Image(systemName: mode.systemImage).font(.system(size: 16, weight: .semibold))
                Text(mode.displayName).font(AppTypography.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .foregroundStyle(selected ? Color.white : AppColors.textSecondary)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? AnyShapeStyle(AppGradients.brandButton) : AnyShapeStyle(Color.clear))
            )
        }
        .buttonStyle(SoftPressStyle())
    }

    private var mapSection: some View {
        SettingsCard(title: "Map style") {
            HStack(spacing: 6) {
                ForEach(MapDisplayStyle.allCases) { mapStyleOption($0) }
            }
        }
    }

    private func mapStyleOption(_ style: MapDisplayStyle) -> some View {
        let selected = appModel.settings.mapStyle == style
        return Button {
            appModel.haptics.tap()
            appModel.settings.mapStyle = style
        } label: {
            VStack(spacing: 5) {
                Image(systemName: style.systemImage).font(.system(size: 15, weight: .semibold))
                Text(style.displayName)
                    .font(AppTypography.micro)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .foregroundStyle(selected ? Color.white : AppColors.textSecondary)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? AnyShapeStyle(AppGradients.brandButton) : AnyShapeStyle(Color.clear))
            )
        }
        .buttonStyle(SoftPressStyle())
    }

    private var experienceSection: some View {
        SettingsCard(title: "Experience") {
            VStack(spacing: 0) {
                ToggleRow(systemImage: "speaker.wave.2.fill", title: "Sound",
                          subtitle: "Ambient audio during journeys",
                          isOn: boolBinding(\.soundEnabled))
                RowDivider()
                ToggleRow(systemImage: "iphone.radiowaves.left.and.right", title: "Haptics",
                          subtitle: "Gentle feedback on take-off & landing",
                          isOn: boolBinding(\.hapticsEnabled))
                RowDivider()
                ToggleRow(systemImage: "eye.slash", title: "Start in Pure Mode",
                          subtitle: "Hide controls when a journey begins",
                          isOn: boolBinding(\.pureModeDefault))
            }
        }
    }

    private var proSection: some View {
        SettingsCard(title: "FocusGlobe Pro") {
            VStack(spacing: 0) {
                if appModel.isPro {
                    SettingsRow(systemImage: "checkmark.seal.fill", title: "Pro is active",
                                subtitle: "Thank you for your support", tint: AppColors.success,
                                trailing: AnyView(EmptyView()))
                } else {
                    Button {
                        router.presentPaywall()
                    } label: {
                        SettingsRow(systemImage: "sparkles", title: "Remove ads & go Pro",
                                    subtitle: "Premium routes, skins & more", tint: AppColors.gold,
                                    trailing: AnyView(Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(AppColors.textTertiary)))
                    }
                    .buttonStyle(SoftPressStyle())
                }
                RowDivider()
                Button {
                    Task {
                        let ok = await appModel.restorePurchases()
                        restoreMessage = ok ? "Purchases restored." : "Nothing to restore."
                    }
                } label: {
                    SettingsRow(systemImage: "arrow.clockwise", title: "Restore Purchases",
                                subtitle: restoreMessage, tint: AppColors.brand,
                                trailing: AnyView(EmptyView()))
                }
                .buttonStyle(SoftPressStyle())
            }
        }
    }

    private var privacySection: some View {
        SettingsCard(title: "Privacy") {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.success)
                Text("Your focus history stays on device. No account, no location, no tracking.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer(minLength: 0)
            }
        }
    }

    #if DEBUG
    private var developerSection: some View {
        SettingsCard(title: "Developer") {
            Button {
                showResetConfirm = true
            } label: {
                SettingsRow(systemImage: "trash", title: "Reset local data",
                            subtitle: "Debug only", tint: AppColors.danger,
                            trailing: AnyView(EmptyView()))
            }
            .buttonStyle(SoftPressStyle())
        }
    }
    #endif

    private var versionFooter: some View {
        VStack(spacing: 4) {
            AppLogo(size: 24)
            Text("Version \(appVersion)")
                .font(AppTypography.micro)
                .foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.sm)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private func boolBinding(_ keyPath: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { appModel.settings[keyPath: keyPath] },
            set: { appModel.settings[keyPath: keyPath] = $0 }
        )
    }
}

// MARK: - Building blocks

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionLabel(text: title)
            AppGlassCard(padding: AppSpacing.md) { content() }
        }
    }
}

private struct ToggleRow: View {
    let systemImage: String
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: AppSpacing.sm) {
                iconBadge(systemImage, tint: AppColors.brand)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(AppTypography.callout).foregroundStyle(AppColors.textPrimary)
                    if let subtitle {
                        Text(subtitle).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                    }
                }
            }
        }
        .tint(AppColors.brand)
        .padding(.vertical, 6)
    }
}

private struct SettingsRow: View {
    let systemImage: String
    let title: String
    var subtitle: String?
    var tint: Color = AppColors.brand
    let trailing: AnyView

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            iconBadge(systemImage, tint: tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(AppTypography.callout).foregroundStyle(AppColors.textPrimary)
                if let subtitle {
                    Text(subtitle).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                }
            }
            Spacer()
            trailing
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

private struct RowDivider: View {
    var body: some View {
        Rectangle().fill(AppColors.hairline).frame(height: 1)
    }
}

private func iconBadge(_ systemImage: String, tint: Color) -> some View {
    Image(systemName: systemImage)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(tint)
        .frame(width: 32, height: 32)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(tint.opacity(0.14)))
}
