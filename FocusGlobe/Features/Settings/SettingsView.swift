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
                    mapSection
                    experienceSection
                    journeyAudioSection
                    proSection
                    privacySection
                    versionFooter
                }
                .padding(AppSpacing.screen)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xxl)
            }
        }
        .focusScreenChrome()
        .onAppear { appModel.analytics.log(.settingsOpened) }
        .sheet(isPresented: $showCityPicker) { LocationPickerView() }
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
                    Button { showCityPicker = true } label: {
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

    // MARK: Journey sound

    /// Selects the looping ambience that plays during a journey, shown as a grid
    /// of colourful "sound cards". Wind is free; the rest require active Pro
    /// (locked cards open the paywall). The master Sound toggle (in Experience)
    /// stays the on/off switch — this only chooses *which* sound plays.
    private var journeyAudioSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionLabel(text: "Journey sound")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: AppSpacing.sm),
                                GridItem(.flexible(), spacing: AppSpacing.sm)],
                      spacing: AppSpacing.sm) {
                ForEach(JourneyAudioOption.all) { option in
                    JourneySoundCard(option: option,
                                     theme: audioTheme(option),
                                     unlocked: appModel.isAudioUnlocked(option),
                                     selected: appModel.selectedJourneyAudio.id == option.id) {
                        if appModel.isAudioUnlocked(option) {
                            appModel.selectJourneyAudio(option)
                        } else {
                            appModel.haptics.tap()
                            router.presentPaywall()
                        }
                    }
                }
            }
        }
    }

    /// A distinct accent per sound so each card has its own personality.
    private func audioTheme(_ option: JourneyAudioOption) -> RouteTheme {
        switch option.id {
        case "wind":        return .teal
        case "focus-music": return .indigo
        case "alpha-waves": return .lavender
        case "rain":        return .slate
        case "ocean":       return .aurora
        case "relaxing":    return .mint
        case "jazz":        return .coral
        default:            return .teal
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
                        Button { showCustomerCenter = true } label: {
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

// MARK: - Journey sound card

/// A large, colourful "sound disc" card for the journey-audio picker. Each sound
/// has its own gradient personality; the selected card shows a bright ring +
/// check, and locked premium cards show a gold crown (and open the paywall).
private struct JourneySoundCard: View {
    let option: JourneyAudioOption
    let theme: RouteTheme
    let unlocked: Bool
    let selected: Bool
    let action: () -> Void

    private var locked: Bool { option.isPremium && !unlocked }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle().fill(.white.opacity(0.18))
                        Image(systemName: option.systemImage)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 42, height: 42)
                    Spacer()
                    statusBadge
                }
                Spacer(minLength: AppSpacing.sm)
                Text(option.displayName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(statusText)
                    .font(AppTypography.micro)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(AppSpacing.md)
            .frame(height: 118, alignment: .topLeading)
            .frame(maxWidth: .infinity)
            .background(cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .strokeBorder(.white.opacity(selected ? 0.9 : 0.12), lineWidth: selected ? 2.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous))
            .shadow(color: theme.accent.opacity(selected ? 0.5 : 0.22), radius: selected ? 14 : 8, y: 5)
        }
        .buttonStyle(SoftPressStyle(scale: 0.98))
    }

    private var cardBackground: some View {
        ZStack {
            LinearGradient(colors: [theme.accent.opacity(0.9), theme.soft.opacity(0.55)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Color.black.opacity(0.16)   // keep the white text legible on any accent
        }
    }

    @ViewBuilder private var statusBadge: some View {
        if selected {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
        } else if locked {
            Image(systemName: "crown.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: 0x14181F))
                .padding(6)
                .background(Circle().fill(AppColors.gold))
        }
    }

    private var statusText: String {
        if selected { return "Playing on journeys" }
        if option.isPremium { return unlocked ? "Pro" : "Unlock with Pro" }
        return "Free"
    }
}
