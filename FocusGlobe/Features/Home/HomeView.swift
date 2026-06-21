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
    @State private var originPoint: CGPoint?

    private var origin: JourneyOrigin? { appModel.currentOrigin }

    var body: some View {
        ZStack {
            map
            if let originPoint {
                // Full-bleed container so `.position` shares the map's projection
                // coordinate space exactly (no safe-area offset).
                ZStack(alignment: .topLeading) {
                    Color.clear
                    RadarPulse().position(originPoint)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            atmosphere
            topBar
            VStack {
                Spacer()
                bottomCluster
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, AppSpacing.lg)
        }
        .focusScreenChrome()
        .onAppear {
            appModel.requestLocation()
            maybeShowPremiumIntro()
        }
        .onChange(of: appModel.currentOrigin) { _, newOrigin in
            if newOrigin != nil { maybeShowPremiumIntro() }
        }
        .sheet(isPresented: $showCityPicker) { LocationPickerView() }
    }

    /// Show the one-time premium intro once, after we have a real origin and the
    /// user isn't already Pro. Marked seen immediately so it never re-triggers.
    private func maybeShowPremiumIntro() {
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
            JourneyBackdropMap(origin: origin, mode: .origin, showsBalloon: true,
                               bottomInset: 330, originZoom: 6.3, onOriginPoint: setOriginPoint)
                .ignoresSafeArea()
        } else {
            // No real/chosen origin yet — a calm high-altitude map with no
            // "you are here" halo, so we never imply a fake location.
            JourneyBackdropMap(origin: .default, mode: .origin,
                               showsBalloon: false, showsOrigin: false,
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
                CrownButton { appModel.haptics.tap(); router.presentPaywall() }
                if appModel.progress.currentStreak > 0 { streakBadge }
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

    // A calm, premium streak chip — small glass capsule, gold flame + count.
    private var streakBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColors.gold)
            Text("\(appModel.progress.currentStreak)")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassBackground(cornerRadius: AppSpacing.pillRadius, tintOpacity: 0.18, shadowRadius: 6, shadowY: 3)
        .accessibilityLabel("\(appModel.progress.currentStreak) day streak")
    }

    private var bottomCluster: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.greeting)
                    .font(AppTypography.subhead)
                    .foregroundStyle(.white.opacity(0.55))
                Text(bigTitle)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppTypography.subhead)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .shadow(color: .black.opacity(0.45), radius: 12, y: 3)

            if let origin {
                AppPrimaryButton(title: "Start Journey", systemImage: "paperplane.fill") {
                    appModel.haptics.tap()
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
                    appModel.haptics.tap()
                    showCityPicker = true
                }
            }

            missionsCard

            HStack(spacing: AppSpacing.xs) {
                compactNav(title: "Passport", systemImage: "globe.europe.africa") { router.openPassport() }
                compactNav(title: "Settings", systemImage: "gearshape") { router.openSettings() }
            }
        }
    }

    // A calm Missions / Daily Goals summary (replaces the old History row).
    // Shows today's progress and opens the Passport where the full list lives.
    private var missionsCard: some View {
        let missions = appModel.dailyMissions
        let done = missions.filter { $0.isComplete }.count
        return Button { router.openPassport() } label: {
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
