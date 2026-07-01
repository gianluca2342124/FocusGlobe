import SwiftUI

/// Map-first home, in the FocusFlight grammar: a full-screen real Google map
/// centred on the user's current location, a large greeting + city name, a
/// single white CTA, and a couple of quiet glass rows. No logo, no stat boxes.
///
/// Honesty rule: when location is denied/unavailable we never present a fake
/// city as "real" — Home shows a clean "choose your starting city" state.
struct HomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = HomeViewModel()
    @State private var showCityPicker = false
    @State private var showResume = false
    @State private var showStreak = false
    @State private var originPoint: CGPoint?

    private var origin: JourneyOrigin? { appModel.currentOrigin }

    var body: some View {
        ZStack {
            map
            if originPoint != nil {
                // The Home globe uses a planetary camera centred on the origin, so
                // the balloon/origin is always at the exact view centre. Pin the
                // radar to the geometric centre (reliable on iPad/Mac) rather than a
                // reported map point, which can drift across coordinate spaces.
                GeometryReader { geo in
                    RadarPulse().position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            atmosphere
            topBar
            VStack {
                Spacer()
                bottomCluster
                    .clusterMaxWidth()   // centred band on iPad/Mac; full-width on iPhone
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, AppSpacing.lg)
        }
        // Home is built on the dark globe map. Its floating glass HUD (streak,
        // continue-journey, missions) is designed light-on-dark, so lock the
        // over-map content to the dark rendering — in Light Mode the cards stay
        // readable and premium instead of turning into white-text-on-light-glass.
        // (The white Start Journey CTA is mode-independent and unaffected.)
        .environment(\.colorScheme, .dark)
        .focusScreenChrome()
        .onAppear {
            appModel.requestLocation()
            maybeShowResume()
            maybeShowPremiumIntro()
        }
        .onChange(of: appModel.currentOrigin) { _, newOrigin in
            if newOrigin != nil { maybeShowPremiumIntro() }
        }
        .sheet(isPresented: $showCityPicker) { LocationPickerView().environmentObject(appModel) }
        .adaptiveModal(isPresented: $showStreak,
                       width: Layout.streakPanelWidth, height: Layout.streakPanelHeight) {
            StreakDetailsView().environmentObject(appModel)
        }
        .adaptiveModal(isPresented: $showResume,
                       width: Layout.resumePanelWidth, height: Layout.resumePanelHeight) {
            ResumeJourneySheet(
                snapshot: appModel.resumableJourney,
                onContinue: { showResume = false; continueResumableJourney() },
                onStartNew: { showResume = false; appModel.clearResumableJourney(); router.openRouteSelection() }
            )
        }
    }

    /// Offer to continue an unfinished journey if one was saved (and we're not
    /// already in a journey). Shown over Home on launch / return.
    private func maybeShowResume() {
        guard appModel.resumableJourney != nil, router.activeJourney == nil else { return }
        showResume = true
    }

    /// Reconstruct and present the saved journey (seeded at its saved elapsed).
    private func continueResumableJourney() {
        guard let journey = appModel.makeResumeJourney() else { return }
        // Let the sheet dismiss first, then present the full-screen journey cover.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            router.activeJourney = journey
        }
    }

    /// Auto-present the premium paywall once per session for non-Pro users, after
    /// we have a real origin and the UI is ready. Never clashes with the resume
    /// card. Marked shown immediately so it never loops or reopens this session.
    private func maybeShowPremiumIntro() {
        guard appModel.resumableJourney == nil, !showResume else { return }
        guard appModel.shouldShowPremiumIntro, !router.showPaywall else { return }
        appModel.markPremiumIntroSeen()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            router.presentPaywall()
        }
    }

    @ViewBuilder private var map: some View {
        if let origin {
            // Lift the origin/balloon into the upper half. The map's bottom inset
            // also lifts the Google attribution to just above the (compact) text
            // cluster, so it stays visible without colliding with the title.
            // Planetary Satellite framing: a far, top-down satellite view so the
            // round Earth reads as a small 3D globe in space (a large global
            // context, not a flat regional map). The balloon stays pinned over
            // the origin on the globe.
            JourneyBackdropMap(origin: origin, mode: .origin, showsBalloon: true,
                               bottomInset: 330, originZoom: 4.3,
                               skinAssetName: appModel.selectedSkin.assetName,
                               style: .satellite, planetary: true,
                               onOriginPoint: setOriginPoint)
                .ignoresSafeArea()
        } else {
            // No real/chosen origin yet — a calm planetary Satellite globe with
            // no "you are here" halo, so we never imply a fake location.
            JourneyBackdropMap(origin: .default, mode: .origin,
                               showsBalloon: false, showsOrigin: false,
                               style: .satellite, planetary: true,
                               onOriginPoint: setOriginPoint)
                .ignoresSafeArea()
        }
    }

    private func setOriginPoint(_ p: CGPoint?) {
        guard let p else { if originPoint != nil { originPoint = nil }; return }
        if let o = originPoint, abs(o.x - p.x) < 1.5, abs(o.y - p.y) < 1.5 { return }
        originPoint = p
    }

    private var atmosphere: some View {
        ZStack {
            LinearGradient(colors: [AppColors.brand.opacity(0.10), .clear, AppColors.gold.opacity(0.06)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.45), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 200)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.78)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 460)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // Crown (premium) entry point on the left; a DEBUG-only Simulator city
    // override on the right. In production there is no prominent "change city"
    // affordance on Home — travel happens by completing journeys.
    private var topBar: some View {
        VStack {
            HStack(spacing: AppSpacing.xs) {
                // The crown only opens the paywall — hide it once the user is Pro.
                if !appModel.isPro {
                    CrownButton(size: Layout.pad(44, 52)) { appModel.tapFeedback(); router.presentPaywall() }
                }
                streakButton
                Spacer()
                // Non-interactive origin indicator (never opens the picker once a
                // real/virtual origin exists). DEBUG-only dev hint.
                #if DEBUG
                HStack(spacing: 6) {
                    Image(systemName: "location.fill").font(.system(size: 12, weight: .bold))
                    Text(origin?.code ?? "—")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 9)
                .glassBackground(cornerRadius: AppSpacing.pillRadius, tintOpacity: 0.22, shadowRadius: 8, shadowY: 4)
                #endif
            }
            Spacer()
        }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.top, AppSpacing.xs)
    }

    // A calm, premium streak badge — a glass capsule with a gold flame + count.
    // Tapping opens the Streak Details sheet (shown even at 0).
    private var streakButton: some View {
        Button {
            appModel.tapFeedback()
            showStreak = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: Layout.pad(15, 18), weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFB13C), Color(hex: 0xF2643C)],
                                                    startPoint: .top, endPoint: .bottom))
                Text("\(appModel.progress.currentStreak)")
                    .font(.system(size: Layout.pad(16, 20), weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, Layout.pad(13, 16))
            .padding(.vertical, Layout.pad(9, 11))
            .glassBackground(cornerRadius: AppSpacing.pillRadius, tintOpacity: 0.18, shadowRadius: 7, shadowY: 4)
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel("\(appModel.progress.currentStreak) day streak. Opens streak details.")
    }

    private var bottomCluster: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.greeting)
                    .font(.system(size: Layout.pad(14, 18), weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                Text(bigTitle)
                    .font(.system(size: Layout.pad(46, 64), weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: Layout.pad(14, 18), weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .shadow(color: .black.opacity(0.45), radius: 12, y: 3)

            if let origin {
                AppPrimaryButton(title: "Start Journey", systemImage: "paperplane.fill") {
                    appModel.tapFeedback()
                    #if DEBUG
                    let started = Date()
                    #endif
                    // Plan is cached (and catalogs are warmed at launch), so this
                    // fills the cache for this origin before Route Selection renders.
                    _ = JourneyPlanner.plan(from: origin)
                    router.openRouteSelection()
                    #if DEBUG
                    print("[Performance] Start Journey tap-to-navigation \(Int(Date().timeIntervalSince(started) * 1000)) ms")
                    #endif
                }
            } else {
                AppPrimaryButton(title: "Choose starting city", systemImage: "mappin.and.ellipse") {
                    appModel.tapFeedback()
                    showCityPicker = true
                }
            }

            missionsCard

            HStack(spacing: AppSpacing.xs) {
                compactNav(title: "Passport", systemImage: "globe.europe.africa") { appModel.tapFeedback(); router.openPassport() }
                compactNav(title: "Settings", systemImage: "gearshape") { appModel.tapFeedback(); router.openSettings() }
            }
        }
    }

    // A calm Missions / Daily Goals summary (replaces the old History row).
    // Shows today's progress and opens the Passport where the full list lives.
    private var missionsCard: some View {
        let missions = appModel.dailyMissions
        let done = missions.filter { $0.isComplete }.count
        return Button { appModel.tapFeedback(); router.openPassport() } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "target")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.gold)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily goals").font(AppTypography.callout).foregroundStyle(.white)
                    Text("\(done) of \(missions.count) complete")
                        .font(AppTypography.caption).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                HStack(spacing: 5) {
                    ForEach(missions) { mission in
                        Circle()
                            .fill(mission.isComplete ? AppColors.gold : Color.white.opacity(0.25))
                            .frame(width: 7, height: 7)
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 13)
            .glassBackground(cornerRadius: 16, tintOpacity: 0.16, shadowRadius: 8, shadowY: 4)
        }
        .buttonStyle(SoftPressStyle(scale: 0.99))
    }

    private func compactNav(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: systemImage).font(.system(size: 15, weight: .semibold))
                Text(title).font(AppTypography.callout)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .glassBackground(cornerRadius: 16, tintOpacity: 0.16, shadowRadius: 8, shadowY: 4)
        }
        .buttonStyle(SoftPressStyle(scale: 0.98))
    }

    private var bigTitle: String {
        if let origin { return origin.city }
        return appModel.isLocating ? "Locating…" : "Choose your city"
    }

    private var subtitle: String {
        if origin != nil { return "" }
        return appModel.isLocating ? "Finding where you are…" : "Pick a starting city to begin."
    }
}

// MARK: - Resume unfinished journey

/// A calm card offered on Home when an unfinished journey was saved. The user
/// chooses to continue it (resumed at the saved progress) or start a new one.
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
                    Text("Continue your journey?")
                        .font(AppTypography.title2)
                        .foregroundStyle(.white)
                    if let s = snapshot {
                        Text("\(s.origin.city) → \(s.route.destinationName)")
                            .font(AppTypography.headline)
                            .foregroundStyle(.white.opacity(0.9))
                        Text(progressText(s))
                            .font(AppTypography.caption)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                .multilineTextAlignment(.center)
                Spacer()
                VStack(spacing: AppSpacing.sm) {
                    AppPrimaryButton(title: "Continue journey", systemImage: "paperplane.fill") { onContinue() }
                    Button(action: onStartNew) {
                        Text("Start a new journey")
                            .font(AppTypography.headline)
                            .foregroundStyle(.white.opacity(0.85))
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
