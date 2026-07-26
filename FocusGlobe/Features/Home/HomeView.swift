import Foundation
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
    @Environment(\.focusViewport) private var viewport
    @StateObject private var viewModel = HomeViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview
    /// Non-invasive review-prompt tracking (persisted in UserDefaults): every 3rd
    /// genuine return to Home we may ask Apple to show its review prompt.
    @AppStorage("home.visitCount") private var homeVisitCount = 0
    @AppStorage("home.lastReviewPromptAt") private var lastReviewPromptAt = 0.0
    @State private var showSetup = false
    @State private var showPreview = false
    @State private var balloonFloat: CGFloat = 0
    @State private var streakPulse = false
    /// True while an arrow tap is animating into a sentinel wrap page (the tap
    /// normalises the index itself; the pager onChange must not double-jump).
    @State private var arrowWrapping = false
    /// Drives the Resume tab's one-time rise from behind Start Focus.
    @State private var resumeTabIn = false
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
    /// One stable clock is shared by every carousel page, including sentinels.
    /// Swiping or silently normalising a circular wrap never restarts a Sky.
    @State private var homeSkyClockOrigin = ProcessInfo.processInfo.systemUptime

    private var currentSky: FocusSky {
        FocusSky.all[max(0, min(FocusSky.all.count - 1, skyIndex))]
    }
    private var currentSkyUnlocked: Bool { appModel.isSkyUnlocked(currentSky) }
    /// The Resume tab may ONLY appear when the main CTA is the real "Start Focus"
    /// action (an unlocked Sky). On a locked Sky the CTA is a Preview button, and
    /// a resume tab hanging off a preview would be nonsensical — so it's hidden.
    private var showResumeTab: Bool { appModel.resumableJourney != nil && currentSkyUnlocked }

    /// The selected page runs the full production cadence, its circular
    /// neighbours retain the complete scene at a reduced cadence, and far
    /// offscreen pages hold a rich settled frame.
    private func pageQuality(_ index: Int) -> SkyRenderQuality {
        guard !reduceMotion else { return .still }
        let n = FocusSky.all.count
        guard n > 0 else { return .still }
        let a = ((index % n) + n) % n
        let b = ((skyIndex % n) + n) % n
        let d = abs(a - b)
        switch min(d, n - d) {
        case 0: return .full
        case 1: return .reduced
        default: return .still
        }
    }

    private var homeSkyElapsed: () -> Double {
        { ProcessInfo.processInfo.systemUptime - homeSkyClockOrigin }
    }

    private func homeSky(_ sky: FocusSky, page index: Int) -> some View {
        let quality = pageQuality(index)
        return SkyFlightSceneView(
            sky: sky,
            elapsed: homeSkyElapsed,
            animated: quality != .still,
            seed: 0x484F4D45,
            presentationMode: .homeSelector,
            renderQuality: quality
        )
    }

    var body: some View {
        ZStack {
            // The Sky pager IS the background: swiping travels between Skies.
            // Sentinel pages at both ends (a copy of the last Sky before the
            // first, and of the first after the last) make the carousel truly
            // CIRCULAR: swiping past either end lands on identical content, then
            // the selection is silently normalised with animations disabled — no
            // visible jump, flash or reset, and the dots stay in step.
            // Only the visible page AND its circular neighbours animate — any
            // page that can slide on screen mid-swipe shares the same live
            // clock (so nothing ever snaps in view), while far pages render a
            // still frame and never steal frame budget from taps. Far pages
            // only switch modes while fully off screen.
            TabView(selection: $skyIndex) {
                if let last = FocusSky.all.last {
                    homeSky(last, page: -1)
                        .id("sky-page-leading-\(last.id)")
                        .tag(-1)
                        .ignoresSafeArea()
                }
                ForEach(Array(FocusSky.all.enumerated()), id: \.element.id) { index, sky in
                    homeSky(sky, page: index)
                        .id("sky-page-\(sky.id)")
                        .tag(index)
                        .ignoresSafeArea()
                }
                if let first = FocusSky.all.first {
                    homeSky(first, page: FocusSky.all.count)
                        .id("sky-page-trailing-\(first.id)")
                        .tag(FocusSky.all.count)
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
                // The top controls are the ONE part of the Home chrome that
                // follows the REAL appearance: a warm-white surface + dark
                // glyphs by day, a premium translucent glass by night — via the
                // shared `homeControl*` tokens (no scattered scheme checks).
                topBar
                // Everything that sits DIRECTLY on the always-dark Sky —
                // greeting, Sky name, the Start Focus pill — is pinned to DARK
                // so it reads light-on-sky (and Start Focus stays the signature
                // white pill) in both appearances. Sheets/popups are presented
                // outside this scope and keep the user's chosen appearance.
                greetingBlock
                    .environment(\.colorScheme, .dark)
                Spacer()
                bottomCluster
                    .environment(\.colorScheme, .dark)
            }
            .frame(maxWidth: viewport.homeContentWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, viewport.pagePadding)
            .padding(.bottom, max(AppSpacing.lg, viewport.pagePadding * 0.62))
            .opacity(handingOff ? 0 : 1)
        }
        .animation(.easeOut(duration: 0.3), value: handingOff)
        .focusScreenChrome()
        // Home's Sky is ALWAYS dark, so the status bar must be light content in
        // both appearances — in Light Mode the system would otherwise draw black
        // icons over the night sky. Screen-scoped: other tabs keep their
        // appearance-dependent status bar.
        .lightStatusBar()
        .onAppear {
            if !didInitSky {
                skyIndex = FocusSky.all.firstIndex(of: appModel.selectedSky) ?? 0
                didInitSky = true
            }
            presentHomeAutoPopup()
            maybeRequestReview()
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) { balloonFloat = -10 }
            if appModel.progress.currentStreak > 0 {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { streakPulse = true }
            }
        }
        // Travelling the pager: a soft haptic, and unlocked Skies become the
        // active choice immediately (locked ones stay preview-only). Landing on
        // a SENTINEL page (the circular wrap) normalises to the real index with
        // animations disabled once the page has settled — the content is
        // pixel-identical, so nothing visibly moves; sentinels never select a
        // Sky, fire analytics or persist anything.
        .onChange(of: skyIndex) { _, new in
            guard didInitSky else { return }
            let n = FocusSky.all.count
            if new == -1 || new == n {
                guard !arrowWrapping else { return }   // the arrow tap normalises itself
                let target = new == -1 ? n - 1 : 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    guard skyIndex == new else { return }
                    var t = Transaction(); t.disablesAnimations = true
                    withTransaction(t) { skyIndex = target }
                }
                return
            }
            appModel.haptics.tap()
            if currentSkyUnlocked { appModel.selectSky(currentSky) }
        }
        .fullScreenCover(isPresented: $showSetup, onDismiss: launchPendingFlight) {
            FlightSetupView(focusSky: currentSkyUnlocked ? currentSky : appModel.selectedSky,
                            onTakeOff: beginTakeOff)
                // The canonical FocusOnlineModel MUST cross this presentation
                // boundary explicitly: a full-screen cover on Mac (Designed for
                // iPad) is hosted separately and does NOT inherit the WindowGroup
                // root's environment objects, so `FlightModeSelectorView` (which
                // reads `online.availability`) would crash without it. Same
                // instance as everywhere else — never a second model.
                .environmentObject(appModel).environmentObject(router).environmentObject(online)
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
        // Streak, Coin Spin and the Coins Boost gift now present through the ONE
        // app-wide modal coordinator (see `AppRouter.activeModal`) so Home never
        // owns competing sheets.
    }

    // MARK: Ticket → flight hand-off (no Home flash)

    /// Called from inside the setup ritual the instant the ticket validates.
    /// Hides the Home chrome first (so nothing can pop in behind the dismissing
    /// cover), stashes the flight, then dismisses the setup cover.
    private func beginTakeOff(route: Route, intention: String?) {
        pendingTakeoff = (route, intention)
        handingOff = true
        // Raise the opaque curtain BEFORE the setup cover dismisses: the gap
        // between the two presentation layers shows the flight's own sky —
        // never Home, never a dark interstitial.
        router.raiseTakeoffCurtain(skyID: FocusSky.matching(routeID: route.id)?.id)
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
        router.raiseTakeoffCurtain(skyID: FocusSky.matching(routeID: journey.route.id)?.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            router.activeJourney = journey
        }
    }

    /// Every 3rd genuine return to Home, ask StoreKit to consider showing the
    /// system review prompt — never during onboarding, an active/ resumable
    /// flight, or while the paywall is up. Apple may still choose not to show it.
    private func maybeRequestReview() {
        guard !router.showPaywall, router.activeJourney == nil,
              appModel.resumableJourney == nil else { return }
        homeVisitCount += 1
        guard homeVisitCount % 3 == 0 else { return }
        let now = Date().timeIntervalSince1970
        // Don't ask again within ~30 days of the last prompt.
        if lastReviewPromptAt > 0, now - lastReviewPromptAt < 60 * 60 * 24 * 30 { return }
        lastReviewPromptAt = now
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { requestReview() }
    }

    /// Home auto-presents AT MOST ONE popup per appearance, decided in a single
    /// synchronous pass with a strict priority (launch paywall > Coins Boost
    /// gift), so the paywall sheet and the boost sheet can never contend for
    /// the one presentation slot (the old flash-then-swap flicker: the intro
    /// marked itself "seen" immediately but presented 0.6 s later, which let
    /// the boost's guard pass and its 1.0 s sheet tear the paywall down
    /// mid-animation). A boost skipped in favour of the paywall is NOT
    /// throttled away — it simply waits for the next eligible Home visit. The
    /// boost also re-checks at fire time in case another path (deep link,
    /// locked-Sky tap) raised the paywall during its delay.
    private func presentHomeAutoPopup() {
        guard appModel.resumableJourney == nil, !router.showPaywall else { return }
        if appModel.shouldShowPremiumIntro {
            appModel.markPremiumIntroSeen()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                router.presentPaywall()
            }
        } else if appModel.shouldOfferCoinBoost {
            appModel.markCoinBoostOffered()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                guard router.activeModal == nil, router.activeJourney == nil else { return }
                router.present(.coinBoostGift)
            }
        }
    }

    // MARK: Top bar — streak ember (left) · coins + premium (right)

    // One coherent circular control family (streak · reward spin · PRO), with
    // Focus Coins as the matching expandable capsule — never four unrelated
    // pill shapes. All targets ≥ 44 pt.
    private var topBar: some View {
        HStack(alignment: .center, spacing: AppSpacing.xs) {
            StreakCircleButton(streak: appModel.progress.currentStreak,
                               pulsing: streakPulse,
                               size: viewport.navigationControlSize) {
                appModel.tapFeedback(); router.present(.streak)
            }
            CoinSpinCircleButton(size: viewport.navigationControlSize) {
                appModel.tapFeedback(); router.present(.coinSpin)
            }
            Spacer()
            coinsChip
            StatusCircleButton(size: viewport.navigationControlSize,
                               ring: appModel.isPro ? AppColors.gold.opacity(0.42) : nil,
                               accessibilityText: appModel.isPro
                                ? "FocusGlobe PRO is active"
                                : "Unlock FocusGlobe PRO") {
                appModel.tapFeedback()
                router.presentPaywall(context: .general)
            } content: {
                Image(systemName: "crown.fill")
                    .font(.system(size: viewport.navigationControlSize * 0.38, weight: .bold))
                    .foregroundStyle(ProBrand.gradient)
            }
            .shadow(color: ProBrand.glow.opacity(0.30), radius: 8, y: 0)
        }
        .padding(.top, AppSpacing.xs)
    }

    /// Focus Coins — the one member of the family that expands horizontally
    /// (balances grow to many digits) while sharing the same glass language.
    private var coinsChip: some View {
        Button { appModel.tapFeedback(); router.openStore() } label: {
            HStack(spacing: 5) {
                FocusCoinIcon(size: viewport.navigationControlSize * 0.45)
                Text(Formatters.miles(appModel.focusCoins))
                    .font(.system(size: viewport.bodySize - 1, weight: .heavy, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(AppColors.homeControlGlyph)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(.leading, viewport.kind == .wide ? 13 : 10)
            .padding(.trailing, viewport.kind == .wide ? 16 : 12)
            .frame(height: viewport.navigationControlSize)
            .background {
                FocusLiquidGlassSurface(
                    shape: Capsule(),
                    tint: AppColors.homeControlFill,
                    tintOpacity: 0.52
                )
            }
        }
        .buttonStyle(SoftPressStyle(scale: 0.94))
        .accessibilityLabel("\(appModel.focusCoins) Focus Coins. Opens the Store.")
    }

    // MARK: Greeting + selected Sky

    /// The refined greeting: a smaller contextual daypart line, and — only when
    /// the pilot gave a REAL preferred name — their name beneath with stronger
    /// emphasis. No blank second line, never the generated online alias.
    private var greetingBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(viewModel.greeting + (preferredName != nil ? "," : ""))
                .font(.system(size: viewport.titleSize - 8, weight: .medium, design: .serif))
                .foregroundStyle(.white.opacity(preferredName != nil ? 0.82 : 1))
            if let preferredName {
                Text(preferredName)
                    .font(.system(size: viewport.titleSize + 8, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, AppSpacing.sm)
        .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
        .animation(.easeInOut(duration: 0.3), value: viewModel.greeting)
        .accessibilityElement(children: .combine)
    }

    /// A REAL user-provided name only (set in Settings) — trimmed, and never
    /// the auto-generated Sky-pilot alias.
    private var preferredName: String? {
        guard let raw = appModel.profile.name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        return raw
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

    /// Move one Sky in either direction. A wrap ANIMATES into the adjacent
    /// sentinel page (identical content to the far end), then silently
    /// normalises the index with animations disabled — so last → first and
    /// first → last look exactly like any other page turn.
    private func stepSky(_ delta: Int) {
        let n = FocusSky.all.count
        guard n > 0 else { return }
        let target = skyIndex + delta
        if target == -1 || target == n {
            appModel.haptics.bubble()
            arrowWrapping = true
            withAnimation(.easeInOut(duration: 0.35)) { skyIndex = target }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { skyIndex = (target == -1 ? n - 1 : 0) }
                arrowWrapping = false
            }
        } else {
            withAnimation(.easeInOut(duration: 0.35)) { skyIndex = max(0, min(n - 1, target)) }
        }
    }

    private func edgeArrow(system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: viewport.navigationControlSize * 0.40, weight: .bold))
                // The shared adaptive control surface: a warm-white disc + dark
                // chevron by day, a premium translucent glass disc by night.
                // (This sits OUTSIDE any force-dark chrome, so the `homeControl`
                // tokens resolve to the pilot's real appearance.)
                .foregroundStyle(AppColors.homeControlGlyph)
                .frame(width: viewport.navigationControlSize, height: viewport.navigationControlSize)
                .background {
                    FocusLiquidGlassSurface(
                        shape: Circle(),
                        tint: AppColors.homeControlFill,
                        tintOpacity: 0.52
                    )
                }
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
                        .font(.system(size: viewport.titleSize - 3, weight: .semibold, design: .serif))
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

            // A subtle tag while a Coins Boost is armed, sitting just above the
            // Start Focus button so the pilot sees it before flying.
            if appModel.isCoinBoostArmed {
                CoinBoostTag().environmentObject(appModel)
            }

            // Start Focus stays THE action; a resumable flight appears as a small
            // tab rising from BEHIND its upper edge — one attached action area,
            // both independently tappable, no stacked second card.
            ZStack(alignment: .top) {
                if showResumeTab {
                    resumeTab
                        .offset(y: resumeTabIn ? -Layout.pad(34, 38) : 0)
                        .opacity(resumeTabIn ? 1 : 0)
                        .zIndex(0)
                }
                Group {
                    if currentSkyUnlocked {
                        AppPrimaryButton(title: "Start Focus", systemImage: "arrow.up", iconTrailing: true) {
                            appModel.tapFeedback()
                            appModel.selectSky(currentSky)
                            showSetup = true
                        }
                    } else {
                        lockedCTA
                    }
                }
                .zIndex(1)
            }
            .padding(.top, showResumeTab ? Layout.pad(30, 34) : 0)
            .onAppear { riseResumeTab() }
            .onChange(of: showResumeTab) { _, has in
                if has { resumeTabIn = false; riseResumeTab() } else { resumeTabIn = false }
            }
        }
    }

    /// Animate the Resume tab into view once Home has settled — a short premium
    /// spring (instant under Reduce Motion), never replayed by unrelated state.
    private func riseResumeTab() {
        guard showResumeTab, !resumeTabIn else { return }
        if reduceMotion { resumeTabIn = true; return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { resumeTabIn = true }
        }
    }

    /// The compact Resume tab that peeks from behind Start Focus.
    private var resumeTab: some View {
        Button {
            appModel.tapFeedback()
            continueResumableJourney()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.uturn.up")
                    .font(.system(size: 11, weight: .heavy))
                Text("Resume your flight")
                    .font(.system(size: 13, weight: .bold, design: .default))
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .opacity(0.7)
            }
            .foregroundStyle(Color(hex: 0x2B2510))
            .padding(.horizontal, 16)
            .padding(.top, 9)
            // Taller than its visible lip: the lower part stays tucked behind
            // the Start Focus capsule, so the tab reads as attached to it.
            .frame(height: Layout.pad(34, 38) + 16, alignment: .top)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 0,
                                       bottomTrailingRadius: 0, topTrailingRadius: 14,
                                       style: .continuous)
                    .fill(AppColors.gold)
            )
        }
        .buttonStyle(SoftPressStyle(scale: 0.97))
        .accessibilityLabel("Resume your unfinished flight")
    }

    /// One dot per Sky, the selected one stretched into a gold capsule. The
    /// index is normalised so the sentinel wrap pages light the correct dot.
    private var skyDots: some View {
        let n = max(1, FocusSky.all.count)
        let current = ((skyIndex % n) + n) % n
        return HStack(spacing: 5) {
            ForEach(FocusSky.all.indices, id: \.self) { i in
                Capsule()
                    .fill(i == current ? AppColors.gold : .white.opacity(0.30))
                    .frame(width: i == current ? 16 : 5, height: 5)
            }
        }
    }

    // The former "N users focusing now" island was removed from Home — the live
    // activity now lives inside the Online card on Choose your Flight, keeping
    // Home focused on the Sky, the hero balloon and the main action.

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
                    .font(.system(size: Layout.pad(17, 19), weight: .bold, design: .default))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(Color(hex: 0x14120E))
            .frame(maxWidth: .infinity)
            .frame(height: Layout.pad(56, 64))
            .background(Capsule(style: .continuous).fill(Color(hex: 0xF4EFE4)))
            .overlay(Capsule(style: .continuous)
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
            // A LOCKED-Sky preview shows only the Sky and the pilot's OWN balloon:
            // no public/ambient pilots or labels here (real Global journeys and
            // Private participants are unaffected — this is a preview, not a room).
            SkyFlightSceneView(
                sky: sky,
                elapsed: previewElapsed,
                animated: !reduceMotion,
                presentationMode: .lockedPreview,
                renderQuality: reduceMotion ? .still : .full
            )
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
                AppIconButton(systemImage: "xmark", size: 44, tint: .white,
                              accessibilityLabel: "Close") {
                    appModel.tapFeedback()
                    dismiss()
                }
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
                .font(.system(size: Layout.pad(14, 16), weight: .medium, design: .default))
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

    /// A focus-minutes Sky is pure free progression (earned by focusing), so its
    /// preview leads with the progress and shows NO PRO call-to-action.
    private var isFreeMinutesSky: Bool {
        if case .focusMinutes = sky.unlockRequirement { return true }
        return false
    }

    private var actions: some View {
        VStack(spacing: AppSpacing.sm) {
            if isFreeMinutesSky {
                // Fiji Lagoon (and any focus-minute Sky): the progress IS the hero;
                // never a PRO upsell.
                secondaryButton
                softSecondary(title: "Keep focusing") { dismiss() }
            } else {
                AppPrimaryButton(title: "Unlock FocusGlobe PRO", systemImage: "sparkles") {
                    appModel.tapFeedback()
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.presentPaywall(context: .sky) }
                }
                if isPremiumOnly {
                    softSecondary(title: "Maybe later") { dismiss() }
                } else {
                    Text("or")
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundStyle(.white.opacity(0.6))
                    secondaryButton
                }
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
                .font(.system(size: 15, weight: .semibold, design: .default))
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
                Text(title).font(.system(size: 15, weight: .bold, design: .default))
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
        case "fiji-lagoon":      return ["Focus above the lagoon", "Turquoise calm for deep work", "Unlock this Sky to fly here"]
        case "kyoto-lanterns":   return ["Study among the lanterns", "A quiet Kyoto evening", "Unlock this Sky to fly here"]
        case "aurora-snowfield": return ["Focus under the aurora", "Northern lights for deep work", "Unlock this Sky to fly here"]
        case "rainy-tokyo":      return ["Study over rainy Tokyo", "Neon calm and soft rain", "Unlock this Sky to fly here"]
        case "swiss-alps":       return ["Study above the Alps", "Crisp mountain air for focus", "Unlock this Sky to fly here"]
        case "sahara-night":     return ["Focus under desert stars", "A vast night made for depth", "Unlock this Sky to fly here"]
        case "galaxy-drift":     return ["Focus among the stars", "Drift through falling starlight", "Unlock this Sky to fly here"]
        case "deep-space":       return ["Study in deep space", "Cosmic silence for deep work", "Unlock this Sky to fly here"]
        default:                 return ["Focus in \(sky.name)", "A Sky made for deep work", "Unlock this Sky to fly here"]
        }
    }

    private var subtitle: String {
        switch sky.unlockRequirement {
        case .premium:
            return "Upgrade to FocusGlobe PRO to unlock \(sky.name)."
        case .invite(let n):
            return "Invite \(n) friend\(n == 1 ? "" : "s") or upgrade to FocusGlobe PRO to unlock \(sky.name)."
        case .focusMinutes(let n):
            return "Focus \(n.formatted()) minutes to unlock \(sky.name) — free, just keep flying."
        case .streakDays(let n):
            return "Reach a \(n)-day streak or upgrade to FocusGlobe PRO to unlock \(sky.name)."
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
                    AppPrimaryButton(title: "Continue flight", systemImage: "arrow.up", iconTrailing: true) { onContinue() }
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
