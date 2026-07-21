import SwiftUI

/// Hosts the navigation stack, the full-screen journey cover and the paywall
/// sheet. Applies the user's chosen appearance app-wide.
struct RootView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var appModel: AppModel
    @State private var ready = false

    var body: some View {
        Group {
            if appModel.needsOnboarding {
                OnboardingView()
                    .transition(.opacity)
            } else {
                NavigationStack(path: $router.path) {
                    AppShell()
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
            PaywallView(context: router.paywallContext)
                .environmentObject(appModel)
                .environmentObject(router)
        }
        // The take-off curtain: an opaque cover raised the instant the Boarding
        // Pass is cut, so Home can never flash between the setup cover's
        // dismissal and the journey cover's presentation. It is painted with
        // the destination Sky's OWN first-frame gradient, so the hand-off reads
        // as one continuous sky — never a black interstitial. The journey
        // container lowers it on mount (plus the router's own 3 s watchdog).
        .overlay {
            if router.takeoffCurtain {
                LinearGradient(colors: router.takeoffCurtainSkyID
                                   .map { SkyGradientTimeline.stops(skyID: $0, at: 0) }
                                   ?? [AppColors.neutralBase, AppColors.neutralDeep],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .allowsHitTesting(true)
            }
        }
        .animation(.easeOut(duration: 0.25), value: router.takeoffCurtain)
        .preferredColorScheme(appModel.settings.appearance.colorScheme)
        // The branded in-app loading state covers the very first launch frame,
        // then crossfades away. No artificial delay — it is only ever briefly up.
        .overlay {
            if !ready {
                LoadingView().transition(.opacity)
            }
        }
        .task { withAnimation(.easeInOut(duration: 0.5)) { ready = true } }
    }
}
