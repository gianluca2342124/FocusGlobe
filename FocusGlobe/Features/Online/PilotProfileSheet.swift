import SwiftUI

/// A compact profile for a REAL online pilot: alias, balloon, flag, category,
/// approximate remaining time, and Crew actions. Shows nothing personal.
/// Decorative pilots never open this sheet.
struct PilotProfileSheet: View {
    let pilot: OnlinePilot
    @EnvironmentObject private var online: FocusOnlineModel
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var note: String?
    @State private var busy = false
    @State private var showReport = false
    @State private var showBlock = false

    /// Closed set of report reasons — no free text, no personal data.
    private let reportReasons = ["Inappropriate alias", "Harassment or bullying",
                                 "Spam", "Something else"]

    /// The sheet's pilot is the current user (never offer social actions on self).
    private var isSelf: Bool { pilot.id == online.currentUserID }

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            VStack(spacing: AppSpacing.md) {
                Capsule().fill(.white.opacity(0.2)).frame(width: 40, height: 4).padding(.top, 10)
                BalloonView(height: 96, showBurner: false, showGlow: true,
                            skin: BalloonSkin.skin(id: pilot.balloonSkinID))
                    .padding(.top, AppSpacing.sm)
                HStack(spacing: 6) {
                    Text(pilot.displayName)
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .foregroundStyle(AppColors.textPrimary)
                    if let cc = pilot.countryCode { Text(flagEmoji(cc)) }
                }
                // Only REAL shared-for-this-flight metadata — clean human
                // labels, nothing fabricated: focus category and the fixed-
                // catalog sound name when shared, plus the LIVE countdown below.
                // (PRO is deliberately NOT shown — there is no trusted server
                // entitlement source, so it can't be published truthfully.)
                HStack(spacing: 8) {
                    if !pilot.focusCategory.isEmpty {
                        label(pilot.focusCategory.capitalized, icon: "target")
                    }
                    if let soundName = sharedSoundName {
                        label(soundName, icon: "music.note")
                    }
                }
                HStack(spacing: 8) {
                    if pilot.isPaused {
                        label("Paused", icon: "pause.circle")
                    } else if pilot.hasLiveSession {
                        TimelineView(.periodic(from: .now, by: 1)) { ctx in
                            label(pilot.liveCountdown(at: ctx.date), icon: "timer")
                        }
                    }
                }
                if let note {
                    Text(note).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                }
                VStack(spacing: AppSpacing.sm) {
                    if !isSelf {
                        applaudButton
                    }
                    if isSelf {
                        // Never offer a friend action on yourself.
                        Text("That's you")
                            .font(.system(size: 15, weight: .bold, design: .default))
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .glassBackground(cornerRadius: AppSpacing.pillRadius, tintOpacity: 0.14,
                                             shadowRadius: 4, shadowY: 2)
                    } else if let status = online.requestStatus(for: pilot.id) {
                        Text(status)   // "Crew member" / "Request sent"
                            .font(.system(size: 15, weight: .bold, design: .default))
                            .foregroundStyle(AppColors.gold)
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .glassBackground(cornerRadius: AppSpacing.pillRadius, tintOpacity: 0.18,
                                             shadowRadius: 4, shadowY: 2)
                    } else if pilot.allowsFriendRequest {
                        AppPrimaryButton(title: busy ? "Sending…" : "Add Friend", systemImage: "person.badge.plus") {
                            guard !busy else { return }
                            busy = true
                            appModel.tapFeedback()
                            Task { @MainActor in
                                note = await online.sendFriendRequest(to: pilot)
                                busy = false
                                if note == nil { note = "Request sent." }
                            }
                        }
                        .disabled(busy)
                    }
                    if !isSelf {
                        HStack(spacing: AppSpacing.lg) {
                            Button("Hide this pilot") {
                                appModel.tapFeedback()
                                appModel.hidePilot(pilot.id)
                                dismiss()
                            }
                            .foregroundStyle(AppColors.textTertiary)
                            Button("Block") {
                                appModel.tapFeedback()
                                showBlock = true
                            }
                            .foregroundStyle(AppColors.danger.opacity(0.85))
                            Button("Report") {
                                appModel.tapFeedback()
                                showReport = true
                            }
                            .foregroundStyle(AppColors.danger.opacity(0.85))
                        }
                        .font(AppTypography.callout)
                    }
                }
                .padding(.horizontal, AppSpacing.screen)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        .presentationDetents([.fraction(0.55)])
        .presentationDragIndicator(.hidden)
        .confirmationDialog("Block this pilot?", isPresented: $showBlock, titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                appModel.tapFeedback()
                Task { @MainActor in
                    let err = await online.blockPilot(pilot)
                    if err == nil {
                        appModel.hidePilot(pilot.id)
                        dismiss()
                    } else {
                        note = err
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You won't see each other in public Skies, and they can't send you requests or join your rooms.")
        }
        .confirmationDialog("Report this pilot?", isPresented: $showReport, titleVisibility: .visible) {
            ForEach(reportReasons, id: \.self) { reason in
                Button(reason, role: .destructive) {
                    appModel.tapFeedback()
                    Task { @MainActor in
                        let err = await online.reportPilot(pilot, reason: reason)
                        note = err ?? "Thanks — our team will review this pilot."
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Reports are anonymous and reviewed by our team. Only this pilot's anonymous ID and your chosen reason are sent — never any personal details.")
        }
    }

    /// The pilot's shared sound, resolved against the app's FIXED catalog —
    /// unknown/absent ids show nothing (never an arbitrary client string).
    private var sharedSoundName: String? {
        guard let id = pilot.soundID else { return nil }
        return JourneyAudioOption.all.first { $0.id == id }?.displayName
    }

    @State private var applauded = false
    @State private var applauding = false

    /// 👏 Applaud — the SERVER decides (identity, co-presence, self and the 45s
    /// cooldown are all enforced in `send_applause`). The button reflects the
    /// real outcome; it never claims "applauded" unless the server accepted it,
    /// and a rejection shows a friendly reason.
    private var applaudButton: some View {
        let cooling = applauded || online.applauseOnCooldown(for: pilot)
        return Button {
            guard !cooling, !applauding else { return }
            appModel.tapFeedback()
            applauding = true
            Task { @MainActor in
                let result = await online.applaud(pilot)
                applauding = false
                switch result {
                case .sent:
                    applauded = true
                    appModel.haptics.rewardClaim()
                case .cooldown:
                    applauded = true   // reflect the server cooldown honestly
                    note = "You recently applauded this pilot."
                case .recipientNotFlying:
                    note = "Pilot is no longer flying."
                case .notFlying:
                    note = "Try again in a moment."
                case .unavailable:
                    note = "Connection unavailable — try again."
                }
            }
        } label: {
            HStack(spacing: 8) {
                if applauding {
                    ProgressView().tint(Color(hex: 0x2B2510))
                } else {
                    Text("👏")
                    Text(cooling ? "Applauded" : "Applaud")
                        .font(.system(size: 16, weight: .bold, design: .default))
                }
            }
            .foregroundStyle(cooling ? AppColors.textSecondary : Color(hex: 0x2B2510))
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(Capsule().fill(cooling ? Color.white.opacity(0.08) : AppColors.gold))
        }
        .buttonStyle(SoftPressStyle(scale: 0.97))
        .disabled(cooling || applauding)
        .accessibilityLabel(cooling ? "Already applauded" : "Applaud this pilot")
    }

    private func label(_ text: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(text).font(.system(size: 12.5, weight: .semibold, design: .default))
        }
        .foregroundStyle(AppColors.textSecondary)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(.white.opacity(0.08)))
    }
}

/// A country code ("US") → flag emoji.
func flagEmoji(_ countryCode: String) -> String {
    countryCode.uppercased().unicodeScalars.reduce(into: "") { result, scalar in
        if let flag = UnicodeScalar(127397 + scalar.value) { result.unicodeScalars.append(flag) }
    }
}
