import SwiftUI

/// Map-first home, in the FocusFlight grammar: a full-screen living map, a large
/// place name, a single confident CTA, and a couple of quiet rows. No
/// dashboard, no stat boxes (those live in the Passport).
struct HomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = HomeViewModel()

    private var featured: Route { appModel.recommendedRoute }

    var body: some View {
        ZStack {
            RoutePreviewMap(route: featured, progress: 0.5)
                .ignoresSafeArea()

            // Scrims for legibility over the map.
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.45), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 180)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.72)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 420)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                Spacer()
                bottomCluster
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.lg)
        }
        .focusScreenChrome()
    }

    private var bottomCluster: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.greeting)
                    .font(AppTypography.callout)
                    .foregroundStyle(.white.opacity(0.8))
                Text(featured.shortName)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(featured.name) · \(featured.durationLabel)")
                    .font(AppTypography.subhead)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .shadow(color: .black.opacity(0.4), radius: 10, y: 3)

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
