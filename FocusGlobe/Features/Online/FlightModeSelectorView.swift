import SwiftUI

/// The FIRST pre-flight step: pick your flight. Two equal cards — Online or
/// Solo — and nothing else. Choosing Online + Continue takes off IMMEDIATELY
/// into a Global Flight (real pilots + a living sky); Solo takes off alone.
/// Private Flights are never chosen here — they are born from an Invite Friends
/// tap during a Global Flight. The only thing that ever appears under the cards
/// is a Sign in with Apple prompt when Online is chosen while signed out.
struct FlightModeSelectorView: View {
    @EnvironmentObject private var online: FocusOnlineModel
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.horizontalSizeClass) private var hSize
    /// Free pilot chose Online → open the ritual's Online paywall. Presented by
    /// the setup ritual itself (a local sheet), never via the app-wide router
    /// coordinator — presenting a router sheet from inside the full-screen cover
    /// collapses the cover and strands the modal state.
    var onNeedOnlinePaywall: () -> Void = {}
    /// PRO pilot signed out → open Sign in with Apple (also ritual-local).
    var onNeedSignIn: () -> Void = {}
    /// Called with the chosen mode when the user continues.
    var onContinue: (OnlineFlightMode) -> Void

    @State private var selection: OnlineFlightMode = OnlineCache.lastFlightMode == .solo ? .solo : .publicSky
    /// Set when a PRO pilot presses Continue while signed out — after Sign in with
    /// Apple succeeds we continue exactly once (never a second time).
    @State private var pendingOnlineContinue = false
    /// The brief "Online needs a connection" notice. One value, so repeated taps
    /// refresh it instead of stacking pills.
    @State private var notice = FocusNoticeState()

    private var onlineAvailable: Bool { online.availability.isAvailable }
    private var canSignIn: Bool {
        online.availability == .signedOut || online.availability == .sessionExpired
    }
    private var onlineSelected: Bool { selection.isOnline }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("Choose your Flight")
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            // Two equal cards, side by side.
            HStack(spacing: AppSpacing.md) {
                modeCard(mode: .publicSky, title: "Online", icon: "person.3.fill",
                         subtitle: "Focus together")
                modeCard(mode: .solo, title: "Solo", icon: "person.fill",
                         subtitle: "Private")
            }
            .frame(maxWidth: hSize == .regular ? 540 : .infinity)

            // The ONLY thing under the cards: sign in when Online needs it — and
            // only for a confirmed PRO pilot. A free pilot sees the Online card +
            // live count but is taken to the Online paywall on Continue (never
            // sign-in first). While the entitlement is still loading, nothing is
            // shown (we don't presume Free).
            if onlineSelected && canSignIn && appModel.entitlement == .premium {
                signInPrompt
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            AppPrimaryButton(title: "Continue", systemImage: "arrow.right", iconTrailing: true) {
                appModel.tapFeedback()
                continueTapped()
            }
        }
        .focusTransientNotice($notice, alignment: .bottom, inset: 8)
        .animation(.snappy(duration: 0.22), value: onlineSelected)
        .animation(.snappy(duration: 0.22), value: canSignIn)
        .onAppear {
            if !onlineAvailable && selection.isOnline && !canSignIn { selection = .solo }
            // A FREE pilot must never sit on a pre-selected Online card (the last
            // mode could have been Online before an entitlement lapse). Solo is
            // the default until a premium pilot chooses Online. Loading is never
            // presumed free, so it's left alone.
            if selection.isOnline && appModel.entitlement == .free { selection = .solo }
            Task { await online.refreshAvailability() }
        }
        // If the entitlement resolves to free while Online is showing selected,
        // fall back to Solo (no flash of a premium-only preselect for a free user).
        .onChange(of: appModel.entitlement) { _, now in
            if now == .free && selection.isOnline { selection = .solo }
        }
        .onChange(of: online.availability) { _, now in
            // Fall back to Solo only for a genuine outage — signed-out still
            // offers Sign in on the Online card.
            if !now.isAvailable && !canSignIn && selection.isOnline { selection = .solo }
            // A PRO pilot who pressed Continue while signed out: once sign-in
            // makes Online available, continue exactly once.
            if now.isAvailable && pendingOnlineContinue {
                pendingOnlineContinue = false
                continueTapped()
            }
        }
        // Online paywall + Sign in with Apple present through the setup ritual's
        // OWN local coordinator (see FlightSetupView) — never the app-wide router,
        // which would collapse this full-screen cover.
        //
        // NO public-presence disclosure is shown on this step: not the old "Fly in
        // Public Skies?" alert, and not the inline paragraph that replaced it. The
        // cards go straight to Continue, with no reserved vertical space. Choosing
        // Online still records the acknowledgement silently in `continueTapped()`,
        // and the privacy wording lives in Settings ▸ Privacy (Privacy Policy and
        // Terms are unchanged and still reachable there).
    }

    private func continueTapped() {
        let mode = selection
        guard mode.isOnline else { finish(.solo); return }
        // Online is a FocusGlobe PRO feature, gated on the REAL entitlement.
        switch appModel.entitlement {
        case .free:
            // Free pilot: the Online paywall ONLY — NO auth, NO presence, NO room.
            appModel.tapFeedback()
            onNeedOnlinePaywall()
            return
        case .loading:
            // Entitlement still resolving — never flash a paywall at a possibly
            // PRO/Lifetime owner. Nudge a refresh; they can Continue once resolved.
            appModel.tapFeedback()
            appModel.refreshSubscriptionStatus()
            return
        case .premium:
            break   // PRO / Lifetime — proceed.
        }
        // PRO from here — and the first thing an Online flight needs is a
        // network. Without this the offline path fell straight through to the
        // `return` below: not signed out, so no sign-in prompt, and nothing
        // else to show. The pilot pressed Continue and the app did nothing,
        // which reads as a broken button rather than as "you are offline".
        //
        // `isDefinitelyOffline` only, never `!isOnline` — the monitor's initial
        // `unknown` must not block someone who is perfectly connected in the
        // moment after launch.
        if appModel.connectivity.isDefinitelyOffline {
            appModel.tapFeedback()
            notice.show(FocusConnectivity.offlineMessage)
            return
        }
        // Online requires a signed-in session first.
        if !onlineAvailable {
            if canSignIn {
                pendingOnlineContinue = true          // continue once after auth
                appModel.tapFeedback()
                onNeedSignIn()
            }
            return
        }
        // Take off immediately. Choosing Online IS the acknowledgement: it is
        // recorded silently here, with no modal and no visible disclosure on the
        // step (the privacy wording lives in Settings ▸ Privacy).
        //
        // `setDiscoverable(true)` is called ONLY on the first Online flight — it
        // is the pilot's public-presence preference, and re-asserting it on every
        // launch would silently undo a later opt-out in
        // Friends ▸ Online & Friends Settings ▸ Appear in Public Skies.
        if !OnlineCache.disclosureSeen {
            OnlineCache.disclosureSeen = true
            online.setDiscoverable(true)
        }
        finish(.publicSky)
    }

    private func finish(_ mode: OnlineFlightMode) {
        online.flightMode = mode
        onContinue(mode)
    }

    // MARK: - Two equal cards

    /// The warm cream selection highlight — a calm, premium accent shared by
    /// BOTH cards, replacing the old saturated electric-blue. No blue anywhere.
    private static let creamAccent = Color(hex: 0xF3ECD9)

    private func modeCard(mode: OnlineFlightMode, title: String, icon: String,
                          subtitle: String) -> some View {
        let selected = selection == mode || (mode == .publicSky && selection.isOnline)
        let cream = Self.creamAccent
        return Button {
            appModel.tapFeedback()
            cardTapped(mode)
        } label: {
            VStack(spacing: AppSpacing.sm) {
                ZStack {
                    Image(systemName: icon)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(selected ? AnyShapeStyle(cream) : AnyShapeStyle(.white.opacity(0.7)))
                    if mode == .publicSky {
                        liveDot.offset(x: 30, y: -20)
                    }
                }
                .frame(height: 40)
                Text(title)
                    .font(.system(size: 23, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.7)
                cardSubtitle(mode: mode, fallback: subtitle, selected: selected)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 146)
            .padding(AppSpacing.md)
            .glassBackground(cornerRadius: AppSpacing.cardRadius,
                             tintOpacity: selected ? 0.24 : 0.13, shadowRadius: 12, shadowY: 6)
            // Soft warm cream border + gentle neutral glow — the SAME selection
            // language for Solo and Online (no saturated blue outline).
            .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                .strokeBorder(selected ? cream.opacity(0.8) : Color.white.opacity(0.1),
                              lineWidth: selected ? 2 : 1))
            .shadow(color: selected ? Color.white.opacity(0.22) : .clear, radius: 14)
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(cream)
                        .padding(10)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(SoftPressStyle(scale: 0.97))
    }

    /// A card tap decides everything up front — never Continue. Solo always
    /// selects. Online is PRO: a FREE pilot goes STRAIGHT to the Online paywall
    /// with Solo left selected (no selection change, no auth, no presence, no
    /// room); a LOADING entitlement only nudges a refresh (never presumed free);
    /// only a PREMIUM pilot actually selects Online.
    private func cardTapped(_ mode: OnlineFlightMode) {
        guard mode.isOnline else {
            withAnimation(.snappy(duration: 0.2)) { selection = mode }
            return
        }
        switch appModel.entitlement {
        case .premium:
            withAnimation(.snappy(duration: 0.2)) { selection = mode }
        case .free:
            onNeedOnlinePaywall()
        case .loading:
            appModel.refreshSubscriptionStatus()
        }
    }

    /// The Online card's second line: the LIVE ambient count for the selected
    /// Sky ("N pilots focusing now"), so the Global Sky reads as alive right
    /// where the choice is made. Counts come from the existing `SkyActivity`
    /// provider (never hardcoded) and are shown ALWAYS — even signed out — since
    /// the sign-in gate only fires when actually continuing into Online. Solo
    /// always stays quiet/private with its neutral subtitle.
    @ViewBuilder
    private func cardSubtitle(mode: OnlineFlightMode, fallback: String, selected: Bool) -> some View {
        if mode == .publicSky {
            HStack(spacing: 5) {
                Circle().fill(Color(hex: 0x4ADE80)).frame(width: 6, height: 6)
                Text("\(SkyActivity.count(for: appModel.selectedSky)) focusing now")
                    .font(.system(size: 12.5, weight: .semibold, design: .default))
                    // Always clearly readable — the live count is information,
                    // not decoration, so it never sinks into the card tint.
                    .foregroundStyle(selected ? AppColors.textSecondary : .white.opacity(0.72))
                    .monospacedDigit()
            }
            .lineLimit(1).minimumScaleFactor(0.7)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Live. \(SkyActivity.count(for: appModel.selectedSky)) focusing now")
        } else {
            Text(fallback)
                .font(.system(size: 12.5, weight: .semibold, design: .default))
                .foregroundStyle(selected ? AppColors.textSecondary : AppColors.textTertiary)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    private var liveDot: some View {
        HStack(spacing: 4) {
            Circle().fill(Color(hex: 0x4ADE80)).frame(width: 7, height: 7)
            Text("Live").font(.system(size: 10, weight: .heavy, design: .default))
                .foregroundStyle(Color(hex: 0x4ADE80))
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(Capsule().fill(Color(hex: 0x4ADE80).opacity(0.16)))
    }

    // MARK: - Sign-in prompt (only when Online is chosen while signed out)

    private var signInPrompt: some View {
        Button {
            appModel.tapFeedback(); onNeedSignIn()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "applelogo").font(.system(size: 15, weight: .bold))
                Text("Sign in with Apple")
                    .font(.system(size: 15, weight: .bold, design: .default))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.textTertiary)
            }
            .foregroundStyle(AppColors.textPrimary)
            .padding(.horizontal, AppSpacing.md).padding(.vertical, 13)
            .glassBackground(cornerRadius: 16, tintOpacity: 0.2, shadowRadius: 6, shadowY: 3)
        }
        .buttonStyle(SoftPressStyle())
    }

    /// Formats a mm:ss countdown to `date` (from `now`). Kept here because the
    /// invite sheet's throttle card still reuses it.
    static func countdown(to date: Date, now: Date) -> String {
        let secs = max(0, Int(date.timeIntervalSince(now).rounded(.up)))
        return String(format: "%d:%02d", secs / 60, secs % 60)
    }
}
