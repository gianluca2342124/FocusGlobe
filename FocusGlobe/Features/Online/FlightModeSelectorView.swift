import SwiftUI

/// The FIRST pre-flight ritual step: Online vs Solo, as two large premium
/// cards. One tap selects; Continue proceeds into the existing ritual. If
/// CloudKit is unavailable the Online card stays legible but shows an
/// "Unavailable" badge and Solo stays instantly available — this choice never
/// lives in Settings, and there is never a "Sign in with Apple" prompt.
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
        VStack(spacing: AppSpacing.lg) {
            VStack(spacing: 6) {
                Text("Choose your flight")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("You can change this any time you fly.")
                    .font(AppTypography.callout)
                    .foregroundStyle(.white.opacity(0.72))
            }
            .multilineTextAlignment(.center)

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
            }

            if !onlineAvailable {
                Text(online.availability == .noAccount
                     ? "Online Flights need an active iCloud account. Sign in to iCloud in your device settings to fly with other pilots — Solo Flights always work offline."
                     : "You're offline right now. Solo Flights always work offline.")
                    .font(AppTypography.caption)
                    .foregroundStyle(.white.opacity(0.6))
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
            // Consent IS the enable: continuing online turns on Appear in Public
            // Skies (the user can switch it off later in Settings). Cancelling
            // leaves them private and does not record consent.
            Button("Continue Online") {
                OnlineCache.disclosureSeen = true
                online.setDiscoverable(true)
                finish(effectiveMode)
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Other pilots will see your anonymous alias, your balloon skin, your Sky and roughly how long you're focusing — plus an optional country flag. Your name, email and personal goals are never shared.")
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
            .padding(.vertical, 14)
            .glassBackground(cornerRadius: 16, tintOpacity: 0.2, shadowRadius: 6, shadowY: 3)
        }
        .buttonStyle(SoftPressStyle())
    }

    private func card(mode: OnlineFlightMode, title: String, subtitle: String,
                      icon: String, benefits: [String], disabled: Bool) -> some View {
        let selected = effectiveMode == mode || (mode == .publicSky && selection.isOnline)
        // Disabled online stays fully legible: only the icon/benefit text mute,
        // never the whole card, and an "Unavailable" badge explains it.
        let titleColor: Color = disabled ? .white.opacity(0.82) : .white
        let subtitleColor = disabled ? AppColors.textTertiary : AppColors.textSecondary
        return Button {
            guard !disabled else { return }
            appModel.tapFeedback()
            withAnimation(.snappy(duration: 0.2)) { selection = mode }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(selected ? AppColors.gold : (disabled ? AppColors.textTertiary : AppColors.textSecondary))
                        .frame(width: 34)
                    Text(title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(titleColor)
                    Spacer()
                    if mode == .publicSky {
                        if disabled {
                            statusBadge("Unavailable", tint: AppColors.textTertiary, filled: false)
                        } else {
                            HStack(spacing: 5) {
                                Circle().fill(Color(hex: 0x4ADE80)).frame(width: 7, height: 7)
                                Text("Live")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                    }
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(selected ? AppColors.gold : AppColors.textTertiary.opacity(0.5))
                }
                Text(subtitle)
                    .font(AppTypography.callout)
                    .foregroundStyle(subtitleColor)
                Text(benefits.joined(separator: "  ·  "))
                    .font(AppTypography.caption)
                    .foregroundStyle(disabled ? AppColors.textTertiary.opacity(0.8) : AppColors.textTertiary)
                    .lineLimit(2)
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 118)
            .glassBackground(cornerRadius: AppSpacing.cardRadius,
                             tintOpacity: disabled ? 0.16 : 0.22,
                             shadowRadius: 10, shadowY: 5)
            .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                .strokeBorder(selected ? AppColors.gold.opacity(0.75) : Color.white.opacity(0.1),
                              lineWidth: selected ? 1.6 : 1))
        }
        .buttonStyle(SoftPressStyle(scale: 0.99))
        .disabled(disabled)
    }

    private func statusBadge(_ text: String, tint: Color, filled: Bool) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.14)))
    }
}
