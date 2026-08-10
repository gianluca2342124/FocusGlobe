import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var online: FocusOnlineModel
    @State private var restoreMessage: String?
    /// The Name field's live text. Committed on submit only — never per
    /// keystroke, which would spend the daily rename on "G". See `commitName()`.
    @State private var nameDraft = ""
    @State private var editingName = false
    @State private var isSavingName = false
    @State private var nameStatus: NameStatus?
    @FocusState private var nameFieldFocused: Bool
    @State private var showManageOnlineData = false
    @State private var showLanguagePicker = false
    /// Account section state (free, always available — never Debug-only).
    @State private var showAccountSignOutConfirm = false
    @State private var accountError: String?
    #if canImport(RevenueCatUI)
    @State private var showCustomerCenter = false
    #endif
    @State private var showResetConfirm = false

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
                    if isOwnerDeveloperAccount {
                        debugSection
                    }
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
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerView()
                .environmentObject(appModel)
                .presentationDragIndicator(.visible)
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
    /// Reading and editing are separate states. At rest the name is a label
    /// with a small pencil beside it; the field only exists while editing, and
    /// it opens with the whole name selected so a pilot who was handed
    /// "QuietComet" can type straight over it.
    private var profileBlock: some View {
        AppGlassCard(padding: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
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
                        if editingName {
                            nameField
                        } else {
                            Text(appModel.canonicalName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(AppColors.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    // Clamp the (horizontally greedy) field so it can never grow
                    // the row past the viewport and induce a sideways drift.
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !editingName { editNameButton }
                }

                if let nameStatus {
                    Text(nameStatus.message)
                        .font(AppTypography.caption)
                        .foregroundStyle(nameStatus.isError ? AppColors.danger : AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 56 + AppSpacing.md)
                }
            }
        }
        .onAppear {
            // The canonical name always exists, but restating it here means the
            // block can never render a blank even if something upstream failed.
            appModel.ensureCanonicalNameExists()
            nameDraft = appModel.canonicalName
        }
        // Carrying a customized name onto an account someone else already owns
        // is the one conflict the pilot has to resolve themselves.
        .onChange(of: online.nameConflict) { _, conflict in
            guard let conflict else { return }
            nameStatus = .error("\(conflict) is already taken on another account. Your name is \(appModel.canonicalName) — tap the pencil to choose another.")
            online.nameConflict = nil
        }
    }

    /// Small, subtle, and the same pencil language the results screen uses:
    /// a 26 pt glyph inside a 44 pt target.
    private var editNameButton: some View {
        Button {
            appModel.tapFeedback()
            nameDraft = appModel.canonicalName
            nameStatus = nil
            editingName = true
            // Focus on the NEXT runloop: the field does not exist yet on this
            // one, and focusing a view that has not been installed is a no-op.
            DispatchQueue.main.async { nameFieldFocused = true }
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(AppColors.textPrimary.opacity(0.07)))
                .overlay(Circle().strokeBorder(AppColors.textPrimary.opacity(0.12), lineWidth: 1))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit name")
        .accessibilityValue(appModel.canonicalName)
    }

    private var nameField: some View {
        TextField("Name", text: $nameDraft)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(AppColors.textPrimary)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .disabled(isSavingName)
            .focused($nameFieldFocused)
            .onSubmit { Task { await commitName() } }
            .onChange(of: nameFieldFocused) { _, focused in
                // Select the whole name the instant the field takes focus, so
                // typing replaces a generated one instead of appending to it.
                guard focused else { return }
                #if canImport(UIKit)
                DispatchQueue.main.async {
                    UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)),
                                                    to: nil, from: nil, for: nil)
                }
                #endif
            }
    }

    /// Server first, local second — the reverse of everywhere else in this app,
    /// and deliberately so.
    ///
    /// A public name has to be globally unique, and only the database can settle
    /// that. So nothing becomes canonical until `claim_public_alias` has taken
    /// it atomically: an unverified name published optimistically is exactly how
    /// two pilots end up sharing one identity. Offline, the current name simply
    /// stands.
    private func commitName() async {
        let candidate = PublicName.display(nameDraft)
        guard !candidate.isEmpty else {
            nameDraft = appModel.canonicalName        // empty falls back, never clears
            nameStatus = nil
            editingName = false
            return
        }
        if PublicName.isSameName(candidate, appModel.canonicalName),
           candidate == appModel.canonicalName {
            editingName = false                       // nothing changed at all
            nameStatus = nil
            return
        }
        if let message = PublicName.validationMessage(for: candidate) {
            nameStatus = .error(message)
            return
        }
        guard online.isSignedIn else {
            nameStatus = .error("Connect to the internet to change your name.")
            return
        }

        isSavingName = true
        nameStatus = .info("Checking…")
        let failure = await online.updateAlias(candidate)
        isSavingName = false

        if let failure {
            nameStatus = .error(failure)              // taken / invalid / offline
            return
        }
        // Only now is it canonical: the row is ours, so the local copy and
        // `hasCustomizedName` can follow.
        appModel.setCanonicalName(candidate)
        nameDraft = appModel.canonicalName
        nameStatus = nil
        editingName = false
        nameFieldFocused = false
    }

    /// A one-line status under the field: neutral while working, red when the
    /// name cannot be taken. Deliberately not an alert — a taken name is an
    /// ordinary answer, not an error worth a modal.
    enum NameStatus: Equatable {
        case info(String)
        case error(String)

        var message: String {
            switch self {
            case .info(let m), .error(let m): return m
            }
        }
        var isError: Bool { if case .error = self { return true }; return false }
    }

    private var experienceSection: some View {
        SettingsCard(title: "Experience") {
            VStack(spacing: 0) {
                // Language leads the section. It is an app-wide preference like
                // the three below it, and it is the one a pilot goes looking
                // for — the Welcome screen offered it once and then it was
                // gone. Not in the profile block: a flag beside the pilot's
                // name would read as a nationality, which it is not.
                Button {
                    appModel.tapFeedback()
                    showLanguagePicker = true
                } label: {
                    SettingsRow(systemImage: "globe", title: "Language",
                                subtitle: "The language FocusGlobe uses",
                                trailing: AnyView(HStack(spacing: 6) {
                                    Text(appModel.preferredLanguage.badge)
                                        .font(AppTypography.callout)
                                        .foregroundStyle(AppColors.textSecondary)
                                        .lineLimit(1)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(AppColors.textTertiary)
                                }))
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityLabel(Text("Language"))
                .accessibilityValue(appModel.preferredLanguage.nativeName)
                RowDivider()
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
                Text(LocalizedStringKey(accountError))
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

    private var isOwnerDeveloperAccount: Bool {
        online.authenticatedEmail?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == "gianlucacrous@gmail.com"
    }

    // Owner-only local reset. The section is absent unless the canonical
    // authenticated Supabase email matches the owner account exactly.
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
                appModel.resetAllLocalDataForOwner()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deletes flights, coins, streaks, unlocks and your profile on this device. The app returns to first launch.")
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

// MARK: - Manage Online Data

/// Settings → Experience → Language.
///
/// The SAME preference the Welcome screen writes, exposed a second time rather
/// than reimplemented: the list is `FocusLanguage.allCases` in its declared
/// order, the current value is `appModel.preferredLanguage`, and choosing a row
/// assigns to that same property. There is no array of eleven languages here,
/// no second `UserDefaults` key and no `@AppStorage` — the setter already
/// persists through `AppSettings`, mirrors the code into the App Group for the
/// widgets and the Shield extensions, and republishes.
///
/// IT DOES NOT DISMISS ON SELECTION, deliberately. This screen is where the
/// pilot is choosing a language, quite possibly one they are not fluent in, and
/// the honest way to confirm the choice is to watch this screen become that
/// language under their finger. Tap Español and the header reads Idioma; tap
/// Deutsch and it reads Sprache. Closing the sheet the instant they tap would
/// hide the only feedback that matters.
///
/// The locale is restated on this view's own body for the same reason
/// `LocalizedRoot` restates it on the app's: a sheet is hosted separately, and
/// this view observes `appModel`, so re-reading `preferredLocale` here is what
/// guarantees the switch lands on THIS screen and not only on the one behind it.
private struct LanguagePickerView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    ScreenHeader(title: "Language", showsBack: false)
                    AppGlassCard(padding: AppSpacing.md) {
                        VStack(spacing: 0) {
                            ForEach(Array(FocusLanguage.allCases.enumerated()), id: \.element) { index, language in
                                if index > 0 { RowDivider() }
                                row(language)
                            }
                        }
                    }
                }
                .padding(AppSpacing.screen)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xxl)
                .frame(maxWidth: .infinity, alignment: .leading)
                .settingsMaxWidth()
            }
        }
        .environment(\.locale, appModel.preferredLocale)
    }

    private func row(_ language: FocusLanguage) -> some View {
        let isSelected = appModel.preferredLanguage == language
        return Button {
            // Writing on every tap, including a tap on the language already
            // showing, is the same deliberate choice the Welcome capsule makes:
            // it turns "the device happens to be French" into "this pilot chose
            // French", which then survives the phone changing.
            appModel.tapFeedback()
            appModel.preferredLanguage = language
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Text(language.badge)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: AppSpacing.xs)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(AppColors.selectionGold)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle(scale: 0.99))
        // "Español, seleccionado" — the endonym, never the code, and the state
        // in FocusGlobe's language rather than the phone's.
        //
        // The checkmark is a drawn glyph, not a system control, so its state
        // has to be spoken by this value or not at all. `.isSelected` is
        // deliberately NOT added on top: VoiceOver speaks that trait itself, in
        // the DEVICE language, and the row would announce its state twice in
        // two different languages.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(language.nativeName)
        .accessibilityValue(isSelected ? Text("Selected") : Text(verbatim: ""))
        .accessibilityAddTraits(.isButton)
    }
}

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
                    Text(LocalizedStringKey(title)).font(AppTypography.callout).foregroundStyle(AppColors.textPrimary)
                    if let subtitle {
                        Text(LocalizedStringKey(subtitle)).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
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
                Text(LocalizedStringKey(title)).font(AppTypography.callout).foregroundStyle(AppColors.textPrimary)
                if let subtitle {
                    Text(LocalizedStringKey(subtitle)).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
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
