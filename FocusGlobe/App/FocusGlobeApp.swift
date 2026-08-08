import SwiftUI
#if canImport(GoogleMaps)
import GoogleMaps
#endif

/// The one place `\.locale` is injected — and the reason it is a VIEW rather
/// than a modifier written straight onto the `WindowGroup` content.
///
/// `preferredLocale` is a computed property. SwiftUI cannot observe a computed
/// property; it observes the OBJECT. A regular `View` holding
/// `@EnvironmentObject` is re-evaluated whenever `AppModel` publishes, and the
/// `preferredLanguage` setter publishes (it mutates `@Published var settings`).
/// So the chain that has to hold is: selector → setter → `settings` publishes →
/// this body re-runs → `preferredLocale` is recomputed → a new `\.locale`
/// reaches the tree → every `LocalizedStringKey` below re-resolves.
///
/// `RootView()` keeps its structural identity across that re-evaluation, so no
/// `@State` is lost: onboarding progress, navigation and open sheets survive a
/// language change. That is why this is a wrapper and not `.id(language)`.
private struct LocalizedRoot: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        RootView()
            // Selects BOTH the localization SwiftUI reads and the locale it
            // formats dates, numbers and plural categories with.
            .environment(\.locale, appModel.preferredLocale)
    }
}

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
        // A green catalog audit proves the translations EXIST. This proves the
        // running app can REACH them: it asks the resolver for a key that
        // certainly has Spanish, German, Chinese and Brazilian Portuguese
        // values and fails if any of them comes back English.
        if let localizationFailure = FocusLocalization._selfCheck() {
            assertionFailure(localizationFailure)
        }
        // Country names are resolved to ISO 3166-1 codes by a fixed table, then
        // named by Foundation in the selected language. Two things are worth
        // knowing at launch: that the table is well-formed, and that it still
        // covers every country in the geography JSON.
        //
        // The FIRST is asserted, because a malformed table is a typo in code
        // that no data can cause and every developer should see immediately.
        //
        // The SECOND only LOGS. A country nobody added to the table shows in
        // English — a cosmetic defect on one label — and a cosmetic defect must
        // never be the reason FocusGlobe will not open. This assertion used to
        // exist, and it did exactly that: it took the whole app down over the
        // word "China". The strict, build-time version of this check now lives
        // in `Tools/region_audit.py`, which fails loudly where failing loudly
        // costs nothing.
        if let regionTableFailure = CanonicalRegionCodes._selfCheck() {
            assertionFailure(regionTableFailure)
        }
        let regionCoverage = RegionDisplayNames._countryCoverage()
        if regionCoverage.unresolved.isEmpty {
            print("[Localization] bundled regions resolved: "
                  + "\(regionCoverage.resolved)/\(regionCoverage.total)")
        } else {
            print("[Localization] unresolved bundled regions: "
                  + regionCoverage.unresolved.joined(separator: ", ")
                  + " — these will display exactly as the catalog spells them")
        }
        // The general PRO reel alternates categories, including across the loop
        // seam. It is a property of the CATALOG, so adding a cabin item or
        // retiring a Sky is exactly what would silently reintroduce a run of
        // three identical-looking slides.
        if let showcaseFailure = PaywallShowcaseCarousel._selfCheck() {
            assertionFailure(showcaseFailure)
        }
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
            LocalizedRoot()
                .focusResponsiveLayout()
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
                    // Restate the selection at launch. `AppModel.init` already
                    // activated it before the first frame; this re-asserts the
                    // App Group mirror so a widget or Shield added before the
                    // pilot ever touched the selector reads the app's language
                    // rather than the device's.
                    FocusLocalization.select(appModel.preferredLanguage)
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
