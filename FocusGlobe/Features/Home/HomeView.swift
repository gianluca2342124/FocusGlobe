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

    private var origin: JourneyOrigin? { appModel.currentOrigin }

    var body: some View {
        ZStack {
            map
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
            // Zoomed-out, region-from-above framing with the origin lifted into
            // the upper half so it never collides with the text block.
            JourneyBackdropMap(origin: origin, mode: .origin, showsBalloon: true, bottomInset: 360)
                .ignoresSafeArea()
        } else {
            // No real/chosen origin yet — a calm high-altitude map with no
            // "you are here" halo, so we never imply a fake location.
            JourneyBackdropMap(origin: .default, mode: .origin,
                               showsBalloon: false, showsOrigin: false)
                .ignoresSafeArea()
        }
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
            HStack {
                CrownButton { appModel.haptics.tap(); router.presentPaywall() }
                Spacer()
                #if DEBUG
                Button { showCityPicker = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill").font(.system(size: 12, weight: .bold))
                        Text(origin?.code ?? "SET")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 9)
                    .glassBackground(cornerRadius: AppSpacing.pillRadius, tintOpacity: 0.22, shadowRadius: 8, shadowY: 4)
                }
                .buttonStyle(SoftPressStyle())
                #endif
            }
            Spacer()
        }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.top, AppSpacing.xs)
    }

    private var bottomCluster: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: 2) {
                if appModel.progress.currentStreak > 0 {
                    StreakPill(days: appModel.progress.currentStreak)
                        .padding(.bottom, AppSpacing.xs)
                }
                Text(viewModel.greeting)
                    .font(AppTypography.headline)
                    .foregroundStyle(.white.opacity(0.82))
                Text(bigTitle)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Text(subtitle)
                    .font(AppTypography.subhead)
                    .foregroundStyle(.white.opacity(0.8))
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

            VStack(spacing: AppSpacing.xs) {
                homeRow(title: "Passport", systemImage: "globe.europe.africa") { router.openPassport() }
                homeRow(title: "History", systemImage: "clock.arrow.circlepath") { router.openHistory() }
                homeRow(title: "Settings", systemImage: "gearshape") { router.openSettings() }
            }
        }
    }

    private var bigTitle: String {
        if let origin { return origin.city }
        return appModel.isLocating ? "Locating…" : "Choose your city"
    }

    private var subtitle: String {
        if origin != nil { return "Your balloon is ready to drift." }
        return appModel.isLocating ? "Finding where you are…" : "Pick a starting city to begin."
    }

    private func homeRow(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 24)
                Text(title).font(AppTypography.callout)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 13)
            .glassBackground(cornerRadius: 16, tintOpacity: 0.16, shadowRadius: 8, shadowY: 4)
        }
        .buttonStyle(SoftPressStyle(scale: 0.99))
    }
}
