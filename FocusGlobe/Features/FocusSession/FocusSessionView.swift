import SwiftUI

/// Hosts the live focus session and, on completion, the completion screen —
/// both inside the same full-screen cover so the flight stays seamless.
struct FocusSessionContainerView: View {
    let journey: Journey
    @EnvironmentObject private var appModel: AppModel
    @StateObject private var vm: FocusSessionViewModel

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
        }
        .onAppear {
            vm.attach(appModel: appModel)
            vm.startIfNeeded()
        }
        .onDisappear { vm.tearDown() }
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
                                             animated: !reduceMotion)
                    .transition(.opacity)
                balloon
                    .transition(.opacity)
            case .cabin:
                CabinView(elapsed: { displayElapsed(at: Date()) },
                          seed: worldSeed,
                          animated: !reduceMotion)
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

            topControls.opacity(uiIn ? 1 : 0)
            bottomBar.opacity(uiIn ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.35), value: vm.isPaused)
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
                router.finishToHome()
            }
            Button("Keep focusing", role: .cancel) { vm.dismissCancel() }
        } message: {
            Text("You can pick up where you left off from Home.")
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
            guard !reduceMotion else { takeoffLift = 1; return }
            // The cinematic take-off pull-back: ~5.5 s to ease the balloon from
            // close-and-low up to its cruising size and centre. Then settle into
            // an endless gentle breathe (sway + bob) and a slow lateral drift.
            withAnimation(.easeInOut(duration: 5.5)) { takeoffLift = 1 }
            withAnimation(.easeInOut(duration: 4.2).repeatForever(autoreverses: true)) { balloonSway = 5 }
            withAnimation(.easeInOut(duration: 3.1).repeatForever(autoreverses: true)) { balloonBob = -7 }
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
            FlightBalloonView(size: balloonSize, showGlow: true)
                .scaleEffect(takeoffScale)
                .rotationEffect(.degrees(Double(balloonSway) * 0.6))
                .offset(x: balloonSway + balloonDrift, y: balloonBob)
                .position(x: geo.size.width / 2, y: restY)
                .shadow(color: .black.opacity(0.28),
                        radius: 10 + 8 * (1 - takeoffLift), y: 6 + 8 * (1 - takeoffLift))
        }
        .allowsHitTesting(false)
    }

    // MARK: Top — exit, state, mute

    private var topControls: some View {
        VStack {
            HStack(alignment: .top) {
                AppIconButton(systemImage: "xmark", size: Layout.pad(44, 54), tint: .white,
                              accessibilityLabel: "End flight") { vm.requestCancel() }
                Spacer()
                statusPill
                Spacer()
                HStack(spacing: Layout.pad(8, 12)) {
                    AppIconButton(systemImage: viewMode == .cabin ? "mountain.2.fill" : "cup.and.saucer.fill",
                                  size: Layout.pad(44, 54), tint: .white,
                                  accessibilityLabel: viewMode == .cabin ? "Exterior view" : "Cabin view") {
                        appModel.tapFeedback()
                        withAnimation(.easeInOut(duration: 0.5)) {
                            viewMode = (viewMode == .cabin ? .exterior : .cabin)
                        }
                    }
                    AppIconButton(systemImage: vm.muteIconName, size: Layout.pad(44, 54), tint: .white,
                                  accessibilityLabel: vm.isAudioMuted ? "Unmute" : "Mute") {
                        vm.toggleMute()
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.top, AppSpacing.xs)
        .transition(.opacity)
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle().fill(AppColors.success).frame(width: 7, height: 7)
            Text(vm.statusLabel).font(AppTypography.caption)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 8)
        .background(Capsule().fill(.white.opacity(0.1)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }

    // MARK: Paused state — a large, calm, unmistakable pause treatment

    private var pausedOverlay: some View {
        ZStack {
            // A soft dim settles the moving world so the pause reads instantly.
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: Layout.pad(18, 26)) {
                // A large elegant pause glyph — two softly-glowing rounded bars.
                HStack(spacing: Layout.pad(15, 22)) {
                    Capsule().fill(.white.opacity(0.92))
                        .frame(width: Layout.pad(19, 28), height: Layout.pad(66, 96))
                    Capsule().fill(.white.opacity(0.92))
                        .frame(width: Layout.pad(19, 28), height: Layout.pad(66, 96))
                }
                .shadow(color: .black.opacity(0.45), radius: 20, y: 8)
                Text("Paused")
                    .font(.system(size: Layout.pad(19, 25), weight: .semibold, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .offset(y: -Layout.pad(44, 66))   // rest a little above the hero timer
        }
        .allowsHitTesting(false)              // never blocks the Resume control
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

    private func heroTimer(now: Date) -> some View {
        let elapsed = displayElapsed(at: now)
        let elapsedSecs = Int(elapsed.rounded(.down))
        let remainingSecs = max(0, Int((durationSeconds - elapsed).rounded(.up)))
        let label = isInfinity ? "Focused" : "Time Remaining"
        let value = isInfinity ? Formatters.flightClock(elapsedSecs)
                               : Formatters.flightClock(remainingSecs)
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
}

