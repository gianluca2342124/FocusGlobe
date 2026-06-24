import SwiftUI
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @State private var restoreMessage: String?
    @State private var showCityPicker = false
    #if canImport(RevenueCatUI)
    @State private var showCustomerCenter = false
    #endif

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    ScreenHeader(title: "Settings")

                    appearanceSection
                    locationSection
                    experienceSection
                    proSection
                    privacySection
                    versionFooter
                }
                .padding(AppSpacing.screen)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xxl)
                .settingsMaxWidth()   // centred list on iPad/Mac; full-width on iPhone
            }
        }
        .focusScreenChrome()
        .onAppear {
            appModel.analytics.log(.settingsOpened)
            // Calm moment to ask for notification permission (provisional, no
            // prompt) — never after a journey, never at first launch.
            appModel.requestNotificationPermissionForEngagement()
        }
        .sheet(isPresented: $showCityPicker) { LocationPickerView().environmentObject(appModel) }
        #if canImport(RevenueCatUI)
        .sheet(isPresented: $showCustomerCenter) { CustomerCenterView() }
        #endif
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
            appModel.tapFeedback()
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

    private var locationSection: some View {
        SettingsCard(title: "Starting location") {
            VStack(spacing: 0) {
                SettingsRow(systemImage: "location.fill",
                            title: appModel.currentOrigin?.city ?? "Not set",
                            subtitle: locationSubtitle, tint: AppColors.brand,
                            trailing: AnyView(EmptyView()))
                if appModel.canReturnToRealLocation {
                    RowDivider()
                    Button { appModel.useCurrentLocation() } label: {
                        SettingsRow(systemImage: "arrow.counterclockwise",
                                    title: "Return to my real location",
                                    subtitle: "Use GPS and clear travel progress", tint: AppColors.brand,
                                    trailing: AnyView(EmptyView()))
                    }
                    .buttonStyle(SoftPressStyle())
                }
                if appModel.allowsManualOrigin {
                    RowDivider()
                    Button { appModel.tapFeedback(); showCityPicker = true } label: {
                        SettingsRow(systemImage: "mappin.and.ellipse", title: "Choose starting city",
                                    subtitle: "Browse and search world cities", tint: AppColors.gold,
                                    trailing: AnyView(Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(AppColors.textTertiary)))
                    }
                    .buttonStyle(SoftPressStyle())
                }
            }
        }
    }

    private var locationSubtitle: String {
        if appModel.settings.virtualOrigin != nil { return "Travelling — you landed here" }
        if appModel.isUsingManualOrigin { return "Chosen manually" }
        switch appModel.locationState {
        case .resolved:           return "Detected automatically"
        case .resolving:          return "Locating…"
        case .denied:             return "Location off — pick a city"
        case .unavailable, .idle: return "Detect or choose a city"
        }
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
                ToggleRow(systemImage: "bell.badge.fill", title: "Reminders",
                          subtitle: "Streak, focus & goal nudges",
                          isOn: Binding(get: { appModel.notifications.isEnabled },
                                        set: { appModel.tapFeedback(); appModel.setNotificationsEnabled($0) }))
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
                    #if canImport(RevenueCatUI)
                    if appModel.subscriptions.isAvailable {
                        RowDivider()
                        Button { appModel.tapFeedback(); showCustomerCenter = true } label: {
                            SettingsRow(systemImage: "person.crop.circle", title: "Manage subscription",
                                        subtitle: "Billing, restore & support", tint: AppColors.brand,
                                        trailing: AnyView(Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(AppColors.textTertiary)))
                        }
                        .buttonStyle(SoftPressStyle())
                    }
                    #endif
                } else {
                    Button {
                        appModel.tapFeedback()
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
                    appModel.tapFeedback()
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
                Text("Your focus history stays on device. Location is used only to set your starting city and never leaves your device. No account, no tracking.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer(minLength: 0)
            }
        }
    }

    private var versionFooter: some View {
        Text("Version \(appVersion)")
            .font(AppTypography.micro)
            .foregroundStyle(AppColors.textTertiary)
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
            set: { appModel.tapFeedback(); appModel.settings[keyPath: keyPath] = $0 }
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
