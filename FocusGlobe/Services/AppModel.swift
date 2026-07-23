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
    /// The lightweight local account/profile (onboarding answers, selected Sky,
    /// invite state). Persisted under its own key; auto-saves on every change.
    /// (didSet doesn't fire during `init`, matching the other stores.)
    @Published var profile: UserProfile {
        didSet { persistence.save(profile, for: .profile) }
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

    /// The premium entitlement as a tri-state. Monthly / Annual / Lifetime all
    /// resolve to `.premium` through the SAME authority (`isPro`, driven by
    /// RevenueCat's single entitlement / the persisted mirror). `.loading` is only
    /// ever reported while RevenueCat is still resolving CustomerInfo for a pilot
    /// who isn't already Pro — so a gate must NEVER treat `.loading` as Free and
    /// flash a paywall at a PRO/Lifetime owner whose entitlement hasn't arrived.
    enum Entitlement { case loading, free, premium }
    var entitlement: Entitlement {
        if isPro { return .premium }
        if subscriptions.isAvailable && !subscriptions.hasResolvedEntitlement { return .loading }
        return .free
    }
    /// `true` only when we can be sure the pilot is NOT premium (never during load).
    var isConfirmedFree: Bool { entitlement == .free }

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
        let loadedProgress = persistence.load(UserProgress.self, for: .progress) ?? .empty
        let loadedHistory = persistence.load([FocusSessionRecord].self, for: .history) ?? []
        self.progress = loadedProgress
        self.history = loadedHistory
        self.isPro = persistence.bool(for: .isPro)
        self.resumableJourney = persistence.load(ResumableJourney.self, for: .resumableJourney)

        // Profile: first-run onboarding shows only for genuinely new pilots.
        // Anyone with existing progress/history predates onboarding — mark it
        // completed once so they are never onboarded retroactively.
        var loadedProfile = persistence.load(UserProfile.self, for: .profile) ?? .empty
        if !loadedProfile.hasCompletedOnboarding
            && (loadedProgress.hasAnyProgress || !loadedHistory.isEmpty) {
            loadedProfile.hasCompletedOnboarding = true
            persistence.save(loadedProfile, for: .profile)
        }
        // Sky-catalog migration: a persisted selection pointing at a removed Sky
        // (e.g. the retired Moon Garden / Paris Sunset) is normalised to the free
        // default once, so no invalid identifier is ever left behind. (The
        // `selectedSky` getter also falls back at read time — this just keeps
        // storage clean.)
        // A stored id no longer in the catalog (e.g. the retired "golden-hour")
        // migrates to the free default (Desert Night) here.
        if let storedSkyID = loadedProfile.selectedSkyID, FocusSky.byID(storedSkyID) == nil {
            loadedProfile.selectedSkyID = FocusSky.defaultFree.id
            persistence.save(loadedProfile, for: .profile)
        }
        // Store-catalog migration: seven items were retired (Brass Compass, Cream
        // Pennant, Paper Lantern, Potted Plant, Scented Candle, Alarm Clock, Aurora
        // Quilt). Drop any owned/equipped id no longer in the live catalog so an
        // old profile never keeps a dangling reference (a removed equipped piece
        // simply becomes unequipped — the cabin falls back to nothing/default).
        do {
            let valid = StoreItem.validIDs
            var dirty = false
            if let owned = loadedProfile.ownedStoreItemIDs {
                let kept = owned.intersection(valid)
                if kept != owned { loadedProfile.ownedStoreItemIDs = kept; dirty = true }
            }
            if let equipped = loadedProfile.equippedCabinItemIDs {
                let kept = equipped.intersection(valid)
                if kept != equipped { loadedProfile.equippedCabinItemIDs = kept; dirty = true }
            }
            if let trail = loadedProfile.equippedTrailID, !valid.contains(trail) {
                loadedProfile.equippedTrailID = nil; dirty = true
            }
            if dirty { persistence.save(loadedProfile, for: .profile) }
        }
        // Balloon-skin migration (flight milestones → focused minutes): the five
        // milestone skins now unlock at 300/900/1800/3000/5000 focused minutes.
        // Grandfather any skin a pilot already earned under the OLD flight
        // thresholds so the new rule can NEVER re-lock an owned skin. Runs once
        // (guarded on the set being absent), then the live capture keeps it fresh.
        if loadedProfile.unlockedSkinIDs == nil {
            let legacyFlightThresholds: [(id: String, flights: Int)] = [
                ("balloon", 10), ("marshmallow", 25), ("emoji", 50), ("hohoho", 75), ("sky-pilot", 100)
            ]
            var owned = Set<String>()
            for t in legacyFlightThresholds where loadedProgress.landings >= t.flights {
                owned.insert(t.id)
            }
            loadedProfile.unlockedSkinIDs = owned

            // Sky-threshold preservation (Rainy Tokyo 3→7 days, Swiss Alps 7→14
            // days): grandfather any streak Sky the pilot already satisfies under
            // the OLD threshold, so raising the bar never re-locks a Sky they had.
            // Runs in this same one-time block, so a NEW pilot (streak 0) captures
            // nothing and must reach the new thresholds. Fiji (was PRO-only, now
            // 100 min) needs no migration: PRO still bypasses and no free user
            // could have "owned" it before.
            var unlockedSkies = loadedProfile.unlockedSkyIDs ?? []
            if loadedProgress.currentStreak >= 3 { unlockedSkies.insert("rainy-tokyo") }
            if loadedProgress.currentStreak >= 7 { unlockedSkies.insert("swiss-alps") }
            loadedProfile.unlockedSkyIDs = unlockedSkies

            persistence.save(loadedProfile, for: .profile)
        }
        self.profile = loadedProfile
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
        // Bridge the nested SubscriptionManager's own @Published changes (plans,
        // isLoading, isPurchasing, errorMessage) up to AppModel, so SwiftUI views
        // that observe `appModel` (the Paywall, Settings) re-render when offerings
        // and prices finish loading — otherwise the paywall can keep showing the
        // initial disabled fallback plans even after real packages arrive.
        subscriptions.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.objectWillChange.send() }
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

    /// First-launch gate: the premium first-run onboarding shows only until the
    /// local profile is created (and never for pre-existing pilots — see `init`,
    /// which auto-completes it when progress/history already exist).
    var needsOnboarding: Bool { !profile.hasCompletedOnboarding }

    // MARK: - Skies (destination system) + invites

    /// The currently selected Sky. Falls back to the free default (Desert Night)
    /// whenever nothing is chosen or the stored choice is no longer unlocked
    /// (e.g. Pro lapsed) — premium Skies are never permanently kept.
    var selectedSky: FocusSky {
        let stored = FocusSky.byID(profile.selectedSkyID) ?? .defaultFree
        return isSkyUnlocked(stored) ? stored : .defaultFree
    }

    /// Whether a Sky is flyable for this pilot: free Sky always; Premium unlocks
    /// all while active; otherwise the Sky must have earned its own 3 accepted
    /// invites (per-Sky unlocks — never global).
    func isSkyUnlocked(_ sky: FocusSky) -> Bool {
        // Invite unlocks are SERVER-authoritative: the count is the verified
        // `campaign_progress` RPC (distinct authenticated joiners, self excluded),
        // never the client-side tally. A previously-earned invite Sky stays
        // unlocked via the persisted `unlockedSkyIDs` grandfather set.
        SkyUnlock.isUnlocked(sky, isPro: isPro, unlockedSkyIDs: profile.unlockedSkyIDs ?? [],
                             focusMinutes: lifetimeFocusMinutes,
                             streakDays: progress.currentStreak,
                             invites: onlineRef?.campaignProgress(skyID: sky.id) ?? 0)
    }

    /// Lifetime completed focus minutes — drives minute-based Sky unlocks.
    var lifetimeFocusMinutes: Int {
        history.filter { $0.completed }.reduce(0) { $0 + $1.focusedSeconds } / 60
    }

    private func rawInviteCount(for sky: FocusSky) -> Int {
        (profile.inviteProgressBySkyID ?? [:])[sky.id] ?? 0
    }

    /// Accepted invites counted toward unlocking this specific Sky (capped at the
    /// Sky's own required count).
    func inviteProgress(for sky: FocusSky) -> Int {
        min(sky.invitesRequired ?? SkyUnlock.invitesNeeded, rawInviteCount(for: sky))
    }

    /// The backend/universal-link entry point: one verified accepted invite for
    /// one specific Sky. At the Sky's required count, that Sky (and only that
    /// Sky) unlocks. Production must only ever call this from a trusted source.
    func registerAcceptedInvite(forSkyID skyID: String) {
        var perSky = profile.inviteProgressBySkyID ?? [:]
        perSky[skyID, default: 0] += 1
        profile.inviteProgressBySkyID = perSky
        let need = FocusSky.byID(skyID)?.invitesRequired ?? SkyUnlock.invitesNeeded
        if perSky[skyID, default: 0] >= need {
            var unlocked = profile.unlockedSkyIDs ?? []
            unlocked.insert(skyID)
            profile.unlockedSkyIDs = unlocked
        }
    }

    /// FocusGlobe Online: a Sky's invite campaign reached its verified target
    /// (verified unique participants, server-counted). Unlocks permanently —
    /// idempotent, survives account changes, and never re-locks offline.
    func unlockSkyFromVerifiedInvites(skyID: String) {
        var unlocked = profile.unlockedSkyIDs ?? []
        guard !unlocked.contains(skyID) else { return }
        unlocked.insert(skyID)
        profile.unlockedSkyIDs = unlocked
    }

    /// Select a Sky for the next flights. Locked Skies can be previewed on Home
    /// but never stored as the active choice.
    func selectSky(_ sky: FocusSky) {
        guard isSkyUnlocked(sky) else { return }
        guard profile.selectedSkyID != sky.id else { return }
        profile.selectedSkyID = sky.id
    }

    /// This pilot's stable invite code (created lazily on first use).
    func referralCode() -> String {
        if let code = profile.referralCode { return code }
        let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        var code = ""
        for _ in 0..<6 { code.append(alphabet[Int.random(in: 0..<alphabet.count)]) }
        profile.referralCode = code
        return code
    }

    /// The per-Sky share message. The link carries the referral code AND the
    /// Sky being unlocked, so an accepted invite credits exactly that Sky.
    /// (Placeholder domain until the referral backend + Associated Domains ship.)
    func inviteShareMessage(for sky: FocusSky) -> String {
        "Fly with me in \(sky.name) on FocusGlobe — focus feels like a calm balloon flight. " +
        "My invite code: \(referralCode()) → https://focusglobe.app/i/\(referralCode())?sky=\(sky.id)"
    }

    #if DEBUG
    /// DEBUG-only: simulate the backend confirming one accepted invite for one
    /// Sky, so the per-Sky unlock flow is testable. Never compiled into release.
    func debugSimulateAcceptedInvite(forSkyID skyID: String) {
        registerAcceptedInvite(forSkyID: skyID)
        haptics.tap()
    }

    /// DEBUG-only: wipe every piece of local data and return the app to a true
    /// first-launch state — onboarding shows again on the spot, no reinstall
    /// needed. Disk keys are removed first; the assignments reset the published
    /// state (settings/profile/isPro re-persist via their own `didSet`, the
    /// rest simply load as empty next launch). Never compiled into release.
    func debugResetAllData() {
        persistence.wipeAll()
        UserDefaults.standard.removeObject(forKey: "fg.notifications.enabled")
        settings = .default
        progress = .empty
        history = []
        isPro = false
        resumableJourney = nil
        profile = .empty        // hasCompletedOnboarding = false → onboarding returns
        syncWidgets()
        haptics.tap()
    }
    #endif

    // MARK: - Focus Coins + Store

    /// The spendable **Focus Coins** balance: lifetime coins earned by landing
    /// flights minus what's been spent in the Store. (The lifetime total keeps
    /// driving achievements, so spending never un-earns a badge.)
    var focusCoins: Int {
        max(0, progress.totalFocusMiles - (profile.spentFocusCoins ?? 0))
    }

    func ownsStoreItem(_ item: StoreItem) -> Bool {
        (profile.ownedStoreItemIDs ?? []).contains(item.id)
    }

    // MARK: - Daily gift (Shop)

    static let dailyGiftCoins = 5

    private var todayDayOrdinal: Int {
        Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
    }

    /// True at most once per calendar day, until the gift is collected.
    var canClaimDailyGift: Bool { profile.lastDailyGiftDay != todayDayOrdinal }

    /// Collect the daily gift: +5 Focus Coins, once per day. Returns the amount
    /// granted (0 if already claimed today). Premium pilots receive it too.
    @discardableResult
    func claimDailyGift() -> Int {
        guard canClaimDailyGift else { return 0 }
        profile.lastDailyGiftDay = todayDayOrdinal
        var p = progress
        p.totalFocusMiles += Self.dailyGiftCoins
        progress = p
        persistAll()
        haptics.rewardClaim()
        uiSound.play(.claim)
        analytics.log(.rewardClaimed, ["source": "daily_gift", "miles": Self.dailyGiftCoins])
        return Self.dailyGiftCoins
    }

    // MARK: - Free Coin Spin (rewarded) & Coins Boost

    /// The weighted spin ladder — small wins common, big wins rare (25 ultra rare).
    static let coinSpinPrizes: [(coins: Int, weight: Int)] = [
        (1, 26), (2, 22), (3, 18), (4, 12), (5, 9), (10, 7), (15, 4), (20, 1), (25, 1)
    ]

    /// A light anti-spam gate: at most one successful spin every 90 seconds. The
    /// rewarded ad itself is the real throttle; this only stops rapid re-taps.
    var canCoinSpin: Bool {
        guard let last = profile.lastCoinSpinAt else { return true }
        return Date().timeIntervalSince1970 - last >= 90
    }

    /// Show a rewarded ad, then (on reward) grant a weighted spin prize and return
    /// it. Returns `nil` when no reward was earned (ad unavailable / dismissed) or
    /// the cooldown hasn't elapsed — the caller shows a gentle message.
    func spinCoinReward() async -> Int? {
        guard canCoinSpin else { return nil }
        let earned = await ads.showRewarded(.doubleMiles, isPro: isPro)
        guard earned else { return nil }
        let prize = Self.weightedSpinPrize()
        profile.lastCoinSpinAt = Date().timeIntervalSince1970
        addCoins(prize, source: "coin_spin")
        return prize
    }

    private static func weightedSpinPrize() -> Int {
        let total = coinSpinPrizes.reduce(0) { $0 + $1.weight }
        var roll = Int.random(in: 0..<max(1, total))
        for p in coinSpinPrizes {
            if roll < p.weight { return p.coins }
            roll -= p.weight
        }
        return 1
    }

    /// Add Focus Coins to the balance (spins, gifts). Lifetime-earned rises, so
    /// spending never un-earns a badge.
    func addCoins(_ n: Int, source: String) {
        guard n > 0 else { return }
        var p = progress
        p.totalFocusMiles += n
        progress = p
        persistAll()
        haptics.rewardClaim()
        uiSound.play(.claim)
        analytics.log(.rewardClaimed, ["source": source, "miles": n])
    }

    /// Whether an equipped Coins Boost is armed and still valid (24h window).
    var isCoinBoostArmed: Bool {
        guard let expiry = profile.coinBoostExpiresAt else { return false }
        return Date().timeIntervalSince1970 < expiry
    }

    /// Seconds until the armed boost expires (0 when none).
    var coinBoostRemaining: TimeInterval {
        guard let expiry = profile.coinBoostExpiresAt else { return 0 }
        return max(0, expiry - Date().timeIntervalSince1970)
    }

    /// Accept the gift: arm the boost for the next eligible flight (valid 24h).
    /// Only one boost at a time — accepting again simply resets the window.
    func armCoinBoost() {
        profile.coinBoostExpiresAt = Date().timeIntervalSince1970 + 24 * 60 * 60
        persistAll()
        haptics.rewardClaim()
        analytics.log(.rewardClaimed, ["source": "coin_boost_armed", "miles": 0])
    }

    /// Consume the boost if armed (called once at flight completion). Returns
    /// whether it was active so the caller applies the doubling; also clears a
    /// stale/expired boost so it can never linger.
    @discardableResult
    private func consumeCoinBoostIfArmed() -> Bool {
        let armed = isCoinBoostArmed
        profile.coinBoostExpiresAt = nil
        return armed
    }

    /// Offer the Coins Boost gift occasionally: never on a brand-new account,
    /// never while one is armed, and at most every ~3 days.
    var shouldOfferCoinBoost: Bool {
        guard progress.landings >= 1, !isCoinBoostArmed else { return false }
        guard let last = profile.lastBoostGiftAt else { return true }
        return Date().timeIntervalSince1970 - last > 3 * 24 * 60 * 60
    }

    func markCoinBoostOffered() {
        profile.lastBoostGiftAt = Date().timeIntervalSince1970
    }

    // MARK: - Clean flight mode

    var isCleanFlightMode: Bool { profile.cleanFlightMode ?? false }
    func setCleanFlightMode(_ on: Bool) { profile.cleanFlightMode = on }

    // MARK: - FocusGlobe Online bridge

    /// The online coordinator (owned by the App as a @StateObject; attached at
    /// launch). Weak so AppModel never keeps UI-scoped state alive.
    weak var onlineRef: FocusOnlineModel?

    func attachOnline(_ online: FocusOnlineModel) {
        onlineRef = online
        online.bootstrap(appModel: self)
    }

    /// The skin id shown to other pilots online.
    var equippedSkinIDForOnline: String { selectedSkin.id }

    /// Hide an online pilot locally (their presence is simply not rendered).
    func hidePilot(_ publicID: String) {
        var hidden = profile.hiddenPilotIDs ?? []
        hidden.insert(publicID)
        profile.hiddenPilotIDs = hidden
    }

    /// Verified invite-unlock progress: real server-verified participants
    /// when available, never share-button taps. Falls back to any legacy local
    /// count so previously-earned progress is never lost.
    func verifiedInviteProgress(for sky: FocusSky) -> Int {
        let online = onlineRef?.campaignProgress(skyID: sky.id) ?? 0
        return max(online, inviteProgress(for: sky))
    }

    // Flight lifecycle → online presence (no-ops for Solo; never blocks local).
    func onlineFlightDidStart(skyID: String, sessionID: String, expectedEndAt: Date?) {
        onlineRef?.flightDidStart(skyID: skyID, sessionID: sessionID,
                                  expectedEndAt: expectedEndAt,
                                  category: profile.focusStyle ?? "Focus")
    }
    func onlineFlightPauseChanged(_ paused: Bool) { onlineRef?.flightPauseChanged(isPaused: paused) }
    func onlineFlightDidEnd(sessionID: String) { onlineRef?.flightDidEnd(sessionID: sessionID) }

    /// Buy a cosmetic with Focus Coins (or claim a premium item when Pro).
    /// Returns `true` on success.
    @discardableResult
    func purchaseStoreItem(_ item: StoreItem) -> Bool {
        guard !ownsStoreItem(item) else { return true }
        if item.isPremium {
            guard isPro else { return false }
        } else {
            guard focusCoins >= item.price else { return false }
            profile.spentFocusCoins = (profile.spentFocusCoins ?? 0) + item.price
        }
        var owned = profile.ownedStoreItemIDs ?? []
        owned.insert(item.id)
        profile.ownedStoreItemIDs = owned
        haptics.rewardClaim()
        uiSound.play(.claim)
        return true
    }

    // MARK: - Equipping cosmetics (owned items become visible effects)

    /// The one equipped balloon trail, if any — drawn behind the balloon in flight.
    var equippedTrail: StoreItem? {
        guard let id = profile.equippedTrailID else { return nil }
        guard let item = StoreItem.byID(id), item.kind == .trail else { return nil }
        return ownsStoreItem(item) ? item : nil
    }

    /// Equip a trail (or pass the equipped one again to unequip). Owned only.
    func equipTrail(_ item: StoreItem) {
        guard item.kind == .trail, ownsStoreItem(item) else { return }
        profile.equippedTrailID = profile.equippedTrailID == item.id ? nil : item.id
        haptics.tap()
    }

    func isCabinItemEquipped(_ item: StoreItem) -> Bool {
        (profile.equippedCabinItemIDs ?? []).contains(item.id)
    }

    /// Show/hide an owned decoration inside the Cabin View.
    func toggleCabinItem(_ item: StoreItem) {
        guard item.kind == .cabinDecoration, ownsStoreItem(item) else { return }
        var ids = profile.equippedCabinItemIDs ?? []
        if ids.contains(item.id) { ids.remove(item.id) } else { ids.insert(item.id) }
        profile.equippedCabinItemIDs = ids
        haptics.tap()
    }

    // MARK: - Onboarding completion

    /// Persist everything gathered by first-run onboarding and open the app.
    func completeOnboarding(name: String?, yearGoal: String?, ageRange: String?,
                            struggle: String?, focusStyle: String?, shieldOptIn: Bool) {
        var p = profile
        p.name = name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? name : nil
        p.yearGoal = yearGoal?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? yearGoal : nil
        p.ageRange = ageRange
        p.focusStruggle = struggle
        p.focusStyle = focusStyle
        p.focusShieldOptIn = shieldOptIn
        p.createdAt = p.createdAt ?? Date()
        p.hasCompletedOnboarding = true
        profile = p
    }

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
        // Grandfathering: a skin the pilot has ever earned is owned forever, so a
        // change to the unlock RULE can never re-lock it.
        if (profile.unlockedSkinIDs ?? []).contains(skin.id) { return true }
        switch skin.unlock {
        case .free:                return true
        case .focusMinutes(let n): return lifetimeFocusMinutes >= n   // real completed focused minutes
        case .journeys(let n):     return progress.landings >= n
        case .miles(let n):        return progress.totalFocusMiles >= n
        case .pro:                 return isPro   // active subscription only — re-locks if Pro lapses
        }
    }

    /// Whether a milestone skin is grandfathered (owned regardless of the rule).
    func isSkinGrandfathered(_ skin: BalloonSkin) -> Bool {
        (profile.unlockedSkinIDs ?? []).contains(skin.id)
    }

    /// 0…1 progress toward a milestone skin; `nil` for free, Pro, or already-unlocked.
    func unlockProgress(for skin: BalloonSkin) -> Double? {
        guard !isSkinUnlocked(skin) else { return nil }
        switch skin.unlock {
        case .focusMinutes(let n): return n <= 0 ? 1 : min(1, Double(lifetimeFocusMinutes) / Double(n))
        case .journeys(let n):     return n <= 0 ? 1 : min(1, Double(progress.landings) / Double(n))
        case .miles(let n):        return n <= 0 ? 1 : min(1, Double(progress.totalFocusMiles) / Double(n))
        case .free, .pro:          return nil
        }
    }

    /// Persist any newly-earned (non-PRO) milestone skin into the grandfather
    /// set, so future rule changes never re-lock it. Cheap and idempotent.
    private func captureEarnedSkins() {
        var owned = profile.unlockedSkinIDs ?? []
        var changed = false
        for skin in BalloonSkin.all {
            guard !skin.unlock.isPremium, !owned.contains(skin.id) else { continue }
            let earned: Bool
            switch skin.unlock {
            case .focusMinutes(let n): earned = lifetimeFocusMinutes >= n
            case .journeys(let n):     earned = progress.landings >= n
            case .miles(let n):        earned = progress.totalFocusMiles >= n
            case .free, .pro:          earned = false
            }
            if earned { owned.insert(skin.id); changed = true }
        }
        if changed { profile.unlockedSkinIDs = owned }
    }

    /// Persist any Sky whose FREE path is now satisfied into the permanent
    /// grandfather set, so a later requirement change (or a dropped streak) can
    /// never re-lock a Sky the pilot already earned. Never captures PRO-only or
    /// the free Sky. Idempotent.
    private func captureUnlockedSkies() {
        var unlocked = profile.unlockedSkyIDs ?? []
        var changed = false
        let minutes = lifetimeFocusMinutes
        let streak = progress.currentStreak
        for sky in FocusSky.all where !unlocked.contains(sky.id) {
            let invites = rawInviteCount(for: sky)
            if SkyUnlock.freePathMet(sky, focusMinutes: minutes, streakDays: streak, invites: invites) {
                unlocked.insert(sky.id); changed = true
            }
        }
        if changed { profile.unlockedSkyIDs = unlocked }
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
        // Every soundscape is free for now — sound is core to the experience.
        // (A future premium tier can reintroduce gating here in one place.)
        true
    }

    func selectJourneyAudio(_ option: JourneyAudioOption) {
        guard isAudioUnlocked(option) else { return }
        settings.selectedJourneyAudioID = option.id
        sound.switchOption(option)   // live-swap if a journey is currently playing
        tapFeedback()
    }

    /// The soundscape currently previewing (onboarding / Passport), or nil.
    var previewingJourneyAudioID: String? { sound.previewingOptionID }

    /// Start a looping PREVIEW of a soundscape (no flight). One at a time.
    func previewJourneyAudio(_ option: JourneyAudioOption) {
        sound.preview(option: option)
    }

    /// Stop any soundscape preview.
    func stopJourneyAudioPreview() {
        sound.stopPreview()
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
        // A "deep" journey = one qualifying session of at least 25 focused minutes
        // today (Infinite counts once it passes 25 min; cancelled / short sessions
        // never qualify — `todays` is already completed sessions only).
        let deepJourneys = Double(todays.filter { $0.focusedSeconds >= 25 * 60 }.count)
        return [
            DailyMission(id: "journey", title: "Complete one flight", systemImage: "paperplane.fill",
                         accent: .indigo, target: 1, current: journeys),
            DailyMission(id: "focus", title: "Focus 30 minutes", systemImage: "timer",
                         accent: .teal, target: 30, current: minutes),
            DailyMission(id: "deep", title: "Complete a 25-minute focus journey",
                         systemImage: "hourglass", accent: .gold, target: 1, current: deepJourneys),
            DailyMission(id: "miles", title: "Earn 60 Focus Coins", systemImage: "sparkles",
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
    /// Cap applied to the coins banked at landing after all multipliers
    /// (base → boost → friend ×2). The rewarded-ad double on the Landing
    /// screen doubles this already-capped amount at most once.
    static let maximumCoinsPerJourneyAfterMultipliers = 50

    func completeJourney(origin: JourneyOrigin, route: Route,
                         focusedSeconds: Int, intention: String?,
                         onlineSessionID: String? = nil) -> LandingSummary {
        // CANONICAL five-minute eligibility (the ONE rule): a journey only counts
        // when it banks >= 300 real focused seconds. A shorter completion earns
        // NOTHING and touches NO stat — coins, journeys, streak, best, routes,
        // postcards, Sky/skin unlocks, the consistency grid, totals, distance and
        // widgets — and is recorded as a non-qualifying (uncredited) session so
        // every `completed`-filtered surface excludes it. Infinite flights qualify
        // only when ended after >= 300 focused seconds (same gate). Duplicate
        // completions are prevented upstream by the session's `didLand` guard.
        let qualifies = focusedSeconds >= FocusConsistency.qualifyingSeconds

        // Canonical focus distance: the balloon drifts at 15 km/h, so distance
        // comes purely from REAL focused time (never geography).
        let distanceKm = FocusMetrics.distanceKm(focusedSeconds: focusedSeconds)
        // Focus Coins scale with *actual completed focus minutes* — and only for a
        // qualifying journey, so a short flight can never be farmed for coins.
        let baseMiles = qualifies ? FocusEconomy.coins(forFocusedSeconds: focusedSeconds) : 0
        // An equipped Coins Boost is consumed + doubles the coins for up to the
        // first hour — only on a qualifying journey (a short flight never burns it).
        let boostBonus = (qualifies && consumeCoinBoostIfArmed())
            ? FocusEconomy.coins(forFocusedSeconds: min(focusedSeconds, 3600)) : 0
        // Friend-flight bonus: a VERIFIED private-room flight with ≥5 minutes of
        // real overlap doubles the coins — once per session (idempotent), never
        // for decorative pilots or public strangers, capped globally.
        var friendMultiplier = 1
        if qualifies, let sessionID = onlineSessionID,
           onlineRef?.friendBonusEligible(sessionID: sessionID) == true,
           !(profile.rewardedFriendSessionIDs ?? []).contains(sessionID) {
            friendMultiplier = 2
            var rewarded = profile.rewardedFriendSessionIDs ?? []
            rewarded.append(sessionID)
            if rewarded.count > 60 { rewarded.removeFirst(rewarded.count - 60) }
            profile.rewardedFriendSessionIDs = rewarded
        }
        let awardedMiles = qualifies
            ? min(Self.maximumCoinsPerJourneyAfterMultipliers, (baseMiles + boostBonus) * friendMultiplier)
            : 0
        let isNewRoute = qualifies && !progress.completedRouteIDs.contains(route.id)
        let isNewBest = qualifies && focusedSeconds > progress.bestFocusSeconds

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
            focusMiles: awardedMiles,
            intention: finalIntention,
            completed: qualifies      // uncredited when < 300 s → excluded everywhere
        )

        history.insert(record, at: 0)

        let postcard = Postcard(route: route)
        var streakIncreased = false
        var landedStreak = progress.currentStreak

        if qualifies {
            var p = progress
            p.totalFocusMiles += awardedMiles
            p.landings += 1
            p.bestFocusSeconds = max(p.bestFocusSeconds, focusedSeconds)
            p.completedRouteIDs.insert(route.id)
            if !p.postcards.contains(where: { $0.id == postcard.id }) {
                p.postcards.insert(postcard, at: 0)
            }
            let previousStreak = progress.currentStreak
            applyStreak(to: &p, landingDate: record.date)
            streakIncreased = p.currentStreak > previousStreak
            progress = p
            landedStreak = p.currentStreak
            // Capture any skin or Sky just earned into the grandfather sets, so a
            // later rule change (or a dropped streak) can never re-lock them.
            captureEarnedSkins()
            captureUnlockedSkies()

            // Remember where we came from so the next screen can offer a return
            // trip, then make the destination the next origin. Only a qualifying
            // journey moves the pilot across the world.
            settings.previousOrigin = origin
            arrive(at: JourneyOrigin(city: route.destinationName, country: "",
                                     coordinate: route.destination, code: route.destinationCode))
        }

        persistAll()
        analytics.log(.journeyCompleted, [
            "route": route.id, "minutes": focusedSeconds / 60, "miles": baseMiles,
            "qualified": qualifies
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
            baseMiles: awardedMiles,
            postcard: postcard,
            streak: landedStreak,
            isNewRoute: isNewRoute,
            isNewBest: isNewBest,
            streakIncreased: streakIncreased
        )
    }

    /// Records a cancelled journey for history. Does not award miles or streak.
    func cancelJourney(origin: JourneyOrigin, route: Route, focusedSeconds: Int, intention: String?) {
        let trimmed = intention?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalIntention = (trimmed?.isEmpty == false) ? trimmed : nil
        // Focus distance from the REAL partial focused time — the cancelled
        // session's own effort, never a fraction of a geographic route.
        let distanceKm = FocusMetrics.distanceKm(focusedSeconds: focusedSeconds)

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
    /// Journey-scoped: true once this journey's single post-flight ad
    /// opportunity has been used — either a watched Double-Coins rewarded ad or
    /// one journey-complete interstitial attempt. Prevents a rewarded ad and an
    /// interstitial from stacking in one landing. Reset when the next journey
    /// begins (see `FocusSessionViewModel.startIfNeeded`). Never set for Pro or
    /// previews.
    var postFlightAdSatisfied = false

    func watchRewardedAd() async -> Bool {
        let earned = await ads.showRewarded(.doubleMiles, isPro: isPro)
        if earned { postFlightAdSatisfied = true }
        return earned
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

        if let longest = history.filter({ $0.completed }).max(by: { $0.focusDistanceKm < $1.focusDistanceKm }) {
            snap.longestRouteOrigin = longest.originName
            snap.longestRouteDestination = longest.destinationName
            snap.longestRouteKm = Int(longest.focusDistanceKm.rounded())
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

        // MARK: Final-5 widget data
        // The ONE authoritative focused-time total (completed sessions only).
        snap.totalFocusedSeconds = history.filter { $0.completed }.reduce(0) { $0 + max(0, $1.focusedSeconds) }
        // Active focus days + today state + the 26-week grid's active day set,
        // from the SAME model the Passport/Streak grid uses (300 s rule).
        let cal = Calendar.current
        let activeDays = FocusConsistency.activeDays(history: history, calendar: cal)
        snap.activeFocusDays = activeDays.count
        let today = cal.startOfDay(for: Date())
        snap.focusedToday = activeDays[today] != nil
        // Only the last ~26 weeks are needed for the grid; keep the payload small.
        let cutoff = today.addingTimeInterval(-Double(26 * 7 + 2) * 86_400)
        func ordinal(_ day: Date) -> Int {
            Int((cal.startOfDay(for: day).timeIntervalSince1970 / 86_400).rounded())
        }
        snap.activeDayOrdinals = activeDays.keys.filter { $0 >= cutoff }.map(ordinal)
        // Per-day focus category (latest qualifying journey), keyed by the SAME
        // ordinal, so the widget grid tints each lit day exactly like Passport.
        let dayCats = FocusConsistency.dayCategories(history: history, calendar: cal)
        var catByOrdinal: [Int: String] = [:]
        for (day, key) in dayCats where day >= cutoff { catByOrdinal[ordinal(day)] = key }
        snap.activeDayCategories = catByOrdinal
        // The selected Sky's identity + gradient for the idle Focus Now backdrop.
        let sky = selectedSky
        snap.selectedSkyName = sky.name
        snap.skyTopHex = Int(sky.moodPalette.first ?? 0x181721)
        snap.skyBottomHex = Int(sky.moodPalette.last ?? 0x100F16)
        // Active-flight live state (nil when idle).
        snap.activeFlight = activeFlightSkyName != nil || activeFlightEndDate != nil || activeFlightInfinite
        snap.activeEndDate = activeFlightEndDate
        snap.activeInfinite = activeFlightInfinite
        snap.activeSkyName = activeFlightSkyName
        snap.activeCategory = activeFlightCategory
        // Badges — real earned state (never fabricated).
        let badges = makeWidgetBadges()
        snap.badges = badges
        snap.badgeUnlockedCount = badges.filter { $0.earned }.count
        snap.badgeTotal = badges.count

        snap.updatedAt = Date()
        return snap
    }

    // MARK: Active-flight widget state (drives the Focus Now live timer)

    private(set) var activeFlightEndDate: Date?
    private(set) var activeFlightSkyName: String?
    private(set) var activeFlightCategory: String?
    private(set) var activeFlightInfinite = false

    /// Called when a flight actually starts (or resumes) so the Focus Now widget
    /// can show the live remaining time via a native timer. `endDate == nil` with
    /// `infinite == true` renders ∞.
    func flightDidStart(skyName: String, category: String?, endDate: Date?, infinite: Bool) {
        activeFlightSkyName = skyName
        activeFlightCategory = category
        activeFlightEndDate = endDate
        activeFlightInfinite = infinite
        syncWidgets()
    }

    /// Called when a flight lands, is cancelled, or the session tears down.
    func flightDidEnd() {
        guard activeFlightSkyName != nil || activeFlightEndDate != nil || activeFlightInfinite else { return }
        activeFlightSkyName = nil
        activeFlightCategory = nil
        activeFlightEndDate = nil
        activeFlightInfinite = false
        syncWidgets()
    }

    /// The badge set for the Badge Collection widget — a compact, real slice of
    /// the Passport achievements (earned flags computed from live progress; never
    /// fabricated). Ordered so unlocked badges surface first and the first locked
    /// one is the "next" hint.
    private func makeWidgetBadges() -> [WidgetBadge] {
        let flights = progress.landings
        let mins = lifetimeFocusMinutes
        let best = progress.bestFocusMinutes
        let streak = max(progress.currentStreak, progress.longestStreak)
        let coins = progress.totalFocusMiles
        let raw: [(String, String, Bool)] = [
            ("First Flight", "airplane.departure", flights >= 1),
            ("5 Flights", "5.circle.fill", flights >= 5),
            ("10 Flights", "10.circle.fill", flights >= 10),
            ("25 Flights", "airplane.circle.fill", flights >= 25),
            ("25-Min Pilot", "25.circle.fill", best >= 25),
            ("1 Hour Focused", "hourglass.bottomhalf.filled", best >= 60),
            ("100 Focus Minutes", "clock.fill", mins >= 100),
            ("500 Focus Minutes", "clock.badge.checkmark.fill", mins >= 500),
            ("1,000 Focus Minutes", "infinity.circle.fill", mins >= 1000),
            ("3-Day Streak", "flame.fill", streak >= 3),
            ("7-Day Streak", "bolt.heart.fill", streak >= 7),
            ("14-Day Streak", "flame.circle.fill", streak >= 14),
            ("Focus Coin Saver", "circle.hexagongrid.circle.fill", coins >= 100),
            ("PRO Pilot", "crown.fill", isPro),
        ]
        let earned = raw.filter { $0.2 }.map { WidgetBadge(name: $0.0, icon: $0.1, earned: true) }
        let locked = raw.filter { !$0.2 }.map { WidgetBadge(name: $0.0, icon: $0.1, earned: false) }
        return earned + locked
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
