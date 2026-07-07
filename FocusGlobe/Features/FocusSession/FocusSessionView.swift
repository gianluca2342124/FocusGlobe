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

    private var isInfinity: Bool { FlightRouteFactory.isInfinity(vm.route) }
    private var sky: SkyScene {
        SkyScene.all.first { vm.route.destinationName == $0.name } ?? SkyScene.today()
    }
    /// Sky altitude: real progress for timed flights; a slow, endless drift for ∞.
    private var skyAltitude: Double {
        isInfinity ? SkyScene.loopedProgress(vm.progress * 12) : vm.progress
    }
    private var elapsedSeconds: Int {
        max(0, vm.route.durationMinutes * 60 - vm.remainingSeconds)
    }

    // MARK: Local flight display model — the *visible* numbers.
    //
    // The symbolic route distance is the single source for the readouts (never
    // the old geographic origin→destination span), and it re-derives on every
    // one-second timer tick, so both values move from the very first second.

    private var remainingDistanceText: String {
        Formatters.flightKm(max(0, vm.route.approximateDistanceKm * (1 - min(1, vm.progress))))
    }
    private var traveledDistanceText: String {
        Formatters.flightKm(FlightRouteFactory.traveledKm(elapsedSeconds: elapsedSeconds))
    }
    /// Infinity clock: live seconds under an hour ("12:34"), then "1h 12m".
    private var focusedTimeText: String {
        elapsedSeconds < 3600
            ? Formatters.countdown(elapsedSeconds)
            : Formatters.durationLabel(minutes: elapsedSeconds / 60)
    }

    var body: some View {
        ZStack {
            SkySceneView(scene: sky, altitude: skyAltitude,
                         motion: reduceMotion ? .still : .flight)

            balloon

            // Soft bottom scrim so the readouts stay legible over bright bands.
            VStack {
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 240)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            topControls.opacity(uiIn ? 1 : 0)
            bottomReadouts.opacity(uiIn ? 1 : 0)
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
            // The controls surface a beat after the world, so entering the
            // flight reads as arriving in a place, not loading a screen.
            withAnimation(.easeOut(duration: 0.8).delay(reduceMotion ? 0 : 0.25)) { uiIn = true }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 4.2).repeatForever(autoreverses: true)) { balloonSway = 5 }
            withAnimation(.easeInOut(duration: 3.1).repeatForever(autoreverses: true)) { balloonBob = -7 }
        }
    }

    // The balloon is **tiny** (~7% of screen height) and stays roughly still,
    // just breathing with a gentle sway + bob. The world scrolls *downward*
    // behind it (see `SkySceneView`), so the balloon reads as rising while the
    // landscape — not the balloon — is the protagonist.
    private var balloon: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let balloonSize = max(34, min(64, h * 0.075))   // 5–8% of screen height
            MiniBalloonView(size: balloonSize, showGlow: true)
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

    // MARK: Bottom — readouts + pause

    private var bottomReadouts: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: AppSpacing.md) {
                HStack(alignment: .bottom) {
                    if isInfinity {
                        // Endless flight — both counters climb from second one.
                        readout(label: "Time Focused", value: focusedTimeText, alignment: .leading)
                        Spacer(minLength: AppSpacing.sm)
                        readout(label: "Distance Traveled", value: traveledDistanceText, alignment: .trailing)
                    } else {
                        readout(label: "Time Remaining", value: vm.remainingMinutesText, alignment: .leading)
                        Spacer(minLength: AppSpacing.sm)
                        readout(label: "Distance Remaining", value: remainingDistanceText, alignment: .trailing)
                    }
                }
                .padding(.horizontal, Layout.pad(AppSpacing.lg, 44))

                // Timed flights pause & resume from the centre; an endless flight
                // can't pause — its one central control lands the flight now.
                if isInfinity {
                    LandNowButton(size: Layout.pad(58, 70)) {
                        appModel.tapFeedback()
                        vm.landNow()
                    }
                } else {
                    WhitePauseButton(isPaused: vm.isPaused, size: Layout.pad(58, 70)) { vm.togglePause() }
                }
            }
            .frame(maxWidth: Layout.pad(Layout.journeyReadouts, .infinity))
            .frame(maxWidth: .infinity)
        }
        .padding(.bottom, AppSpacing.lg)
        .transition(.opacity)
    }

    fileprivate func readout(label: String, value: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(.white.opacity(0.65))
            Text(value)
                .font(.system(size: Layout.pad(34, 52), weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
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
