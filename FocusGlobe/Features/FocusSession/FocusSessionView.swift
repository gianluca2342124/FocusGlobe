import SwiftUI

/// Hosts the take-off ritual, the live focus session and, on completion, the
/// Landing screen — all inside the same full-screen cover so the journey stays
/// seamless from take-off to landing.
struct FocusSessionContainerView: View {
    let journey: Journey
    @EnvironmentObject private var appModel: AppModel
    @StateObject private var vm: FocusSessionViewModel
    @State private var showTakeoff = true

    init(journey: Journey) {
        self.journey = journey
        _vm = StateObject(wrappedValue: FocusSessionViewModel(journey: journey))
    }

    var body: some View {
        ZStack {
            if vm.didLand, let summary = vm.landingSummary {
                LandingView(summary: summary)
                    .transition(.opacity)
            } else if showTakeoff {
                TakeoffView(route: journey.route) {
                    withAnimation(.easeInOut(duration: 0.55)) { showTakeoff = false }
                    vm.startIfNeeded()
                }
                .transition(.opacity)
            } else {
                FocusSessionView(vm: vm)
                    .transition(.opacity)
            }
        }
        .onAppear { vm.attach(appModel: appModel) }
        .onDisappear { vm.tearDown() }
    }
}

/// The flagship screen. The real map dominates; the balloon is the moving
/// vehicle; the UI is sparse, floating and high-end (FocusFlight-style):
/// minimal corner controls, and large floating readouts at the bottom with no
/// card — just the map, the journey, and restraint.
struct FocusSessionView: View {
    @ObservedObject var vm: FocusSessionViewModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            JourneyMapView(data: vm.mapData, onUserPan: { vm.userInteractedWithMap() })
                .ignoresSafeArea()

            // Edge vignette + strong bottom scrim so white readouts stay legible
            // over any map (dark or light).
            vignette

            if vm.pureMode {
                pureControls
            } else {
                topControls
                bottomReadouts
            }
        }
        .statusBarHidden(vm.pureMode)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: vm.pureMode)
        .confirmationDialog("Leave this journey?",
                            isPresented: $vm.showCancelConfirm,
                            titleVisibility: .visible) {
            Button("End journey", role: .destructive) {
                vm.confirmCancel()
                router.finishToHome()
            }
            Button("Keep focusing", role: .cancel) { vm.dismissCancel() }
        } message: {
            Text("Your progress won't be saved as a landing. You can always start again.")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { vm.refresh() }
        }
    }

    // MARK: - Backdrop

    private var vignette: some View {
        ZStack {
            RadialGradient(colors: [.clear, .black.opacity(0.28)],
                           center: .center, startRadius: 220, endRadius: 580)
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(vm.pureMode ? 0.18 : 0.30), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 170)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(vm.pureMode ? 0.34 : 0.62)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 300)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Top controls

    private var topControls: some View {
        VStack {
            HStack(alignment: .top) {
                AppIconButton(systemImage: "xmark", size: 46, tint: AppColors.textPrimary,
                              accessibilityLabel: "End journey") { vm.requestCancel() }
                Spacer()
                statusPill
                Spacer()
                VStack(spacing: AppSpacing.xs) {
                    mapStyleMenu
                    AppIconButton(systemImage: vm.showsRecenter ? "location.fill" : "arrow.up.left.and.arrow.down.right",
                                  size: 46, tint: AppColors.textPrimary,
                                  accessibilityLabel: vm.showsRecenter ? "Recenter on balloon" : "View full route") {
                        vm.showsRecenter ? vm.recenter() : vm.showFullRoute()
                    }
                    AppIconButton(systemImage: "view.3d", size: 46,
                                  tint: vm.tilted ? AppColors.gold : AppColors.textPrimary,
                                  accessibilityLabel: "Toggle 3D tilt") { vm.toggleTilt() }
                    AppIconButton(systemImage: "eye.slash", size: 46, tint: AppColors.textPrimary,
                                  accessibilityLabel: "Pure mode") { vm.togglePureMode() }
                }
            }
            Spacer()
        }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.top, AppSpacing.xs)
        .transition(.opacity)
    }

    private var mapStyleMenu: some View {
        Menu {
            ForEach(MapDisplayStyle.allCases) { style in
                Button { vm.setMapStyle(style) } label: {
                    Label(style.displayName, systemImage: style.systemImage)
                }
            }
        } label: {
            GlassCircle(systemImage: vm.mapStyle.systemImage)
        }
        .accessibilityLabel("Map style")
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Image(systemName: vm.phase.systemImage).font(.system(size: 12, weight: .semibold))
            Text(vm.phase.title).font(AppTypography.caption)
        }
        .foregroundStyle(AppColors.textPrimary)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 8)
        .glassBackground(cornerRadius: AppSpacing.pillRadius, tintOpacity: 0.22, shadowRadius: 8, shadowY: 4)
    }

    // MARK: - Bottom readouts (no card — floating typography on the map)

    private var bottomReadouts: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                readout(label: "Time Remaining", value: vm.remainingMinutesText, alignment: .leading)
                Spacer(minLength: AppSpacing.sm)
                centerCluster
                Spacer(minLength: AppSpacing.sm)
                readout(label: "Distance Remaining", value: vm.remainingDistanceText, alignment: .trailing)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
        }
        .transition(.opacity)
    }

    private func readout(label: String, value: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
        .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
    }

    private var centerCluster: some View {
        VStack(spacing: AppSpacing.xs) {
            Text(vm.remainingTimeText)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
            WhitePauseButton(isPaused: vm.isPaused, size: 56) { vm.togglePause() }
        }
    }

    // MARK: - Pure mode

    private var pureControls: some View {
        VStack {
            HStack {
                Spacer()
                Text(vm.remainingTimeText)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xs + 2)
                    .glassBackground(cornerRadius: AppSpacing.pillRadius, tintOpacity: 0.22,
                                     shadowRadius: 10, shadowY: 5)
                Spacer()
            }
            .padding(.top, AppSpacing.xs)

            Spacer()

            VStack(spacing: AppSpacing.sm) {
                WhitePauseButton(isPaused: vm.isPaused, size: 60) { vm.togglePause() }
                Button { vm.togglePureMode() } label: {
                    Text("Show controls")
                        .font(AppTypography.caption)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 6)
                }
                .buttonStyle(SoftPressStyle())
            }
            .padding(.bottom, AppSpacing.lg)
        }
        .padding(.horizontal, AppSpacing.screen)
        .transition(.opacity)
    }
}

/// A white circular pause/resume button — always white (it sits on the dark
/// scrim), matching the FocusFlight session control.
struct WhitePauseButton: View {
    let isPaused: Bool
    var size: CGFloat = 56
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(Color(hex: 0x14181F))
                .frame(width: size, height: size)
                .background(Circle().fill(.white))
                .shadow(color: .black.opacity(0.3), radius: 12, y: 5)
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel(isPaused ? "Resume" : "Pause")
    }
}
