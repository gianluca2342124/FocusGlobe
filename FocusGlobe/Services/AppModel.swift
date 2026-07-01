import Combine
import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// The app's single source of truth and coordinator.
///
/// Holds settings, progress and history; owns the mock services; and exposes
/// the small set of intent methods the UI calls (start / complete / cancel a
/// journey, claim a bonus, change settings, go Pro). Views observe only this
/// object, which keeps the dependency graph simple.
///
/// Google Maps is the temporary MVP map provider. Note that nothing in this
/// file references the map layer — journey/timer/reward logic is completely
/// independent of how the map is rendered, so migrating to Apple Maps later
/// never touches this code.
@MainActor
final class AppModel: ObservableObject {

    // MARK: Published state
    @Published var settings: AppSettings {
        didSet { settingsChanged(from: oldValue) }
    }
    @Published private(set) var progress: UserProgress
    @Published private(set) var history: [FocusSessionRecord]
    @Published private(set) var isPro: Bool {
        didSet {
            guard oldValue != isPro else { return }
            // Persist the local Pro mirror so a returning Pro user isn't briefly
            // un-Pro at cold launch before RevenueCat re-resolves the entitlement.
            // RevenueCat remains the source of truth and corrects this if it ever
            // disagrees (e.g. a lapse detected once back online).
            persistence.setBool(isPro, for: .isPro)
            // When Pro lapses, premium skins/audio must re-lock immediately and
            // any premium selection falls back to its free default. Premium
            // content is never permanently unlocked. (didSet doesn't fire during
            // `init`, so launch-time safety relies on the resolvers below.)
            if !isPro { reconcilePremiumSelections() }
            syncWidgets()
        }
    }

    /// A lightweight snapshot of an unfinished journey, offered for resume on Home.
    @Published private(set) var resumableJourney: ResumableJourney?

    /// Mirrors the location service's resolution state so views can observe it.
    @Published private(set) var locationState: LocationService.State = .idle

    // MARK: Services
    let analytics = AnalyticsService()
    let haptics = HapticsService()
    let sound = SoundService()
    /// One-shot premium UI earcons — separate from the ambient journey `sound`.
    let uiSound = UISoundService()
    let ads = AdService()
    /// Tasteful local re-engagement / streak notifications.
    let notifications = NotificationService()
    let purchases: PurchaseService
    let location = LocationService()
    /// RevenueCat-backed subscription state (inert until the SDK is linked).
    let subscriptions = SubscriptionManager()
    /// Screen Time app-blocking ("Focus Shield") during journeys. A safe no-op on
    /// unsupported platforms (Mac Designed for iPad, missing FamilyControls).
    let focusShield = FocusShieldService()

    private let persistence: PersistenceService
    private var cancellables: Set<AnyCancellable> = []

    // MARK: Init

    init(persistence: PersistenceService = PersistenceService()) {
        LaunchLog.mark("AppModel.init begin")
        self.persistence = persistence
        self.purchases = PurchaseService(persistence: persistence)

        let loadedSettings = persistence.load(AppSettings.self, for: .settings) ?? .default
        self.settings = loadedSettings
        self.progress = persistence.load(UserProgress.self, for: .progress) ?? .empty
        self.history = persistence.load([FocusSessionRecord].self, for: .history) ?? []
        self.isPro = persistence.bool(for: .isPro)
        self.resumableJourney = persistence.load(ResumableJourney.self, for: .resumableJourney)
        LaunchLog.mark("AppModel.init persistence loaded")

        haptics.isEnabled = loadedSettings.hapticsEnabled
        sound.isEnabled = loadedSettings.soundEnabled
        uiSound.isEnabled = loadedSettings.soundEnabled

        // Mirror the location state so views observe `appModel.locationState`.
        locationState = location.state
        location.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.locationState = state
                // In production, a real fix replaces any manual fallback origin
                // so the previous/manual city is never reused once we know where
                // the user actually is. (DEBUG keeps the manual override.)
                #if !DEBUG
                if case .resolved = state, self.settings.startingCity != nil {
                    self.settings.startingCity = nil
                }
                #endif
                self.syncWidgets()   // origin city may have changed
            }
            .store(in: &cancellables)

        // RevenueCat: configure once (non-blocking) and let it drive Pro state
        // when it's the source of truth. When the SDK isn't linked it stays inert
        // and the local/mock Pro flag is used instead.
        LaunchLog.mark("subscriptions.configure")
        subscriptions.configure()
        subscriptions.$isPro
            .receive(on: RunLoop.main)
            .sink { [weak self] pro in
                guard let self, self.subscriptions.isAvailable else { return }
                self.isPro = pro
            }
            .store(in: &cancellables)

        // AdMob: configure analytics + resolve UMP consent and initialise the SDK
        // (safe no-op without the Google Mobile Ads package). No ad is requested
        // before consent is resolved/allowed; ads never show for Pro users.
        LaunchLog.mark("ads.configure + start")
        ads.configure(analytics: analytics)
        ads.start()

        // Warm the journey catalogs shortly after launch so the first Start Journey
        // tap is instant. Runs on the main actor (not off-main) — see the function.
        Self.warmJourneyEngine()

        // Publish the initial widget snapshot from the just-loaded state.
        LaunchLog.mark("syncWidgets")
        syncWidgets()

        // Schedule re-engagement reminders from the just-loaded state (no prompt
        // at launch — permission is requested later, after the first landing).
        LaunchLog.mark("refreshNotifications")
        refreshNotifications()
        LaunchLog.mark("AppModel.init end")
    }

    /// Warms the journey catalogs shortly after launch so the first plan is fast.
    /// Their `static let` storage then stays cached for the app's lifetime.
    ///
    /// LAUNCH-STABILITY (build 5): this deliberately runs on the **main actor**
    /// (`Task { @MainActor }`), never a detached/background task. An earlier
    /// `Task.detached(.utility)` here was the *only* non-main-actor Task in the
    /// whole app — i.e. the only code that could run on the Swift cooperative
    /// pool, which is exactly the executor the App Review launch crash faulted on
    /// (`com.apple.root.user-initiated-qos.cooperative`). Keeping every launch
    /// task on the main actor removes that entire class of off-main launch crash.
    /// The decode is a one-time in-memory cost and is non-blocking (it runs after
    /// `init` returns), so it never delays the first frame.
    private static func warmJourneyEngine() {
        Task { @MainActor in
            LaunchLog.mark("warmJourneyEngine begin")
            _ = TravelNetworkCatalog.allNodes.count
            _ = WorldCityCatalog.allCities.count
            #if DEBUG
            JourneyPlanner.validateCoverage()
            #endif
            LaunchLog.mark("warmJourneyEngine end")
        }
    }

    // MARK: - Location & origin

    /// The effective starting point, in precedence order:
    ///   1. the virtual location from a completed journey (travel the world),
    ///   2. real current location (when available),
    ///   3. a manually chosen starting city,
    ///   4. `nil` → ask the user to choose a starting city (never faked).
    /// GPS never overwrites the virtual origin.
    ///
    /// In DEBUG the manual city outranks GPS so the Simulator (which always
    /// reports San Francisco) can be overridden for testing.
    var currentOrigin: JourneyOrigin? {
        if let virtual = settings.virtualOrigin { return virtual }
        #if DEBUG
        if let manual = settings.startingCity { return manual }
        if case .resolved(let resolved) = locationState { return resolved }
        return nil
        #else
        if case .resolved(let resolved) = locationState { return resolved }
        return settings.startingCity
        #endif
    }

    /// `true` once the user has travelled away from their real location (virtual
    /// origin or manual city set) — used to offer "Return to my real location".
    var canReturnToRealLocation: Bool {
        settings.virtualOrigin != nil || settings.startingCity != nil
    }

    /// `true` once the user has begun travelling the world — either by landing
    /// at least once or by holding a virtual origin. From this point the app
    /// continues from the latest landed destination and never offers a normal
    /// "change starting city" control.
    var hasStartedTravelling: Bool {
        progress.landings > 0 || settings.virtualOrigin != nil
    }

    /// First-launch gate: show the resolving / choose-a-city onboarding only while
    /// we have no origin at all (no GPS fix yet, none chosen, never travelled).
    var needsOnboarding: Bool { currentOrigin == nil }

    /// Whether the manual starting-city picker should be offered. It appears only
    /// when there is no valid origin yet — i.e. real location isn't resolved *and*
    /// the user hasn't started travelling. Once GPS resolves or a journey has been
    /// completed, the picker is hidden everywhere (Home and Settings). A separate
    /// DEBUG-only developer override remains for the Simulator.
    var allowsManualOrigin: Bool {
        if hasStartedTravelling { return false }
        if case .resolved = locationState { return false }
        return true
    }

    var hasRealLocation: Bool {
        if case .resolved = locationState { return true }
        return false
    }

    /// A non-optional origin for journey math. Falls back to the default only
    /// as a last resort; the UI prevents starting a journey without an origin.
    var originForJourney: JourneyOrigin { currentOrigin ?? .default }

    var isUsingManualOrigin: Bool { settings.startingCity != nil }

    var isLocating: Bool {
        if case .resolving = locationState { return true }
        return false
    }

    /// `true` when location was denied/unavailable and no manual city is set.
    var needsStartingCity: Bool {
        guard currentOrigin == nil else { return false }
        switch locationState {
        case .denied, .unavailable, .idle: return true
        case .resolving, .resolved: return false
        }
    }

    /// Begins the calm location flow (permission prompt on first launch, then a
    /// single fix that's reverse-geocoded to a city). Safe to call repeatedly.
    func requestLocation() {
        location.requestLocation()
    }

    /// The city the user departed from on the last completed journey — used to
    /// offer a "back to …" return trip on Choose Journey.
    var previousOrigin: JourneyOrigin? { settings.previousOrigin }

    /// Pick a starting city manually. Starts a fresh trip from there.
    func setManualOrigin(_ origin: JourneyOrigin) {
        settings.virtualOrigin = nil
        settings.startingCity = origin
        settings.previousOrigin = nil
        haptics.tap()
    }

    /// "Return to my real location": clear any virtual/manual origin and use GPS.
    func useCurrentLocation() {
        settings.virtualOrigin = nil
        settings.startingCity = nil
        settings.previousOrigin = nil
        location.requestLocation()
        haptics.tap()
    }

    /// Arrive at a destination — it becomes the virtual origin for the next
    /// journey (persisted across launches; not overwritten by GPS).
    func arrive(at origin: JourneyOrigin) {
        settings.virtualOrigin = origin
    }

    /// A calm default recommendation for the current origin.
    func recommendedJourney() -> PlannedJourney? {
        guard currentOrigin != nil else { return nil }
        return JourneyPlanner.recommended(from: originForJourney)
    }

    // MARK: - Premium intro

    /// In-memory, per-launch flag: the auto-paywall shows at most once per app
    /// session (not once per install), and never reopens after the user closes it
    /// during the same session. Resets naturally on the next cold launch.
    var launchPaywallShown = false

    /// Whether the launch paywall should auto-present: once per session, only
    /// after the app has a real origin and the user isn't already Pro.
    var shouldShowPremiumIntro: Bool {
        !isPro && !launchPaywallShown && currentOrigin != nil
    }

    func markPremiumIntroSeen() {
        launchPaywallShown = true
    }

    // MARK: - UI feedback

    /// Shared, premium tap feedback for meaningful UI interactions — a soft
    /// haptic plus the same subtle earcon the crown button uses (`.modal`).
    /// Centralised so primary taps across the app (Start Journey, navigation,
    /// journey/skin/sound selection, paywall open/close, rewards, major toggles)
    /// feel consistent and high-end. Respects the master Sound setting (the
    /// earcon is silent when Sound is off) and is a one-shot — never looped or
    /// played per-frame, so it never feels spammy.
    func tapFeedback() {
        haptics.tap()
        uiSound.play(.modal)
    }

    // MARK: - Balloon skins

    /// The selected skin — resolved defensively so a locked skin is never
    /// rendered. If a premium skin was selected and Pro has since lapsed (or a
    /// milestone isn't earned), this safely falls back to the default skin.
    var selectedSkin: BalloonSkin {
        let stored = BalloonSkin.skin(id: settings.selectedSkinID)
        return isSkinUnlocked(stored) ? stored : .default
    }

    func isSkinUnlocked(_ skin: BalloonSkin) -> Bool {
        switch skin.unlock {
        case .free:            return true
        case .journeys(let n): return progress.landings >= n        // completed journeys
        case .miles(let n):    return progress.totalFocusMiles >= n
        case .pro:             return isPro   // active subscription only — re-locks if Pro lapses
        }
    }

    /// 0…1 progress toward a milestone skin; `nil` for free, Pro, or already-unlocked.
    func unlockProgress(for skin: BalloonSkin) -> Double? {
        guard !isSkinUnlocked(skin) else { return nil }
        switch skin.unlock {
        case .journeys(let n): return n <= 0 ? 1 : min(1, Double(progress.landings) / Double(n))
        case .miles(let n):    return n <= 0 ? 1 : min(1, Double(progress.totalFocusMiles) / Double(n))
        case .free, .pro:      return nil
        }
    }

    func selectSkin(_ skin: BalloonSkin) {
        guard isSkinUnlocked(skin) else { return }
        settings.selectedSkinID = skin.id
        tapFeedback()
    }

    // MARK: - Journey audio

    /// The selected journey ambience — resolved defensively so a locked premium
    /// option is never played. Premium options fall back to Wind when Pro isn't
    /// active.
    var selectedJourneyAudio: JourneyAudioOption {
        let stored = JourneyAudioOption.option(id: settings.selectedJourneyAudioID)
        return isAudioUnlocked(stored) ? stored : .wind
    }

    /// Wind is free for everyone; the rest require an **active** subscription.
    func isAudioUnlocked(_ option: JourneyAudioOption) -> Bool {
        !option.isPremium || isPro
    }

    func selectJourneyAudio(_ option: JourneyAudioOption) {
        guard isAudioUnlocked(option) else { return }
        settings.selectedJourneyAudioID = option.id
        sound.switchOption(option)   // live-swap if a journey is currently playing
        tapFeedback()
    }

    // MARK: - Premium reconciliation

    /// Re-locks premium content when Pro is inactive: a selected premium skin or
    /// audio option falls back to its free default. Availability always reflects
    /// the *current* subscription — premium content is never permanently unlocked.
    private func reconcilePremiumSelections() {
        if !isSkinUnlocked(BalloonSkin.skin(id: settings.selectedSkinID)) {
            settings.selectedSkinID = nil
        }
        if !isAudioUnlocked(JourneyAudioOption.option(id: settings.selectedJourneyAudioID)) {
            settings.selectedJourneyAudioID = nil
        }
    }

    // MARK: - Daily missions

    /// Today's goals, computed fresh from the session history (so they reset at
    /// midnight with no scheduler). Progress is real; completion is derived.
    var dailyMissions: [DailyMission] {
        let cal = Calendar.current
        let todays = history.filter { $0.completed && cal.isDateInToday($0.date) }
        let journeys = Double(todays.count)
        let minutes = Double(todays.reduce(0) { $0 + $1.focusedSeconds }) / 60.0
        let miles = Double(todays.reduce(0) { $0 + $1.focusMiles })
        let earlierRouteIDs = Set(history.filter { $0.completed && !cal.isDateInToday($0.date) }.map { $0.routeID })
        let newDestinations = Double(Set(todays.map { $0.routeID }).subtracting(earlierRouteIDs).count)
        return [
            DailyMission(id: "journey", title: "Complete a journey", systemImage: "paperplane.fill",
                         accent: .indigo, target: 1, current: journeys),
            DailyMission(id: "focus", title: "Focus 30 minutes", systemImage: "timer",
                         accent: .teal, target: 30, current: minutes),
            DailyMission(id: "new", title: "Visit a new destination", systemImage: "mappin.and.ellipse",
                         accent: .gold, target: 1, current: newDestinations),
            DailyMission(id: "miles", title: "Earn 60 miles", systemImage: "sparkles",
                         accent: .coral, target: 60, current: miles),
        ]
    }

    var dailyMissionsComplete: Bool { dailyMissions.allSatisfy { $0.isComplete } }

    /// Bonus miles granted once when all of today's missions are complete.
    let dailyMissionRewardMiles = 50

    var canClaimDailyMissionReward: Bool {
        dailyMissionsComplete && progress.missionRewardDay != Self.dayKey(Date())
    }

    func claimDailyMissionReward() {
        guard canClaimDailyMissionReward else { return }
        var p = progress
        p.totalFocusMiles += dailyMissionRewardMiles
        p.missionRewardDay = Self.dayKey(Date())
        progress = p
        persistAll()
        haptics.rewardClaim()
        uiSound.play(.claim)
        analytics.log(.rewardClaimed, ["source": "daily_missions", "miles": dailyMissionRewardMiles])
    }

    private static func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    // MARK: - Access helpers

    /// Whether the user may start this route. **Long and Ultra** journeys require
    /// Pro; Short and Deep are always free and bookable.
    func isUnlocked(_ route: Route) -> Bool {
        switch route.category {
        case .long, .ultra: return isPro
        case .short, .deep: return true
        }
    }

    func hasCompleted(_ route: Route) -> Bool {
        progress.completedRouteIDs.contains(route.id)
    }

    func postcard(for routeID: String) -> Postcard? {
        progress.postcards.first { $0.id == routeID }
    }

    // MARK: - Resume unfinished journey

    /// Persist a lightweight snapshot of an unfinished journey so it can be
    /// resumed (or discarded) from Home. Does not change the virtual origin —
    /// that only moves when a journey actually lands.
    func saveResumableJourney(origin: JourneyOrigin, route: Route, intention: String?,
                              elapsedSeconds: Int, skinAssetName: String, soundID: String?) {
        let snapshot = ResumableJourney(origin: origin, route: route, intention: intention,
                                        elapsedSeconds: elapsedSeconds, skinAssetName: skinAssetName,
                                        soundID: soundID, savedAt: Date())
        resumableJourney = snapshot
        persistence.save(snapshot, for: .resumableJourney)
        syncWidgets()
    }

    func clearResumableJourney() {
        guard resumableJourney != nil else { return }
        resumableJourney = nil
        persistence.remove(.resumableJourney)
        syncWidgets()
    }

    /// Reconstruct a `Journey` from the saved snapshot, seeded at the saved
    /// elapsed time. Returns `nil` (and discards safely) if the snapshot is
    /// invalid or already complete.
    func makeResumeJourney() -> Journey? {
        guard let snapshot = resumableJourney else { return nil }
        let total = snapshot.route.durationMinutes * 60
        guard snapshot.elapsedSeconds > 0, snapshot.elapsedSeconds < total else {
            clearResumableJourney()
            return nil
        }
        return Journey(origin: snapshot.origin, route: snapshot.route, intention: snapshot.intention,
                       resumeElapsedSeconds: snapshot.elapsedSeconds)
    }

    // MARK: - Journey lifecycle

    /// Banks a completed journey: miles, streak, landing count, best duration,
    /// completed routes and the unlocked postcard. Returns a summary for the
    /// Landing screen.
    func completeJourney(origin: JourneyOrigin, route: Route,
                         focusedSeconds: Int, intention: String?) -> LandingSummary {
        // Distance (and miles) reflect the *real* journey: the user's live
        // location → the chosen destination.
        let distanceKm = GeoMath.distanceKm(from: origin.coordinate, to: route.destination)
        let baseMiles = max(1, Int(distanceKm.rounded()))
        let isNewRoute = !progress.completedRouteIDs.contains(route.id)
        let isNewBest = focusedSeconds > progress.bestFocusSeconds

        let trimmedIntention = intention?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalIntention = (trimmedIntention?.isEmpty == false) ? trimmedIntention : nil

        let record = FocusSessionRecord(
            routeID: route.id,
            routeName: route.name,
            originName: origin.city,
            destinationName: route.destinationName,
            mood: route.mood,
            theme: route.colorTheme,
            plannedMinutes: route.durationMinutes,
            focusedSeconds: focusedSeconds,
            distanceKm: distanceKm,
            focusMiles: baseMiles,
            intention: finalIntention,
            completed: true
        )

        history.insert(record, at: 0)

        var p = progress
        p.totalFocusMiles += baseMiles
        p.landings += 1
        p.bestFocusSeconds = max(p.bestFocusSeconds, focusedSeconds)
        p.completedRouteIDs.insert(route.id)

        let postcard = Postcard(route: route)
        if !p.postcards.contains(where: { $0.id == postcard.id }) {
            p.postcards.insert(postcard, at: 0)
        }
        let previousStreak = progress.currentStreak
        applyStreak(to: &p, landingDate: record.date)
        let streakIncreased = p.currentStreak > previousStreak
        progress = p

        // Remember where we came from so the next screen can offer a return trip,
        // then make the destination the next origin (travelling the world).
        settings.previousOrigin = origin
        arrive(at: JourneyOrigin(city: route.destinationName, country: "",
                                 coordinate: route.destination, code: route.destinationCode))

        persistAll()
        analytics.log(.journeyCompleted, [
            "route": route.id, "minutes": focusedSeconds / 60, "miles": baseMiles
        ])

        // Re-engagement: reschedule reminders from the new progress. Permission
        // is NOT requested here — landing is not the moment to interrupt the
        // reward. It's requested later, calmly, when the user opens Passport or
        // Settings (see `requestNotificationPermissionForEngagement`).
        refreshNotifications()

        return LandingSummary(
            id: record.id,
            route: route,
            originName: origin.city,
            intention: finalIntention,
            focusedSeconds: focusedSeconds,
            distanceKm: distanceKm,
            baseMiles: baseMiles,
            postcard: postcard,
            streak: p.currentStreak,
            isNewRoute: isNewRoute,
            isNewBest: isNewBest,
            streakIncreased: streakIncreased
        )
    }

    /// Records a cancelled journey for history. Does not award miles or streak.
    func cancelJourney(origin: JourneyOrigin, route: Route, focusedSeconds: Int, intention: String?) {
        let trimmed = intention?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalIntention = (trimmed?.isEmpty == false) ? trimmed : nil
        let progressFraction = min(1, Double(focusedSeconds) / route.duration)
        let distanceKm = GeoMath.distanceKm(from: origin.coordinate, to: route.destination)

        let record = FocusSessionRecord(
            routeID: route.id,
            routeName: route.name,
            originName: origin.city,
            destinationName: route.destinationName,
            mood: route.mood,
            theme: route.colorTheme,
            plannedMinutes: route.durationMinutes,
            focusedSeconds: focusedSeconds,
            distanceKm: distanceKm * progressFraction,
            focusMiles: 0,
            intention: finalIntention,
            completed: false
        )
        history.insert(record, at: 0)
        persistAll()
        analytics.log(.journeyCancelled, ["route": route.id, "seconds": focusedSeconds])
    }

    /// Adds bonus miles (e.g. after a rewarded ad doubles the reward) and
    /// updates the saved record so History stays consistent.
    func grantBonusMiles(for summary: LandingSummary) {
        var p = progress
        p.totalFocusMiles += summary.baseMiles
        progress = p

        if let idx = history.firstIndex(where: { $0.id == summary.id }) {
            let r = history[idx]
            history[idx] = FocusSessionRecord(
                id: r.id, routeID: r.routeID, routeName: r.routeName,
                originName: r.originName, destinationName: r.destinationName,
                mood: r.mood, theme: r.theme, date: r.date,
                plannedMinutes: r.plannedMinutes, focusedSeconds: r.focusedSeconds,
                distanceKm: r.distanceKm, focusMiles: r.focusMiles + summary.baseMiles,
                intention: r.intention, completed: r.completed
            )
        }
        persistAll()
        analytics.log(.rewardClaimed, ["route": summary.route.id, "bonus": summary.baseMiles])
    }

    // MARK: - Monetization

    func goPro() async -> Bool {
        let ok = await purchases.purchasePro()
        if ok { isPro = true }
        return ok
    }

    func restorePurchases() async -> Bool {
        if subscriptions.isAvailable {
            let ok = await subscriptions.restorePurchases()
            isPro = subscriptions.isPro
            return ok
        }
        let ok = await purchases.restore()
        isPro = purchases.isPro
        return ok
    }

    /// Re-check the RevenueCat entitlement (Pro) — call when the app returns to the
    /// foreground so renewals / expirations / restores made elsewhere are reflected.
    /// No-op when RevenueCat isn't linked; RevenueCat stays the source of truth.
    func refreshSubscriptionStatus() {
        subscriptions.refreshCustomerInfo()
    }

    /// Double-miles rewarded ad (Landing). Pro users never reach this (the button
    /// is hidden for Pro); the service also guards against showing them an ad.
    func watchRewardedAd() async -> Bool {
        await ads.showRewarded(.doubleMiles, isPro: isPro)
    }

    /// Daily Mission Boost rewarded ad. Returns whether the boost was granted.
    /// Pro users never see the ad. Grants a small flat miles top-up on reward.
    func watchDailyMissionBoostAd() async -> Bool {
        let earned = await ads.showRewarded(.dailyBoost, isPro: isPro)
        if earned { grantMissionBoost() }
        return earned
    }

    private func grantMissionBoost() {
        var p = progress
        p.totalFocusMiles += AdMobConfig.dailyBoostMiles
        progress = p
        persistAll()
        haptics.rewardClaim()
        uiSound.play(.claim)
        analytics.log(.rewardClaimed, ["source": "daily_mission_boost", "miles": AdMobConfig.dailyBoostMiles])
    }

    // MARK: - Debug

    #if DEBUG
    func resetAllData() {
        persistence.wipeAll()
        purchases.clear()
        progress = .empty
        history = []
        isPro = false
        resumableJourney = nil
        settings = .default
    }
    #endif

    // MARK: - Private

    private func applyStreak(to p: inout UserProgress, landingDate: Date) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: landingDate)
        if let last = p.lastLandingDay {
            let lastDay = cal.startOfDay(for: last)
            if cal.isDate(lastDay, inSameDayAs: today) {
                // Already landed today — streak unchanged.
            } else if let yesterday = cal.date(byAdding: .day, value: -1, to: today),
                      cal.isDate(lastDay, inSameDayAs: yesterday) {
                p.currentStreak += 1
            } else {
                p.currentStreak = 1
            }
        } else {
            p.currentStreak = 1
        }
        p.longestStreak = max(p.longestStreak, p.currentStreak)
        p.lastLandingDay = today
    }

    private func settingsChanged(from old: AppSettings) {
        haptics.isEnabled = settings.hapticsEnabled
        sound.setEnabled(settings.soundEnabled)
        uiSound.isEnabled = settings.soundEnabled
        persistence.save(settings, for: .settings)
        if old.appearance != settings.appearance {
            analytics.log(.appearanceChanged, ["mode": settings.appearance.rawValue])
        }
        syncWidgets()
    }

    // MARK: - Notifications

    /// Build the lightweight state the notification scheduler needs.
    private func notificationState() -> NotificationState {
        let cal = Calendar.current
        let landedToday = history.contains { $0.completed && cal.isDateInToday($0.date) }
        let remaining = dailyMissions.filter { !$0.isComplete }.count
        let resumable = resumableJourney
        return NotificationState(streak: progress.currentStreak,
                                 landedToday: landedToday,
                                 goalsRemaining: remaining,
                                 allGoalsDoneToday: remaining == 0,
                                 hasUnfinishedJourney: resumable != nil,
                                 unfinishedOrigin: resumable?.origin.city,
                                 unfinishedDestination: resumable?.route.destinationName,
                                 originCity: currentOrigin?.city)
    }

    /// Reschedule reminders from the current progress (no-op unless authorised).
    func refreshNotifications() {
        notifications.refresh(state: notificationState())
    }

    /// Ask for notification permission at a calm, user-initiated moment — called
    /// when the user opens the Passport or Settings. Uses provisional auth (no
    /// prompt, quiet delivery) so it's never aggressive, only acts while the
    /// permission is still undecided, and never prompts twice. Never called after
    /// a journey completes.
    func requestNotificationPermissionForEngagement() {
        notifications.requestProvisionalAuthorizationIfNeeded(state: notificationState())
    }

    /// Settings toggle entry point: enable/disable and (when enabling) prompt.
    func setNotificationsEnabled(_ on: Bool) {
        notifications.setEnabled(on)
        if on { notifications.requestAuthorizationIfNeeded(state: notificationState()) }
        refreshNotifications()
    }

    private func persistAll() {
        persistence.save(progress, for: .progress)
        persistence.save(history, for: .history)
        syncWidgets()
    }

    // MARK: - Widget snapshot

    /// Assemble the read-only snapshot the widgets render, write it to the shared
    /// App Group store and ask WidgetKit to refresh. Cheap; safe to call often.
    private func syncWidgets() {
        WidgetStore.write(makeWidgetSnapshot())
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private func makeWidgetSnapshot() -> WidgetSnapshot {
        var snap = WidgetSnapshot()
        snap.isPro = isPro
        snap.originCity = currentOrigin?.city
        snap.originCode = currentOrigin?.code

        snap.totalFocusMiles = progress.totalFocusMiles
        snap.landings = progress.landings
        snap.currentStreak = progress.currentStreak
        snap.longestStreak = progress.longestStreak
        snap.bestFocusMinutes = progress.bestFocusMinutes
        snap.postcardCount = progress.postcards.count
        snap.selectedSkinName = selectedSkin.name

        if let r = resumableJourney {
            let total = max(1, r.route.durationMinutes * 60)
            snap.hasResumable = r.elapsedSeconds > 0 && r.elapsedSeconds < total
            snap.resumeOriginCity = r.origin.city
            snap.resumeOriginCode = r.origin.code
            snap.resumeDestinationCity = r.route.destinationName
            snap.resumeDestinationCode = r.route.destinationCode
            snap.resumeRemainingSeconds = max(0, total - r.elapsedSeconds)
            snap.resumeRouteKm = Int(r.route.approximateDistanceKm.rounded())
            snap.resumeProgress = min(1, Double(r.elapsedSeconds) / Double(total))
        }

        if let longest = history.filter({ $0.completed }).max(by: { $0.distanceKm < $1.distanceKm }) {
            snap.longestRouteOrigin = longest.originName
            snap.longestRouteDestination = longest.destinationName
            snap.longestRouteKm = Int(longest.distanceKm.rounded())
            snap.longestRouteDurationMinutes = longest.plannedMinutes
        }

        let missions = dailyMissions
        snap.goals = missions.map {
            WidgetGoal(title: $0.title, systemImage: $0.systemImage,
                       current: $0.current, target: $0.target)
        }
        snap.goalsCompleted = missions.filter { $0.isComplete }.count
        snap.goalsTotal = missions.count
        snap.canClaimReward = canClaimDailyMissionReward

        snap.updatedAt = Date()
        return snap
    }
}

/// A lightweight, Codable snapshot of an unfinished journey, used to offer a
/// "Continue / Start new" choice on the next launch. Stored in UserDefaults.
/// Carries enough to safely reconstruct the active session.
struct ResumableJourney: Codable, Equatable {
    let origin: JourneyOrigin
    let route: Route
    let intention: String?
    let elapsedSeconds: Int
    let skinAssetName: String
    let soundID: String?
    let savedAt: Date
}
