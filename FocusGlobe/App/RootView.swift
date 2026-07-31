import SwiftUI

/// Hosts the navigation stack, the full-screen journey cover and the paywall
/// sheet. Applies the user's chosen appearance app-wide.
struct RootView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var online: FocusOnlineModel

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
                .environmentObject(online)
        }
        // Paywall occupies the complete presentation area. Other coordinated
        // destinations remain sheets; the filtered bindings still share the
        // router's one-modal authority, so two presenters can never be active.
        .fullScreenCover(item: paywallModalBinding) { modal in
            coordinatedModal(modal)
        }
        .sheet(item: sheetModalBinding) { modal in
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
        // Install the supported status-bar container once (reparents the window
        // root on first layout; zero-size, no lifecycle impact).
        .installStatusBarContainer()
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
                .focusResponsiveLayout()
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

    private var paywallModalBinding: Binding<AppModal?> {
        Binding(
            get: {
                guard case .paywall = router.activeModal else { return nil }
                return router.activeModal
            },
            set: { newValue in
                if let newValue {
                    router.activeModal = newValue
                } else if case .paywall = router.activeModal {
                    router.activeModal = nil
                }
            }
        )
    }

    private var sheetModalBinding: Binding<AppModal?> {
        Binding(
            get: {
                guard let modal = router.activeModal else { return nil }
                if case .paywall = modal { return nil }
                return modal
            },
            set: { newValue in
                if let newValue {
                    router.activeModal = newValue
                } else if let modal = router.activeModal {
                    if case .paywall = modal { return }
                    router.activeModal = nil
                }
            }
        )
    }
}
