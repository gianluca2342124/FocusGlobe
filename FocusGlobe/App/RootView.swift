import SwiftUI

/// Hosts the navigation stack, the full-screen journey cover and the paywall
/// sheet. Applies the user's chosen appearance app-wide.
struct RootView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var online: FocusOnlineModel
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
        // The ONE coordinated modal presenter for the whole app: exactly one
        // sheet at a time (paywall, Online sign-in, Coin Spin, Coins Boost,
        // Streak, Daily Gift, share). This is what removes the "only presenting a
        // single sheet is supported" console conflicts — no view owns its own
        // competing global sheet anymore. Env objects injected explicitly.
        .sheet(item: $router.activeModal) { modal in
            coordinatedModal(modal)
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

    /// Renders the single coordinated modal. Every case injects the environment
    /// objects it needs explicitly (a presented sheet does not always inherit
    /// them on all platforms).
    @ViewBuilder private func coordinatedModal(_ modal: AppModal) -> some View {
        switch modal {
        case .paywall(let ctx):
            PaywallView(context: ctx)
                .environmentObject(appModel)
                .environmentObject(router)
                .paywallMaxWidth()
        case .onlineSignIn:
            OnlineSignInView { }
                .environmentObject(online)
                .environmentObject(appModel)
        case .coinSpin:
            CoinSpinSheet().environmentObject(appModel)
        case .coinBoostGift:
            CoinsBoostPopup(onAccept: { appModel.armCoinBoost() })
                .environmentObject(appModel)
        case .streak:
            StreakDetailsView().environmentObject(appModel)
        case .dailyGift:
            DailyGiftSheet().environmentObject(appModel)
        case .share(let items):
            ActivityShareSheet(items: items)
        }
    }
}
