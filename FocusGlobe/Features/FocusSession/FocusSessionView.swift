import Foundation
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
    /// The in-flight "invite a friend to this Sky" sheet.
    @State private var showInvite = false
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
                                             openingBias: matchedSky?.flightOpening,
                                             skyPool: matchedSky?.flightPool,
                                             skyParticles: matchedSky?.flightParticles ?? .none,
                                             focusSky: matchedSky)
                    .transition(.opacity)
                if !(appModel.profile.soloFlights ?? false) {
                    AmbientPilotsLayer(skyID: matchedSky?.id ?? "classic",
                                       elapsed: { displayElapsed(at: Date()) },
                                       animated: !reduceMotion)
                        .transition(.opacity)
                }
                balloon
                    .transition(.opacity)
            case .cabin:
                CabinView(elapsed: { displayElapsed(at: Date()) },
                          seed: worldSeed,
                          animated: !reduceMotion,
                          openingBias: matchedSky?.flightOpening,
                          skyPool: matchedSky?.flightPool,
                          skyParticles: matchedSky?.flightParticles ?? .none,
                          focusSky: matchedSky,
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

            topControls.opacity(uiIn ? 1 : 0)
            bottomBar.opacity(uiIn ? 1 : 0)

            if soundToastVisible {
                soundToast
                    .transition(.opacity.combined(with: .offset(y: -8)))
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
        .confirmationDialog("Give up this flight?",
                            isPresented: $vm.showCancelConfirm,
                            titleVisibility: .visible) {
            Button("Give up", role: .destructive) {
                vm.confirmCancel()
                router.finishToHome()
            }
            Button("Keep flying", role: .cancel) { vm.dismissCancel() }
        } message: {
            Text("Your progress pauses here: no Focus Coins are earned, today's missions don't count this flight, and your streak only grows when you land. You can resume from Home.")
        }
        .sheet(isPresented: $showInvite) {
            FlightInviteSheet(sky: matchedSky ?? appModel.selectedSky)
                .environmentObject(appModel)
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
            ZStack {
                // The equipped Store trail hangs beneath the basket and inherits
                // the same breathing offsets, so it reads as part of the balloon.
                // (It fades itself in only after the take-off camera settles.)
                if let trail = appModel.equippedTrail {
                    BalloonTrailView(item: trail,
                                     elapsed: { displayElapsed(at: Date()) },
                                     animated: !reduceMotion)
                        .frame(width: CGFloat(64), height: CGFloat(180))
                        .offset(x: balloonSway + balloonDrift, y: balloonBob)
                        .position(x: geo.size.width / 2,
                                  y: restY + balloonSize * CGFloat(0.62) + CGFloat(90))
                }
                FlightBalloonView(size: balloonSize, showGlow: true)
                    .scaleEffect(takeoffScale)
                    .rotationEffect(.degrees(Double(balloonSway) * 0.6))
                    .offset(x: balloonSway + balloonDrift, y: balloonBob)
                    .position(x: geo.size.width / 2, y: restY)
                    .shadow(color: .black.opacity(0.28),
                            radius: 10 + 8 * (1 - takeoffLift), y: 6 + 8 * (1 - takeoffLift))
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Top — exit, state, mute

    private var topControls: some View {
        VStack {
            HStack(alignment: .top) {
                HoldToGiveUpButton(size: Layout.pad(44, 54)) {
                    appModel.haptics.tap()
                    vm.requestCancel()
                }
                Spacer()
                statusPill
                Spacer()
                HStack(spacing: Layout.pad(8, 12)) {
                    AppIconButton(systemImage: "person.badge.plus",
                                  size: Layout.pad(44, 54), tint: .white,
                                  accessibilityLabel: "Invite a friend to this Sky") {
                        appModel.tapFeedback()
                        showInvite = true
                    }
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

    /// The "Playing …" soundscape toast — a small glass capsule under the pill.
    private var soundToast: some View {
        VStack {
            HStack(spacing: 7) {
                Image(systemName: appModel.selectedJourneyAudio.systemImage)
                    .font(.system(size: 12, weight: .bold))
                Text("Playing \u{201C}\(appModel.selectedJourneyAudio.displayName)\u{201D}")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().fill(Color.black.opacity(0.22)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1))
            .padding(.top, Layout.pad(64, 78))
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
}


// MARK: - Hold to give up (never one accidental tap)

/// The flight's exit control: press and HOLD — a ring fills while holding, with
/// haptic feedback — and only a completed hold opens the give-up confirmation.
/// Releasing early cancels. A stray tap can never end a focus flight.
private struct HoldToGiveUpButton: View {
    var size: CGFloat = 44
    let onComplete: () -> Void

    @State private var progress: CGFloat = 0
    @State private var holding = false

    private let holdDuration: Double = 1.2

    var body: some View {
        ZStack {
            Circle().fill(.white.opacity(0.10))
            Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color(hex: 0xE9654B),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(2)
            Image(systemName: "xmark")
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .scaleEffect(holding ? 0.94 : 1)
        .onLongPressGesture(minimumDuration: holdDuration, maximumDistance: 60) {
            progress = 0
            holding = false
            onComplete()
        } onPressingChanged: { pressing in
            holding = pressing
            if pressing {
                withAnimation(.linear(duration: holdDuration)) { progress = 1 }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
            }
        }
        .accessibilityLabel("Give up flight")
        .accessibilityHint("Press and hold to open the give-up confirmation.")
    }
}

// MARK: - In-flight invite (friends join this Sky)

/// A small sheet to invite a friend into the current Sky mid-flight: share the
/// per-Sky link and see that Sky's honest invite progress. Accepted invites are
/// only ever credited by the verified referral path — never from this sheet.
private struct FlightInviteSheet: View {
    let sky: FocusSky
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            VStack(spacing: AppSpacing.lg) {
                VStack(spacing: 6) {
                    Text("Invite a friend to \(sky.name)")
                        .font(AppTypography.serifTitle2)
                        .foregroundStyle(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("They join your Sky when they accept — and 3 accepted invites unlock it for good.")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, AppSpacing.xl)

                ShareLink(item: appModel.inviteShareMessage(for: sky)) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .bold))
                        Text("Share invite")
                            .font(AppTypography.headline)
                    }
                    .foregroundStyle(AppColors.ctaText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: AppSpacing.pillRadius, style: .continuous)
                        .fill(AppColors.ctaFill))
                }
                .simultaneousGesture(TapGesture().onEnded { appModel.tapFeedback() })

                if !appModel.isSkyUnlocked(sky) || appModel.inviteProgress(for: sky) > 0 {
                    HStack(spacing: 8) {
                        ForEach(0..<SkyUnlock.invitesNeeded, id: \.self) { i in
                            Circle()
                                .fill(i < appModel.inviteProgress(for: sky)
                                      ? AppColors.gold : AppColors.textPrimary.opacity(0.14))
                                .frame(width: 9, height: 9)
                        }
                        Text("\(appModel.inviteProgress(for: sky))/\(SkyUnlock.invitesNeeded) joined")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, AppSpacing.screen)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Equipped balloon trail (Store cosmetic)

/// The equipped Store trail — a soft wake the balloon leaves beneath itself
/// while it climbs. Three styles (stardust sparkles, a silk ribbon, a comet
/// streak), all pure `Canvas`, tinted from the `StoreItem`, and driven by the
/// pause-aware flight clock so the wake breathes with the flight and freezes
/// on pause. It fades itself in only after the take-off camera settles.
private struct BalloonTrailView: View {
    let item: StoreItem
    let elapsed: () -> Double
    var animated: Bool = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animated)) { _ in
            Canvas { ctx, size in
                let e = elapsed()
                let fadeIn = max(0.0, min(1.0, (e - 5.0) / 3.0))
                guard fadeIn > 0.01 else { return }
                switch item.id {
                case "trail-ribbon": drawRibbon(&ctx, s: size, e: e, alpha: fadeIn)
                case "trail-comet":  drawComet(&ctx, s: size, e: e, alpha: fadeIn)
                default:             drawStardust(&ctx, s: size, e: e, alpha: fadeIn)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Scattered four-point sparkles shed from the basket, sinking and fading.
    private func drawStardust(_ c: inout GraphicsContext, s: CGSize, e: Double, alpha: Double) {
        var rng = SeededRNG(seed: 0x57A2)
        for _ in 0..<14 {
            let phase = rng.unit()
            let speed = 0.05 + rng.unit() * 0.045
            let swaySpeed = 0.6 + rng.unit() * 0.5
            let swayPhase = rng.unit() * Double.pi * 2
            let twinkleSpeed = 2.2 + rng.unit() * 2.0
            let baseR = 0.9 + rng.unit() * 1.5
            let f = (e * speed + phase).truncatingRemainder(dividingBy: 1.0)
            let fall = 1.0 - f
            let sway = Foundation.sin(e * swaySpeed + swayPhase)
            let twinkle = 0.55 + 0.45 * Foundation.sin(e * twinkleSpeed + swayPhase * 3.0)
            let a = alpha * fall * twinkle * 0.85
            guard a > 0.02 else { continue }
            let x = s.width * CGFloat(0.5) + CGFloat(sway) * s.width * CGFloat(0.22)
            let y = CGFloat(f) * s.height
            let r = CGFloat(baseR) * CGFloat(0.6 + 0.4 * fall)
            let center = CGPoint(x: x, y: y)
            let g = Gradient(colors: [item.tint.opacity(a), item.tint.opacity(0)])
            c.fill(Path(ellipseIn: CGRect(x: center.x - r * 3, y: center.y - r * 3,
                                          width: r * 6, height: r * 6)),
                   with: .radialGradient(g, center: center, startRadius: 0, endRadius: r * 3))
            var star = Path()
            star.move(to: CGPoint(x: center.x - r * 1.8, y: center.y))
            star.addLine(to: CGPoint(x: center.x + r * 1.8, y: center.y))
            star.move(to: CGPoint(x: center.x, y: center.y - r * 1.8))
            star.addLine(to: CGPoint(x: center.x, y: center.y + r * 1.8))
            c.stroke(star, with: .color(.white.opacity(a * 0.9)), lineWidth: CGFloat(0.8))
        }
    }

    /// A silk line rippling behind the basket, fading out below.
    private func drawRibbon(_ c: inout GraphicsContext, s: CGSize, e: Double, alpha: Double) {
        let g = Gradient(colors: [item.tint.opacity(alpha * 0.8),
                                  item.tint.opacity(alpha * 0.35),
                                  item.tint.opacity(0)])
        let shading = GraphicsContext.Shading.linearGradient(
            g,
            startPoint: CGPoint(x: s.width / 2, y: 0),
            endPoint: CGPoint(x: s.width / 2, y: s.height))
        let amp = s.width * CGFloat(0.16)
        for (offsetPhase, width) in [(0.0, 2.2), (0.9, 1.0)] {
            var line = Path()
            let steps = 26
            for i in 0...steps {
                let f = Double(i) / Double(steps)
                let wave = Foundation.sin(f * 4.4 + e * 1.1 + offsetPhase)
                let x = s.width * CGFloat(0.5) + CGFloat(wave) * amp * CGFloat(0.35 + 0.6 * f)
                let y = CGFloat(f) * s.height
                let pt = CGPoint(x: x, y: y)
                if i == 0 { line.move(to: pt) } else { line.addLine(to: pt) }
            }
            c.stroke(line, with: shading,
                     style: StrokeStyle(lineWidth: CGFloat(width), lineCap: .round))
        }
    }

    /// A tapered streak with a slow lateral breathing, plus shed sparks.
    private func drawComet(_ c: inout GraphicsContext, s: CGSize, e: Double, alpha: Double) {
        let midX = s.width * CGFloat(0.5)
        let ampX = s.width * CGFloat(0.08)
        func xAt(_ f: Double) -> CGFloat {
            let wave = Foundation.sin(e * 0.8 + f * 2.6)
            return midX + CGFloat(wave) * ampX * CGFloat(f)
        }
        let segments = 12
        for i in 0..<segments {
            let f0 = Double(i) / Double(segments)
            let f1 = Double(i + 1) / Double(segments)
            var seg = Path()
            seg.move(to: CGPoint(x: xAt(f0), y: CGFloat(f0) * s.height))
            seg.addLine(to: CGPoint(x: xAt(f1), y: CGFloat(f1) * s.height))
            let a = alpha * (1.0 - f0) * 0.55
            let w = CGFloat(5.5) * CGFloat(1.0 - f0) + CGFloat(0.6)
            c.stroke(seg, with: .color(item.tint.opacity(a)), lineWidth: w)
        }
        var rng = SeededRNG(seed: 0xC03E)
        for _ in 0..<7 {
            let phase = rng.unit()
            let speed = 0.06 + rng.unit() * 0.05
            let baseR = 0.8 + rng.unit() * 1.1
            let f = (e * speed + phase).truncatingRemainder(dividingBy: 1.0)
            let a = alpha * (1.0 - f) * 0.8
            guard a > 0.02 else { continue }
            let wave = Foundation.sin(e * 1.3 + phase * 9.0)
            let x = midX + CGFloat(wave) * s.width * CGFloat(0.16) * CGFloat(f)
            let y = CGFloat(f) * s.height
            let r = CGFloat(baseR)
            let g = Gradient(colors: [Color.white.opacity(a), item.tint.opacity(0)])
            c.fill(Path(ellipseIn: CGRect(x: x - r * 2.5, y: y - r * 2.5,
                                          width: r * 5, height: r * 5)),
                   with: .radialGradient(g, center: CGPoint(x: x, y: y),
                                         startRadius: 0, endRadius: r * 2.5))
        }
    }
}
