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
                            case .focusLoadout(let route): PreBoardingFocusView(route: route)
                            case .boarding(let route, let focus):
                                BoardingView(route: route, preselectedFocus: focus)
                            case .passport: PassportView()
                            case .history: HistoryView()
                            case .settings: SettingsView()
                            case .store: StoreView()
                            case .friends: FriendsView()
                            }
                        }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appModel.needsOnboarding)
        .fullScreenCover(item: $router.activeJourney) { journey in
            FocusSessionContainerView(journey: journey)
                .environmentObject(appModel)
                .environmentObject(router)
        }
        // iPhone: a sheet. iPad/Mac: a large centred premium panel (not a tiny
        // compressed form-sheet). Env objects are injected explicitly so the
        // modal never crashes on Mac.
        .adaptiveModal(isPresented: $router.showPaywall,
                       width: Layout.paywallPanelWidth, height: Layout.paywallPanelHeight) {
            PaywallView()
                .environmentObject(appModel)
                .environmentObject(router)
        }
        .preferredColorScheme(appModel.settings.appearance.colorScheme)
    }
}
