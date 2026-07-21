import SwiftUI
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var online: FocusOnlineModel
    @State private var restoreMessage: String?
    @State private var showAliasEditor = false
    @State private var aliasDraft = ""
    @State private var aliasError: String?
    @State private var showManageOnlineData = false
    @State private var showOnlineSignIn = false
    @State private var showSignOutConfirm = false
    #if canImport(RevenueCatUI)
    @State private var showCustomerCenter = false
    #endif
    #if DEBUG
    @State private var showResetConfirm = false
    @State private var showOnlineDiagnostics = false
    #endif

    var body: some View {
        ZStack {
            AppBackground()
            // Vertical-only scroll. The content is clamped to the viewport width
            // and horizontal bounce is disabled, so the page can never drift
            // sideways (matches Passport and the other screens).
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    ScreenHeader(title: "Settings", showsBack: false)

                    appearanceSection
                    experienceSection
                    onlineSection
                    FocusShieldSettingsSection(service: appModel.focusShield)
                    ultraSection
                    privacyDataSection
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
                RowDivider()
                // The pilot's PRIVATE preferred name — personalises the Home
                // greeting only; it is never published as the Online alias.
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "person.text.rectangle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.brand)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your name")
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.textPrimary)
                        TextField("Add your name", text: Binding(
                            get: { appModel.profile.name ?? "" },
                            set: { appModel.profile.name = $0.isEmpty ? nil : String($0.prefix(24)) }))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                    }
                    // Clamp the (horizontally greedy) TextField so it can never
                    // grow the row past the viewport and induce a sideways drift.
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 6)

            }
        }
    }

    private var ultraSection: some View {
        SettingsCard(title: "FocusGlobe PRO") {
            VStack(spacing: 0) {
                if appModel.isPro {
                    SettingsRow(systemImage: "checkmark.seal.fill", title: "PRO is active",
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
                        SettingsRow(systemImage: "sparkles", title: "Unlock FocusGlobe PRO",
                                    subtitle: "No ads · all PRO Skies & flights · exclusive extras", tint: AppColors.gold,
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

    // FocusGlobe Online — anonymous presence controls backed by a private
    // FocusGlobe account (Sign in with Apple). Everything here is opt-in;
    // disabling visibility removes live presence immediately.
    private var onlineSection: some View {
        SettingsCard(title: "FocusGlobe Online") {
            VStack(spacing: 0) {
                if online.availability == .signedOut || online.availability == .sessionExpired {
                    Button {
                        appModel.tapFeedback()
                        showOnlineSignIn = true
                    } label: {
                        SettingsRow(systemImage: "person.crop.circle.badge.plus", title: "Sign in to FocusGlobe Online",
                                    subtitle: "Fly with other pilots — you appear only as an anonymous alias",
                                    tint: AppColors.brand,
                                    trailing: AnyView(Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(AppColors.textTertiary)))
                    }
                    .buttonStyle(SoftPressStyle())
                    RowDivider()
                } else if online.isSignedIn {
                    Button {
                        appModel.tapFeedback()
                        showSignOutConfirm = true
                    } label: {
                        SettingsRow(systemImage: "person.crop.circle.badge.checkmark", title: "Account",
                                    subtitle: "Signed in as \(online.profile?.displayName ?? "Sky Pilot") — tap to sign out",
                                    tint: AppColors.brand,
                                    trailing: AnyView(Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(AppColors.textTertiary)))
                    }
                    .buttonStyle(SoftPressStyle())
                    RowDivider()
                }
                ToggleRow(systemImage: "globe.americas.fill", title: "Appear in Public Skies",
                          subtitle: "Let other pilots see your balloon while you focus online.",
                          isOn: Binding(get: { appModel.profile.onlineDiscoverable ?? false },
                                        set: { appModel.tapFeedback(); online.setDiscoverable($0) }))
                RowDivider()
                ToggleRow(systemImage: "person.crop.circle.badge.plus", title: "Allow Friend Requests",
                          subtitle: "Allow pilots you meet to send you a Crew request.",
                          isOn: Binding(get: { appModel.profile.onlineAllowsFriendRequests ?? true },
                                        set: { appModel.tapFeedback(); online.setAllowsFriendRequests($0) }))
                RowDivider()
                Button {
                    appModel.tapFeedback()
                    aliasDraft = online.profile?.displayName ?? ""
                    showAliasEditor = true
                } label: {
                    SettingsRow(systemImage: "textformat", title: "Public alias",
                                subtitle: online.profile?.displayName ?? "Set after signing in",
                                tint: AppColors.brand,
                                trailing: AnyView(Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppColors.textTertiary)))
                }
                .buttonStyle(SoftPressStyle())
                .disabled(online.profile == nil)
            }
        }
        .sheet(isPresented: $showOnlineSignIn) {
            OnlineSignInView()
                .environmentObject(online)
                .environmentObject(appModel)
        }
        .confirmationDialog("Sign out of FocusGlobe Online?", isPresented: $showSignOutConfirm,
                            titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                Task { await online.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your local flights, coins and streaks stay on this device. Your online profile remains until you delete it in Manage Online Data.")
        }
        .alert("Change alias", isPresented: $showAliasEditor) {
            TextField("Alias", text: $aliasDraft)
            Button("Save") {
                Task { aliasError = await online.updateAlias(aliasDraft) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("3–20 characters. Shown to other pilots instead of your name.")
        }
        .alert("Couldn't change alias", isPresented: Binding(
            get: { aliasError != nil }, set: { if !$0 { aliasError = nil } }
        )) {
            Button("OK", role: .cancel) { aliasError = nil }
        } message: {
            Text(aliasError ?? "")
        }
    }

    // Privacy & Data — the privacy statement, the legal links (real hosted
    // pages, same `LegalLinks` used by the paywall footer), and the route to
    // manage/delete FocusGlobe Online data.
    private var privacyDataSection: some View {
        SettingsCard(title: "Privacy & Data") {
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
                Button {
                    appModel.tapFeedback()
                    showManageOnlineData = true
                } label: {
                    SettingsRow(systemImage: "icloud.and.arrow.down", title: "Manage Online Data",
                                subtitle: "Review or delete your FocusGlobe Online data",
                                tint: AppColors.brand,
                                trailing: AnyView(Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppColors.textTertiary)))
                }
                .buttonStyle(SoftPressStyle())
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
        .sheet(isPresented: $showManageOnlineData) {
            ManageOnlineDataView()
                .environmentObject(appModel)
                .environmentObject(online)
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
            VStack(spacing: 0) {
                Button {
                    appModel.tapFeedback()
                    showOnlineDiagnostics = true
                } label: {
                    SettingsRow(systemImage: "waveform.badge.magnifyingglass", title: "Online diagnostics",
                                subtitle: "Supabase status, presence & rooms",
                                tint: AppColors.brand,
                                trailing: AnyView(Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppColors.textTertiary)))
                }
                .buttonStyle(SoftPressStyle())
                RowDivider()
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
        }
        .sheet(isPresented: $showOnlineDiagnostics) {
            OnlineDiagnosticsView()
                .environmentObject(appModel)
                .environmentObject(online)
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

// MARK: - Manage Online Data

/// The pushed detail behind Settings → Privacy & Data → Manage Online Data.
/// Lists exactly what is deleted from FocusGlobe Online, then offers a
/// destructive confirmation. Local streak, Store ownership, purchases and
/// offline history are untouched.
private struct ManageOnlineDataView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var online: FocusOnlineModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirming = false
    @State private var working = false

    private let deletes = [
        ("person.crop.circle", "Your public profile & anonymous alias"),
        ("dot.radiowaves.left.and.right", "Your current live presence"),
        ("person.2", "Crew requests, responses & connections"),
        ("airplane", "Rooms you own or have joined"),
        ("internaldrive", "Cached online data on this device"),
    ]

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    ScreenHeader(title: "Manage Online Data",
                                 subtitle: "Delete your FocusGlobe Online data", showsBack: false)

                    AppGlassCard(padding: AppSpacing.md) {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Deleting removes the following from FocusGlobe Online:")
                                .font(AppTypography.callout)
                                .foregroundStyle(AppColors.textSecondary)
                            ForEach(deletes, id: \.1) { item in
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: item.0)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(AppColors.danger)
                                        .frame(width: 26)
                                    Text(item.1)
                                        .font(AppTypography.callout)
                                        .foregroundStyle(AppColors.textPrimary)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                    }

                    Text("Your local flights, coins, streak, Store items and purchases stay on this device.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)

                    Button(role: .destructive) {
                        appModel.tapFeedback()
                        confirming = true
                    } label: {
                        HStack(spacing: 8) {
                            if working { ProgressView().tint(.white) }
                            Text(working ? "Deleting…" : "Delete Online Data")
                                .font(AppTypography.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: AppSpacing.pillRadius, style: .continuous)
                            .fill(AppColors.danger))
                    }
                    .buttonStyle(SoftPressStyle())
                    .disabled(working)

                    Button("Cancel") { dismiss() }
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
                .padding(AppSpacing.screen)
                .padding(.bottom, AppSpacing.xxl)
                .settingsMaxWidth()
            }
        }
        .confirmationDialog("Delete Online Data?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Delete online data", role: .destructive) {
                working = true
                Task {
                    await online.deleteOnlineData()
                    working = false
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone. Your local flights, coins and streak are kept.")
        }
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
