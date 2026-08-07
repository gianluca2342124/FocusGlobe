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
        didSet {
            guard !isBatchingPersistence else { return }
            persistence.save(profile, for: .profile)
        }
    }
    @Published private(set) var progress: UserProgress
    @Published private(set) var history: [FocusSessionRecord]
    /// The REAL entitlement, mirrored from RevenueCat and persisted.
    ///
    /// This is the only Pro value that is ever written to disk. The Debug-only
    /// override deliberately does NOT flow into it: `fg.isPro` is read back at
    /// launch by every configuration, so letting a local override persist here
    /// would let a Debug session grant Pro to a Release build on the same device.
    /// Read `isPro` (below) for access decisions; assign this only from a real
    /// RevenueCat / purchase result.
    @Published private(set) var revenueCatPro: Bool {
        didSet {
            guard oldValue != revenueCatPro else { return }
            // Persist the local Pro mirror so a returning Pro user isn't briefly
            // un-Pro at cold launch before RevenueCat re-resolves the entitlement.
            // RevenueCat remains the source of truth and corrects this if it ever
            // disagrees (e.g. a lapse detected once back online).
            persistence.setBool(revenueCatPro, for: .isPro)
            proAccessDidChange()
        }
    }

    /// THE canonical PRO access for the whole app — the real RevenueCat
    /// entitlement, and nothing else.
    ///
    /// Every gate — Skies, skins, cabin items, Online Mode, Unlimited Time,
    /// widgets, ads, 2x coins, Store, Friends, Settings, journey setup, paywalls,
    /// onboarding — reads this one value.
    ///
    /// There is deliberately no local override of any kind, in any build
    /// configuration. The temporary Debug "Force FocusGlobe PRO" switch has been
    /// removed now that the developer account holds a real lifetime entitlement;
    /// testing PRO means signing into an account that owns it (Settings ▸
    /// Account), which exercises the same path a customer takes.
    var isPro: Bool { revenueCatPro }

    /// Side effects of an effective-access change, from either source.
    ///
    /// When Pro lapses, premium skins/audio must re-lock immediately and any
    /// premium selection falls back to its free default — premium content is
    /// never permanently unlocked.
    private func proAccessDidChange() {
        if !isPro { reconcilePremiumSelections() }
        syncWidgets()
        recordNewBadgeUnlocks()
    }

    /// The premium entitlement as a tri-state. Monthly / Annual / Lifetime all
    /// resolve to `.premium` through the SAME authority (`isPro`, driven by
    /// RevenueCat's single entitlement / the persisted mirror). `.loading` is only
    /// ever reported while RevenueCat is still resolving CustomerInfo for a pilot
    /// who isn't already Pro — so a gate must NEVER treat `.loading` as Free and
    /// flash a paywall at a PRO/Lifetime owner whose entitlement hasn't arrived.
    enum Entitlement: Equatable { case loading, free, premium }
    var entitlement: Entitlement {
        if isPro { return .premium }
        if subscriptions.isAvailable && !subscriptions.hasResolvedEntitlement { return .loading }
        return .free
    }
    /// `true` only when we can be sure the pilot is NOT premium (never during load).
    var isConfirmedFree: Bool { entitlement == .free }

    /// A lightweight snapshot of an unfinished journey, offered for resume on Home.
    @Published private(set) var resumableJourney: ResumableJourney?

    /// The ONE question every resume surface should ask: is there a journey we can
    /// genuinely offer to continue? Only a Solo snapshot qualifies — an Online or
    /// unidentifiable one is never resumable, however recent it is.
    var hasResumableJourney: Bool { resumableJourney?.isResumable ?? false }

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
    /// The app's ONE network-path monitor. Owned here so no view ever creates a
    /// second `NWPathMonitor`; started once in `init`.
    let connectivity = FocusConnectivity()

    private let persistence: PersistenceService
    private var cancellables: Set<AnyCancellable> = []
    /// Suppresses per-domain `didSet` writes while a cross-domain economy or
    /// identity mutation is assembled for one atomic snapshot commit.
    private var isBatchingPersistence = false

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
        self.revenueCatPro = persistence.bool(for: .isPro)
        // Only a snapshot that PROVES it is Solo survives the load. An Online one —
        // or a legacy one from before the mode was recorded, which is therefore
        // indistinguishable from a stale Online journey written by a buggy build —
        // is dropped here rather than being offered on Home. This is what clears
        // the "Resume your flight" CTA that is already stuck on existing installs.
        let loadedResume = persistence.load(ResumableJourney.self, for: .resumableJourney)
        if let loadedResume, !loadedResume.isResumable {
            self.resumableJourney = nil
            persistence.remove(.resumableJourney)
        } else {
            self.resumableJourney = loadedResume
        }

        // Profile: first-run onboarding shows only for genuinely new pilots.
        // Anyone with existing progress/history predates onboarding — mark it
        // completed once so they are never onboarded retroactively.
        var loadedProfile = persistence.load(UserProfile.self, for: .profile) ?? .empty
        if !loadedProfile.hasCompletedOnboarding
            && (loadedProgress.hasAnyProgress || !loadedHistory.isEmpty) {
            loadedProfile.hasCompletedOnboarding = true
            persistence.save(loadedProfile, for: .profile)
        }
        // Canonical name resolution — exactly once per profile, at first load
        // under this build. `hasCustomizedName == nil` is the "not yet resolved"
        // marker; after this it is always a real Bool and never revisited, so a
        // launch can never regenerate or reclassify a name.
        //
        // Three cases, in priority order:
        //  1. A name is already stored. Only the old Settings "Your name" field
        //     ever wrote one, and only a human ever typed into it — so it is
        //     genuinely theirs and is kept AND marked customized.
        //  2. No name, but this device has a cached Online profile. Adopt that
        //     alias rather than minting a second identity, and leave it marked
        //     generated so Home stays quiet about it.
        //  3. Neither. Generate one, once.
        if loadedProfile.hasCustomizedName == nil {
            let stored = loadedProfile.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !stored.isEmpty {
                loadedProfile.name = stored
                loadedProfile.hasCustomizedName = true
            } else {
                let cachedAlias = OnlineCache.loadProfile()?.displayName
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                loadedProfile.name = cachedAlias.isEmpty ? PublicName.generated() : cachedAlias
                loadedProfile.hasCustomizedName = false
            }
            persistence.save(loadedProfile, for: .profile)
        }
        // The guarantee, restated unconditionally: a name exists at every stable
        // state, including profiles resolved by an older build and any that lost
        // the field in a partial decode. Cheap, idempotent, and it means no
        // surface downstream needs a placeholder.
        if PublicName.display(loadedProfile.name ?? "").isEmpty {
            loadedProfile.name = PublicName.generated()
            loadedProfile.hasCustomizedName = loadedProfile.hasCustomizedName ?? false
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
                var kept = equipped.intersection(valid)
                // The Cabin now holds at most `StoreItem.maxEquipped` objects. A
                // profile saved before that cap could carry more, so trim to the
                // catalog's first N — deterministic, and it keeps the pieces a
                // pilot is most likely to recognise rather than an arbitrary
                // subset of an unordered Set.
                if kept.count > StoreItem.maxEquipped {
                    kept = Set(StoreItem.cabinDecorations
                        .filter { kept.contains($0.id) }
                        .prefix(StoreItem.maxEquipped)
                        .map(\.id))
                }
                if kept != equipped { loadedProfile.equippedCabinItemIDs = kept; dirty = true }

                // Upgrade the old four-bucket auto-layout to persisted semantic
                // slots. Preserve a valid saved choice; otherwise choose the
                // item's preferred free slot, then its next compatible slot.
                var placements = loadedProfile.cabinItemSlotByID ?? [:]
                placements = placements.filter { kept.contains($0.key) }
                var occupied = Set<CabinSlot>()
                var placedIDs = Set<String>()
                for item in StoreItem.cabinDecorations where kept.contains(item.id) {
                    let saved = placements[item.id].flatMap(CabinSlot.persisted)
                    let candidates = ([item.preferredSlot].compactMap { $0 } + item.allowedSlots)
                        .reduce(into: [CabinSlot]()) { result, slot in
                            if !result.contains(slot) { result.append(slot) }
                        }
                    guard let slot = saved.flatMap({ item.supports($0) && !occupied.contains($0) ? $0 : nil })
                            ?? candidates.first(where: { !occupied.contains($0) }) else {
                        placements.removeValue(forKey: item.id)
                        continue
                    }
                    placements[item.id] = slot.rawValue
                    occupied.insert(slot)
                    placedIDs.insert(item.id)
                }
                if placedIDs != kept {
                    loadedProfile.equippedCabinItemIDs = placedIDs
                    kept = placedIDs
                    dirty = true
                }
                if placements != loadedProfile.cabinItemSlotByID {
                    loadedProfile.cabinItemSlotByID = placements
                    dirty = true
                }
            }
            if let trail = loadedProfile.equippedTrailID, !valid.contains(trail) {
                loadedProfile.equippedTrailID = nil; dirty = true
            }
            if dirty { persistence.save(loadedProfile, for: .profile) }
        }
        // Balloon-skin migration (flight milestones → focused minutes): the
        // original five milestone skins unlock at 300/900/1800/3000/5000
        // focused minutes; later progression skins use the same canonical path.
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
        // Capture every currently-satisfied progression skin on launch. This
        // makes the 10,000-minute Earth unlock monotonic for an existing pilot
        // immediately after an app update, without waiting for another flight.
        if Self.captureEarnedSkinIDs(into: &loadedProfile,
                                     progress: loadedProgress,
                                     history: loadedHistory) {
            persistence.save(loadedProfile, for: .profile)
        }
        self.profile = loadedProfile
        LaunchLog.mark("AppModel.init persistence loaded")

        haptics.isEnabled = loadedSettings.hapticsEnabled
        sound.isEnabled = loadedSettings.soundEnabled
        uiSound.isEnabled = loadedSettings.soundEnabled

        // Retention-notification analytics (scheduled / cancelled). Opened is
        // logged by the notification-center delegate.
        notifications.onEvent = { [weak analytics] action, category in
            let event: AnalyticsEvent = (action == "scheduled") ? .notificationScheduled : .notificationCancelled
            analytics?.log(event, ["category": category])
        }

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
        // One path monitor for the whole app, started once. Cheap, and the
        // only thing that can answer "is there a connection right now" before a
        // request has already failed.
        connectivity.start()
        LaunchLog.mark("subscriptions.configure")
        subscriptions.configure()
        subscriptions.$isPro
            .receive(on: RunLoop.main)
            .sink { [weak self] pro in
                guard let self, self.subscriptions.isAvailable else { return }
                self.revenueCatPro = pro
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

        // A streak can die between launches with nothing running to notice, so
        // correct the loaded value BEFORE anything reads or publishes it —
        // otherwise the first widget snapshot of the session carries a number the
        // calendar broke days ago.
        reconcileStreakIfNeeded()

        // Publish the initial widget snapshot from the just-loaded state.
        LaunchLog.mark("syncWidgets")
        initializeBadgeTrackingIfNeeded()
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
        recordNewBadgeUnlocks()
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
        revenueCatPro = false
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
        item.isPremium ? isPro : (profile.ownedStoreItemIDs ?? []).contains(item.id)
    }

    // MARK: - Daily gift (Shop)

    static let dailyGiftCoins = 10

    private var todayDayOrdinal: Int {
        Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
    }

    /// True at most once per calendar day, until the gift is collected.
    var canClaimDailyGift: Bool {
        Self.canClaimDailyGift(lastClaimedDay: profile.lastDailyGiftDay,
                               today: todayDayOrdinal)
    }

    /// Kept pure so the once-per-local-day rule and update behavior can be
    /// regression-tested without mutating a real pilot's profile.
    private static func canClaimDailyGift(lastClaimedDay: Int?, today: Int) -> Bool {
        lastClaimedDay != today
    }

    /// Collect the daily gift: +10 Coins, once per day. Returns the amount
    /// granted (0 if already claimed today). Premium pilots receive it too.
    @discardableResult
    func claimDailyGift() -> Int {
        guard canClaimDailyGift else { return 0 }
        let claimedDay = todayDayOrdinal
        performPersistedTransaction {
            profile.lastDailyGiftDay = claimedDay
            var p = progress
            p.totalFocusMiles += Self.dailyGiftCoins
            progress = p
            recordCoinEarnings(Self.dailyGiftCoins)
            recordNewBadgeUnlocks()
        }
        haptics.rewardClaim()
        uiSound.play(.claim)
        analytics.log(.rewardClaimed, ["source": "daily_gift", "miles": Self.dailyGiftCoins])
        return Self.dailyGiftCoins
    }

    #if DEBUG
    /// Pure policy checks for the economy change. Durable transaction and
    /// account-isolation coverage lives in `PersistenceService._selfCheck()`.
    static func _dailyGiftSelfCheck() -> String? {
        guard dailyGiftCoins == 10 else { return "Daily Gift is not exactly 10 Coins" }
        guard canClaimDailyGift(lastClaimedDay: nil, today: 7_500) else {
            return "A never-claimed Daily Gift was not eligible"
        }
        guard !canClaimDailyGift(lastClaimedDay: 7_500, today: 7_500) else {
            return "An already-claimed local day became eligible again"
        }
        guard canClaimDailyGift(lastClaimedDay: 7_500, today: 7_501) else {
            return "The next local day did not become eligible"
        }
        guard 42 + dailyGiftCoins == 52 else {
            return "Daily Gift balance delta was not exactly 10"
        }
        return nil
    }
    #endif

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

    /// Show the rewarded video, then — and ONLY then — grant a weighted spin
    /// prize and return it. Returns `nil` whenever no reward was earned: the ad
    /// failed to load, no ad was available, consent hasn't resolved, the pilot
    /// closed it early, or the cooldown hasn't elapsed. The caller shows a gentle
    /// message and the wheel never turns. Nothing is credited on any of those paths.
    ///
    /// EVERY pilot watches, PRO included. PRO buys away the ads FocusGlobe puts
    /// in front of you — banners, interstitials, anything automatic — not the
    /// video you choose to watch because you want the coins on the other side of
    /// it. The spin is a voluntary exchange, so `showVoluntaryRewarded` is used
    /// and the entitlement is not consulted here at all. (Entitlement logic is
    /// untouched; this is a placement decision, nothing more.)
    func spinCoinReward() async -> Int? {
        guard canCoinSpin else { return nil }
        let earned = await ads.showVoluntaryRewarded(.doubleMiles)
        guard earned else { return nil }
        let prize = Self.weightedSpinPrize()
        var updated = profile
        updated.lastCoinSpinAt = Date().timeIntervalSince1970
        // Stamp the objective here, at the single point where a spin is genuinely
        // resolved: the prize is decided and the coins are about to be credited.
        // The wheel that follows is presentation only.
        updated.coinSpinEventDayKey = Self.dayKey(Date())
        profile = updated
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
        recordCoinEarnings(n)
        recordNewBadgeUnlocks()
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

    /// Called only by the canonical Online identity coordinator when the stable
    /// Supabase user UUID changes. Local progress is committed before switching,
    /// then the selected account's complete state is loaded as one revision.
    func persistenceAccountDidChange(to stableUserID: String?) {
        flushPersistentState()
        guard persistence.activateAccount(stableUserID) else { return }

        let loadedSettings = persistence.load(AppSettings.self, for: .settings) ?? .default
        let loadedProgress = persistence.load(UserProgress.self, for: .progress) ?? .empty
        let loadedHistory = persistence.load([FocusSessionRecord].self, for: .history) ?? []
        var loadedProfile = persistence.load(UserProfile.self, for: .profile) ?? .empty

        if !loadedProfile.hasCompletedOnboarding
            && (loadedProgress.hasAnyProgress || !loadedHistory.isEmpty) {
            loadedProfile.hasCompletedOnboarding = true
        }
        if let skyID = loadedProfile.selectedSkyID, FocusSky.byID(skyID) == nil {
            loadedProfile.selectedSkyID = FocusSky.defaultFree.id
        }
        // Switching accounts loads a DIFFERENT profile, which may be empty (a
        // first sign-in on this device) or predate the canonical name. The
        // guarantee has to hold for whatever was just loaded, not only for the
        // one resolved at launch.
        if PublicName.display(loadedProfile.name ?? "").isEmpty {
            loadedProfile.name = PublicName.generated()
            loadedProfile.hasCustomizedName = loadedProfile.hasCustomizedName ?? false
        }

        // Account files may have last been opened by an older catalog. Remove
        // only invalid references; valid ownership and semantic Cabin slots stay
        // byte-for-byte account specific.
        let validStoreIDs = StoreItem.validIDs
        loadedProfile.ownedStoreItemIDs = loadedProfile.ownedStoreItemIDs?.intersection(validStoreIDs)
        if let trail = loadedProfile.equippedTrailID, !validStoreIDs.contains(trail) {
            loadedProfile.equippedTrailID = nil
        }
        var equipped = loadedProfile.equippedCabinItemIDs?.intersection(validStoreIDs) ?? []
        if equipped.count > StoreItem.maxEquipped {
            equipped = Set(StoreItem.cabinDecorations
                .filter { equipped.contains($0.id) }
                .prefix(StoreItem.maxEquipped)
                .map(\.id))
        }
        var placements = loadedProfile.cabinItemSlotByID ?? [:]
        placements = placements.filter { itemID, rawSlot in
            guard equipped.contains(itemID),
                  let item = StoreItem.byID(itemID),
                  let slot = CabinSlot.persisted(rawSlot) else { return false }
            return item.supports(slot)
        }
        // Deterministically resolve old duplicate-slot data without moving any
        // valid earlier catalog item to arbitrary device coordinates.
        var occupied = Set<CabinSlot>()
        for item in StoreItem.cabinDecorations where equipped.contains(item.id) {
            guard let raw = placements[item.id], let slot = CabinSlot.persisted(raw) else {
                equipped.remove(item.id)
                continue
            }
            if occupied.contains(slot) {
                equipped.remove(item.id)
                placements.removeValue(forKey: item.id)
            } else {
                occupied.insert(slot)
            }
        }
        loadedProfile.equippedCabinItemIDs = equipped
        loadedProfile.cabinItemSlotByID = placements.filter { equipped.contains($0.key) }
        _ = Self.captureEarnedSkinIDs(into: &loadedProfile,
                                      progress: loadedProgress,
                                      history: loadedHistory)

        isBatchingPersistence = true
        progress = loadedProgress
        history = loadedHistory
        settings = loadedSettings
        profile = loadedProfile

        let loadedResume = persistence.load(ResumableJourney.self, for: .resumableJourney)
        if let loadedResume, loadedResume.isResumable {
            resumableJourney = loadedResume
        } else {
            resumableJourney = nil
            persistence.remove(.resumableJourney)
        }
        isBatchingPersistence = false

        haptics.isEnabled = settings.hapticsEnabled
        sound.setEnabled(settings.soundEnabled)
        uiSound.isEnabled = settings.soundEnabled
        reconcileStreakIfNeeded()
        initializeBadgeTrackingIfNeeded()
        flushPersistentState()
        syncWidgets()
        refreshNotifications()
    }

    /// Immediate durable checkpoint for lifecycle and identity boundaries.
    /// Normal mutations already save synchronously; this prevents a future
    /// debounced writer from weakening the force-quit guarantee.
    func flushPersistentState() {
        persistence.saveCanonicalState(settings: settings,
                                       progress: progress,
                                       history: history,
                                       profile: profile,
                                       resumableJourney: resumableJourney)
        persistence.flush()
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
    func onlineFlightDidEnd(sessionID: String) {
        // A definitive "an Online flight just ended" signal, independent of the
        // sticky `flightMode`. Leaving an Online journey must never leave a resume
        // offer behind — including one inherited from an earlier Solo flight, which
        // can no longer be reconstructed meaningfully once this journey replaced it.
        if onlineRef?.flightMode.isOnline == true { clearResumableJourney() }
        onlineRef?.flightDidEnd(sessionID: sessionID)
    }

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
        recordNewBadgeUnlocks()
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

    /// The one persisted placement map used by Store preview and active Cabin.
    var cabinPlacements: [String: CabinSlot] {
        let equipped = profile.equippedCabinItemIDs ?? []
        let raw = profile.cabinItemSlotByID ?? [:]
        return raw.reduce(into: [:]) { result, pair in
            guard equipped.contains(pair.key),
                  let item = StoreItem.byID(pair.key),
                  let slot = CabinSlot.persisted(pair.value),
                  item.supports(slot) else { return }
            result[pair.key] = slot
        }
    }

    func cabinSlot(for item: StoreItem) -> CabinSlot? { cabinPlacements[item.id] }

    /// Compatible unoccupied slots. Passing the currently-moving item excludes
    /// its own old placement from collision checks.
    func availableCabinSlots(for item: StoreItem, moving: StoreItem? = nil) -> [CabinSlot] {
        let ignoredID = moving?.id ?? item.id
        let occupied = Set(cabinPlacements.compactMap { $0.key == ignoredID ? nil : $0.value })
        return item.allowedSlots.filter { !occupied.contains($0) }
    }

    /// How many decorations are currently placed in the Cabin.
    var equippedCabinItemCount: Int { (profile.equippedCabinItemIDs ?? []).count }

    /// True when the Cabin is full, so the Store can say so up front instead of
    /// letting a tap silently do nothing.
    var isCabinFull: Bool { equippedCabinItemCount >= StoreItem.maxEquipped }

    /// Place an owned item in a compatible semantic slot. A fifth item must name
    /// the equipped item it replaces; collisions and window-covering coordinates
    /// are impossible because callers can only provide a catalogued `CabinSlot`.
    @discardableResult
    func placeCabinItem(_ item: StoreItem, in slot: CabinSlot,
                        replacing replacement: StoreItem? = nil) -> Bool {
        guard item.kind == .cabinDecoration, ownsStoreItem(item), item.supports(slot) else {
            haptics.refused()
            return false
        }
        var ids = profile.equippedCabinItemIDs ?? []
        var placements = profile.cabinItemSlotByID ?? [:]

        if let replacement, replacement.id != item.id {
            guard ids.contains(replacement.id) else { return false }
            ids.remove(replacement.id)
            placements.removeValue(forKey: replacement.id)
        }
        if !ids.contains(item.id), ids.count >= StoreItem.maxEquipped {
            haptics.refused()
            return false
        }
        let occupiedByAnother = placements.contains {
            $0.key != item.id && ids.contains($0.key)
                && CabinSlot.persisted($0.value) == slot
        }
        guard !occupiedByAnother else {
            haptics.refused()
            return false
        }
        ids.insert(item.id)
        placements[item.id] = slot.rawValue
        profile.equippedCabinItemIDs = ids
        profile.cabinItemSlotByID = placements
        haptics.tap()
        return true
    }

    @discardableResult
    func moveCabinItem(_ item: StoreItem, to slot: CabinSlot) -> Bool {
        guard isCabinItemEquipped(item) else { return false }
        return placeCabinItem(item, in: slot)
    }

    func unequipCabinItem(_ item: StoreItem) {
        var ids = profile.equippedCabinItemIDs ?? []
        var placements = profile.cabinItemSlotByID ?? [:]
        ids.remove(item.id)
        placements.removeValue(forKey: item.id)
        profile.equippedCabinItemIDs = ids
        profile.cabinItemSlotByID = placements
        haptics.tap()
    }

    /// Compatibility path for older call sites: remove an equipped item, or
    /// place a new one in its first free preferred/allowed slot.
    @discardableResult
    func toggleCabinItem(_ item: StoreItem) -> Bool {
        guard item.kind == .cabinDecoration, ownsStoreItem(item) else { return false }
        if isCabinItemEquipped(item) {
            unequipCabinItem(item)
            return true
        }
        guard !isCabinFull,
              let slot = availableCabinSlots(for: item).first else {
            haptics.refused()
            return false
        }
        return placeCabinItem(item, in: slot)
    }

    // MARK: - Language

    /// The active language. Reads the pilot's choice when they made one, the
    /// device's own preference when they have not.
    ///
    /// There is no third state and no separate "has chosen" flag: `nil` in
    /// settings IS "never chose". That is why selecting the language the device
    /// already reports still writes — from then on the choice is theirs and
    /// survives the phone being switched to something else.
    var preferredLanguage: FocusLanguage {
        get {
            guard let stored = settings.preferredLanguageCode else { return .devicePreferred }
            return FocusLanguage.resolve(stored)
        }
        set { settings.preferredLanguageCode = newValue.code }
    }

    /// The locale handed to the SwiftUI environment at the app root.
    var preferredLocale: Locale { Locale(identifier: preferredLanguage.code) }

    // MARK: - The canonical name

    /// The ONE user-facing name: the Settings Profile field, and the alias
    /// Friends and Online publish. There is no second name anywhere — the old
    /// split (a private `Your name` for Home, a separate `Public alias` for the
    /// network) is what made them drift.
    var canonicalName: String { profile.name ?? "" }

    /// Whether the pilot typed it themselves. Every profile carries a name from
    /// its first load, so a non-empty value proves nothing.
    /// See `UserProfile.hasCustomizedName`.
    var hasCustomizedName: Bool { profile.hasCustomizedName ?? false }

    /// The name to ADDRESS the pilot by — `nil` until they chose one.
    ///
    /// The one rule that keeps this from going wrong: `canonicalName` is what
    /// FocusGlobe PUBLISHES (Friends, Online, the profile row), `personalName`
    /// is what it CALLS you. Every surface that speaks to the pilot — the Home
    /// greeting, the Passport logbook, a shared grid — reads this one, so a
    /// generated "SkyPilot4823" can never be mistaken for a name someone chose.
    var personalName: String? {
        guard hasCustomizedName else { return nil }
        let trimmed = canonicalName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Take the server's name as canonical WITHOUT marking it customized.
    ///
    /// Used only when signing in: the `profiles` row is authoritative for a name
    /// that already exists, so a pilot who never chose one adopts whatever the
    /// account holds — including a name assigned on another device. It stays
    /// marked generated, which is what keeps Home quiet about it.
    func adoptServerName(_ name: String) {
        let resolved = PublicName.display(name)
        guard !resolved.isEmpty, resolved != profile.name else { return }
        var p = profile
        p.name = resolved
        profile = p
    }

    /// The name always exists. Called at load and after any identity change.
    ///
    /// `hasCustomizedName == nil` is the "never resolved" marker, but a name can
    /// also go missing later — a decode that dropped the field, a profile reset,
    /// a build that predates this. This repairs any of those in one place rather
    /// than leaving a UI fallback like "Pilot" standing in for a real value.
    /// It never touches a name that already exists.
    func ensureCanonicalNameExists() {
        guard PublicName.display(profile.name ?? "").isEmpty else { return }
        var p = profile
        p.name = PublicName.generated()
        // Generated, so Home stays quiet — unless the pilot had already been
        // marked customized, in which case that fact is theirs and stands.
        if p.hasCustomizedName == nil { p.hasCustomizedName = false }
        profile = p
    }

    /// Commit a name the pilot typed.
    ///
    /// Trimmed, and capped at 20 to match the alias rule `updateAlias` already
    /// enforces, so a value accepted here can never be rejected by the network
    /// for length. An all-whitespace value is ignored rather than stored: the
    /// existing name stays, because a profile with no name would leave Friends
    /// with nothing to show. Persisting happens through `profile`'s own
    /// didSet — no second write path.
    func setCanonicalName(_ raw: String) {
        let trimmed = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        guard !trimmed.isEmpty, trimmed != profile.name else { return }
        var p = profile
        p.name = trimmed
        p.hasCustomizedName = true
        profile = p
    }

    // MARK: - Onboarding completion

    /// Persist everything gathered by first-run onboarding and open the app.
    /// Write the pilot's onboarding answers into the canonical settings.
    ///
    /// Separate from `completeOnboarding()` on purpose. The first run commits
    /// these while its setup screen is on display — so that screen is describing
    /// work that is really happening — and a pilot who abandons on the offer
    /// still keeps every answer they gave. Flipping `hasCompletedOnboarding`
    /// here would tear the flow down mid-run, which is why that stayed separate.
    ///
    /// Only values something reads:
    /// * `focusPresetTitle` -> the Online presence category, and the focus token
    ///   the flight-setup ritual opens on.
    /// * `preferredMinutes` -> the setup dial's opening value for the first flight.
    ///
    /// * `weeklyFocusDays` -> the plan's rhythm: the Rhythm row names them back
    ///   and the results chart's target counts them.
    ///
    /// The soundscape is not a parameter: the selector commits it to
    /// `settings.selectedJourneyAudioID` as the pilot browses.
    func applyOnboardingSelections(focusPresetTitle: String?,
                                   preferredMinutes: Int?,
                                   weeklyFocusDays: [FocusWeekday] = []) {
        var p = profile
        // Only a real `FocusPreset` title is stored: this value is published as
        // an Online flight category, so it must stay a known token rather than
        // whatever a future copy edit calls it.
        if let title = focusPresetTitle, FocusPreset.all.contains(where: { $0.title == title }) {
            p.focusStyle = title
        }
        p.createdAt = p.createdAt ?? Date()
        // Stable ISO weekday numbers, never localized strings. An empty
        // selection is not written: the picker cannot produce one, so an empty
        // array here means the caller had nothing to say rather than that the
        // pilot chose no days.
        if !weeklyFocusDays.isEmpty {
            p.weeklyFocusDays = FocusWeekday.rawValues(weeklyFocusDays)
        }
        profile = p

        if let preferredMinutes {
            settings.preferredFlightMinutes = preferredMinutes
        }
    }

    /// Mark the first run finished. Nothing else — the answers were already
    /// committed by `applyOnboardingSelections`.
    func completeOnboarding() {
        var p = profile
        p.createdAt = p.createdAt ?? Date()
        p.hasCompletedOnboarding = true
        profile = p
        // Durable, and written in the same breath as the flag that ends
        // onboarding. Held only in memory, this was a real hole: the profile is
        // persisted, so a termination between here and Home's first appearance
        // skipped onboarding on relaunch AND lost the pending ask permanently.
        // Device-scoped rather than account-scoped, because iOS grants the one
        // permission opportunity to this install, not to whoever signs in.
        persistence.setBool(true, for: .pendingNotificationPrompt)
    }

    /// True from the instant the first run finishes until Home has genuinely
    /// dealt with the ask. Survives termination, force quit, a purchase, a
    /// restore, an entitlement refresh and any delay in reaching Home, because
    /// none of those touch it — only `consumeNotificationPromptIfNeeded` clears
    /// it, and only after the system has actually been consulted.
    var hasPendingNotificationPrompt: Bool {
        persistence.bool(for: .pendingNotificationPrompt)
    }

    /// Guards re-entry only. Home's `onAppear` fires again on every return to
    /// the tab, and the pending flag deliberately stays set for the whole time
    /// the system sheet is up — without this, coming back mid-request would
    /// start a second one.
    private var isResolvingNotificationPrompt = false

    /// The one-shot post-onboarding ask.
    ///
    /// The permission belongs here rather than inside onboarding: a system sheet
    /// before the offer is friction at the worst possible moment, and one on
    /// arrival lands just after the pilot has been told their first flight is
    /// ready. Home is also structurally safe — `RootView` swaps onboarding OUT
    /// for the shell, so nothing can fire while onboarding or its inline paywall
    /// is still on screen.
    ///
    /// `requestFirstRunAuthorization` reads the status BEFORE requesting
    /// anything, so `.notDetermined` is the only branch that shows a dialog.
    /// Authorized, provisional, ephemeral and denied all fall straight through
    /// to the clear — iOS was consulted either way, so the ask is spent either
    /// way, and a pilot who said no is never asked twice.
    func consumeNotificationPromptIfNeeded() {
        guard !isResolvingNotificationPrompt, hasPendingNotificationPrompt else { return }
        isResolvingNotificationPrompt = true
        Task { @MainActor in
            defer { isResolvingNotificationPrompt = false }

            let outcome = await notifications.requestFirstRunAuthorization(state: notificationState())
            // A refusal must not leave "Reminders" reading as on in Settings for
            // something iOS will never deliver. Only an answer to OUR sheet
            // moves the preference — `.alreadyDecided` leaves whatever the pilot
            // set previously exactly as it was.
            if case .asked(let granted) = outcome, !granted {
                notifications.setEnabled(false)
            }

            // Cleared only now: the status has been checked and, where the
            // status made it applicable, the request has been made. A crash
            // before this point leaves the flag set and the ask simply happens
            // on the next launch, which is the correct failure direction.
            persistence.setBool(false, for: .pendingNotificationPrompt)
            refreshNotifications()
        }
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
        isConfirmedFree && !launchPaywallShown && currentOrigin != nil
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
        if case .pro = skin.unlock { return isPro }
        return skin.progressionRequirementMet(focusMinutes: lifetimeFocusMinutes,
                                              journeys: progress.landings,
                                              focusMiles: progress.totalFocusMiles)
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
        var updated = profile
        if Self.captureEarnedSkinIDs(into: &updated, progress: progress, history: history) {
            profile = updated
        }
    }

    /// Idempotently stores all earned non-PRO skins. Keeping this pure over the
    /// supplied account state lets launch, account switching, and journey
    /// completion share the exact same monotonic rule.
    @discardableResult
    private static func captureEarnedSkinIDs(into profile: inout UserProfile,
                                             progress: UserProgress,
                                             history: [FocusSessionRecord]) -> Bool {
        let focusMinutes = history.lazy.filter(\.completed)
            .reduce(0) { $0 + $1.focusedSeconds } / 60
        var owned = profile.unlockedSkinIDs ?? []
        let initial = owned
        for skin in BalloonSkin.all where !skin.isPremium && skin.id != BalloonSkin.default.id {
            if skin.progressionRequirementMet(focusMinutes: focusMinutes,
                                              journeys: progress.landings,
                                              focusMiles: progress.totalFocusMiles) {
                owned.insert(skin.id)
            }
        }
        guard owned != initial else { return false }
        profile.unlockedSkinIDs = owned
        return true
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
        var equipped = profile.equippedCabinItemIDs ?? []
        var placements = profile.cabinItemSlotByID ?? [:]
        let premiumIDs = Set(StoreItem.cabinDecorations.filter(\.isPremium).map(\.id))
        equipped.subtract(premiumIDs)
        placements = placements.filter { !premiumIDs.contains($0.key) }
        profile.equippedCabinItemIDs = equipped
        profile.cabinItemSlotByID = placements
    }

    // MARK: - Daily objective event tracking

    /// Add a genuine earning event to today's monotonic counter. Wallet spending
    /// is intentionally unrelated, and the all-objectives completion bonus does
    /// not call this helper, preventing a self-completing reward loop.
    private func recordCoinEarnings(_ amount: Int) {
        guard amount > 0 else { return }
        let today = Self.dayKey(Date())
        var updated = profile
        if updated.coinEarningsDayKey != today {
            updated.coinEarningsDayKey = today
            updated.coinsEarnedOnDay = 0
        }
        updated.coinsEarnedOnDay = (updated.coinsEarnedOnDay ?? 0) + amount
        profile = updated
    }

    /// The same real conditions exposed as collectible Passport badges. Stable
    /// string keys make the event tracker migration-safe without persisting view
    /// models or fabricated completion values.
    private var earnedBadgeKeys: Set<String> {
        let completed = history.filter(\.completed)
        let flights = max(progress.landings, completed.count)
        let minutes = completed.reduce(0) { $0 + $1.focusedSeconds } / 60
        let best = progress.bestFocusMinutes
        let streak = max(progress.currentStreak, progress.longestStreak)
        let coins = progress.totalFocusMiles
        let destinations = completed.map(\.destinationName)
        let hours = completed.map { Calendar.current.component(.hour, from: $0.date) }
        let ownsCabin = StoreItem.all.contains {
            $0.kind == .cabinDecoration && ownsStoreItem($0)
        }
        let skinsOwned = BalloonSkin.all.filter { isSkinUnlocked($0) }.count
        let acceptedInvites = (profile.inviteProgressBySkyID ?? [:]).values.reduce(0, +)

        var keys = Set<String>()
        func earn(_ key: String, _ condition: Bool) {
            if condition { keys.insert(key) }
        }
        func visited(_ names: [String]) -> Bool {
            destinations.contains { names.contains($0) }
        }

        earn("first-flight", flights >= 1)
        earn("25-minute-pilot", best >= 25)
        earn("one-hour-focused", best >= 60)
        earn("five-flights", flights >= 5)
        earn("ten-flights", flights >= 10)
        earn("twenty-five-flights", flights >= 25)
        earn("100-focus-minutes", minutes >= 100)
        earn("500-focus-minutes", minutes >= 500)
        earn("1000-focus-minutes", minutes >= 1_000)
        earn("three-day-streak", streak >= 3)
        earn("seven-day-streak", streak >= 7)
        earn("fourteen-day-streak", streak >= 14)
        earn("night-owl", hours.contains { $0 >= 22 || $0 < 4 })
        earn("early-bird", hours.contains { $0 >= 4 && $0 < 8 })
        earn("tokyo-pilot", visited(["Rainy Tokyo"]))
        earn("fiji-pilot", visited(["Fiji Lagoon"]))
        earn("kyoto-lantern", visited(["Kyoto Lantern Night", "Kyoto Lanterns"]))
        earn("aurora-explorer", visited(["Northern Aurora", "Aurora Snowfield"]))
        earn("desert-stargazer",
             visited(["Desert Night", "Sahara Night", "Amber Highlands", "Golden Hour"]))
        earn("alpine-pilot", visited(["Swiss Alps"]))
        earn("deep-space-pilot", visited(["Deep Space"]))
        earn("focus-coin-saver", coins >= 100)
        earn("cabin-decorator", ownsCabin)
        earn("skin-collector", skinsOwned >= 3)
        earn("friend-flight", acceptedInvites >= 1)
        earn("pro-pilot", isPro)
        earn("comeback-pilot",
             progress.longestStreak > progress.currentStreak && progress.currentStreak >= 1)
        return keys
    }

    /// Existing pilots begin with a silent baseline: installing this version
    /// must not turn badges they already owned into fake "today" events.
    private func initializeBadgeTrackingIfNeeded() {
        guard profile.observedBadgeKeys == nil else { return }
        var updated = profile
        updated.observedBadgeKeys = earnedBadgeKeys
        profile = updated
    }

    /// Persist a real transition from not-observed to earned. The observed set
    /// only grows, so temporary entitlement/streak changes cannot award twice.
    ///
    /// No daily objective reads `badgeUnlockEventDayKey` any more (today's third
    /// objective is the Free Coin Spin). The tracker is kept running because it is
    /// cheap, idempotent and — crucially — the observed set must stay continuous:
    /// if it stopped growing now, every badge earned in the meantime would look
    /// brand new the day anything reads it again.
    private func recordNewBadgeUnlocks() {
        guard let observed = profile.observedBadgeKeys else {
            initializeBadgeTrackingIfNeeded()
            return
        }
        let current = earnedBadgeKeys
        let newKeys = current.subtracting(observed)
        guard !newKeys.isEmpty else { return }
        var updated = profile
        updated.observedBadgeKeys = observed.union(current)
        updated.badgeUnlockEventDayKey = Self.dayKey(Date())
        profile = updated
    }

    // MARK: - Daily missions

    /// Today's goals, computed fresh from the session history (so they reset at
    /// midnight with no scheduler). Progress is real; completion is derived.
    var dailyMissions: [DailyMission] {
        let cal = Calendar.current
        let todays = history.filter { $0.completed && cal.isDateInToday($0.date) }
        let journeys = Double(todays.count)
        let minutes = Double(todays.reduce(0) { $0 + $1.focusedSeconds }) / 60.0
        // Today's third objective is the Free Coin Spin, which every pilot can
        // reach from Home on any day. It replaced "Unlock a new badge", which was
        // unreachable for anyone who had already collected the badges their
        // progress qualified for — an objective that silently became impossible.
        let spunToday = profile.coinSpinEventDayKey == Self.dayKey(Date())
        let coinsEarnedToday = profile.coinEarningsDayKey == Self.dayKey(Date())
            ? Double(profile.coinsEarnedOnDay ?? 0) : 0
        return [
            DailyMission(id: "journey", title: "Complete one flight", systemImage: "paperplane.fill",
                         accent: .indigo, target: 1, current: journeys),
            DailyMission(id: "focus", title: "Focus 30 minutes", systemImage: "timer",
                         accent: .teal, target: 30, current: minutes),
            DailyMission(id: "spin", title: "Spin the Free Coin Spin",
                         systemImage: "arrow.triangle.2.circlepath", accent: .gold, target: 1,
                         current: spunToday ? 1 : 0),
            DailyMission(id: "coins", title: "Earn 10 Focus Coins", systemImage: "sparkles",
                         accent: .coral, target: 10, current: coinsEarnedToday),
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
        // The completion bonus intentionally does not advance today's coin
        // objective, but it may legitimately cross a lifetime badge threshold.
        recordNewBadgeUnlocks()
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
    /// ONLINE journeys are never resumable. A Global/Private flight is a live room
    /// with real pilots and server presence — once you leave it, there is nothing
    /// to rejoin, so offering "Resume your flight" on Home is a promise the app
    /// cannot keep. `FocusSessionViewModel` has no concept of flight mode, so it
    /// asked for a snapshot on every journey; the mode is checked HERE, at the one
    /// place snapshots are written, using the canonical `FocusOnlineModel.flightMode`
    /// rather than a duplicated boolean.
    func saveResumableJourney(origin: JourneyOrigin, route: Route, intention: String?,
                              elapsedSeconds: Int, skinAssetName: String, soundID: String?) {
        // `?? .publicSky` is the fail-SAFE default: if the online model is somehow
        // unreachable we must not mint a snapshot we cannot prove is Solo. The old
        // `onlineRef?.flightMode.isOnline != true` inverted exactly here — a nil
        // ref made the expression true and an Online journey WAS saved.
        let mode = onlineRef?.flightMode ?? .publicSky
        guard mode == .solo else {
            // Not merely "don't save": an Online journey must also DROP whatever
            // snapshot is already on disk. Skipping silently is what left Home
            // showing "Resume your flight" after an Online flight — the CTA was
            // being served by an older, unrelated snapshot that nothing cleared.
            #if DEBUG
            print("[Resume] rejected: Online/shared journeys are never resumable")
            #endif
            clearResumableJourney()
            return
        }
        let snapshot = ResumableJourney(origin: origin, route: route, intention: intention,
                                        elapsedSeconds: elapsedSeconds, skinAssetName: skinAssetName,
                                        soundID: soundID, savedAt: Date(), mode: .solo)
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
        // Belt-and-braces with the load-time purge and the Home gate: an Online or
        // unidentifiable snapshot is never reconstructed, and is dropped on sight.
        guard snapshot.isResumable else {
            clearResumableJourney()
            return nil
        }
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
    /// Cap applied to the coins a FREE pilot banks at landing after all
    /// multipliers (base → boost → friend ×2). The rewarded-ad double on the
    /// Landing screen doubles this already-capped amount at most once.
    ///
    /// PRO's journey multiplier is applied OUTSIDE this ceiling, so a PRO
    /// landing is always exactly twice what the identical flight would have paid
    /// a free pilot — at 120 minutes with a boost and a friend bonus that is 50
    /// against 100, not 50 against 50.
    static let maximumCoinsPerJourneyAfterMultipliers = 50

    /// What a flight would pay if it landed RIGHT NOW, for surfaces that need to
    /// state the stake before it is banked — today only the leave-flight
    /// confirmation.
    ///
    /// Deliberately built from the same pieces as `completeJourney` rather than
    /// re-deriving them: same eligibility gate, same base, same boost window,
    /// same ceiling, same PRO multiplier. A second formula here is exactly how a
    /// confirmation ends up quoting a number the landing then contradicts.
    ///
    /// The friend-flight bonus is NOT included: it depends on verified overlap
    /// that cannot be known before landing, so this is a floor, not a promise —
    /// which is why the UI says "up to".
    func projectedJourneyCoins(focusedSeconds: Int) -> Int {
        guard focusedSeconds >= FocusConsistency.qualifyingSeconds else { return 0 }
        let base = FocusEconomy.coins(forFocusedSeconds: focusedSeconds)
        let boost = isCoinBoostArmed
            ? FocusEconomy.coins(forFocusedSeconds: min(focusedSeconds, 3600)) : 0
        let creditedForFree = min(Self.maximumCoinsPerJourneyAfterMultipliers, base + boost)
        return FocusEconomy.journeyCoins(creditedForFree: creditedForFree, isPro: isPro)
    }

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
        // Everything a FREE pilot would bank for this identical flight, ceiling
        // included. This is the number PRO doubles.
        let creditedForFree = qualifies
            ? min(Self.maximumCoinsPerJourneyAfterMultipliers, (baseMiles + boostBonus) * friendMultiplier)
            : 0
        // PRO doubles the JOURNEY reward — applied last, exactly once, and read
        // from the verified RevenueCat entitlement (`isPro` is `revenueCatPro`,
        // which nothing but the SDK and a real purchase/restore ever writes).
        // Never a debug flag, a selected plan, Store ownership or a product-load
        // state. A non-qualifying flight is 0 before this, so it stays 0 after.
        let proApplied = qualifies && isPro
        let awardedMiles = FocusEconomy.journeyCoins(creditedForFree: creditedForFree, isPro: proApplied)
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
            recordCoinEarnings(awardedMiles)
            // Capture any skin or Sky just earned into the grandfather sets, so a
            // later rule change (or a dropped streak) can never re-lock them.
            captureEarnedSkins()
            captureUnlockedSkies()
            recordNewBadgeUnlocks()

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
            streakIncreased: streakIncreased,
            proMultiplierApplied: proApplied
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
        recordCoinEarnings(summary.baseMiles)
        recordNewBadgeUnlocks()

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
        if ok { revenueCatPro = true }
        return ok
    }

    func restorePurchases() async -> Bool {
        if subscriptions.isAvailable {
            let ok = await subscriptions.restorePurchases()
            revenueCatPro = subscriptions.isPro
            return ok
        }
        let ok = await purchases.restore()
        revenueCatPro = purchases.isPro
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
        recordCoinEarnings(AdMobConfig.dailyBoostMiles)
        recordNewBadgeUnlocks()
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
        revenueCatPro = false
        resumableJourney = nil
        settings = .default
    }
    #endif

    // MARK: - Private

    /// Whole local calendar days from one instant's day to another's. Positive
    /// means `to` is later. THE single definition of "consecutive" — both the
    /// landing path and the launch reconciliation measure with this, so they can
    /// never disagree about what a missed day is.
    ///
    /// `Calendar.current` throughout: the pilot's own calendar and time zone, and
    /// `startOfDay` + a `.day` component so a DST shift is still exactly one day.
    static func dayGap(from earlier: Date, to later: Date,
                       calendar: Calendar = .current) -> Int {
        let a = calendar.startOfDay(for: earlier)
        let b = calendar.startOfDay(for: later)
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    /// The streak that is still genuinely running as of `now`.
    ///
    /// A run survives only while its last completed day is today (gap 0) or
    /// yesterday (gap 1) — yesterday is still alive because flying today would
    /// continue it. Anything older means a whole local day passed with no
    /// completed flight, and the run is over: 0, not the stale count, and not 1
    /// (no flight has been completed today, so there is nothing to show).
    ///
    /// A negative gap means the device clock moved backwards or the pilot crossed
    /// a time zone eastward. That is not a missed day, so the streak stands.
    static func liveStreak(_ streak: Int, lastLandingDay: Date?, asOf now: Date,
                           calendar: Calendar = .current) -> Int {
        guard streak > 0, let last = lastLandingDay else { return 0 }
        return dayGap(from: last, to: now, calendar: calendar) <= 1 ? streak : 0
    }

    /// Drop a streak that has already been broken by the calendar.
    ///
    /// `applyStreak` only ever runs when a flight LANDS, so a streak that dies
    /// from simple inactivity was never written down as dead: the last landing's
    /// value just sat in storage, and Home, Passport, the streak sheet and the
    /// widgets all kept reporting it for days. Monday's 5 was still showing on
    /// Friday. This is the missing half — called at launch and every time the app
    /// comes forward, so the number is correct before a new flight is completed
    /// and not only after one.
    func reconcileStreakIfNeeded(now: Date = Date()) {
        let live = Self.liveStreak(progress.currentStreak,
                                   lastLandingDay: progress.lastLandingDay,
                                   asOf: now)
        guard live != progress.currentStreak else { return }

        // Bank what the run legitimately earned BEFORE it is dropped. The pilot
        // really did reach that streak, so a Sky unlocked by it must survive —
        // `captureUnlockedSkies` is the permanent grandfather set and is
        // idempotent, so this is safe to call on every reconciliation. (Milestone
        // skins key off minutes / journeys / miles, never the streak, so they
        // cannot be affected.)
        captureUnlockedSkies()

        var p = progress
        // The record is a lifetime best and is never reduced by a broken run.
        p.longestStreak = max(p.longestStreak, p.currentStreak)
        p.currentStreak = live
        progress = p

        // Streak badges read `max(currentStreak, longestStreak)`, so they cannot
        // be un-earned here; this only keeps the observed set continuous.
        recordNewBadgeUnlocks()
        // Persists progress AND republishes the widget snapshot, so the Streak
        // Companion stops showing the dead number immediately.
        persistAll()
    }

    private func applyStreak(to p: inout UserProgress, landingDate: Date) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: landingDate)

        guard let last = p.lastLandingDay else {
            p.currentStreak = 1
            p.longestStreak = max(p.longestStreak, 1)
            p.lastLandingDay = today
            return
        }

        switch Self.dayGap(from: last, to: today, calendar: cal) {
        case ..<0:
            // A landing dated BEFORE the last recorded day — a late Online
            // completion, a backfilled record, a clock correction. It can neither
            // extend nor break the run, and it must not drag `lastLandingDay`
            // backwards, which would make the NEXT landing look like a huge gap
            // and wrongly reset a healthy streak.
            return
        case 0:
            break                  // already flown today — one day, one streak day
        case 1:
            p.currentStreak += 1   // yesterday → consecutive
        default:
            p.currentStreak = 1    // a whole day was missed → this is day one
        }
        p.longestStreak = max(p.longestStreak, p.currentStreak)
        p.lastLandingDay = today
    }

    private func settingsChanged(from old: AppSettings) {
        haptics.isEnabled = settings.hapticsEnabled
        sound.setEnabled(settings.soundEnabled)
        uiSound.isEnabled = settings.soundEnabled
        if !isBatchingPersistence {
            persistence.save(settings, for: .settings)
        }
        // Unreachable now that Appearance is not user-settable; kept so the
        // event is not lost if a themed surface is ever reintroduced.
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
                                 hasUnfinishedJourney: resumable?.isResumable ?? false,
                                 unfinishedOrigin: resumable?.origin.city,
                                 unfinishedDestination: resumable?.route.destinationName,
                                 originCity: currentOrigin?.city,
                                 dailyGiftAvailable: canClaimDailyGift,
                                 isPremium: isPro)
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
        persistence.saveCanonicalState(settings: settings,
                                       progress: progress,
                                       history: history,
                                       profile: profile,
                                       resumableJourney: resumableJourney)
        syncWidgets()
    }

    /// Groups a mutation that spans two or more canonical domains into a single
    /// snapshot write. This is used for rewards whose claim marker and wallet
    /// credit must never become durable independently.
    private func performPersistedTransaction(_ mutation: () -> Void) {
        let wasAlreadyBatching = isBatchingPersistence
        isBatchingPersistence = true
        mutation()
        isBatchingPersistence = wasAlreadyBatching
        if !wasAlreadyBatching { persistAll() }
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
            snap.hasResumable = r.isResumable && r.elapsedSeconds > 0 && r.elapsedSeconds < total
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
        snap.selectedSkyArtworkName = sky.widgetArtworkAssetName
        snap.skyTopHex = Int(sky.moodPalette.first ?? 0x181721)
        snap.skyBottomHex = Int(sky.moodPalette.last ?? 0x100F16)
        // Active-flight live state (nil when idle).
        snap.activeFlight = activeFlightSkyName != nil || activeFlightEndDate != nil || activeFlightInfinite
        snap.activeEndDate = activeFlightEndDate
        snap.activeInfinite = activeFlightInfinite
        snap.activeSkyName = activeFlightSkyName
        snap.activeSkyArtworkName = activeFlightSkyName
            .flatMap { name in FocusSky.all.first(where: { $0.name == name })?.widgetArtworkAssetName }
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
    /// The flight mode this snapshot was taken in. ONLY `.solo` is resumable.
    ///
    /// Optional purely for decoding: snapshots written before this field existed
    /// carry no mode and are therefore *unidentifiable* — they could equally be a
    /// stale Online journey from a buggy build. `isResumable` treats them as not
    /// resumable, so the invariant holds for data already on disk rather than only
    /// for newly written snapshots.
    var mode: OnlineFlightMode? = nil

    /// The single rule Home and the restore path both use.
    var isResumable: Bool { mode == .solo }
}
