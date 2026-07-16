import SwiftUI
import StoreKit

/// The FocusGlobe home — a **full-screen Sky selector**. The selected Sky *is*
/// the screen: swipe horizontally to travel between Skies (the whole background
/// changes), the pilot's balloon stays centred as the anchor, and one strong
/// Start Focus button begins the ritual. Locked Skies preview freely but ask
/// for Premium or 3 invited friends to fly. The user should feel:
/// "I'm choosing where to focus today."
struct HomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var online: FocusOnlineModel
    @StateObject private var viewModel = HomeViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview
    /// Non-invasive review-prompt tracking (persisted in UserDefaults): every 5th
    /// genuine return to Home we may ask Apple to show its review prompt.
    @AppStorage("home.visitCount") private var homeVisitCount = 0
    @AppStorage("home.lastReviewPromptAt") private var lastReviewPromptAt = 0.0
    @State private var showStreak = false
    @State private var showSetup = false
    @State private var showPreview = false
    @State private var showCoinSpin = false
    @State private var showBoostGift = false
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
            // Larger and more emotionally central on Home (the flight keeps its
            // own small balloon).
            GeometryReader { geo in
                // Larger again and truly centred in the main visual area.
                let size = max(132, min(198, geo.size.height * 0.225))
                FlightBalloonView(size: size, showGlow: true)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.45 + balloonFloat)
                    .shadow(color: .black.opacity(0.3), radius: 18, y: 10)
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
            maybeShowPremiumIntro()
            maybeRequestReview()
            maybeOfferBoost()
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
        .fullScreenCover(isPresented: $showPreview) {
            SkyPreviewFlightView(sky: currentSky)
                .environmentObject(appModel).environmentObject(router)
                .environmentObject(online)
        }
        .adaptiveModal(isPresented: $showStreak,
                       width: Layout.streakPanelWidth, height: Layout.streakPanelHeight) {
            StreakDetailsView().environmentObject(appModel)
        }
        .sheet(isPresented: $showCoinSpin) {
            CoinSpinSheet().environmentObject(appModel)
        }
        .sheet(isPresented: $showBoostGift) {
            CoinsBoostPopup(onAccept: { appModel.armCoinBoost() })
                .environmentObject(appModel)
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

    // MARK: Resume / premium intro

    private func continueResumableJourney() {
        guard let journey = appModel.makeResumeJourney() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            router.activeJourney = journey
        }
    }

    /// Every 5th genuine return to Home, ask StoreKit to consider showing the
    /// system review prompt — never during onboarding, an active/ resumable
    /// flight, or while the paywall is up. Apple may still choose not to show it.
    private func maybeRequestReview() {
        guard !router.showPaywall, router.activeJourney == nil,
              appModel.resumableJourney == nil else { return }
        homeVisitCount += 1
        guard homeVisitCount % 5 == 0 else { return }
        let now = Date().timeIntervalSince1970
        // Don't ask again within ~30 days of the last prompt.
        if lastReviewPromptAt > 0, now - lastReviewPromptAt < 60 * 60 * 24 * 30 { return }
        lastReviewPromptAt = now
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { requestReview() }
    }

    /// Occasionally gift a Coins Boost on Home — never on a brand-new account,
    /// never stacked on the onboarding paywall or an active/resumable flight, and
    /// at most every ~3 days (the throttle lives in `AppModel`).
    private func maybeOfferBoost() {
        guard appModel.shouldOfferCoinBoost else { return }
        guard !router.showPaywall, !appModel.shouldShowPremiumIntro,
              appModel.resumableJourney == nil else { return }
        appModel.markCoinBoostOffered()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { showBoostGift = true }
    }

    private func maybeShowPremiumIntro() {
        guard appModel.resumableJourney == nil else { return }
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
            CoinSpinButton { appModel.tapFeedback(); showCoinSpin = true }
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
                FocusCoinIcon(size: Layout.pad(22, 25))
                Text(Formatters.miles(appModel.focusCoins))
                    .font(.system(size: Layout.pad(14, 17), weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.leading, Layout.pad(8, 11))
            .padding(.trailing, Layout.pad(11, 14))
            .padding(.vertical, Layout.pad(6, 8))
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
            edgeArrow(system: "chevron.left") { stepSky(-1) }
            Spacer()
            edgeArrow(system: "chevron.right") { stepSky(1) }
        }
        .padding(.horizontal, AppSpacing.xs)
        .offset(y: -28)
    }

    /// Move one Sky in either direction, wrapping around the ends (last → first
    /// and first → last) with a soft haptic tick on the wrap.
    private func stepSky(_ delta: Int) {
        let n = FocusSky.all.count
        guard n > 0 else { return }
        let wrapping = (delta > 0 && skyIndex == n - 1) || (delta < 0 && skyIndex == 0)
        if wrapping { appModel.haptics.bubble() }
        let next = ((skyIndex + delta) % n + n) % n
        withAnimation(.easeInOut(duration: 0.35)) { skyIndex = next }
    }

    private func edgeArrow(system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: Layout.pad(19, 23), weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
                .frame(width: Layout.pad(48, 56), height: Layout.pad(48, 56))
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().fill(Color.black.opacity(0.18)))
                .overlay(Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1))
                .shadow(color: .black.opacity(0.28), radius: 9, y: 4)
        }
        .buttonStyle(SoftPressStyle())
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

            if appModel.resumableJourney != nil {
                resumeBanner
            }

            // A subtle tag while a Coins Boost is armed, sitting just above the
            // Start Focus button so the pilot sees it before flying.
            if appModel.isCoinBoostArmed {
                CoinBoostTag().environmentObject(appModel)
            }

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

    /// A subtle, non-blocking resume card (replaces the old modal pop-up): shown
    /// only when an unfinished flight is saved. Tapping continues it.
    private var resumeBanner: some View {
        Button {
            appModel.tapFeedback()
            continueResumableJourney()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColors.gold)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Resume your flight")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("You have an unfinished flight")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.black.opacity(0.26)))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(AppColors.gold.opacity(0.3), lineWidth: 1))
            )
        }
        .buttonStyle(SoftPressStyle(scale: 0.99))
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
            Text("\(SkyActivity.count(for: currentSky)) users focusing now")
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
            showPreview = true
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("Preview")
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
        .accessibilityLabel("Preview \(currentSky.name)")
    }

}

// MARK: - Locked Sky preview (a real, full-screen flight you can look at)

/// A full-screen **preview flight** for a locked Sky: the real animated Sky
/// world with a default balloon and no session controls — just an X to close,
/// rotating headline copy, the unlock requirement, and the unlock actions. No
/// timer, no pause, no debug text. Replaces the old unlock sheet.
private struct SkyPreviewFlightView: View {
    let sky: FocusSky
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var online: FocusOnlineModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var headlineIndex = 0
    @State private var showInvite = false

    private var isPremiumOnly: Bool {
        if case .premium = sky.unlockRequirement { return true }
        return false
    }
    /// A **compressed highlight journey**: the exact same journey renderer and
    /// chapter tape as a real flight, but the clock starts past the take-off
    /// chapter and runs 2.5× faster — ~60 s of preview shows several authored
    /// chapters (never just the first scene).
    private var previewElapsed: () -> Double { { Date().timeIntervalSince(start) * 2.5 + 40 } }

    var body: some View {
        ZStack {
            // The real, animated Sky world — same renderer as an active flight.
            SkyFlightSceneView(sky: sky, elapsed: previewElapsed, animated: !reduceMotion)
                .ignoresSafeArea()
            AmbientPilotsLayer(skyID: sky.id, elapsed: previewElapsed, animated: !reduceMotion)
                .allowsHitTesting(false)
                .ignoresSafeArea()
            // A soft premium darkening — light enough to appreciate the living
            // sky, strong enough at the edges for the copy and buttons.
            LinearGradient(colors: [.black.opacity(0.38), .black.opacity(0.1), .black.opacity(0.55)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            // A default balloon, centred — no controls.
            GeometryReader { geo in
                let s = max(120, min(184, geo.size.height * 0.2))
                BalloonView(height: s, showBurner: true, showGlow: true, skin: BalloonSkin.default)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.46)
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()

            overlay
        }
        .task(id: headlineIndex) {
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            withAnimation(.easeInOut(duration: 0.5)) {
                headlineIndex = (headlineIndex + 1) % max(1, headlines.count)
            }
        }
    }

    private var overlay: some View {
        VStack(spacing: 0) {
            HStack {
                Button { appModel.tapFeedback(); dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(.ultraThinMaterial))
                        .overlay(Circle().fill(Color.black.opacity(0.22)))
                        .overlay(Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1))
                }
                .buttonStyle(SoftPressStyle())
                Spacer()
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.top, AppSpacing.sm)

            Text(headlines[min(headlineIndex, headlines.count - 1)])
                .font(.system(size: Layout.pad(28, 38), weight: .semibold, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .id(headlineIndex)
                .transition(.opacity)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.xl)

            Text(subtitle)
                .font(.system(size: Layout.pad(14, 16), weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, AppSpacing.sm)

            Spacer()

            actions
                .padding(.horizontal, AppSpacing.screen)
                .padding(.bottom, AppSpacing.xl)
        }
    }

    private var actions: some View {
        VStack(spacing: AppSpacing.sm) {
            AppPrimaryButton(title: "Unlock FocusGlobe Pro", systemImage: "crown.fill") {
                appModel.tapFeedback()
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.presentPaywall() }
            }
            if isPremiumOnly {
                softSecondary(title: "Maybe later") { dismiss() }
            } else {
                Text("or")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                secondaryButton
            }
        }
    }

    @ViewBuilder private var secondaryButton: some View {
        switch sky.unlockRequirement {
        case .invite(let n):
            // Real invite unlocks: only friends who actually JOINED the
            // invitation room count — never share-button taps.
            let cur = min(appModel.verifiedInviteProgress(for: sky), n)
            Button {
                appModel.tapFeedback()
                showInvite = true
            } label: {
                progressPill(title: "\(cur)/\(n) friends joined", icon: "person.2.fill",
                             fraction: n <= 0 ? 1 : Double(cur) / Double(n))
            }
            .buttonStyle(SoftPressStyle())
            .sheet(isPresented: $showInvite) {
                InvitePeopleView(context: .skyUnlock(sky))
                    .environmentObject(appModel)
                    .environmentObject(online)
            }
            .task {
                await online.refreshCampaignProgress(skyID: sky.id, required: n)
            }
        case .focusMinutes(let n):
            // Focus-minute / streak goals are earned by flying — no share sheet;
            // closing the preview returns to Home to start focusing.
            let cur = min(appModel.lifetimeFocusMinutes, n)
            Button { appModel.tapFeedback(); dismiss() } label: {
                progressPill(title: "\(cur.formatted())/\(n.formatted()) focus minutes", icon: "timer",
                             fraction: n <= 0 ? 1 : Double(cur) / Double(n))
            }
            .buttonStyle(SoftPressStyle())
        case .streakDays(let n):
            let cur = min(appModel.progress.currentStreak, n)
            Button { appModel.tapFeedback(); dismiss() } label: {
                progressPill(title: "\(cur)/\(n) streak days", icon: "flame.fill",
                             fraction: n <= 0 ? 1 : Double(cur) / Double(n))
            }
            .buttonStyle(SoftPressStyle())
        default:
            softSecondary(title: "Continue flying") { dismiss() }
        }
    }

    private func softSecondary(title: String, action: @escaping () -> Void) -> some View {
        Button { appModel.tapFeedback(); action() } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(Capsule().fill(.white.opacity(0.12)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle())
    }

    /// A large, readable requirement button: an icon + "current/target" label over
    /// a slim gold progress bar, so the unlock method is understood instantly.
    private func progressPill(title: String, icon: String, fraction: Double) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 15, weight: .bold))
                Text(title).font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.16))
                    Capsule().fill(AppColors.gold)
                        .frame(width: max(6, g.size.width * CGFloat(min(1, max(0, fraction)))))
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.2), lineWidth: 1))
    }

    // Rotating headline copy — three lines, adapted to the Sky.
    private var headlines: [String] {
        switch sky.id {
        case "paris-sunset":     return ["Study above Paris", "A sunset made for deep work", "Unlock this Sky to fly here"]
        case "fiji-lagoon":      return ["Focus above the lagoon", "Turquoise calm for deep work", "Unlock this Sky to fly here"]
        case "kyoto-lanterns":   return ["Study among the lanterns", "A quiet Kyoto evening", "Unlock this Sky to fly here"]
        case "aurora-snowfield": return ["Focus under the aurora", "Northern lights for deep work", "Unlock this Sky to fly here"]
        case "rainy-tokyo":      return ["Study over rainy Tokyo", "Neon calm and soft rain", "Unlock this Sky to fly here"]
        case "moon-garden":      return ["Focus beneath the moon", "A silver night for deep work", "Unlock this Sky to fly here"]
        case "swiss-alps":       return ["Study above the Alps", "Crisp mountain air for focus", "Unlock this Sky to fly here"]
        case "sahara-night":     return ["Focus under desert stars", "A vast night made for depth", "Unlock this Sky to fly here"]
        case "galaxy-drift":     return ["Focus among the stars", "Drift through a living galaxy", "Unlock this Sky to fly here"]
        case "deep-space":       return ["Study in deep space", "Cosmic silence for deep work", "Unlock this Sky to fly here"]
        default:                 return ["Focus in \(sky.name)", "A Sky made for deep work", "Unlock this Sky to fly here"]
        }
    }

    private var subtitle: String {
        switch sky.unlockRequirement {
        case .premium:
            return "Upgrade to FocusGlobe Pro to unlock \(sky.name)."
        case .invite(let n):
            return "Invite \(n) friend\(n == 1 ? "" : "s") or upgrade to FocusGlobe Pro to unlock \(sky.name)."
        case .focusMinutes(let n):
            return "Focus \(n.formatted()) minutes or upgrade to FocusGlobe Pro to unlock \(sky.name)."
        case .streakDays(let n):
            return "Reach a \(n)-day streak or upgrade to FocusGlobe Pro to unlock \(sky.name)."
        case .free:
            return "Fly \(sky.name) any time."
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
