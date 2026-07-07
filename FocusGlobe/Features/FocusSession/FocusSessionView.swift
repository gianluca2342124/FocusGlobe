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

    private var isInfinity: Bool { FlightRouteFactory.isInfinity(vm.route) }
    private var sky: SkyScene {
        SkyScene.all.first { vm.route.destinationName == $0.name } ?? SkyScene.today()
    }
    /// Sky altitude: real progress for timed flights; a slow, endless drift for ∞.
    private var skyProgress: Double {
        isInfinity ? SkyScene.loopedProgress(vm.progress * 12) : vm.progress
    }
    private var elapsedSeconds: Int {
        max(0, vm.route.durationMinutes * 60 - vm.remainingSeconds)
    }

    var body: some View {
        ZStack {
            SkySceneView(scene: sky, progress: skyProgress, animated: !reduceMotion)

            balloon

            // Soft bottom scrim so the readouts stay legible over bright bands.
            VStack {
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 240)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            topControls
            bottomReadouts
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
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true)) { balloonSway = 5 }
        }
    }

    // The small white balloon — rises gently up the screen with progress,
    // swinging subtly. The landscape stays the protagonist.
    private var balloon: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let y = h * (0.62 - CGFloat(min(1, skyProgress)) * 0.3)
            BalloonView(height: 92, showBurner: true, showGlow: false,
                        assetName: appModel.selectedSkin.assetName)
                .rotationEffect(.degrees(Double(balloonSway) * 0.4))
                .offset(x: balloonSway)
                .position(x: geo.size.width / 2, y: y)
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
                        readout(label: "Time Focused",
                                value: Formatters.durationLabel(minutes: max(0, elapsedSeconds / 60)),
                                alignment: .leading)
                        Spacer(minLength: AppSpacing.sm)
                        readout(label: "Distance Traveled",
                                value: Formatters.distance(km: FlightRouteFactory.traveledKm(elapsedSeconds: elapsedSeconds)),
                                alignment: .trailing)
                    } else {
                        readout(label: "Time Remaining", value: vm.remainingMinutesText, alignment: .leading)
                        Spacer(minLength: AppSpacing.sm)
                        readout(label: "Distance Remaining", value: vm.remainingDistanceText, alignment: .trailing)
                    }
                }
                .padding(.horizontal, Layout.pad(AppSpacing.lg, 44))

                WhitePauseButton(isPaused: vm.isPaused, size: Layout.pad(58, 70)) { vm.togglePause() }

                if isInfinity {
                    Button {
                        appModel.tapFeedback()
                        vm.landNow()
                    } label: {
                        Text("Land now")
                            .font(AppTypography.callout)
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, AppSpacing.md).padding(.vertical, 8)
                            .background(Capsule().fill(.white.opacity(0.1)))
                    }
                    .buttonStyle(SoftPressStyle())
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
