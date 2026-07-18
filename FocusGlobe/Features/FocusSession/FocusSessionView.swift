import Foundation
import SwiftUI

/// Hosts the live focus session and, on completion, the completion screen —
/// both inside the same full-screen cover so the flight stays seamless.
struct FocusSessionContainerView: View {
    let journey: Journey
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var online: FocusOnlineModel
    @StateObject private var vm: FocusSessionViewModel
    /// The Online-only "pilots are joining" moment shown over the freshly
    /// mounted flight (Solo skips it entirely). It always completes — min beat,
    /// pilot fetch, or hard timeout — so it can never deadlock navigation.
    @State private var joining = false
    @State private var decidedJoining = false

    init(journey: Journey) {
        self.journey = journey
        _vm = StateObject(wrappedValue: FocusSessionViewModel(journey: journey))
    }

    var body: some View {
        ZStack {
            if vm.didLand, let summary = vm.landingSummary {
                LandingView(summary: summary)
                    .transition(.opacity)
            } else {
                FocusSessionView(vm: vm)
                    .transition(.opacity)
            }
            if joining {
                OnlineJoiningView(mode: joiningMode) {
                    withAnimation(.easeInOut(duration: 0.45)) { joining = false }
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .onAppear {
            vm.attach(appModel: appModel)
            vm.startIfNeeded()
            // Decide the joining phase exactly once per cover: ONLINE journeys
            // (host or invited guest) get the connection moment; Solo never.
            if !decidedJoining {
                decidedJoining = true
                joining = online.flightMode.isOnline
            }
            // The journey surface is mounted — the take-off curtain (raised at
            // the Boarding cut so Home can never flash) comes down beneath us.
            router.lowerTakeoffCurtain()
        }
        .onDisappear { vm.tearDown() }
    }

    private var joiningMode: OnlineJoiningView.Mode {
        if journey.sharedEndsAt != nil || online.isPrivateFlight {
            return .privateGuest(hostAlias: nil)
        }
        return .global(FocusSky.matching(routeID: journey.route.id) ?? FocusSky.byID(appModel.selectedSky.id))
    }
}

/// The **Active Flight** — the main focus screen. No maps: a huge procedural
/// sky is the protagonist, and a small white balloon slowly rises through it as
/// the session progresses. UI is sparse: a status pill, time + distance
/// readouts, a pause button, and a quiet exit. The timer/persistence engine
/// (`FocusSessionViewModel`) is unchanged.
struct FocusSessionView: View {
    @ObservedObject var vm: FocusSessionViewModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var balloonSway: CGFloat = 0
    @State private var balloonBob: CGFloat = 0
    /// A slow lateral breeze the balloon rides, layered on the faster sway.
    @State private var balloonDrift: CGFloat = 0
    /// Take-off: 0 = resting low near the terrain, 1 = risen to the cruising
    /// centre. Eased up once on appear, then the balloon steady-follows.
    @State private var takeoffLift: CGFloat = 0
    @State private var uiIn = false
    /// Invite Friends → one fresh link handed straight to the iOS share sheet
    /// (no intermediate custom UI). Promotes a Global Flight to Private in place.
    @State private var shareInviteURL: URL?
    /// The one lobby (participants roster) for the active Private Flight.
    @State private var showLobby = false
    /// In-flight guard so a double tap can't mint two links / two rooms.
    @State private var invitePreparing = false
    /// The single compact flight-controls panel (replaces the old button cluster).
    @State private var showControlsPanel = false
    /// Clean mode: hide chrome down to a tiny timer + a reveal button.
    @State private var cleanMode = false
    /// FocusGlobe Online: the real pilot whose (compact) profile sheet is open —
    /// opened only from a deliberate action, never a normal in-flight tap.
    @State private var selectedRealPilot: OnlinePilot? = nil
    /// A transient social confirmation ("Request sent", etc.) shown as a pill.
    @State private var socialNote: String? = nil
    @EnvironmentObject private var online: FocusOnlineModel

    /// True while this is an Online (public or private) flight. A Solo flight
    /// renders no pilots, publishes nothing, and hides every social control.
    private var isOnlineFlight: Bool { online.flightMode.isOnline }
    /// Private-room participants get persistent identity bubbles (hidden in
    /// Clean Mode to keep it minimal).
    /// Persistent social labels (YOU + alias/countdown bubbles) are on for
    /// EVERY online flight — Global and Private alike; Solo never shows them.
    /// Clean Mode hides them with the rest of the chrome.
    private var roomBubbleMode: Bool { isOnlineFlight && !cleanMode }

    private func quickAddFriend(_ pilot: OnlinePilot) {
        appModel.tapFeedback()
        Task { @MainActor in
            let note = await online.sendFriendRequest(to: pilot)
            socialNote = note ?? "Request sent"
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if socialNote != nil { withAnimation { socialNote = nil } }
        }
    }
    private func quickBlock(_ pilot: OnlinePilot) {
        appModel.tapFeedback()
        appModel.hidePilot(pilot.id)
        Task { @MainActor in _ = await online.blockPilot(pilot) }
    }

    /// Real pilots for this flight (hidden ones filtered locally). Decorative
    /// ambient pilots fill the remaining visual capacity inside the layer.
    private var visibleRealPilots: [OnlinePilot] {
        let hidden = appModel.profile.hiddenPilotIDs ?? []
        return online.realPilots.filter { !hidden.contains($0.id) }
    }
    /// Invite Friends: promote a Global Flight into a Private Flight in place —
    /// no restart, same timer/sky/sound/shield — then hand ONE fresh single-use
    /// link to the native iOS share sheet. If already private, just shares a new
    /// link. In-flight guarded so a double tap can't create two rooms/links.
    private func inviteFriends() async {
        guard isOnlineFlight, !invitePreparing else { return }
        invitePreparing = true
        let skyID = (matchedSky ?? appModel.selectedSky).id
        // Creates/reuses the private-flight record and mints one fresh link —
        // the flight STAYS Global until a real pilot joins.
        if let url = await online.prepareInvite(skyID: skyID) {
            shareInviteURL = url
        }
        invitePreparing = false
    }
    /// True while the give-up button is being held. Used only to fade the centre
    /// watermark on compact iPhone so the expanding capsule never crowds it.
    @State private var holdingGiveUp = false
    @Environment(\.horizontalSizeClass) private var hSize
    /// The "Playing …" soundscape toast shown briefly at take-off.
    @State private var soundToastVisible = false
    /// The wall-clock anchor for everything the pilot sees. Captured **once** on
    /// appear (resume-aware); shifted forward when a pause ends so paused time
    /// never counts. Never touched inside `body`.
    @State private var flightStartedAt: Date?
    /// Set while paused so the display clock holds still.
    @State private var pausedAt: Date?

    /// Which face of the flight the pilot is looking at: the exterior sky world,
    /// or the cozy cabin interior. Presentation only — never affects timing.
    private enum FlightViewMode { case exterior, cabin }
    @State private var viewMode: FlightViewMode = .exterior

    private var isInfinity: Bool { FlightRouteFactory.isInfinity(vm.route) }
    private var durationSeconds: Double { Double(vm.route.durationMinutes) * 60.0 }

    // MARK: The display clock — pure wall-clock arithmetic, no publishers.

    private func displayElapsed(at now: Date) -> Double {
        guard let start = flightStartedAt else { return 0 }
        let effective = pausedAt ?? now
        return max(0, effective.timeIntervalSince(start))
    }

    /// The per-session world seed: fixed once the flight anchors, so the world
    /// order and dressing are stable in-session but fresh every flight.
    @State private var worldSeed: UInt64 = 1

    /// The selected Sky, recovered from the route id (the Sky id is embedded
    /// there, so this survives resume). Drives the whole flight's identity:
    /// its chapter family, its weather, and the cabin window.
    private var matchedSky: FocusSky? {
        FocusSky.matching(routeID: vm.route.id)
    }

    var body: some View {
        ZStack {
            // The vertical world journey — a constant cinematic pace driven by
            // elapsed focus time (pause-aware), fully decoupled from the chosen
            // duration. 1-minute flights drift calmly; 12-hour flights keep
            // evolving; endless flights never run out of sky.
            switch viewMode {
            case .exterior:
                ActiveFlightJourneyWorldView(elapsed: { displayElapsed(at: Date()) },
                                             seed: worldSeed,
                                             animated: !reduceMotion,
                                             focusSky: matchedSky)
                    .transition(.opacity)
                // A Solo flight is truly solo: NO other balloons (real or
                // decorative). Online (public/private) keeps the living Sky.
                if isOnlineFlight {
                    AmbientPilotsLayer(skyID: matchedSky?.id ?? "classic",
                                       elapsed: { displayElapsed(at: Date()) },
                                       animated: !reduceMotion,
                                       realPilots: visibleRealPilots,
                                       roomMode: roomBubbleMode,
                                       isPrivate: online.isPrivateFlight,
                                       onSelectReal: { selectedRealPilot = $0 },
                                       onAddFriend: quickAddFriend,
                                       onHide: { appModel.hidePilot($0.id) },
                                       onBlock: quickBlock,
                                       onReport: { selectedRealPilot = $0 })
                        .transition(.opacity)
                }
                balloon
                    .transition(.opacity)
            case .cabin:
                CabinView(elapsed: { displayElapsed(at: Date()) },
                          seed: worldSeed,
                          animated: !reduceMotion,
                          focusSky: matchedSky,
                          showPilots: isOnlineFlight,
                          realPilots: visibleRealPilots,
                          roomMode: roomBubbleMode,
                          isPrivate: online.isPrivateFlight,
                          equippedItemIDs: appModel.profile.equippedCabinItemIDs ?? [])
                    .transition(.opacity)
            }

            // Soft bottom scrim so the readouts stay legible over bright bands.
            VStack {
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 200)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Paused: gently dim the living world and show a large, calm pause
            // mark so the state is unmistakable. The timer + Resume control sit
            // above it and stay bright.
            if vm.isPaused {
                pausedOverlay
            }

            if cleanMode {
                cleanModeChrome.opacity(uiIn ? 1 : 0)
            } else {
                topControls.opacity(uiIn ? 1 : 0)
                bottomBar.opacity(uiIn ? 1 : 0)
            }

            if soundToastVisible {
                soundToast
                    .transition(.opacity.combined(with: .offset(y: -8)))
            }

            if showControlsPanel {
                flightControlsOverlay
            }
        }
        .animation(.easeInOut(duration: 0.35), value: vm.isPaused)
        .animation(.easeInOut(duration: 0.4), value: soundToastVisible)
        // The engine heartbeat (display never depends on it): refresh the session
        // engine and land a finite flight the moment it is due. `.task` is
        // lifecycle-bound — it cancels itself when the flight screen goes away.
        .task {
            vm.startIfNeeded()   // idempotent belt-and-braces after the container
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                vm.refresh()
                if !isInfinity { vm.finishIfDue() }
            }
        }
        // Pause holds the display clock; resuming shifts the anchor forward by
        // exactly the paused span, so paused minutes never count as focus.
        .onChange(of: vm.isPaused) { _, paused in
            if paused {
                pausedAt = Date()
            } else if let resumedFrom = pausedAt {
                flightStartedAt = flightStartedAt?.addingTimeInterval(Date().timeIntervalSince(resumedFrom))
                pausedAt = nil
            }
        }
        .confirmationDialog("Leave this flight?",
                            isPresented: $vm.showCancelConfirm,
                            titleVisibility: .visible) {
            Button("Leave", role: .destructive) {
                vm.confirmCancel()
                // A terminated real flight (given up / Hold-to-leave) uses the
                // journey's single post-flight ad opportunity: one closable
                // interstitial for non-Pro users, then Home. AdService no-ops
                // for Pro or when no ad is loaded.
                if appModel.postFlightAdSatisfied {
                    router.finishToHome()
                } else {
                    appModel.postFlightAdSatisfied = true
                    appModel.ads.presentJourneyCompleteInterstitial(isPro: appModel.isPro) {
                        router.finishToHome()
                    }
                }
            }
            Button("Keep flying", role: .cancel) { vm.dismissCancel() }
        } message: {
            Text("You'll lose this flight's progress: no Focus Coins earned, today's missions won't count it, and your streak only grows when you land. You can resume from Home.")
        }
        .overlay(alignment: .top) {
            if online.reconnecting && online.flightMode.isOnline {
                Text("Reconnecting…")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .padding(.top, 60)
                    .transition(.opacity)
            }
        }
        // "<alias> joined" — a subtle glass pill, auto-dismissing, once per real
        // join (never for the current user, reconnects, or decorative pilots).
        .overlay(alignment: .top) {
            if let alias = online.joinToastAlias, isOnlineFlight {
                HStack(spacing: 7) {
                    Image(systemName: "person.fill.badge.plus")
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(AppColors.gold)
                    Text("\(alias) joined")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 13).padding(.vertical, 8)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                .padding(.top, 96)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: alias) {
                    try? await Task.sleep(nanoseconds: 2_600_000_000)
                    withAnimation(.easeOut(duration: 0.3)) { online.clearJoinToast() }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let socialNote {
                Text(socialNote)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                    .padding(.bottom, 130)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: online.joinToastAlias)
        .animation(.easeInOut(duration: 0.3), value: socialNote)
        .sheet(item: $selectedRealPilot) { pilot in
            PilotProfileSheet(pilot: pilot)
                .environmentObject(online).environmentObject(appModel)
        }
        // A quiet, elegant applause moment when another pilot applauds ME —
        // auto-dismisses; bursts are throttled in the model.
        .overlay(alignment: .top) {
            if let from = online.applauseFrom {
                HStack(spacing: 8) {
                    Text("👏")
                    Text("\(from) applauds your focus")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().fill(AppColors.gold.opacity(0.22)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
                .padding(.top, 54)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .task {
                    try? await Task.sleep(nanoseconds: 2_600_000_000)
                    withAnimation(.easeOut(duration: 0.35)) { online.clearApplause() }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: online.applauseFrom)
        // Invite Friends hands ONE link to the native share sheet — no custom UI.
        #if canImport(UIKit)
        .sheet(item: Binding(get: { shareInviteURL.map { FlightShareURL(url: $0) } },
                             set: { shareInviteURL = $0?.url })) { item in
            InviteShareSheet(url: item.url)
        }
        #endif
        // Participants → the ONE lobby, as a live roster of the Private Flight.
        .sheet(isPresented: $showLobby) {
            if let room = online.pendingRoom {
                OnlineLobbyView(room: room, asParticipants: true)
                    .environmentObject(online).environmentObject(appModel)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:                vm.refresh()
            case .inactive, .background: vm.persistForResume()
            @unknown default:            break
            }
        }
        .onAppear {
            // Anchor the display clock exactly once. Seeding from the engine's
            // live elapsed makes a resumed flight continue from the right point;
            // a fresh flight anchors at now.
            if flightStartedAt == nil {
                let anchor = Date().addingTimeInterval(-vm.timer.liveElapsed)
                flightStartedAt = anchor
                // Seed the world from the anchor: stable for this session,
                // different for every flight.
                worldSeed = UInt64(bitPattern: Int64(anchor.timeIntervalSince1970 * 1000))
            }
            // The controls surface a beat after the world, so entering the
            // flight reads as arriving in a place, not loading a screen.
            withAnimation(.easeOut(duration: 0.8).delay(reduceMotion ? 0 : 0.25)) { uiIn = true }
            // "Playing 'Wind'" — a quiet confirmation that the soundscape is on.
            if appModel.settings.soundEnabled && !vm.isAudioMuted {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { soundToastVisible = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) { soundToastVisible = false }
            }
            guard !reduceMotion else { takeoffLift = 1; return }
            // The cinematic take-off pull-back: ~3.2 s (present but never slow)
            // to ease the balloon from close-and-low up to its cruising size and
            // centre. Then an endless gentle breathe (sway + bob) and slow drift.
            withAnimation(.easeInOut(duration: 3.2)) { takeoffLift = 1 }
            // Calm 4–7s idle rhythm: a noticeable ~10pt vertical bob with a very
            // subtle sway/rotation and slow lateral drift — a breath, not a shake.
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) { balloonSway = 5 }
            withAnimation(.easeInOut(duration: 4.4).repeatForever(autoreverses: true)) { balloonBob = -10 }
            withAnimation(.easeInOut(duration: 7.5).repeatForever(autoreverses: true)) { balloonDrift = 6 }
        }
    }

    // The balloon is **tiny** (~7% of screen height) and stays roughly still,
    // just breathing with a gentle sway + bob. The world tape scrolls *downward*
    // behind it (see `ActiveFlightJourneyWorldView`), so the balloon reads as rising
    // while the landscape — not the balloon — is the protagonist.
    private var balloon: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let balloonSize = max(38, min(52, h * 0.07))   // 5–8% of screen height
            // Take-off camera: the balloon begins close and large, low near the
            // ground, then the "camera" pulls smoothly back — it shrinks to its
            // cruising size and rises to centre as `takeoffLift` eases 0→1. After
            // that it just breathes (sway + bob + drift).
            let restY = h * (0.82 - 0.32 * takeoffLift)
            let takeoffScale = 1 + (1 - takeoffLift) * 1.4
            ZStack {
                // The hero renders through the EXACT same BalloonView component,
                // size and glow as every other pilot — showing the user's own
                // equipped skin — so no balloon is larger, brighter or sharper
                // than another. Only its position (screen centre) differs. The
                // extra shadow is a take-off ground shadow that fades to zero at
                // cruise, leaving the same baked shadow every balloon shares.
                BalloonView(height: balloonSize, showBurner: false, showGlow: true,
                            skin: BalloonSkin.skin(id: appModel.equippedSkinIDForOnline))
                    .scaleEffect(takeoffScale)
                    .rotationEffect(.degrees(Double(balloonSway) * 0.6))
                    .offset(x: balloonSway + balloonDrift, y: balloonBob)
                    .position(x: geo.size.width / 2, y: restY)
                    .shadow(color: .black.opacity(0.3),
                            radius: 18 * (1 - takeoffLift), y: 12 * (1 - takeoffLift))
                // The user's own balloon is always labelled exactly "YOU" —
                // never their alias. Hidden in Clean Mode and until take-off.
                if roomBubbleMode && takeoffLift > 0.9 {
                    Text("YOU")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11).padding(.vertical, 5)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .overlay(Capsule().fill(AppColors.gold.opacity(0.28)))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                        .position(x: geo.size.width / 2 + balloonSway + balloonDrift,
                                  y: restY + balloonBob - balloonSize - 16)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Top — exit, state, mute

    private var topControls: some View {
        VStack {
            // The watermark is centred in a ZStack **behind** the button row, so
            // its position is fixed to the screen centre and can never be pushed
            // sideways when the give-up capsule expands (Phase 11). On compact
            // iPhone it fades out while the button is held; iPad/Mac keep it.
            ZStack {
                statusPill
                    .opacity(holdingGiveUp && hSize == .compact ? 0 : 1)
                    .animation(.easeInOut(duration: 0.2), value: holdingGiveUp)
                HStack(alignment: .top) {
                    HoldToGiveUpButton(size: Layout.pad(44, 54),
                                       onHoldingChanged: { holdingGiveUp = $0 }) {
                        appModel.haptics.tap()
                        vm.requestCancel()
                    }
                    Spacer()
                    // One compact controls button replaces the old three-button
                    // cluster — it opens the flight-controls panel below.
                    AppIconButton(systemImage: "slider.horizontal.3",
                                  size: Layout.pad(44, 54), tint: .white,
                                  accessibilityLabel: "Flight controls") {
                        appModel.tapFeedback()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                            showControlsPanel.toggle()
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.top, AppSpacing.xs)
        .transition(.opacity)
    }

    /// A subtle FocusGlobe watermark where the status label used to be — quiet,
    /// low-opacity branding that never competes with the flight.
    private var statusPill: some View {
        Text("FocusGlobe")
            .font(.system(size: Layout.pad(13, 15), weight: .semibold, design: .serif))
            .foregroundStyle(.white.opacity(0.4))
            .tracking(0.5)
            .accessibilityHidden(true)
    }

    // MARK: Paused state — a large, calm, unmistakable pause treatment

    private var pausedOverlay: some View {
        ZStack {
            // A soft dim settles the frozen world so the pause reads instantly.
            Color.black.opacity(0.4).ignoresSafeArea()
            // A single large, semi-transparent pause glyph — no "Paused" label.
            // Tapping it resumes instantly. The world + ambient pilots are already
            // frozen (their motion clock is the paused-aware displayElapsed).
            Button {
                vm.togglePause()
            } label: {
                HStack(spacing: Layout.pad(16, 24)) {
                    Capsule().fill(.white.opacity(0.9))
                        .frame(width: Layout.pad(22, 32), height: Layout.pad(74, 108))
                    Capsule().fill(.white.opacity(0.9))
                        .frame(width: Layout.pad(22, 32), height: Layout.pad(74, 108))
                }
                .shadow(color: .black.opacity(0.45), radius: 22, y: 8)
                .padding(Layout.pad(28, 40))
                .contentShape(Rectangle())
            }
            .buttonStyle(SoftPressStyle(scale: 0.94))
            .offset(y: -Layout.pad(40, 60))   // rest a little above the hero timer
            .accessibilityLabel("Paused. Tap to resume.")
        }
        .transition(.opacity)
    }

    // MARK: Bottom bar — a focus-first hero timer

    // FocusGlobe is a focus timer first, so the remaining time is the single hero
    // at the bottom: large and glanceable, with the controls demoted to a quiet
    // secondary affordance beneath it. (Distance was removed — it isn't the point.)
    private var bottomBar: some View {
        VStack(spacing: 0) {
            Spacer()
            // A half-second TimelineView is the tick: every value is derived from
            // `ctx.date` right here, so the clock can never go stale.
            TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                heroTimer(now: ctx.date)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.screen)
        }
        .padding(.bottom, Layout.pad(30, 46))
        .transition(.opacity)
    }

    // MARK: Clean mode — a tiny timer + a reveal button, nothing else

    private var cleanModeChrome: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    appModel.tapFeedback()
                    withAnimation(.easeInOut(duration: 0.3)) { cleanMode = false }
                } label: {
                    Image(systemName: "eye.fill")
                        .font(.system(size: Layout.pad(15, 18), weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: Layout.pad(40, 48), height: Layout.pad(40, 48))
                        .background(Circle().fill(.ultraThinMaterial))
                        .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityLabel("Show flight controls")
            }
            Spacer()
            TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                cleanTimer(now: ctx.date)
            }
        }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.top, AppSpacing.xs)
        .padding(.bottom, Layout.pad(34, 50))
        .transition(.opacity)
    }

    private func cleanTimer(now: Date) -> some View {
        let elapsed = displayElapsed(at: now)
        let remainingSecs = max(0, Int((durationSeconds - elapsed).rounded(.up)))
        let secs = isInfinity ? Int(elapsed.rounded(.down)) : remainingSecs
        let value = secs >= 3600 ? Formatters.countdown(secs) : Formatters.flightClock(secs)
        return Text(value)
            .font(.system(size: Layout.pad(30, 40), weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.85))
            .contentTransition(.numericText(countsDown: !isInfinity))
            .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
            .frame(maxWidth: .infinity)
    }

    private func heroTimer(now: Date) -> some View {
        let elapsed = displayElapsed(at: now)
        let elapsedSecs = Int(elapsed.rounded(.down))
        let remainingSecs = max(0, Int((durationSeconds - elapsed).rounded(.up)))
        let label = isInfinity ? "Time Focused" : "Time Remaining"
        // A true live timer: MM:SS under an hour, H:MM:SS beyond — the seconds
        // always visibly tick (the calm "20 min" style stays on Home/ticket).
        let secs = isInfinity ? elapsedSecs : remainingSecs
        let value = secs >= 3600 ? Formatters.countdown(secs) : Formatters.flightClock(secs)
        return VStack(spacing: Layout.pad(16, 24)) {
            VStack(spacing: 4) {
                Text(label.uppercased())
                    .font(.system(size: Layout.pad(12, 15), weight: .semibold, design: .rounded))
                    .tracking(2.5)
                    .foregroundStyle(.white.opacity(0.55))
                Text(value)
                    .font(.system(size: Layout.pad(66, 108), weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(countsDown: !isInfinity))
                    .animation(.snappy(duration: 0.35), value: value)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.45), radius: 14, y: 3)
            }
            if isInfinity {
                subtleControl(icon: "arrow.down.to.line", title: "Land now") {
                    appModel.tapFeedback(); vm.landNow()
                }
            } else {
                subtleControl(icon: vm.isPaused ? "play.fill" : "pause.fill",
                              title: vm.isPaused ? "Resume" : "Pause") {
                    vm.togglePause()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// A premium music-style "now playing" card near the top (just below the
    /// status/controls) — "Playing" small over the soundscape name large — that
    /// fades in and out and never covers the balloon or the hero timer.
    private var soundToast: some View {
        VStack {
            HStack {
                HStack(spacing: 11) {
                    ZStack {
                        Circle().fill(appModel.selectedJourneyAudio.accent.opacity(0.9))
                            .frame(width: 38, height: 38)
                        Image(systemName: appModel.selectedJourneyAudio.systemImage)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("PLAYING")
                            .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                            .tracking(1.6)
                            .foregroundStyle(.white.opacity(0.6))
                        Text(appModel.selectedJourneyAudio.displayName)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().fill(Color.black.opacity(0.24)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.top, Layout.pad(78, 96))   // just below the status/controls row
            Spacer()
        }
        .allowsHitTesting(false)
    }

    /// A quiet, secondary control beneath the hero timer — deliberately
    /// understated so the time stays the focus.
    private func subtleControl(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: Layout.pad(14, 17), weight: .bold))
                Text(title).font(.system(size: Layout.pad(15, 18), weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, Layout.pad(22, 28))
            .padding(.vertical, Layout.pad(12, 15))
            .background(Capsule().fill(.white.opacity(0.12)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel(title)
    }

    // The compact flight-controls panel, anchored under the controls button.
    // A near-invisible tap-catcher closes it; the flight stays visible behind.
    private var flightControlsOverlay: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.001).ignoresSafeArea()
                .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { showControlsPanel = false } }
            FlightControlsPanel(
                muted: vm.isAudioMuted,
                isCabin: viewMode == .cabin,
                isOnline: isOnlineFlight,
                isPrivate: online.isPrivateFlight || online.isInviteReady,
                preparingInvite: invitePreparing,
                onToggleMute: {
                    vm.toggleMute()
                    // Every panel action closes the panel immediately (Phase 9).
                    withAnimation(.easeOut(duration: 0.2)) { showControlsPanel = false }
                },
                onToggleCabin: {
                    appModel.tapFeedback()
                    withAnimation(.easeInOut(duration: 0.5)) {
                        viewMode = (viewMode == .cabin ? .exterior : .cabin)
                    }
                    withAnimation(.easeOut(duration: 0.2)) { showControlsPanel = false }
                },
                onInvite: {
                    withAnimation(.easeOut(duration: 0.2)) { showControlsPanel = false }
                    appModel.tapFeedback()
                    Task { await inviteFriends() }
                },
                onParticipants: {
                    withAnimation(.easeOut(duration: 0.2)) { showControlsPanel = false }
                    appModel.tapFeedback()
                    showLobby = true
                },
                onCleanMode: {
                    // Session-local only: Clean Mode is an intentional in-flight
                    // action and never persists as a future default.
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showControlsPanel = false
                        cleanMode = true
                    }
                }
            )
            .environmentObject(appModel)
            .padding(.top, Layout.pad(92, 108))
            .padding(.horizontal, AppSpacing.screen)
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
        }
    }
}


// MARK: - Hold to give up (never one accidental tap)

/// The flight's exit control: a small **X** at rest that, on press-and-hold,
/// expands into a "Hold to leave" capsule with a progress fill and haptics. Only
/// a completed hold opens the leave confirmation; releasing early cancels. A
/// stray tap can never end a focus flight.
private struct HoldToGiveUpButton: View {
    var size: CGFloat = 44
    var onHoldingChanged: ((Bool) -> Void)? = nil
    let onComplete: () -> Void

    @State private var progress: CGFloat = 0
    @State private var holding = false

    private let holdDuration: Double = 1.2
    private var width: CGFloat { holding ? size * 3.9 : size }

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(.white.opacity(0.12))
            // The fill sweeps across as the hold completes.
            Capsule().fill(Color(hex: 0xE9654B).opacity(0.55))
                .frame(width: width * progress)
            HStack(spacing: 6) {
                Image(systemName: "xmark")
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                if holding {
                    Text("Hold to leave")
                        .font(.system(size: size * 0.30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize()
                        .padding(.trailing, 14)
                        .transition(.opacity)
                }
            }
        }
        .frame(width: width, height: size, alignment: .leading)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
        .scaleEffect(holding ? 0.97 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: holding)
        .onLongPressGesture(minimumDuration: holdDuration, maximumDistance: 60) {
            progress = 0
            holding = false
            onHoldingChanged?(false)
            onComplete()
        } onPressingChanged: { pressing in
            holding = pressing
            onHoldingChanged?(pressing)
            if pressing {
                withAnimation(.linear(duration: holdDuration)) { progress = 1 }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
            }
        }
        .accessibilityLabel("Leave flight")
        .accessibilityHint("Press and hold to open the leave confirmation.")
    }
}

// MARK: - Flight controls panel (one button → every in-flight control)

/// The compact glass panel opened by the single flight-controls button. It keeps
/// the journey visible behind it and gathers every in-flight control in one
/// place: cabin/exterior, sound (mute + change), solo/online, Focus Shield,
/// invite, and the flight-time readout. Values arrive as plain props/closures so
/// it never reaches into the session view's private state.
private struct FlightControlsPanel: View {
    let muted: Bool
    let isCabin: Bool
    /// Online (public/private) flights show the invite control; a Solo flight
    /// omits it entirely.
    let isOnline: Bool
    /// A Private Flight (someone was invited) also shows Participants.
    var isPrivate: Bool = false
    var preparingInvite: Bool = false
    let onToggleMute: () -> Void
    let onToggleCabin: () -> Void
    let onInvite: () -> Void
    var onParticipants: () -> Void = {}
    let onCleanMode: () -> Void
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("FLIGHT CONTROLS")
                .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.5))

            row(icon: isCabin ? "mountain.2.fill" : "macwindow",
                title: isCabin ? "Exterior view" : "Cabin view",
                subtitle: isCabin ? "Look out at the Sky" : "Cozy up inside",
                action: onToggleCabin)

            row(icon: muted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                title: muted ? "Muted" : "Sound on",
                subtitle: appModel.selectedJourneyAudio.displayName,
                action: onToggleMute)

            soundChips

            row(icon: "eye.slash", title: "Clean mode",
                subtitle: "Hide controls, keep a tiny timer", action: onCleanMode)

            // Invite lives only on Online flights — a Solo flight has no one to
            // invite and no social surface, so the control is omitted entirely.
            // Participants (the one lobby) appears once the flight is Private.
            if isOnline {
                if isPrivate {
                    row(icon: "person.2.fill", title: "Participants",
                        subtitle: "See who's flying with you", action: onParticipants)
                }
                inviteButton
            }
        }
        .padding(AppSpacing.md)
        .frame(width: Layout.pad(270, 300))
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.black.opacity(0.34)))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.4), radius: 20, y: 12)
    }

    private func row(icon: String, title: String, subtitle: String,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.gold)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 11.5, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 7).padding(.horizontal, 9)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.05)))
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle(scale: 0.98))
    }

    private var soundChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(JourneyAudioOption.all) { option in
                    let selected = appModel.selectedJourneyAudio.id == option.id
                    Button {
                        appModel.selectJourneyAudio(option)
                        appModel.haptics.tap()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: option.systemImage).font(.system(size: 11, weight: .bold))
                            Text(option.displayName).font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(selected ? Color(hex: 0x14120E) : .white)
                        .padding(.horizontal, 10).frame(height: 32)
                        .background(Capsule().fill(selected ? AnyShapeStyle(option.accent)
                                                            : AnyShapeStyle(Color.white.opacity(0.08))))
                    }
                    .buttonStyle(SoftPressStyle())
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var inviteButton: some View {
        Button(action: onInvite) {
            HStack(spacing: 8) {
                Image(systemName: preparingInvite ? "hourglass" : "person.badge.plus")
                    .font(.system(size: 14, weight: .bold))
                Text(preparingInvite ? "Preparing…" : "Invite Friends")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Spacer()
                if !preparingInvite {
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).opacity(0.6)
                }
            }
            .foregroundStyle(Color(hex: 0x14120E))
            .padding(.vertical, 10).padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppColors.gold))
        }
        .buttonStyle(SoftPressStyle(scale: 0.98))
        .disabled(preparingInvite)
    }
}

/// Identifiable wrapper so a URL can drive `.sheet(item:)` for the share sheet.
private struct FlightShareURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
