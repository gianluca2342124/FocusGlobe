import SwiftUI

/// Map-first home, in the FocusFlight grammar: a full-screen real Google map
/// centred on the user's current location, a large greeting + city name, a
/// single confident white CTA, and a couple of quiet glass rows. No dashboard,
/// no stat boxes, no logo (those live elsewhere / nowhere).
struct HomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        ZStack {
            JourneyBackdropMap(origin: appModel.origin, mode: .origin)
                .ignoresSafeArea()

            // Atmospheric aurora overlay + legibility scrims (over the map).
            atmosphere

            VStack {
                Spacer()
                bottomCluster
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.lg)
        }
        .focusScreenChrome()
        .onAppear { appModel.requestLocation() }
    }

    private var atmosphere: some View {
        ZStack {
            // Faint aurora wash so the night map still feels like FocusGlobe —
            // an overlay, never a replacement for the real map.
            LinearGradient(colors: [AppColors.brand.opacity(0.10), .clear, AppColors.gold.opacity(0.06)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.45), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 200)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.78)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 440)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var bottomCluster: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.greeting)
                    .font(AppTypography.headline)
                    .foregroundStyle(.white.opacity(0.82))
                Text(appModel.origin.cityName)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(appModel.location.hasResolvedRealLocation
                     ? "Your balloon is ready to drift."
                     : "Choose a destination and drift there.")
                    .font(AppTypography.subhead)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .shadow(color: .black.opacity(0.45), radius: 12, y: 3)

            AppPrimaryButton(title: "Start Journey", systemImage: "paperplane.fill") {
                appModel.haptics.tap()
                router.openRouteSelection()
            }

            VStack(spacing: AppSpacing.xs) {
                homeRow(title: "Passport", systemImage: "globe.europe.africa") { router.openPassport() }
                homeRow(title: "History", systemImage: "clock.arrow.circlepath") { router.openHistory() }
                homeRow(title: "Settings", systemImage: "gearshape") { router.openSettings() }
            }
        }
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
