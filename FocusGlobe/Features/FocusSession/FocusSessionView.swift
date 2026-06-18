import SwiftUI

/// Hosts the live focus session and, on completion, the Landing screen — both
/// inside the same full-screen cover so take-off → land stays seamless.
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

struct FocusSessionView: View {
    @ObservedObject var vm: FocusSessionViewModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            JourneyMapView(data: vm.mapData)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topArea
                Spacer(minLength: AppSpacing.md)
                bottomArea
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.vertical, AppSpacing.xs)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: vm.pureMode)
        }
        .statusBarHidden(vm.pureMode)
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

    // MARK: - Top

    @ViewBuilder private var topArea: some View {
        if vm.pureMode {
            HStack {
                Spacer()
                AppTimePill(value: vm.remainingTimeText)
                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        } else {
            AppFloatingIsland {
                VStack(spacing: AppSpacing.sm) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(vm.route.name)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                            HStack(spacing: 6) {
                                Image(systemName: vm.phase.systemImage)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(vm.route.colorTheme.accent)
                                Text(vm.phase.title)
                                    .font(AppTypography.headline)
                                    .foregroundStyle(AppColors.textPrimary)
                            }
                        }
                        Spacer()
                        Text(vm.progressPercentText)
                            .font(AppTypography.title2)
                            .foregroundStyle(AppColors.textPrimary)
                            .monospacedDigit()
                    }
                    ProgressTrack(progress: vm.progress, color: vm.route.colorTheme.accent)
                    Text(vm.phase.caption)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Bottom

    @ViewBuilder private var bottomArea: some View {
        if vm.pureMode {
            VStack(spacing: AppSpacing.sm) {
                AppIconButton(systemImage: vm.isPaused ? "play.fill" : "pause.fill",
                              size: 66, prominent: true,
                              accessibilityLabel: vm.isPaused ? "Resume" : "Pause") {
                    vm.togglePause()
                }
                Button {
                    vm.togglePureMode()
                } label: {
                    Text("Show controls")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 6)
                        .glassBackground(cornerRadius: AppSpacing.pillRadius,
                                         tintOpacity: 0.25, shadowRadius: 6, shadowY: 3)
                }
                .buttonStyle(SoftPressStyle())
            }
            .frame(maxWidth: .infinity)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            AppFloatingIsland(verticalPadding: AppSpacing.md) {
                VStack(spacing: AppSpacing.md) {
                    HStack {
                        InlineMetric(systemImage: "timer", value: vm.remainingTimeText,
                                     label: "remaining", monospaced: true)
                        Spacer()
                        InlineMetric(systemImage: "location.north.line.fill",
                                     value: vm.remainingDistanceText, label: "to landing",
                                     alignment: .trailing)
                    }
                    HStack {
                        AppIconButton(systemImage: "xmark", size: 52, tint: AppColors.danger,
                                      accessibilityLabel: "Cancel journey") { vm.requestCancel() }
                        Spacer()
                        AppIconButton(systemImage: vm.isPaused ? "play.fill" : "pause.fill",
                                      size: 68, prominent: true,
                                      accessibilityLabel: vm.isPaused ? "Resume" : "Pause") {
                            vm.togglePause()
                        }
                        Spacer()
                        AppIconButton(systemImage: "eye.slash", size: 52,
                                      accessibilityLabel: "Pure mode") { vm.togglePureMode() }
                    }
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Small pieces

private struct InlineMetric: View {
    let systemImage: String
    let value: String
    let label: String
    var monospaced: Bool = false
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 1) {
            HStack(spacing: 5) {
                Image(systemName: systemImage).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
                Text(value)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)
                    .modifier(MaybeMonospaced(on: monospaced))
            }
            Text(label)
                .font(AppTypography.micro)
                .foregroundStyle(AppColors.textTertiary)
        }
    }
}

private struct MaybeMonospaced: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        if on { content.monospacedDigit() } else { content }
    }
}

struct ProgressTrack: View {
    let progress: Double
    var color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(AppColors.hairline)
                Capsule()
                    .fill(color)
                    .frame(width: max(6, geo.size.width * min(1, max(0, progress))))
            }
        }
        .frame(height: 6)
    }
}
