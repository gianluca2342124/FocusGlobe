import SwiftUI

/// The FocusGlobe home: a calm, ultra-minimal scene — today's sky, a small
/// tethered white balloon, a greeting, and one primary action. No maps, no
/// routes, no clutter. The user should understand the app and start a focus
/// flight in under three seconds.
struct HomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = HomeViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showResume = false
    @State private var showStreak = false
    @State private var showSetup = false
    @State private var balloonFloat: CGFloat = 0

    private var sky: SkyScene { SkyScene.today() }

    var body: some View {
        ZStack {
            // The world at rest: alive (twinkle, breathing light) but grounded.
            // It only starts streaming downward once a flight actually begins.
            SkySceneView(scene: sky, altitude: 0.03,
                         motion: reduceMotion ? .still : .ambient)

            // Gentle top/bottom scrims so text and the panel stay readable.
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 180)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 340)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // The small white balloon — gently floating, never the protagonist.
            // The living sky behind it is the scene; the balloon stays small.
            GeometryReader { geo in
                let size = max(70, min(90, geo.size.height * 0.11))
                FlightBalloonView(size: size, showGlow: true)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.36 + balloonFloat)
                    .shadow(color: .black.opacity(0.28), radius: 12, y: 7)
            }
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                greetingBlock
                Spacer()
                bottomPanel
                    .clusterMaxWidth()
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, AppSpacing.lg)
        }
        .focusScreenChrome()
        .onAppear {
            maybeShowResume()
            maybeShowPremiumIntro()
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) { balloonFloat = -10 }
        }
        .fullScreenCover(isPresented: $showSetup) {
            FlightSetupView().environmentObject(appModel).environmentObject(router)
        }
        .adaptiveModal(isPresented: $showStreak,
                       width: Layout.streakPanelWidth, height: Layout.streakPanelHeight) {
            StreakDetailsView().environmentObject(appModel)
        }
        .adaptiveModal(isPresented: $showResume,
                       width: Layout.resumePanelWidth, height: Layout.resumePanelHeight) {
            ResumeJourneySheet(
                snapshot: appModel.resumableJourney,
                onContinue: { showResume = false; continueResumableJourney() },
                onStartNew: {
                    showResume = false
                    appModel.clearResumableJourney()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showSetup = true }
                }
            )
        }
    }

    // MARK: Resume / premium intro (unchanged logic)

    private func maybeShowResume() {
        guard appModel.resumableJourney != nil, router.activeJourney == nil else { return }
        showResume = true
    }

    private func continueResumableJourney() {
        guard let journey = appModel.makeResumeJourney() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            router.activeJourney = journey
        }
    }

    private func maybeShowPremiumIntro() {
        guard appModel.resumableJourney == nil, !showResume else { return }
        guard appModel.shouldShowPremiumIntro, !router.showPaywall else { return }
        appModel.markPremiumIntroSeen()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            router.presentPaywall()
        }
    }

    // MARK: Top bar — streak ember + crown

    private var topBar: some View {
        HStack(spacing: AppSpacing.xs) {
            Spacer()
            if !appModel.isPro {
                CrownButton(size: Layout.pad(42, 50)) { appModel.tapFeedback(); router.presentPaywall() }
            }
            streakButton
        }
        .padding(.top, AppSpacing.xs)
    }

    private var streakButton: some View {
        Button {
            appModel.tapFeedback()
            showStreak = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: Layout.pad(14, 17), weight: .bold))
                    .foregroundStyle(AppColors.gold)
                Text("\(appModel.progress.currentStreak)")
                    .font(.system(size: Layout.pad(15, 19), weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, Layout.pad(12, 15))
            .padding(.vertical, Layout.pad(8, 10))
            .background(Capsule().fill(.white.opacity(0.1)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel("\(appModel.progress.currentStreak) day streak. Opens streak details.")
    }

    // MARK: Greeting

    private var greetingBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(viewModel.greeting)
                .font(.system(size: Layout.pad(30, 40), weight: .semibold, design: .serif))
                .foregroundStyle(.white)
            Text(dateLine)
                .font(.system(size: Layout.pad(14, 17), weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, AppSpacing.sm)
        .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
    }

    private var dateLine: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    // MARK: Bottom panel

    private var bottomPanel: some View {
        VStack(spacing: AppSpacing.sm) {
            AppPrimaryButton(title: "Start Focus", systemImage: "arrow.up") {
                appModel.tapFeedback()
                showSetup = true
            }
            missionsCard
            HStack(spacing: AppSpacing.xs) {
                compactNav(title: "Passport", systemImage: "book.closed") { appModel.tapFeedback(); router.openPassport() }
                compactNav(title: "Settings", systemImage: "gearshape") { appModel.tapFeedback(); router.openSettings() }
            }
        }
    }

    private var missionsCard: some View {
        let missions = appModel.dailyMissions
        let done = missions.filter { $0.isComplete }.count
        return Button { appModel.tapFeedback(); router.openPassport() } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "target")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.gold)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Daily Missions").font(AppTypography.callout).foregroundStyle(.white)
                    Text("\(done) of \(missions.count) complete")
                        .font(AppTypography.caption).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                HStack(spacing: 5) {
                    ForEach(missions) { mission in
                        Circle()
                            .fill(mission.isComplete ? AppColors.gold : .white.opacity(0.22))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle(scale: 0.99))
    }

    private func compactNav(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: systemImage).font(.system(size: 14, weight: .semibold))
                Text(title).font(AppTypography.callout)
            }
            .foregroundStyle(.white.opacity(0.9))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle(scale: 0.98))
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
                    AppPrimaryButton(title: "Continue flight", systemImage: "arrow.up") { onContinue() }
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
