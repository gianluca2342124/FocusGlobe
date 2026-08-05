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
        // The screen-scoped status bar is now driven by a container view
        // controller reparented once at first layout (see RootView
        // `.installStatusBarContainer()`) — no ObjC runtime swap.
        // Decode + trim every balloon-skin image in the background NOW, so the
        // first Shop tap never stalls on synchronous image work.
        BalloonSkinImage.warmUp()
        #if DEBUG
        // Guard the consistency-grid qualification rule (299 inactive / 300
        // active / same-day sum / two-day split / cancelled excluded).
        assert(FocusConsistency._selfCheck() == nil, FocusConsistency._selfCheck() ?? "")
        if let persistenceFailure = PersistenceService._selfCheck() {
            assertionFailure(persistenceFailure)
        }
        if let skinFailure = BalloonSkin._selfCheck() {
            assertionFailure(skinFailure)
        }
        if let dailyGiftFailure = AppModel._dailyGiftSelfCheck() {
            assertionFailure(dailyGiftFailure)
        }
        // The onboarding rules are pure functions, so they can be proven at
        // launch rather than hoped about: every answer combination produces a
        // plan in range, every obstacle changes the benefit order, no branch
        // duplicates or drops a step, an entitled pilot is never offered a
        // paywall, and progress never runs backwards.
        if let planFailure = OnboardingPlanBuilder._selfCheck() {
            assertionFailure(planFailure)
        }
        if let flowFailure = OnboardingFlow._selfCheck() {
            assertionFailure(flowFailure)
        }
        // Localization is gated on computed coverage, so the computation itself
        // has to be trustworthy: English complete, no placeholder lost in
        // translation, no key rendered raw, and no language offered before it
        // is genuinely finished.
        if let keyFailure = FocusStringKey._selfCheck() {
            assertionFailure(keyFailure)
        }
        if let tableFailure = FocusStringTable._selfCheck() {
            assertionFailure(tableFailure)
        }
        if let stringsFailure = FocusStrings._selfCheck() {
            assertionFailure(stringsFailure)
        }
        if let coverageFailure = LocalizationCoverage._selfCheck() {
            assertionFailure(coverageFailure)
        }
        print("[Localization]\n" + LocalizationCoverage.manifest())
        #endif
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
                .focusResponsiveLayout()
                // Language at the window root, above every screen and sheet, so
                // a change takes effect on the next frame — no relaunch, and no
                // screen that kept a copy of the old one.
                .focusLanguage(appModel.language)
                .environmentObject(appModel)
                .environmentObject(router)
                .environmentObject(online)
                .tint(AppColors.selectionGold)
                // FocusGlobe is dark, always. Forced at the window root so no
                // screen, sheet or system control can inherit Light — and so it
                // holds regardless of the device setting.
                .preferredColorScheme(.dark)
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
                    guard phase == .active else {
                        // iOS may terminate a suspended process without a
                        // termination callback. Critical mutations are already
                        // synchronous; this is the explicit lifecycle checkpoint.
                        appModel.flushPersistentState()
                        return
                    }
                    // FIRST: a streak can break while the app sits in the
                    // background — over midnight, or over a whole missed day —
                    // and nothing is running to notice. Correct it before the
                    // notification plan (which reads the streak) and before any
                    // screen redraws with the stale number.
                    appModel.reconcileStreakIfNeeded()
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
