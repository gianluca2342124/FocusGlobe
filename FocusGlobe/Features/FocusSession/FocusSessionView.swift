import SwiftUI

/// Hosts the live focus session and, on completion, the Landing screen — both
/// inside the same full-screen cover so the journey stays seamless to landing.
///
/// There is no separate "Taking off" waiting screen: the cover opens straight
/// into the live journey. The take-off haptic + earcon fire inside the session's
/// `start()`, and the map plays its route-overview → zoom-in → follow intro, so
/// the take-off feeling happens *inside* the Active Journey without delaying the
/// user.
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
            vm.startIfNeeded()   // straight into the live journey — no takeoff screen
        }
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
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            JourneyMapView(data: vm.mapData, onUserPan: { vm.userInteractedWithMap() })
                .ignoresSafeArea()

            // Edge vignette + strong bottom scrim so white readouts stay legible
            // over any map (dark or light).
            vignette

            topControls
            bottomReadouts
        }
        .confirmationDialog("Leave this expedition?",
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
            case .active:              vm.refresh()
            case .inactive, .background: vm.persistForResume()
            @unknown default:          break
            }
        }
    }

    // MARK: - Backdrop

    private var vignette: some View {
        ZStack {
            // Keep bright map types (Terrain/Standard/Satellite) feeling dark and
            // premium without changing the map type itself. Dark styles stay clean.
            if !vm.mapStyle.isDark {
                Color.black.opacity(0.22).ignoresSafeArea()
            }
            // Subtle warm expedition grade so the live flyover reads golden-hour,
            // not cold — kept light so the 3D map and white readouts stay crisp.
            Color(hex: 0x2A1E0F).opacity(0.16).blendMode(.multiply).ignoresSafeArea()
            RadialGradient(colors: [Color(hex: 0xE8A94B).opacity(0.07), .clear],
                           center: .center, startRadius: 40, endRadius: 520)
                .blendMode(.plusLighter).ignoresSafeArea()
            RadialGradient(colors: [.clear, .black.opacity(0.28)],
                           center: .center, startRadius: 220, endRadius: 580)
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.30), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 170)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.62)],
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
                AppIconButton(systemImage: "xmark", size: Layout.pad(46, 56), tint: AppColors.textPrimary,
                              accessibilityLabel: "End expedition") { vm.requestCancel() }
                Spacer()
                statusPill
                Spacer()
                VStack(spacing: AppSpacing.xs) {
                    mapStyleMenu
                    AppIconButton(systemImage: vm.showsRecenter ? "location.fill" : "arrow.up.left.and.arrow.down.right",
                                  size: Layout.pad(46, 56), tint: AppColors.textPrimary,
                                  accessibilityLabel: vm.showsRecenter ? "Recenter on balloon" : "View full route") {
                        vm.showsRecenter ? vm.recenter() : vm.showFullRoute()
                    }
                    // Shows the action it will switch TO: "2D" while 3D is active,
                    // "3D" while 2D is active. Active state is a glass highlight,
                    // never a coloured/yellow tint.
                    GlassTextButton(text: vm.tilted ? "2D" : "3D", size: Layout.pad(46, 56), active: vm.tilted,
                                    accessibilityLabel: vm.tilted ? "Switch to 2D" : "Switch to 3D") {
                        vm.toggleTilt()
                    }
                    AppIconButton(systemImage: vm.muteIconName, size: Layout.pad(46, 56),
                                  tint: AppColors.textPrimary,
                                  accessibilityLabel: vm.isAudioMuted ? "Unmute expedition audio" : "Mute expedition audio") {
                        vm.toggleMute()
                    }
                    // iPad/Mac: the pause control joins the side controls (the bottom-
                    // centre pause is omitted there) so the control set reads as one
                    // unified group. Same gray glass circle as the other buttons.
                    if Layout.isPadIdiom {
                        AppIconButton(systemImage: vm.isPaused ? "play.fill" : "pause.fill",
                                      size: Layout.pad(46, 56), tint: AppColors.textPrimary,
                                      accessibilityLabel: vm.isPaused ? "Resume" : "Pause") {
                            vm.togglePause()
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

    private var mapStyleMenu: some View {
        Menu {
            ForEach(MapDisplayStyle.selectable) { style in
                Button { vm.setMapStyle(style) } label: {
                    Label(style.displayName, systemImage: vm.mapStyle == style ? "checkmark" : style.systemImage)
                }
            }
            Divider()
            Button { vm.toggleLabels() } label: {
                Label(vm.labelsOn ? "Hide labels" : "Show labels", systemImage: "textformat")
            }
        } label: {
            GlassCircle(systemImage: vm.mapStyle.systemImage, size: Layout.pad(46, 56))
        }
        .accessibilityLabel("Map style")
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Image(systemName: vm.phase.systemImage).font(.system(size: 12, weight: .semibold))
            Text(vm.statusLabel).font(AppTypography.caption)
        }
        .foregroundStyle(AppColors.textPrimary)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 8)
        .glassBackground(cornerRadius: AppSpacing.pillRadius, tintOpacity: 0.22, shadowRadius: 8, shadowY: 4)
    }

    // MARK: - Bottom readouts (no card — floating typography on the map)

    private var bottomReadouts: some View {
        VStack(spacing: 0) {
            Spacer()
            // Readouts + banner live in a centred band so on iPad/Mac/landscape the
            // time and distance don't spread to opposite screen edges. On iPhone
            // portrait the cap exceeds the width, so the immersive layout is unchanged.
            VStack(spacing: 0) {
                HStack(alignment: .bottom) {
                    readout(label: "Until landing", value: vm.remainingMinutesText, alignment: .leading)
                    Spacer(minLength: AppSpacing.sm)
                    // iPhone keeps the white pause in the centre; on iPad/Mac the
                    // pause moved to the side controls, so the readouts spread to
                    // the wide band's left/right edges.
                    if !Layout.isPadIdiom {
                        centerCluster
                        Spacer(minLength: AppSpacing.sm)
                    }
                    readout(label: "To discovery", value: vm.remainingDistanceText, alignment: .trailing)
                }
                .padding(.horizontal, Layout.pad(AppSpacing.lg, 44))

                // No banner ads during an expedition — the map breathes. Ads for
                // free users are limited to a single interstitial at journey end.
            }
            // iPad/Mac: span the full width (with a safe-area margin via the inner
            // padding) so Time anchors to the left edge and Distance to the right.
            // iPhone keeps the centred band.
            .frame(maxWidth: Layout.pad(Layout.journeyReadouts, .infinity))
            .frame(maxWidth: .infinity)
        }
        .padding(.bottom, AppSpacing.md)
        .transition(.opacity)
    }

    private func readout(label: String, value: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(label)
                .font(.system(size: Layout.pad(12, 15), weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(.white.opacity(0.75))
            Text(value)
                .font(.system(size: Layout.pad(36, 54), weight: .semibold, design: .serif))
                .monospacedDigit()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
        .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
    }

    private var centerCluster: some View {
        // No seconds countdown — calm and timeless. Just the pause control.
        WhitePauseButton(isPaused: vm.isPaused, size: Layout.pad(60, 72)) { vm.togglePause() }
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
                .foregroundStyle(Color(hex: 0x2B2620))
                .frame(width: size, height: size)
                .background(Circle().fill(.white))
                .shadow(color: .black.opacity(0.3), radius: 12, y: 5)
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel(isPaused ? "Resume" : "Pause")
    }
}
