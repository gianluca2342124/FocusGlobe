import SwiftUI

/// The FocusGlobe Online / social presence controls — moved here from Settings so
/// they live with the Friends experience. The section is always VISIBLE (never
/// blurred): a PRO / Lifetime pilot gets the live controls; a free pilot sees the
/// same rows as clearly-locked entries that open the Online paywall on tap; while
/// the entitlement is still resolving a neutral loading row is shown (never a
/// paywall, never a temporary grant). All stored values/behaviour are preserved.
struct OnlineFriendsSettingsSection: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var online: FocusOnlineModel

    @State private var showSignIn = false
    @State private var showSignOutConfirm = false

    var body: some View {
        SettingsCard(title: "Online & Friends Settings") {
            switch appModel.entitlement {
            case .premium: premiumControls
            case .free:    lockedRows
            case .loading: loadingRow
            }
        }
        .sheet(isPresented: $showSignIn) {
            OnlineSignInView()
                .environmentObject(online)
                .environmentObject(appModel)
        }
        .confirmationDialog("Sign out of FocusGlobe Online?", isPresented: $showSignOutConfirm,
                            titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { Task { await online.signOut() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your local flights, coins and streaks stay on this device. Your online profile remains until you delete it in Settings → Manage Online Data.")
        }
    }

    // MARK: PRO / Lifetime — the real, live controls

    private var premiumControls: some View {
        VStack(spacing: 0) {
            if online.availability == .signedOut || online.availability == .sessionExpired {
                Button {
                    appModel.tapFeedback(); showSignIn = true
                } label: {
                    SettingsRow(systemImage: "person.crop.circle.badge.plus",
                                title: "Sign in to FocusGlobe Online",
                                subtitle: "Fly with other pilots — you appear only as an anonymous alias",
                                tint: AppColors.gold, trailing: chevron)
                }
                .buttonStyle(SoftPressStyle())
                RowDivider()
            } else if online.isSignedIn {
                Button {
                    appModel.tapFeedback(); showSignOutConfirm = true
                } label: {
                    SettingsRow(systemImage: "person.crop.circle.badge.checkmark",
                                title: "Account",
                                subtitle: "Signed in as \(online.profile?.displayName ?? "Sky Pilot") — tap to sign out",
                                tint: AppColors.gold, trailing: chevron)
                }
                .buttonStyle(SoftPressStyle())
                RowDivider()
            }
            ToggleRow(systemImage: "globe.americas.fill", title: "Appear in Public Skies",
                      subtitle: "Let other pilots see your balloon while you focus online.",
                      isOn: Binding(get: { appModel.profile.onlineDiscoverable ?? true },
                                    set: { appModel.tapFeedback(); online.setDiscoverable($0) }))
            RowDivider()
            ToggleRow(systemImage: "person.crop.circle.badge.plus", title: "Allow Friend Requests",
                      subtitle: "Allow pilots you meet to send you a Crew request.",
                      isOn: Binding(get: { appModel.profile.onlineAllowsFriendRequests ?? true },
                                    set: { appModel.tapFeedback(); online.setAllowsFriendRequests($0) }))
            // The public alias row lived here. It is gone because the name it
            // edited is no longer separate: Settings → Name is the canonical
            // value and IS what Friends publishes. Two editors for one string
            // is exactly how the two used to drift apart.
        }
    }

    // MARK: Free — the same rows, clearly locked, opening the Online paywall

    private var lockedRows: some View {
        VStack(spacing: 0) {
            gatedRow("person.crop.circle.badge.plus", "Sign in to FocusGlobe Online",
                     "Fly with other pilots — you appear only as an anonymous alias")
            RowDivider()
            gatedRow("globe.americas.fill", "Appear in Public Skies",
                     "Let other pilots see your balloon while you focus online.")
            RowDivider()
            gatedRow("person.crop.circle.badge.plus", "Allow Friend Requests",
                     "Allow pilots you meet to send you a Crew request.")
        }
    }

    private func gatedRow(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        Button {
            appModel.tapFeedback()
            router.presentPaywall(context: .online)
        } label: {
            SettingsRow(systemImage: icon, title: title, subtitle: subtitle, tint: AppColors.gold,
                        trailing: AnyView(Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColors.textTertiary)))
        }
        .buttonStyle(SoftPressStyle())
    }

    // MARK: Loading — a neutral row (never a paywall, never a temporary grant)

    private var loadingRow: some View {
        HStack(spacing: AppSpacing.sm) {
            ProgressView().controlSize(.small)
            Text("Checking your membership…")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var chevron: AnyView {
        AnyView(Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppColors.textTertiary))
    }
}
