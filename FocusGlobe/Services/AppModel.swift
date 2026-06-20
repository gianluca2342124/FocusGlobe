import Combine
import Foundation

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
    @Published private(set) var isPro: Bool

    /// Mirrors the location service's resolution state so views can observe it.
    @Published private(set) var locationState: LocationService.State = .idle

    // MARK: Services
    let analytics = AnalyticsService()
    let haptics = HapticsService()
    let sound = SoundService()
    let ads = AdService()
    let purchases: PurchaseService
    let location = LocationService()

    private let persistence: PersistenceService
    private var cancellables: Set<AnyCancellable> = []

    // MARK: Init

    init(persistence: PersistenceService = PersistenceService()) {
        self.persistence = persistence
        self.purchases = PurchaseService(persistence: persistence)

        let loadedSettings = persistence.load(AppSettings.self, for: .settings) ?? .default
        self.settings = loadedSettings
        self.progress = persistence.load(UserProgress.self, for: .progress) ?? .empty
        self.history = persistence.load([FocusSessionRecord].self, for: .history) ?? []
        self.isPro = persistence.bool(for: .isPro)

        haptics.isEnabled = loadedSettings.hapticsEnabled
        sound.isEnabled = loadedSettings.soundEnabled

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
            }
            .store(in: &cancellables)
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

    /// Whether the manual starting-city picker should be offered. In production
    /// it appears only when real location isn't available; in DEBUG it's always
    /// available as a Simulator override.
    var allowsManualOrigin: Bool {
        #if DEBUG
        return true
        #else
        if case .resolved = locationState { return false }
        return true
        #endif
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

    /// Pick a starting city manually. Starts a fresh trip from there.
    func setManualOrigin(_ origin: JourneyOrigin) {
        settings.virtualOrigin = nil
        settings.startingCity = origin
        haptics.tap()
    }

    /// "Return to my real location": clear any virtual/manual origin and use GPS.
    func useCurrentLocation() {
        settings.virtualOrigin = nil
        settings.startingCity = nil
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

    // MARK: - Access helpers

    /// Whether the user may start this route (free, or Pro unlocks premium).
    func isUnlocked(_ route: Route) -> Bool {
        !route.isPremium || isPro
    }

    func hasCompleted(_ route: Route) -> Bool {
        progress.completedRouteIDs.contains(route.id)
    }

    func postcard(for routeID: String) -> Postcard? {
        progress.postcards.first { $0.id == routeID }
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
        applyStreak(to: &p, landingDate: record.date)
        progress = p

        // Travelling the world: the destination becomes the next origin.
        arrive(at: JourneyOrigin(city: route.destinationName, country: "",
                                 coordinate: route.destination, code: route.destinationCode))

        persistAll()
        analytics.log(.journeyCompleted, [
            "route": route.id, "minutes": focusedSeconds / 60, "miles": baseMiles
        ])

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
            isNewBest: isNewBest
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
        let ok = await purchases.restore()
        isPro = purchases.isPro
        return ok
    }

    func watchRewardedAd() async -> Bool {
        analytics.log(.mockAdStarted)
        let ok = await ads.showRewardedAd()
        if ok { analytics.log(.mockAdCompleted) }
        return ok
    }

    // MARK: - Debug

    func resetAllData() {
        persistence.wipeAll()
        purchases.clear()
        progress = .empty
        history = []
        isPro = false
        settings = .default
    }

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
        persistence.save(settings, for: .settings)
        if old.appearance != settings.appearance {
            analytics.log(.appearanceChanged, ["mode": settings.appearance.rawValue])
        }
    }

    private func persistAll() {
        persistence.save(progress, for: .progress)
        persistence.save(history, for: .history)
    }
}
