import SwiftUI

/// The FocusGlobe Online / social presence controls — MOVED here from Settings so
/// they live with the Friends experience they belong to. For a free pilot this
/// section sits behind the Friends PRO lock/blur (it is part of the Friends page
/// content); for a PRO / Lifetime pilot it is fully interactive. Everything is
/// opt-in and preserves the exact stored values and behaviour (`onlineDiscoverable`,
/// `onlineAllowsFriendRequests`, the public alias, sign-in / sign-out).
struct OnlineFriendsSettingsSection: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var online: FocusOnlineModel

    @State private var showSignIn = false
    @State private var showSignOutConfirm = false
    @State private var showAliasEditor = false
    @State private var aliasDraft = ""
    @State private var aliasError: String?

    var body: some View {
        SettingsCard(title: "Online & Friends Settings") {
            VStack(spacing: 0) {
                if online.availability == .signedOut || online.availability == .sessionExpired {
                    Button {
                        appModel.tapFeedback()
                        showSignIn = true
                    } label: {
                        SettingsRow(systemImage: "person.crop.circle.badge.plus",
                                    title: "Sign in to FocusGlobe Online",
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
                        SettingsRow(systemImage: "person.crop.circle.badge.checkmark",
                                    title: "Account",
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
        .sheet(isPresented: $showSignIn) {
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
            Text("Your local flights, coins and streaks stay on this device. Your online profile remains until you delete it in Settings → Manage Online Data.")
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
}
