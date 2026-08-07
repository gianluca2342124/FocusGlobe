import SwiftUI
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var online: FocusOnlineModel
    @State private var restoreMessage: String?
    /// The Name field's live text. Committed on submit / focus loss, not per
    /// keystroke — see `commitName()`.
    @State private var nameDraft = ""
    @State private var nameError: String?
    @FocusState private var nameFieldFocused: Bool
    @State private var showManageOnlineData = false
    /// Account section state (free, always available — never Debug-only).
    @State private var showAccountSignOutConfirm = false
    @State private var accountError: String?
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
                    ScreenHeader(title: "Settings", showsBack: false)

                    // The profile block leads: one avatar, one Name. That Name
                    // is the canonical one — it is also the alias Friends and
                    // Online publish, which is why the old `Your name` row in
                    // Experience and the old `Public alias` row in Friends are
                    // both gone. One field, one truth.
                    profileBlock

                    // Account leads. It is the first thing anyone opens Settings
                    // for — signing in, or checking that they are — and it took
                    // the slot the Appearance selector used to occupy.
                    accountSection
                    experienceSection
                    // FocusGlobe Online / social controls now live inside the
                    // Friends page ("Online & Friends Settings"), behind the
                    // Friends PRO lock — they are no longer duplicated here.
                    FocusShieldSettingsSection(service: appModel.focusShield)
                    ultraSection
                    privacyDataSection
                    #if DEBUG
                    debugSection
                    #endif
                    versionFooter
                }
                // Padding INSIDE the stretch, not outside it. The other order —
                // `.frame(maxWidth: .infinity)` then `.padding(...)` — grows the
                // column to the full proposed width and then adds insets around
                // that, so the content ends up `proposal + 2 × screen` wide. A
                // vertical UIScrollView still pans horizontally when its content
                // is wider than its bounds, which is exactly the sideways drag
                // that was reported: not a stray gesture, an overflowing column.
                .padding(AppSpacing.screen)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xxl)
                .frame(maxWidth: .infinity, alignment: .leading)
                .settingsMaxWidth()   // centred list on iPad/Mac; full-width on iPhone
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            // Belt and braces: even if a future row proposes something too wide,
            // it is clipped rather than turned into a pannable content size.
            .clipped()
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

    // The Appearance selector is gone: FocusGlobe is a dark product — the Skies,
    // the cabin and the whole night-flight identity are authored for it — and a
    // Light option only ever produced a second-class version of the app. Dark is
    // now forced at the app root (see `FocusGlobeApp` / `RootView`).
    //
    // `AppSettings.appearance` is deliberately kept so previously stored values
    // still decode; nothing reads it any more.

    /// Avatar + Name. Nothing else — no photo picker, no camera, no account
    /// management. The avatar is a symbol on purpose: it identifies the block
    /// without promising an editing affordance that does not exist.
    ///
    /// The field commits on submit and on focus loss rather than on every
    /// keystroke: this value is published to Friends, and pushing a rename per
    /// character would spend the once-a-day alias change on "G".
    private var profileBlock: some View {
        AppGlassCard(padding: AppSpacing.md) {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle().fill(AppColors.gold.opacity(0.16))
                    Circle().strokeBorder(AppColors.gold.opacity(0.30), lineWidth: 1)
                    Image(systemName: "person.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(AppColors.gold)
                }
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Name")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    TextField("Name", text: $nameDraft)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($nameFieldFocused)
                        .onSubmit { commitName() }
                        .onChange(of: nameFieldFocused) { _, focused in
                            if !focused { commitName() }
                        }
                }
                // Clamp the (horizontally greedy) TextField so it can never grow
                // the row past the viewport and induce a sideways drift.
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear { nameDraft = appModel.canonicalName }
        .alert("Couldn't update your public name", isPresented: Binding(
            get: { nameError != nil }, set: { if !$0 { nameError = nil } }
        )) {
            Button("OK", role: .cancel) { nameError = nil }
        } message: {
            Text(nameError ?? "")
        }
    }

    /// Local first, network second.
    ///
    /// The canonical write is local and unconditional, so the name is saved
    /// even offline or signed out. The Online push is a MIRROR of it through
    /// `updateAlias` — the existing validator and its once-a-day rate limit —
    /// and a rejection surfaces without rolling the local value back. Nothing
    /// drifts: `ensureIdentityAndProfile` republishes from the canonical name
    /// on the next launch, so a failed push heals itself.
    private func commitName() {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            nameDraft = appModel.canonicalName   // empty falls back, never clears
            return
        }
        guard trimmed != appModel.canonicalName else { return }
        appModel.setCanonicalName(trimmed)
        nameDraft = appModel.canonicalName
        guard online.isSignedIn else { return }
        Task { nameError = await online.updateAlias(appModel.canonicalName) }
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
        SettingsCard(title: "FocusGlobe PRO") {
            VStack(spacing: 0) {
                if appModel.isPro {
                    SettingsRow(systemImage: "checkmark.seal.fill", title: "PRO is active",
                                subtitle: "Thank you for your support", tint: AppColors.gold,
                                trailing: AnyView(EmptyView()))
                    #if canImport(RevenueCatUI)
                    if appModel.subscriptions.isAvailable {
                        RowDivider()
                        Button { appModel.tapFeedback(); showCustomerCenter = true } label: {
                            SettingsRow(systemImage: "person.crop.circle", title: "Manage subscription",
                                        subtitle: "Billing, restore & support", tint: AppColors.gold,
                                        trailing: AnyView(Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(AppColors.textTertiary)))
                        }
                        .buttonStyle(SoftPressStyle())
                    }
                    #endif
                } else if appModel.isConfirmedFree {
                    Button {
                        appModel.tapFeedback()
                        router.presentPaywall()
                    } label: {
                        SettingsRow(systemImage: "sparkles", title: "Unlock FocusGlobe PRO",
                                    subtitle: "No ads · Exclusive Skies · online flights", tint: AppColors.gold,
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
                                subtitle: restoreMessage, tint: AppColors.gold,
                                trailing: AnyView(EmptyView()))
                }
                .buttonStyle(SoftPressStyle())
            }
        }
    }


    // Privacy & Data — the privacy statement, the legal links (real hosted
    // pages, same `LegalLinks` used by the paywall footer), and the route to
    // manage/delete FocusGlobe Online data.
    /// The public FocusGlobe account. Visible to EVERY pilot — free, PRO, signed
    /// in, signed out, Debug and Release alike.
    ///
    /// This exists because every other route to Sign in with Apple sits behind an
    /// online/PRO gate (Friends' `gate(.online)`, the Online flight mode, the
    /// Online settings card's `.premium` branch), which left a signed-out FREE
    /// pilot with no way to sign back in and recover an entitlement they already
    /// own. Authentication is not a premium feature and is never gated here.
    ///
    /// Ordinary account styling on purpose: no PRO gradient, no paywall framing.
    @ViewBuilder private var accountSection: some View {
        SettingsCard(title: "Account") {
            if online.isSignedIn {
                signedInAccountRows
            } else {
                signedOutAccountRows
            }
        }
        .confirmationDialog("Sign out of FocusGlobe?",
                            isPresented: $showAccountSignOutConfirm,
                            titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                Task { await online.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can sign in again anytime to restore your account and PRO access.")
        }
    }

    private var signedOutAccountRows: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SettingsRow(systemImage: "person.crop.circle.badge.plus",
                        title: "Sign in to FocusGlobe",
                        subtitle: "Restore your account, progress and PRO access.",
                        tint: AppColors.gold,
                        trailing: AnyView(EmptyView()))
            if let accountError {
                Text(accountError)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.danger.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            // The shared native button. A successful authorization sets the
            // Supabase user id, which drives RevenueCat `logIn` → CustomerInfo →
            // `revenueCatPro` → widgets, so an owned entitlement returns on its
            // own with no purchase and no restart. We stay on Settings.
            FocusAppleSignInButton { error in accountError = error }
                .padding(.top, 2)
        }
    }

    private var signedInAccountRows: some View {
        VStack(spacing: 0) {
            // Deliberately no Supabase UUID, RevenueCat App User ID, token or
            // relay address — none of that belongs in normal Settings.
            SettingsRow(systemImage: "checkmark.circle.fill",
                        title: "Signed in with Apple",
                        subtitle: "Your FocusGlobe account and purchases are connected.",
                        tint: AppColors.gold,
                        trailing: AnyView(EmptyView()))
            RowDivider()
            Button {
                appModel.tapFeedback()
                showAccountSignOutConfirm = true
            } label: {
                SettingsRow(systemImage: "rectangle.portrait.and.arrow.right",
                            title: "Sign Out",
                            tint: AppColors.danger,
                            trailing: AnyView(EmptyView()))
            }
            .buttonStyle(SoftPressStyle())
        }
    }

    private var privacyDataSection: some View {
        SettingsCard(title: "Privacy & Data") {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.gold)
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
                                tint: AppColors.gold,
                                trailing: AnyView(Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppColors.textTertiary)))
                }
                .buttonStyle(SoftPressStyle())
                RowDivider()
                Link(destination: LegalLinks.privacy) {
                    SettingsRow(systemImage: "hand.raised.fill", title: "Privacy Policy",
                                tint: AppColors.gold, trailing: AnyView(legalChevron))
                }
                RowDivider()
                Link(destination: LegalLinks.terms) {
                    SettingsRow(systemImage: "doc.text.fill", title: "Terms of Use",
                                tint: AppColors.gold, trailing: AnyView(legalChevron))
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
                // The temporary PRO controls that lived here (Force FocusGlobe
                // PRO, RevenueCat App User ID, Copy App User ID, Refresh
                // Entitlements, Entitlement status) are GONE. They existed only to
                // identify and configure the administrator account; that account
                // now holds a real lifetime entitlement, so PRO is exercised by
                // signing in via Settings ▸ Account like any customer.
                //
                // The Online diagnostics inspector is gone too — screen, row and
                // sheet. It surfaced backend hostnames, presence internals and a
                // room-creation control; none of that belongs in a shipping build,
                // and a Debug-only fence is not a good enough reason to keep an
                // inspector one build configuration away from a customer.
                //
                // What remains is a single local reset used to replay onboarding.
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

// Shared building blocks — also reused by the Online & Friends settings section
// that now lives inside the Friends page (see `OnlineFriendsSettingsSection`).
struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionLabel(text: title)
            AppGlassCard(padding: AppSpacing.md) { content() }
        }
    }
}

struct ToggleRow: View {
    let systemImage: String
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: AppSpacing.sm) {
                iconBadge(systemImage, tint: AppColors.gold)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(AppTypography.callout).foregroundStyle(AppColors.textPrimary)
                    if let subtitle {
                        Text(subtitle).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                    }
                }
            }
        }
        .tint(AppColors.selectionGold)
        .padding(.vertical, 6)
    }
}

struct SettingsRow: View {
    let systemImage: String
    let title: String
    var subtitle: String?
    var tint: Color = AppColors.gold
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

struct RowDivider: View {
    var body: some View {
        Rectangle().fill(AppColors.hairline).frame(height: 1)
    }
}

func iconBadge(_ systemImage: String, tint: Color) -> some View {
    Image(systemName: systemImage)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(tint)
        .frame(width: 32, height: 32)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(tint.opacity(0.14)))
}
