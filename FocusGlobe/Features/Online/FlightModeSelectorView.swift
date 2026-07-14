import SwiftUI

/// The FIRST pre-flight ritual step: Online vs Solo, as two large premium
/// cards. One tap selects; Continue proceeds into the existing ritual. If
/// CloudKit is unavailable the Online card visibly disables itself and Solo
/// stays instantly available — this choice never lives in Settings.
struct FlightModeSelectorView: View {
    @EnvironmentObject private var online: FocusOnlineModel
    @EnvironmentObject private var appModel: AppModel
    /// Called with the chosen mode when the user continues.
    var onContinue: (OnlineFlightMode) -> Void

    @State private var selection: OnlineFlightMode = OnlineCache.lastFlightMode
    @State private var showDisclosure = false
    @State private var showInvite = false

    private var onlineAvailable: Bool { online.availability.isAvailable }

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            card(mode: .publicSky,
                 title: "Online Flight",
                 subtitle: "Focus alongside real pilots and invite your Crew.",
                 icon: "person.3.fill",
                 benefits: ["See active pilots", "Invite friends", "Private rooms", "Friend coin bonus"],
                 disabled: !onlineAvailable)
            card(mode: .solo,
                 title: "Solo Flight",
                 subtitle: "A private flight that works anywhere.",
                 icon: "person.fill",
                 benefits: ["No internet required", "No public presence", "Completely private"],
                 disabled: false)

            if !onlineAvailable {
                Text(online.availability == .noAccount
                     ? "Online flights require an active iCloud account. You can continue flying Solo without an internet connection."
                     : online.availability.userMessage)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)
            }

            if selection == .publicSky && onlineAvailable {
                inviteRow
            }

            AppPrimaryButton(title: "Continue", systemImage: "arrow.right") {
                appModel.tapFeedback()
                let mode = effectiveMode
                if mode.isOnline && !OnlineCache.disclosureSeen {
                    showDisclosure = true
                } else {
                    finish(mode)
                }
            }
        }
        .onAppear {
            if !onlineAvailable && selection.isOnline { selection = .solo }
            Task { await online.refreshAvailability() }
        }
        .sheet(isPresented: $showInvite) {
            InvitePeopleView(context: .preFlight(skyID: appModel.selectedSky.id))
                .environmentObject(online).environmentObject(appModel)
        }
        .alert("Fly in Public Skies?", isPresented: $showDisclosure) {
            Button("Appear online") {
                OnlineCache.disclosureSeen = true
                online.setDiscoverable(true)
                finish(effectiveMode)
            }
            Button("Not now", role: .cancel) {
                OnlineCache.disclosureSeen = true
                finish(effectiveMode)
            }
        } message: {
            Text("Let other pilots see your balloon while you focus online. Only your anonymous alias and balloon are visible — never your name, contacts or location.")
        }
    }

    /// Selecting a private room upgrades publicSky → privateRoom automatically.
    private var effectiveMode: OnlineFlightMode {
        if selection.isOnline && online.pendingRoom != nil { return .privateRoom }
        return selection
    }

    private func finish(_ mode: OnlineFlightMode) {
        online.flightMode = mode
        onContinue(mode)
    }

    private var inviteRow: some View {
        Button {
            appModel.tapFeedback()
            showInvite = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: online.pendingRoom == nil ? "envelope.badge.person.crop" : "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColors.gold)
                Text(online.pendingRoom == nil ? "Invite Friends to this flight"
                                               : "Private room ready — invites sent from here")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 12)
            .glassBackground(cornerRadius: 16, tintOpacity: 0.2, shadowRadius: 6, shadowY: 3)
        }
        .buttonStyle(SoftPressStyle())
    }

    private func card(mode: OnlineFlightMode, title: String, subtitle: String,
                      icon: String, benefits: [String], disabled: Bool) -> some View {
        let selected = effectiveMode == mode || (mode == .publicSky && selection.isOnline)
        return Button {
            guard !disabled else { return }
            appModel.tapFeedback()
            withAnimation(.snappy(duration: 0.2)) { selection = mode }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(selected ? AppColors.gold : AppColors.textSecondary)
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    if mode == .publicSky && !disabled {
                        HStack(spacing: 5) {
                            Circle().fill(Color(hex: 0x4ADE80)).frame(width: 7, height: 7)
                            Text("Live")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(selected ? AppColors.gold : AppColors.textTertiary.opacity(0.5))
                }
                Text(subtitle)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                Text(benefits.joined(separator: "  ·  "))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .lineLimit(2)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassBackground(cornerRadius: AppSpacing.cardRadius, tintOpacity: 0.22,
                             shadowRadius: 10, shadowY: 5)
            .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                .strokeBorder(selected ? AppColors.gold.opacity(0.75) : Color.white.opacity(0.1),
                              lineWidth: selected ? 1.6 : 1))
            .opacity(disabled ? 0.45 : 1)
        }
        .buttonStyle(SoftPressStyle(scale: 0.99))
        .disabled(disabled)
    }
}
