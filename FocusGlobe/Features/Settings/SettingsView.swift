import SwiftUI
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @State private var restoreMessage: String?
    #if canImport(RevenueCatUI)
    @State private var showCustomerCenter = false
    #endif
    #if DEBUG
    @State private var showResetConfirm = false
    #endif

    var body: some View {
        ZStack {
            AppBackground()
            // Vertical-only scroll. The content is clamped to the viewport width
            // and horizontal bounce is disabled, so the page can never drift
            // sideways (matches Passport and the other screens).
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    ScreenHeader(title: "Settings")

                    appearanceSection
                    experienceSection
                    FocusShieldSettingsSection(service: appModel.focusShield)
                    ultraSection
                    generalSection
                    #if DEBUG
                    debugSection
                    #endif
                    versionFooter
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.screen)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xxl)
                .settingsMaxWidth()   // centred list on iPad/Mac; full-width on iPhone
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        }
        .focusScreenChrome()
        .onAppear {
            appModel.analytics.log(.settingsOpened)
            // Calm moment to ask for notification permission (provisional, no
            // prompt) — never after a journey, never at first launch.
            appModel.requestNotificationPermissionForEngagement()
        }
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

    private var experienceSection: some View {
        SettingsCard(title: "Experience") {
            VStack(spacing: 0) {
                ToggleRow(systemImage: "speaker.wave.2.fill", title: "Sound",
                          subtitle: "Ambient audio during your flights",
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

    private var ultraSection: some View {
        SettingsCard(title: "FocusGlobe Ultra") {
            VStack(spacing: 0) {
                if appModel.isPro {
                    SettingsRow(systemImage: "checkmark.seal.fill", title: "Ultra is active",
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
                        SettingsRow(systemImage: "sparkles", title: "Unlock FocusGlobe Ultra",
                                    subtitle: "No ads · Ultra skies & flights · exclusive extras", tint: AppColors.gold,
                                    trailing: AnyView(Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(AppColors.textTertiary)))
                    }
                    .buttonStyle(SoftPressStyle())
                }
                RowDivider()
                Button {
                    appModel.tapFeedback()
                    Task { @MainActor in
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

    // General — privacy statement + the legal links (real hosted pages, same
    // `LegalLinks` used by the paywall footer).
    private var generalSection: some View {
        SettingsCard(title: "General") {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.success)
                    Text("Your focus history stays on this device. No account, no tracking.")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer(minLength: 0)
                }
                RowDivider()
                Link(destination: LegalLinks.privacy) {
                    SettingsRow(systemImage: "hand.raised.fill", title: "Privacy Policy",
                                tint: AppColors.brand, trailing: AnyView(legalChevron))
                }
                RowDivider()
                Link(destination: LegalLinks.terms) {
                    SettingsRow(systemImage: "doc.text.fill", title: "Terms of Use",
                                tint: AppColors.brand, trailing: AnyView(legalChevron))
                }
            }
        }
    }

    private var legalChevron: some View {
        Image(systemName: "arrow.up.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppColors.textTertiary)
    }

    #if DEBUG
    // Developer-only (never compiled into release builds): a full local data
    // reset so fresh-user onboarding can be re-tested without reinstalling.
    private var debugSection: some View {
        SettingsCard(title: "Developer") {
            Button {
                appModel.tapFeedback()
                showResetConfirm = true
            } label: {
                SettingsRow(systemImage: "trash.fill", title: "Reset all data",
                            subtitle: "Wipe everything and replay onboarding",
                            tint: AppColors.danger,
                            trailing: AnyView(EmptyView()))
            }
            .buttonStyle(SoftPressStyle())
        }
        .confirmationDialog("Reset all data?",
                            isPresented: $showResetConfirm,
                            titleVisibility: .visible) {
            Button("Erase everything", role: .destructive) {
                appModel.debugResetAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deletes flights, coins, streaks, unlocks and your profile on this device. The app returns to first launch.")
        }
    }
    #endif

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
