import SwiftUI
import CloudKit
#if canImport(GoogleMaps)
import GoogleMaps
#endif

/// UIKit delegate bridge for FocusGlobe Online: silent CloudKit pushes and
/// CKShare invitation acceptance. Best-effort only — nothing here can block
/// launch, Solo flights, or local progress.
final class FocusGlobeAppDelegate: NSObject, UIApplicationDelegate {
    /// Set by the App once the online coordinator exists.
    static weak var online: FocusOnlineModel?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        Self.online?.handleRemoteNotification(userInfo)
        return .newData
    }

    func application(_ application: UIApplication,
                     userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Task { @MainActor in
            await Self.online?.handleAcceptedShare(cloudKitShareMetadata)
        }
    }
}

@main
struct FocusGlobeApp: App {
    @UIApplicationDelegateAdaptor(FocusGlobeAppDelegate.self) private var delegate
    @StateObject private var appModel = AppModel()
    @StateObject private var router = AppRouter()
    @StateObject private var online = FocusOnlineModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        LaunchLog.mark("FocusGlobeApp.init")
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
                    FocusGlobeAppDelegate.online = online
                    appModel.attachOnline(online)
                    appModel.analytics.log(.appOpened)
                    // Clear any shields left behind by a previous run (e.g. the app
                    // was killed mid-journey). No journey is in flight at cold launch.
                    appModel.focusShield.reconcile(activeJourneyInFlight: router.activeJourney != nil)
                }
                .onOpenURL { router.handleDeepLink($0) }   // widget deep links
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
