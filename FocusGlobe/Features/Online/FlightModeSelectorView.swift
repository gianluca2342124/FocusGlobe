import SwiftUI

/// The FIRST pre-flight ritual step: Online vs Solo, as two large premium
/// cards. One tap selects; Continue proceeds into the existing ritual. When
/// signed out the Online card offers Sign in with Apple (explicit tap only);
/// when the backend is unreachable it shows an "Unavailable" badge — and Solo
/// stays instantly available either way. This choice never lives in Settings.
struct FlightModeSelectorView: View {
    @EnvironmentObject private var online: FocusOnlineModel
    @EnvironmentObject private var appModel: AppModel
    /// Called with the chosen mode when the user continues.
    var onContinue: (OnlineFlightMode) -> Void

    @State private var selection: OnlineFlightMode = OnlineCache.lastFlightMode
    @State private var showDisclosure = false
    @State private var showInvite = false
    @State private var showSignIn = false

    private var onlineAvailable: Bool { online.availability.isAvailable }
    /// Signed out isn't "broken" — tapping the Online card offers Sign in.
    private var canSignIn: Bool {
        online.availability == .signedOut || online.availability == .sessionExpired
    }

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
                Text(canSignIn
                     ? "Tap Online Flight to sign in with Apple and fly with other pilots — Solo Flights never need an account."
                     : "You're offline right now. Solo Flights always work offline.")
                    .font(AppTypography.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)
            }

            if selection == .publicSky && onlineAvailable {
                // Ticks once a second so a throttle countdown stays live; the row
                // reads the ONE authoritative roomCreationState (never a cached
                // bool), so it can't disagree with the invite sheet.
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    inviteRow(now: ctx.date)
                }
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
            Task {
                await online.refreshAvailability()
                // If a private room is already pending, learn who has really
                // accepted so the invite row can say "N friends joined".
                if let pending = online.pendingRoom { await online.loadParticipants(of: pending) }
            }
        }
        // If availability drops (e.g. a failed op flipped the authoritative
        // state to offline), fall the selection back to Solo so the card and
        // the invite sheet can never disagree.
        .onChange(of: online.availability) { _, now in
            if !now.isAvailable && selection.isOnline { selection = .solo }
        }
        .sheet(isPresented: $showInvite) {
            InvitePeopleView(context: .preFlight(skyID: appModel.selectedSky.id))
                .environmentObject(online).environmentObject(appModel)
        }
        .sheet(isPresented: $showSignIn) {
            OnlineSignInView {
                // Signed in from the Online card → select Online right away.
                withAnimation(.snappy(duration: 0.2)) { selection = .publicSky }
            }
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

    /// Honest state derived from `roomCreationState` — never claims a room is
    /// ready just because a sheet opened or a bool was cached. `.creating` and
    /// throttled states are not tappable (repeated taps can't spawn a new room).
    private func inviteRowContent(now: Date) -> (title: String, icon: String, tappable: Bool) {
        switch online.roomCreationState {
        case .idle:
            return ("Create a Private Flight", "person.badge.plus", true)
        case .creating:
            return ("Creating private room…", "arrow.triangle.2.circlepath", false)
        case .waitingUntil(let date):
            return ("Try again in \(Self.countdown(to: date, now: now))", "clock", false)
        case .failed:
            return ("Private room unavailable — tap to retry", "exclamationmark.triangle", true)
        case .ready:
            let joined = online.activeRoomParticipants.filter { $0.publicID != online.profile?.publicID }.count
            if joined > 0 { return ("\(joined) friend\(joined == 1 ? "" : "s") joined", "checkmark.circle.fill", true) }
            return ("Private room ready — invite friends", "checkmark.circle.fill", true)
        }
    }

    /// Formats a mm:ss countdown to `date` (from `now`).
    static func countdown(to date: Date, now: Date) -> String {
        let secs = max(0, Int(date.timeIntervalSince(now).rounded(.up)))
        return String(format: "%d:%02d", secs / 60, secs % 60)
    }

    private func inviteRow(now: Date) -> some View {
        let content = inviteRowContent(now: now)
        return Button {
            guard content.tappable else { return }
            appModel.tapFeedback()
            showInvite = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: content.icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColors.gold)
                Text(content.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .monospacedDigit()
                Spacer()
                if content.tappable {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 14)
            .glassBackground(cornerRadius: 16, tintOpacity: 0.2, shadowRadius: 6, shadowY: 3)
        }
        .buttonStyle(SoftPressStyle())
        .disabled(!content.tappable)
        .opacity(content.tappable ? 1 : 0.72)
    }

    private func card(mode: OnlineFlightMode, title: String, subtitle: String,
                      icon: String, benefits: [String], disabled: Bool) -> some View {
        let selected = effectiveMode == mode || (mode == .publicSky && selection.isOnline)
        // Disabled online stays fully legible: only the icon/benefit text mute,
        // never the whole card, and an "Unavailable" badge explains it.
        let titleColor: Color = disabled ? .white.opacity(0.82) : .white
        let subtitleColor = disabled ? AppColors.textTertiary : AppColors.textSecondary
        return Button {
            if disabled {
                // Signed out is an invitation, not a dead end: the Online card
                // opens Sign in with Apple (explicit user choice — never auto).
                if mode == .publicSky && canSignIn {
                    appModel.tapFeedback()
                    showSignIn = true
                }
                return
            }
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
                            statusBadge(canSignIn ? "Sign in" : "Unavailable",
                                        tint: canSignIn ? AppColors.gold : AppColors.textTertiary,
                                        filled: false)
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
        .disabled(disabled && !(mode == .publicSky && canSignIn))
    }

    private func statusBadge(_ text: String, tint: Color, filled: Bool) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.14)))
    }
}
