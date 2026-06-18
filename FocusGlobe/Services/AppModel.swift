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

    // MARK: Services
    let analytics = AnalyticsService()
    let haptics = HapticsService()
    let sound = SoundService()
    let ads = AdService()
    let purchases: PurchaseService

    private let persistence: PersistenceService

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
    }

    // MARK: - Access helpers

    /// Whether the user may start this route (free, or Pro unlocks premium).
    func isUnlocked(_ route: Route) -> Bool {
        !route.isPremium || isPro
    }

    var recommendedRoute: Route { RouteCatalog.recommended }

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
    func completeJourney(route: Route, focusedSeconds: Int, intention: String?) -> LandingSummary {
        let baseMiles = route.focusMilesReward
        let isNewRoute = !progress.completedRouteIDs.contains(route.id)
        let isNewBest = focusedSeconds > progress.bestFocusSeconds

        let trimmedIntention = intention?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalIntention = (trimmedIntention?.isEmpty == false) ? trimmedIntention : nil

        let record = FocusSessionRecord(
            routeID: route.id,
            routeName: route.name,
            originName: route.originName,
            destinationName: route.destinationName,
            mood: route.mood,
            theme: route.colorTheme,
            plannedMinutes: route.durationMinutes,
            focusedSeconds: focusedSeconds,
            distanceKm: route.approximateDistanceKm,
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

        persistAll()
        analytics.log(.journeyCompleted, [
            "route": route.id, "minutes": focusedSeconds / 60, "miles": baseMiles
        ])

        return LandingSummary(
            id: record.id,
            route: route,
            intention: finalIntention,
            focusedSeconds: focusedSeconds,
            distanceKm: route.approximateDistanceKm,
            baseMiles: baseMiles,
            postcard: postcard,
            streak: p.currentStreak,
            isNewRoute: isNewRoute,
            isNewBest: isNewBest
        )
    }

    /// Records a cancelled journey for history. Does not award miles or streak.
    func cancelJourney(route: Route, focusedSeconds: Int, intention: String?) {
        let trimmed = intention?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalIntention = (trimmed?.isEmpty == false) ? trimmed : nil
        let progressFraction = min(1, Double(focusedSeconds) / route.duration)

        let record = FocusSessionRecord(
            routeID: route.id,
            routeName: route.name,
            originName: route.originName,
            destinationName: route.destinationName,
            mood: route.mood,
            theme: route.colorTheme,
            plannedMinutes: route.durationMinutes,
            focusedSeconds: focusedSeconds,
            distanceKm: route.approximateDistanceKm * progressFraction,
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
