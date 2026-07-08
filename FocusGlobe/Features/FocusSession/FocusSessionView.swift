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
    @State private var uiIn = false
    /// The wall-clock anchor for everything the pilot sees. Captured **once** on
    /// appear (resume-aware); shifted forward when a pause ends so paused time
    /// never counts. Never touched inside `body`.
    @State private var flightStartedAt: Date?
    /// Set while paused so the display clock holds still.
    @State private var pausedAt: Date?

    private var isInfinity: Bool { FlightRouteFactory.isInfinity(vm.route) }
    private var durationSeconds: Double { Double(vm.route.durationMinutes) * 60.0 }

    // MARK: The display clock — pure wall-clock arithmetic, no publishers.

    private func displayElapsed(at now: Date) -> Double {
        guard let start = flightStartedAt else { return 0 }
        let effective = pausedAt ?? now
        return max(0, effective.timeIntervalSince(start))
    }

    private func displayProgress(at now: Date) -> Double {
        guard durationSeconds > 0 else { return 0 }
        return min(1, displayElapsed(at: now) / durationSeconds)
    }

    /// World progress (0…1 across the six chapters), read live by the tape each
    /// frame. A finite flight traverses every chapter over its duration (a
    /// 1-minute flight shows all six); an endless flight drifts up through them
    /// in ~6 minutes, then folds back forever.
    private func worldProgress() -> Double {
        let now = Date()
        if isInfinity {
            return SkyScene.loopedProgress(displayElapsed(at: now) / 360.0)
        }
        return displayProgress(at: now)
    }

    var body: some View {
        ZStack {
            // The vertical world tape — its own TimelineView reads
            // `worldProgress()` live each frame and slides the six-chapter tape
            // downward, so the world genuinely moves and evolves during flight.
            ActiveFlightJourneyWorldView(progress: worldProgress, animated: !reduceMotion)

            balloon

            // Soft bottom scrim so the readouts stay legible over bright bands.
            VStack {
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 200)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            topControls.opacity(uiIn ? 1 : 0)
            bottomBar.opacity(uiIn ? 1 : 0)
        }
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
                flightStartedAt = Date().addingTimeInterval(-vm.timer.liveElapsed)
            }
            // The controls surface a beat after the world, so entering the
            // flight reads as arriving in a place, not loading a screen.
            withAnimation(.easeOut(duration: 0.8).delay(reduceMotion ? 0 : 0.25)) { uiIn = true }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 4.2).repeatForever(autoreverses: true)) { balloonSway = 5 }
            withAnimation(.easeInOut(duration: 3.1).repeatForever(autoreverses: true)) { balloonBob = -7 }
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
            FlightBalloonView(size: balloonSize, showGlow: true)
                .rotationEffect(.degrees(Double(balloonSway) * 0.6))
                .offset(x: balloonSway, y: balloonBob)
                .position(x: geo.size.width / 2, y: h * 0.5)
                .shadow(color: .black.opacity(0.28), radius: 10, y: 6)
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
                AppIconButton(systemImage: vm.muteIconName, size: Layout.pad(44, 54), tint: .white,
                              accessibilityLabel: vm.isAudioMuted ? "Unmute" : "Mute") {
                    vm.toggleMute()
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

    // MARK: Bottom bar — Time · centre control · Distance, on one row

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Spacer()
            // A half-second TimelineView is the tick: it re-evaluates this row on
            // schedule and every value is derived from `ctx.date` right here —
            // no publishers, no engine state, nothing that can go stale.
            TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                metricsRow(now: ctx.date)
            }
            .frame(maxWidth: Layout.pad(Layout.journeyReadouts, 640))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.screen)
        }
        .padding(.bottom, AppSpacing.md)
        .transition(.opacity)
    }

    private func metricsRow(now: Date) -> some View {
        let elapsed = displayElapsed(at: now)
        let elapsedSecs = Int(elapsed.rounded(.down))
        let remainingSecs = max(0, Int((durationSeconds - elapsed).rounded(.up)))
        let remainingKm = max(0, vm.route.approximateDistanceKm * (1 - displayProgress(at: now)))
        return HStack(alignment: .bottom) {
            if isInfinity {
                readout(label: "Time Focused",
                        value: Formatters.flightClock(elapsedSecs), alignment: .leading)
            } else {
                readout(label: "Time Remaining",
                        value: Formatters.flightClock(remainingSecs), alignment: .leading)
            }

            if isInfinity {
                LandNowButton(size: Layout.pad(56, 68)) {
                    appModel.tapFeedback()
                    vm.landNow()
                }
            } else {
                WhitePauseButton(isPaused: vm.isPaused, size: Layout.pad(56, 68)) { vm.togglePause() }
            }

            if isInfinity {
                readout(label: "Distance Traveled",
                        value: Formatters.flightKm(FlightRouteFactory.traveledKm(elapsedSeconds: elapsedSecs)),
                        alignment: .trailing)
            } else {
                readout(label: "Distance Remaining",
                        value: Formatters.flightKm(remainingKm), alignment: .trailing)
            }
        }
    }

    fileprivate func readout(label: String, value: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1).minimumScaleFactor(0.8)
            Text(value)
                .font(.system(size: Layout.pad(26, 40), weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
        .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
    }
}

/// The round pause/resume control — a warm white disc with a dark glyph, calm
/// and thumb-sized, sitting centre-bottom of the flight.
private struct WhitePauseButton: View {
    let isPaused: Bool
    var size: CGFloat = 58
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(Color(hex: 0x14120E))
                .frame(width: size, height: size)
                .background(Circle().fill(Color(hex: 0xF4EFE4)))
                .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel(isPaused ? "Resume" : "Pause")
    }
}

/// The endless-flight central control. An open-ended (∞) flight never pauses —
/// instead its one button lands the flight now, banking it as complete. Same
/// warm disc as the pause button, with a descend glyph + a small caption.
private struct LandNowButton: View {
    var size: CGFloat = 58
    let action: () -> Void

    var body: some View {
        VStack(spacing: 7) {
            Button(action: action) {
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(Color(hex: 0x14120E))
                    .frame(width: size, height: size)
                    .background(Circle().fill(Color(hex: 0xF4EFE4)))
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
            }
            .buttonStyle(SoftPressStyle())
            Text("Land now")
                .font(AppTypography.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Land now")
        .accessibilityHint("Ends this endless flight and saves it as complete.")
    }
}
