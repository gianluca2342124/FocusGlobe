import SwiftUI
#if canImport(GoogleMaps)
import GoogleMaps
#endif

@main
struct FocusGlobeApp: App {
    @StateObject private var appModel = AppModel()
    @StateObject private var router = AppRouter()
    @StateObject private var online = FocusOnlineModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        LaunchLog.mark("FocusGlobeApp.init")
        // Decode + trim every balloon-skin image in the background NOW, so the
        // first Shop tap never stalls on synchronous image work.
        BalloonSkinImage.warmUp()
        // Google Maps is the temporary MVP provider. Keep all business logic
        // provider-independent so we can migrate to Apple Maps / MapKit later.
        #if canImport(GoogleMaps)
        if MapConfiguration.hasValidGoogleKey {
            GMSServices.provideAPIKey(MapConfiguration.googleMapsAPIKey)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
                .environmentObject(router)
                .environmentObject(online)
                .tint(AppColors.brand)
                .preferredColorScheme(appModel.settings.appearance.colorScheme)
                .onAppear {
                    LaunchLog.mark("RootView onAppear")
                    appModel.attachOnline(online)
                    appModel.analytics.log(.appOpened)
                    // Clear any shields left behind by a previous run (e.g. the app
                    // was killed mid-journey). No journey is in flight at cold launch.
                    appModel.focusShield.reconcile(activeJourneyInFlight: router.activeJourney != nil)
                }
                .onOpenURL { url in
                    // Private-flight invitations (focusglobe://join/<token>, and
                    // https://focusglobe.app/join/<token> once the domain is
                    // configured) — covers cold and warm launch; if the user
                    // isn't signed in yet the token is kept and consumed right
                    // after sign-in. Everything else stays a widget deep link.
                    if DeepLinkService.inviteToken(from: url) != nil {
                        // Any invite open lands in the ONE lobby: surface Friends
                        // (its only observer) so the joined room's lobby appears
                        // no matter which tab was showing.
                        router.openFriends()
                        Task { await online.handleIncomingURL(url) }
                    } else {
                        router.handleDeepLink(url)
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    // Rebuild the notification plan (pushes the comeback sequence out
                    // for active users) and re-check the RevenueCat Pro entitlement so
                    // renewals / expirations / restores made elsewhere are reflected.
                    appModel.refreshNotifications()
                    appModel.refreshSubscriptionStatus()
                    online.appDidEnterForeground()
                    // Drop stale shields if the journey ended while backgrounded.
                    appModel.focusShield.reconcile(activeJourneyInFlight: router.activeJourney != nil)
                }
        }
    }
}
