import SwiftUI

/// The FocusGlobe home — a **full-screen Sky selector**. The selected Sky *is*
/// the screen: swipe horizontally to travel between Skies (the whole background
/// changes), the pilot's balloon stays centred as the anchor, and one strong
/// Start Focus button begins the ritual. Locked Skies preview freely but ask
/// for Premium or 3 invited friends to fly. The user should feel:
/// "I'm choosing where to focus today."
struct HomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = HomeViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showResume = false
    @State private var showStreak = false
    @State private var showSetup = false
    @State private var showUnlock = false
    @State private var balloonFloat: CGFloat = 0
    @State private var activityPulse = false
    @State private var streakPulse = false
    /// The Sky the pager is resting on (an index into `FocusSky.all`).
    @State private var skyIndex = 0
    @State private var didInitSky = false
    /// While handing the ticket off to the flight, the Home chrome (greeting,
    /// panel, resting balloon) is held hidden so only the continuous sky shows as
    /// the setup cover dismisses and the flight cover rises — no Home flash.
    @State private var handingOff = false
    /// The validated flight, stashed by `beginTakeOff` and launched from the
    /// setup cover's `onDismiss` so the two covers never contend to present.
    @State private var pendingTakeoff: (route: Route, intention: String?)?

    private var currentSky: FocusSky {
        FocusSky.all[max(0, min(FocusSky.all.count - 1, skyIndex))]
    }
    private var currentSkyUnlocked: Bool { appModel.isSkyUnlocked(currentSky) }

    var body: some View {
        ZStack {
            // The Sky pager IS the background: swiping travels between Skies.
            TabView(selection: $skyIndex) {
                ForEach(Array(FocusSky.all.enumerated()), id: \.element.id) { index, sky in
                    SkyPreviewView(sky: sky, animated: !reduceMotion)
                        .tag(index)
                        .ignoresSafeArea()
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Gentle top/bottom scrims so text and the panel stay readable.
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 190)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 360)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // The pilot's balloon — the fixed visual anchor while Skies change.
            GeometryReader { geo in
                let size = max(76, min(98, geo.size.height * 0.12))
                FlightBalloonView(size: size, showGlow: true)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.40 + balloonFloat)
                    .shadow(color: .black.opacity(0.28), radius: 12, y: 7)
            }
            .allowsHitTesting(false)
            .opacity(handingOff ? 0 : 1)

            // Big translucent arrows flank the hero at the screen edges, so
            // changing Sky is instantly discoverable — no instructional text.
            edgeArrows
                .opacity(handingOff ? 0 : 1)

            VStack(spacing: 0) {
                topBar
                greetingBlock
                Spacer()
                bottomCluster
                    .clusterMaxWidth()
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, AppSpacing.lg)
            .opacity(handingOff ? 0 : 1)
        }
        .animation(.easeOut(duration: 0.3), value: handingOff)
        .focusScreenChrome()
        .onAppear {
            if !didInitSky {
                skyIndex = FocusSky.all.firstIndex(of: appModel.selectedSky) ?? 0
                didInitSky = true
            }
            maybeShowResume()
            maybeShowPremiumIntro()
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) { balloonFloat = -10 }
            if appModel.progress.currentStreak > 0 {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { streakPulse = true }
            }
        }
        // Travelling the pager: a soft haptic, and unlocked Skies become the
        // active choice immediately (locked ones stay preview-only).
        .onChange(of: skyIndex) { _, _ in
            guard didInitSky else { return }
            appModel.haptics.tap()
            if currentSkyUnlocked { appModel.selectSky(currentSky) }
        }
        .fullScreenCover(isPresented: $showSetup, onDismiss: launchPendingFlight) {
            FlightSetupView(focusSky: currentSkyUnlocked ? currentSky : appModel.selectedSky,
                            onTakeOff: beginTakeOff)
                .environmentObject(appModel).environmentObject(router)
        }
        // "Start another flight" from the Landing screen: wait a beat for the
        // journey cover to finish dismissing, then open the setup ritual.
        .onChange(of: router.pendingNewFlight) { _, wants in
            guard wants else { return }
            router.pendingNewFlight = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showSetup = true }
        }
        // The flight cover is up (Home hidden) or has returned to Home: once it
        // clears, restore the chrome that the take-off hand-off hid.
        .onChange(of: router.activeJourney) { _, journey in
            if journey == nil { handingOff = false }
        }
        .sheet(isPresented: $showUnlock) {
            SkyUnlockSheet(sky: currentSky)
                .environmentObject(appModel).environmentObject(router)
        }
        .adaptiveModal(isPresented: $showStreak,
                       width: Layout.streakPanelWidth, height: Layout.streakPanelHeight) {
            StreakDetailsView().environmentObject(appModel)
        }
        .adaptiveModal(isPresented: $showResume,
                       width: Layout.resumePanelWidth, height: Layout.resumePanelHeight) {
            ResumeJourneySheet(
                snapshot: appModel.resumableJourney,
                onContinue: { showResume = false; continueResumableJourney() },
                onStartNew: {
                    showResume = false
                    appModel.clearResumableJourney()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showSetup = true }
                }
            )
        }
    }

    // MARK: Ticket → flight hand-off (no Home flash)

    /// Called from inside the setup ritual the instant the ticket validates.
    /// Hides the Home chrome first (so nothing can pop in behind the dismissing
    /// cover), stashes the flight, then dismisses the setup cover.
    private func beginTakeOff(route: Route, intention: String?) {
        pendingTakeoff = (route, intention)
        handingOff = true
        showSetup = false
    }

    /// Runs in the setup cover's `onDismiss` — the cover is fully gone, so
    /// presenting the flight here can never contend with it. Home is still
    /// chrome-less (only the sky), so the flight rises over a continuous scene.
    private func launchPendingFlight() {
        guard let takeoff = pendingTakeoff else { return }
        pendingTakeoff = nil
        router.startJourney(origin: appModel.originForJourney,
                            route: takeoff.route, intention: takeoff.intention)
    }

    // MARK: Resume / premium intro (unchanged logic)

    private func maybeShowResume() {
        guard appModel.resumableJourney != nil, router.activeJourney == nil else { return }
        showResume = true
    }

    private func continueResumableJourney() {
        guard let journey = appModel.makeResumeJourney() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            router.activeJourney = journey
        }
    }

    private func maybeShowPremiumIntro() {
        guard appModel.resumableJourney == nil, !showResume else { return }
        guard appModel.shouldShowPremiumIntro, !router.showPaywall else { return }
        appModel.markPremiumIntroSeen()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            router.presentPaywall()
        }
    }

    // MARK: Top bar — streak ember (left) · coins + premium (right)

    private var topBar: some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            streakChip
            Spacer()
            coinsChip
            if appModel.isPro {
                proChip
            } else {
                CrownButton(size: Layout.pad(42, 50)) { appModel.tapFeedback(); router.presentPaywall() }
            }
        }
        .padding(.top, AppSpacing.xs)
    }

    /// The Pro badge — a subtle gold "Ultra" capsule with a soft glow.
    private var proChip: some View {
        HStack(spacing: 5) {
            Image(systemName: "crown.fill")
                .font(.system(size: Layout.pad(12, 14), weight: .bold))
            Text("Ultra")
                .font(.system(size: Layout.pad(13, 15), weight: .heavy, design: .rounded))
        }
        .foregroundStyle(Color(hex: 0x2B2510))
        .padding(.horizontal, Layout.pad(11, 14))
        .padding(.vertical, Layout.pad(8, 10))
        .background(Capsule().fill(AppColors.gold))
        .shadow(color: AppColors.gold.opacity(0.55), radius: 8, y: 0)
        .accessibilityLabel("FocusGlobe Ultra is active")
    }

    private var coinsChip: some View {
        Button { appModel.tapFeedback(); router.openStore() } label: {
            HStack(spacing: 5) {
                FocusCoinIcon(size: Layout.pad(15, 17))
                Text(Formatters.miles(appModel.focusCoins))
                    .font(.system(size: Layout.pad(14, 17), weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, Layout.pad(11, 14))
            .padding(.vertical, Layout.pad(8, 10))
            .background(Capsule().fill(.white.opacity(0.1)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel("\(appModel.focusCoins) Focus Coins. Opens the Store.")
    }

    /// The streak ember — a warm flame that glows and softly pulses while the
    /// streak is alive (the app's most emotional number, upper-left).
    private var streakChip: some View {
        let streak = appModel.progress.currentStreak
        let alive = streak > 0
        return Button {
            appModel.tapFeedback()
            showStreak = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: Layout.pad(15, 18), weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: alive ? [Color(hex: 0xFFB65C), Color(hex: 0xF2643C)]
                                                     : [.white.opacity(0.5), .white.opacity(0.5)],
                                       startPoint: .top, endPoint: .bottom))
                Text("\(streak)")
                    .font(.system(size: Layout.pad(15, 19), weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, Layout.pad(12, 15))
            .padding(.vertical, Layout.pad(8, 10))
            .background(Capsule().fill(.white.opacity(0.1)))
            .overlay(Capsule().strokeBorder(
                (alive ? Color(hex: 0xF2643C).opacity(0.4) : Color.white.opacity(0.12)), lineWidth: 1))
            .shadow(color: Color(hex: 0xF2643C).opacity(alive ? (streakPulse ? 0.6 : 0.28) : 0),
                    radius: streakPulse ? 12 : 7, y: 0)
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel("\(streak) day streak. Opens streak details.")
    }

    // MARK: Greeting + selected Sky

    // The hero text: just the greeting, big and premium — no date line, no
    // instructions, nothing competing with it.
    private var greetingBlock: some View {
        Text(personalGreeting)
            .font(.system(size: Layout.pad(44, 60), weight: .semibold, design: .serif))
            .foregroundStyle(.white)
            .minimumScaleFactor(0.55)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, AppSpacing.sm)
            .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
    }

    private var personalGreeting: String {
        if let name = appModel.profile.name, !name.isEmpty {
            return "\(viewModel.greeting), \(name)"
        }
        return viewModel.greeting
    }

    // MARK: Edge arrows (flank the hero at the screen edges)

    /// Large translucent circular arrows pinned to the left/right screen edges,
    /// vertically level with the hero balloon. The pager still swipes; these make
    /// the interaction obvious for anyone who doesn't think to swipe.
    private var edgeArrows: some View {
        HStack {
            edgeArrow(system: "chevron.left", enabled: skyIndex > 0) {
                withAnimation(.easeInOut(duration: 0.35)) { skyIndex = max(0, skyIndex - 1) }
            }
            Spacer()
            edgeArrow(system: "chevron.right", enabled: skyIndex < FocusSky.all.count - 1) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    skyIndex = min(FocusSky.all.count - 1, skyIndex + 1)
                }
            }
        }
        .padding(.horizontal, AppSpacing.xs)
        .offset(y: -28)
    }

    private func edgeArrow(system: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: Layout.pad(19, 23), weight: .bold))
                .foregroundStyle(.white.opacity(enabled ? 0.92 : 0.3))
                .frame(width: Layout.pad(48, 56), height: Layout.pad(48, 56))
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().fill(Color.black.opacity(0.18)))
                .overlay(Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1))
                .shadow(color: .black.opacity(0.28), radius: 9, y: 4)
        }
        .buttonStyle(SoftPressStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityLabel(system == "chevron.left" ? "Previous Sky" : "Next Sky")
    }

    // MARK: Bottom cluster — Sky name · dots · activity · Start Focus

    private var bottomCluster: some View {
        VStack(spacing: AppSpacing.md) {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Text(currentSky.name)
                        .font(.system(size: Layout.pad(27, 33), weight: .semibold, design: .serif))
                        .foregroundStyle(AppColors.gold)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    if !currentSkyUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: Layout.pad(14, 16), weight: .bold))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                .shadow(color: .black.opacity(0.35), radius: 6, y: 1)
                skyDots
            }
            .animation(.easeInOut(duration: 0.25), value: skyIndex)

            activityIsland

            if currentSkyUnlocked {
                AppPrimaryButton(title: "Start Focus", systemImage: "arrow.up") {
                    appModel.tapFeedback()
                    appModel.selectSky(currentSky)
                    showSetup = true
                }
            } else {
                lockedCTA
            }
        }
    }

    /// One dot per Sky, the selected one stretched into a gold capsule.
    private var skyDots: some View {
        HStack(spacing: 5) {
            ForEach(FocusSky.all.indices, id: \.self) { i in
                Capsule()
                    .fill(i == skyIndex ? AppColors.gold : .white.opacity(0.30))
                    .frame(width: i == skyIndex ? 16 : 5, height: 5)
            }
        }
    }

    /// The floating activity island — a green pulse + "N focusing now". Counts
    /// come from the clearly-simulated `SkyActivity` provider until a live
    /// backend replaces it (see that type's honesty contract).
    private var activityIsland: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(Color(hex: 0x4ADE80))
                .frame(width: 8, height: 8)
                .shadow(color: Color(hex: 0x4ADE80).opacity(0.8), radius: activityPulse ? 5 : 2)
            Text("\(SkyActivity.count(for: currentSky)) focusing now")
                .font(.system(size: Layout.pad(13, 15), weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, Layout.pad(13, 16))
        .padding(.vertical, Layout.pad(9, 11))
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().fill(Color.black.opacity(0.2)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                activityPulse = true
            }
        }
        .animation(.easeInOut(duration: 0.25), value: skyIndex)
    }

    /// The locked-Sky call to action: unmistakable but elegant.
    private var lockedCTA: some View {
        Button {
            appModel.tapFeedback()
            showUnlock = true
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("Unlock \(currentSky.name)")
                    .font(.system(size: Layout.pad(17, 19), weight: .bold, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(Color(hex: 0x14120E))
            .frame(maxWidth: .infinity)
            .frame(height: Layout.pad(56, 64))
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: 0xF4EFE4)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppColors.gold.opacity(0.55), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel("Unlock \(currentSky.name). Premium or invite three friends.")
    }

}

// MARK: - Unlock a Sky (Premium or invite 3 friends)

/// The elegant unlock sheet for a locked Sky: Try Premium, or invite 3 friends
/// (with honest progress — invite counts only ever come from the referral
/// pipeline, never fabricated in production).
private struct SkyUnlockSheet: View {
    let sky: FocusSky
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    private var invites: Int { appModel.inviteProgress(for: sky) }

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            VStack(spacing: AppSpacing.lg) {
                SkyPreviewView(sky: sky, animated: false)
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1))
                    .padding(.top, AppSpacing.lg)

                VStack(spacing: 6) {
                    Text("Unlock \(sky.name)")
                        .font(AppTypography.serifTitle2)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(sky.description)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppSpacing.lg)

                VStack(spacing: AppSpacing.sm) {
                    AppPrimaryButton(title: "Try Premium — unlock all Skies", systemImage: "crown.fill") {
                        appModel.tapFeedback()
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            router.presentPaywall()
                        }
                    }
                    inviteBlock
                }
                .padding(.horizontal, AppSpacing.screen)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var inviteBlock: some View {
        VStack(spacing: AppSpacing.sm) {
            ShareLink(item: appModel.inviteShareMessage(for: sky)) {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("Invite 3 friends")
                        .font(AppTypography.headline)
                }
                .foregroundStyle(AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .glassBackground(cornerRadius: AppSpacing.pillRadius, tintOpacity: 0.2,
                                 shadowRadius: 8, shadowY: 4)
            }
            .simultaneousGesture(TapGesture().onEnded { appModel.tapFeedback() })

            HStack(spacing: 8) {
                ForEach(0..<SkyUnlock.invitesNeeded, id: \.self) { i in
                    Circle()
                        .fill(i < invites ? AppColors.gold : AppColors.textPrimary.opacity(0.14))
                        .frame(width: 9, height: 9)
                }
                Text("\(invites)/\(SkyUnlock.invitesNeeded) friends joined for \(sky.name)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            #if DEBUG
            // Testing only — never compiled into release: simulates the referral
            // backend confirming one accepted invite.
            Button("DEBUG: simulate accepted invite") {
                appModel.debugSimulateAcceptedInvite(forSkyID: sky.id)
            }
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.textTertiary)
            #endif
        }
    }
}

// MARK: - Resume unfinished flight

/// Offered on Home when an unfinished flight was saved: continue at the saved
/// progress, or start a new one.
private struct ResumeJourneySheet: View {
    let snapshot: ResumableJourney?
    let onContinue: () -> Void
    let onStartNew: () -> Void

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            VStack(spacing: AppSpacing.lg) {
                Spacer()
                BalloonView(height: 120, showBurner: true, showGlow: true,
                            glow: (snapshot?.route.colorTheme.soft ?? AppColors.gold.opacity(0.7)),
                            assetName: snapshot?.skinAssetName)
                VStack(spacing: 6) {
                    Text("Resume your flight?")
                        .font(AppTypography.serifTitle2)
                        .foregroundStyle(AppColors.textPrimary)
                    if let s = snapshot {
                        Text(progressText(s))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
                .multilineTextAlignment(.center)
                Spacer()
                VStack(spacing: AppSpacing.sm) {
                    AppPrimaryButton(title: "Continue flight", systemImage: "arrow.up") { onContinue() }
                    Button(action: onStartNew) {
                        Text("Start a new Focus")
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .glassBackground(cornerRadius: AppSpacing.pillRadius, tintOpacity: 0.18,
                                             shadowRadius: 8, shadowY: 4)
                    }
                    .buttonStyle(SoftPressStyle())
                }
            }
            .padding(AppSpacing.screen)
            .padding(.bottom, AppSpacing.xl)
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(true)
    }

    private func progressText(_ s: ResumableJourney) -> String {
        let total = max(1, s.route.durationMinutes * 60)
        let pct = Int((Double(s.elapsedSeconds) / Double(total) * 100).rounded())
        return "\(min(99, max(1, pct)))% complete · \(s.route.durationLabel)"
    }
}
