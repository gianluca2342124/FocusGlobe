import SwiftUI

/// The FIRST pre-flight ritual step: Online vs Solo, as two equal premium
/// cards — icon + one word, no paragraphs. One tap selects; Continue proceeds
/// into the existing ritual. A single compact action below adapts to state
/// (Sign in with Apple / Create a Private Flight / Open Lobby · N joined).
/// Solo is always instantly available; this choice never lives in Settings.
struct FlightModeSelectorView: View {
    @EnvironmentObject private var online: FocusOnlineModel
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.horizontalSizeClass) private var hSize
    /// Called with the chosen mode when the user continues.
    var onContinue: (OnlineFlightMode) -> Void

    @State private var selection: OnlineFlightMode = OnlineCache.lastFlightMode
    @State private var showDisclosure = false
    @State private var showInvite = false
    @State private var showSignIn = false

    private var onlineAvailable: Bool { online.availability.isAvailable }
    private var canSignIn: Bool {
        online.availability == .signedOut || online.availability == .sessionExpired
    }
    private var onlineSelected: Bool { selection.isOnline }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("Choose your flight")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            // Two equal cards side by side (wraps gracefully under large text).
            HStack(spacing: AppSpacing.md) {
                modeCard(mode: .publicSky, title: "Online", icon: "person.3.fill")
                modeCard(mode: .solo, title: "Solo", icon: "person.fill")
            }
            .frame(maxWidth: hSize == .regular ? 520 : .infinity)

            // One compact, state-driven action under the cards.
            if onlineSelected { onlineActionRow }

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
            if !onlineAvailable && selection.isOnline && !canSignIn { selection = .solo }
            Task {
                await online.refreshAvailability()
                if let pending = online.pendingRoom { await online.loadParticipants(of: pending) }
            }
        }
        .onChange(of: online.availability) { _, now in
            // Only fall back to Solo for a genuine outage — signed-out still
            // offers Sign in on the Online card.
            if !now.isAvailable && !canSignIn && selection.isOnline { selection = .solo }
        }
        .sheet(isPresented: $showInvite) {
            InvitePeopleView(context: .preFlight(skyID: appModel.selectedSky.id))
                .environmentObject(online).environmentObject(appModel)
        }
        .sheet(isPresented: $showSignIn) {
            OnlineSignInView {
                withAnimation(.snappy(duration: 0.2)) { selection = .publicSky }
            }
            .environmentObject(online).environmentObject(appModel)
        }
        .alert("Fly in Public Skies?", isPresented: $showDisclosure) {
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

    // MARK: - Two equal cards

    private func modeCard(mode: OnlineFlightMode, title: String, icon: String) -> some View {
        let selected = (mode == .solo && selection == .solo)
            || (mode == .publicSky && selection.isOnline)
        return Button {
            if mode == .publicSky && !onlineAvailable {
                if canSignIn { appModel.tapFeedback(); showSignIn = true }
                return
            }
            appModel.tapFeedback()
            withAnimation(.snappy(duration: 0.2)) { selection = mode }
        } label: {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(selected ? AppColors.gold : .white.opacity(0.7))
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.7)
                // Live status for the Online card only (no paragraph).
                if mode == .publicSky {
                    onlineBadge
                } else {
                    Text("Offline‑ready")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 132)
            .padding(AppSpacing.md)
            .glassBackground(cornerRadius: AppSpacing.cardRadius,
                             tintOpacity: selected ? 0.26 : 0.14, shadowRadius: 10, shadowY: 5)
            .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                .strokeBorder(selected ? AppColors.gold.opacity(0.8) : Color.white.opacity(0.1),
                              lineWidth: selected ? 1.8 : 1))
            .shadow(color: selected ? AppColors.gold.opacity(0.28) : .clear, radius: 12)
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColors.gold)
                        .padding(10)
                }
            }
        }
        .buttonStyle(SoftPressStyle(scale: 0.98))
    }

    @ViewBuilder private var onlineBadge: some View {
        if onlineAvailable {
            HStack(spacing: 5) {
                Circle().fill(Color(hex: 0x4ADE80)).frame(width: 7, height: 7)
                Text("Live").font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }
        } else if canSignIn {
            Text("Sign in").font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.gold)
        } else {
            Text("Unavailable").font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textTertiary)
        }
    }

    // MARK: - One compact state-driven action

    @ViewBuilder private var onlineActionRow: some View {
        if canSignIn {
            compactAction(icon: "applelogo", title: "Sign in with Apple") { showSignIn = true }
        } else if onlineAvailable {
            if case .waitingUntil(let date) = online.roomCreationState {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    compactAction(icon: "clock", title: "Try again in \(Self.countdown(to: date, now: ctx.date))",
                                  enabled: false) {}
                }
            } else if online.pendingRoom != nil {
                let n = online.joinedOthersCount
                compactAction(icon: "person.3.fill",
                              title: n > 0 ? "Open Lobby · \(n) joined" : "Open Lobby · invite friends") {
                    showInvite = true
                }
            } else if case .creating = online.roomCreationState {
                compactAction(icon: "arrow.triangle.2.circlepath", title: "Creating private room…", enabled: false) {}
            } else {
                compactAction(icon: "person.badge.plus", title: "Create a Private Flight") { showInvite = true }
            }
        }
    }

    private func compactAction(icon: String, title: String, enabled: Bool = true,
                               _ action: @escaping () -> Void) -> some View {
        Button {
            guard enabled else { return }
            appModel.tapFeedback()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.gold)
                Text(title).font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary).monospacedDigit()
                Spacer()
                if enabled { Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.textTertiary) }
            }
            .padding(.horizontal, AppSpacing.md).padding(.vertical, 13)
            .glassBackground(cornerRadius: 16, tintOpacity: 0.2, shadowRadius: 6, shadowY: 3)
        }
        .buttonStyle(SoftPressStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.72)
    }

    /// Formats a mm:ss countdown to `date` (from `now`).
    static func countdown(to date: Date, now: Date) -> String {
        let secs = max(0, Int(date.timeIntervalSince(now).rounded(.up)))
        return String(format: "%d:%02d", secs / 60, secs % 60)
    }
}
