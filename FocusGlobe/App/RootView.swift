import SwiftUI

/// Hosts the navigation stack, the full-screen journey cover and the paywall
/// sheet. Applies the user's chosen appearance app-wide.
struct RootView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Group {
            if appModel.needsOnboarding {
                OnboardingView()
                    .transition(.opacity)
            } else {
                NavigationStack(path: $router.path) {
                    HomeView()
                        .navigationDestination(for: AppRouter.Destination.self) { destination in
                            switch destination {
                            case .routeSelection: RouteSelectionView()
                            case .boarding(let route): BoardingView(route: route)
                            case .passport: PassportView()
                            case .history: HistoryView()
                            case .settings: SettingsView()
                            }
                        }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appModel.needsOnboarding)
        .fullScreenCover(item: $router.activeJourney) { journey in
            FocusSessionContainerView(journey: journey)
        }
        .sheet(isPresented: $router.showPaywall) {
            PaywallView()
        }
        .preferredColorScheme(appModel.settings.appearance.colorScheme)
    }
}
