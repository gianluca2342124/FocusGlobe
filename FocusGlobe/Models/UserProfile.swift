import Foundation

/// The lightweight **local** account foundation. No backend, no sign-in — a
/// small on-device profile created by first-run onboarding, stored under its
/// own persistence key (separate from `AppSettings`, so neither can break the
/// other's decoding). A future real account system can hydrate from this.
///
/// Decoding note: this struct is always encoded whole, so today's non-optional
/// fields are safe; any field added LATER must be optional (or have a custom
/// decoder) so older saved profiles keep decoding.
struct UserProfile: Codable, Equatable {
    /// First-run onboarding completed (or auto-skipped for pre-existing users).
    var hasCompletedOnboarding: Bool = false
    /// How FocusGlobe addresses the pilot. Optional — never required.
    var name: String? = nil
    /// LEGACY. The old onboarding asked "What do you want to achieve this
    /// year?" as free text, wrote it here, and read it nowhere. The question is
    /// gone; the key stays so profiles saved by older builds keep decoding.
    /// Nothing writes it any more.
    var yearGoal: String? = nil
    /// LEGACY, for the same reason: an age band nothing ever read.
    var ageRange: String? = nil
    /// LEGACY, for the same reason: a free-text struggle nothing ever read.
    /// Its job — knowing what gets in a pilot's way — is now done by
    /// `onboardingAnswers.obstacle`, which is a stable id and drives the plan.
    var focusStruggle: String? = nil
    /// The pilot's flight category, published by Online presence. Still live:
    /// `applyOnboardingPlan` writes a real `FocusPreset` title derived from the
    /// goal, replacing the free-text question that used to fill it.
    var focusStyle: String? = nil
    /// The user opted into Focus Shield during onboarding (intent only until
    /// the full Screen Time infrastructure ships).
    var focusShieldOptIn: Bool = false
    /// Everything the first-run flow captured, kept so a force-quit resumes
    /// where it stopped instead of restarting from the welcome screen.
    var onboardingAnswers: OnboardingAnswers? = nil
    /// The plan built from those answers, versioned so older plans are
    /// recognisable when the rules change.
    var onboardingPlan: OnboardingFocusPlan? = nil
    /// The step the pilot was last on. Nil once onboarding completes.
    var onboardingStepID: String? = nil
    /// Experiment assignment, decided once and never re-rolled — a variant that
    /// changes per launch measures nothing.
    var onboardingVariantID: String? = nil
    /// The currently selected Sky (see `FocusSky`). `nil` → Golden Hour.
    var selectedSkyID: String? = nil
    /// This pilot's shareable invite code (generated lazily, then stable).
    var referralCode: String? = nil
    /// Friends who joined from this pilot's invite. Driven by a real referral
    /// backend later — production code must never fabricate this.
    var acceptedInviteCount: Int = 0
    /// When the profile was first created.
    var createdAt: Date? = nil
    /// Focus Coins spent in the Store (balance = lifetime earned − spent).
    /// Optional so profiles saved before the Store keep decoding.
    var spentFocusCoins: Int? = nil
    /// Store items this pilot owns. Optional for the same decoding reason.
    var ownedStoreItemIDs: Set<String>? = nil
    /// The equipped trail effect (a `StoreItem` id of kind `.trail`).
    var equippedTrailID: String? = nil
    /// Equipped cabin decorations (`StoreItem` ids of kind `.cabinDecoration`).
    var equippedCabinItemIDs: Set<String>? = nil
    /// Persisted semantic placement (`StoreItem.id` → `CabinSlot.rawValue`).
    /// Optional so profiles saved before user-placeable Cabin items still decode.
    var cabinItemSlotByID: [String: String]? = nil
    /// LEGACY (pre-FocusGlobe-Online "fly with others" toggle). Kept only so
    /// older saved profiles keep decoding; the flight mode now lives in the
    /// pre-flight ritual (`OnlineFlightMode`, persisted by `OnlineCache`).
    var soloFlights: Bool? = nil
    /// Per-Sky unlocks earned by invites: a Sky unlocks individually once its
    /// own invite requirement is satisfied.
    var unlockedSkyIDs: Set<String>? = nil
    /// Balloon skins that have been earned at least once — the GRANDFATHER set.
    /// Milestone skins are normally derived from live progress, but once a skin
    /// is earned it is captured here so a change to the unlock RULE (e.g. flights
    /// → focused minutes) can never re-lock a skin the pilot already owns.
    var unlockedSkinIDs: Set<String>? = nil
    /// Accepted invites counted per Sky (the honest, backend-fed tally).
    var inviteProgressBySkyID: [String: Int]? = nil
    /// The day-ordinal on which the Shop daily gift was last collected (once/day).
    var lastDailyGiftDay: Int? = nil
    /// Whether the pilot prefers a distraction-free "clean" flight (minimal chrome).
    var cleanFlightMode: Bool? = nil
    /// Unix time of the last successful Free Coin Spin (a light anti-spam cooldown).
    var lastCoinSpinAt: Double? = nil
    /// Local day on which a Free Coin Spin was actually RESOLVED — i.e. a prize
    /// was decided and the coins were credited. Stamped only by that grant, never
    /// by opening the sheet, watching a video that yields nothing, relaunching or
    /// restoring. Writing today's key twice is a no-op, so today's Free Coin Spin
    /// objective can never be completed more than once.
    var coinSpinEventDayKey: String? = nil
    /// Unix time at which an *equipped* Coins Boost expires (nil = no boost armed).
    /// While armed and unexpired, the next flight's coins are doubled up to 1 hour.
    var coinBoostExpiresAt: Double? = nil
    /// Unix time the Coins Boost gift popup was last offered (so it isn't shown
    /// every launch).
    var lastBoostGiftAt: Double? = nil
    /// FocusGlobe Online: appear in Public Skies (presence visible to others).
    ///
    /// Optional on purpose, and `nil` means ON. Three states, not two: never
    /// chosen, chose yes, chose no. A plain `Bool` could not tell an untouched
    /// preference from a deliberate opt-out, so flipping the default would have
    /// silently re-enabled discovery for pilots who had explicitly turned it
    /// off. Reads use `?? true`; an explicit `false` is never overwritten.
    ///
    /// This controls VISIBILITY while genuinely flying an eligible Online
    /// journey. It never publishes anyone merely for opening the app.
    var onlineDiscoverable: Bool? = nil
    /// FocusGlobe Online: allow Crew (friend) requests from met pilots.
    var onlineAllowsFriendRequests: Bool? = nil
    /// Sessions already granted the friend-flight coin bonus (idempotency).
    var rewardedFriendSessionIDs: [String]? = nil
    /// Online pilots the user chose to hide locally.
    var hiddenPilotIDs: Set<String>? = nil
    /// Local-day key and monotonic total of Focus Coins genuinely earned that
    /// day. Spending never subtracts from this counter.
    var coinEarningsDayKey: String? = nil
    var coinsEarnedOnDay: Int? = nil
    /// Stable badge keys already observed by the daily-objective tracker. The
    /// set only grows, so a temporary state change can never re-award a badge.
    var observedBadgeKeys: Set<String>? = nil
    /// Local day on which at least one previously unobserved badge became earned.
    /// Still maintained, but no longer drives a daily objective (see
    /// `AppModel.recordNewBadgeUnlocks`).
    var badgeUnlockEventDayKey: String? = nil

    init() {}

    static let empty = UserProfile()

    private enum CodingKeys: String, CodingKey {
        case hasCompletedOnboarding, name, yearGoal, ageRange, focusStruggle, focusStyle
        case focusShieldOptIn, selectedSkyID, referralCode, acceptedInviteCount, createdAt
        case spentFocusCoins, ownedStoreItemIDs, equippedTrailID, equippedCabinItemIDs
        case cabinItemSlotByID, soloFlights, unlockedSkyIDs, unlockedSkinIDs
        case inviteProgressBySkyID, lastDailyGiftDay, cleanFlightMode, lastCoinSpinAt
        case coinSpinEventDayKey, coinBoostExpiresAt, lastBoostGiftAt, onlineDiscoverable
        case onlineAllowsFriendRequests, rewardedFriendSessionIDs, hiddenPilotIDs
        case coinEarningsDayKey, coinsEarnedOnDay, observedBadgeKeys, badgeUnlockEventDayKey
        case onboardingAnswers, onboardingPlan, onboardingStepID, onboardingVariantID
    }

    /// Field-by-field recovery is deliberate: a malformed or absent optional
    /// value from an older release must not discard Coins, inventory, Cabin
    /// slots, unlocks, daily claim markers, or unrelated onboarding answers.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hasCompletedOnboarding = (try? c.decode(Bool.self, forKey: .hasCompletedOnboarding)) ?? false
        name = try? c.decode(String.self, forKey: .name)
        yearGoal = try? c.decode(String.self, forKey: .yearGoal)
        ageRange = try? c.decode(String.self, forKey: .ageRange)
        focusStruggle = try? c.decode(String.self, forKey: .focusStruggle)
        focusStyle = try? c.decode(String.self, forKey: .focusStyle)
        focusShieldOptIn = (try? c.decode(Bool.self, forKey: .focusShieldOptIn)) ?? false
        onboardingAnswers = try? c.decode(OnboardingAnswers.self, forKey: .onboardingAnswers)
        onboardingPlan = try? c.decode(OnboardingFocusPlan.self, forKey: .onboardingPlan)
        onboardingStepID = try? c.decode(String.self, forKey: .onboardingStepID)
        onboardingVariantID = try? c.decode(String.self, forKey: .onboardingVariantID)
        selectedSkyID = try? c.decode(String.self, forKey: .selectedSkyID)
        referralCode = try? c.decode(String.self, forKey: .referralCode)
        acceptedInviteCount = max(0, (try? c.decode(Int.self, forKey: .acceptedInviteCount)) ?? 0)
        createdAt = try? c.decode(Date.self, forKey: .createdAt)
        spentFocusCoins = try? c.decode(Int.self, forKey: .spentFocusCoins)
        ownedStoreItemIDs = try? c.decode(Set<String>.self, forKey: .ownedStoreItemIDs)
        equippedTrailID = try? c.decode(String.self, forKey: .equippedTrailID)
        equippedCabinItemIDs = try? c.decode(Set<String>.self, forKey: .equippedCabinItemIDs)
        cabinItemSlotByID = try? c.decode([String: String].self, forKey: .cabinItemSlotByID)
        soloFlights = try? c.decode(Bool.self, forKey: .soloFlights)
        unlockedSkyIDs = try? c.decode(Set<String>.self, forKey: .unlockedSkyIDs)
        unlockedSkinIDs = try? c.decode(Set<String>.self, forKey: .unlockedSkinIDs)
        inviteProgressBySkyID = try? c.decode([String: Int].self, forKey: .inviteProgressBySkyID)
        lastDailyGiftDay = try? c.decode(Int.self, forKey: .lastDailyGiftDay)
        cleanFlightMode = try? c.decode(Bool.self, forKey: .cleanFlightMode)
        lastCoinSpinAt = try? c.decode(Double.self, forKey: .lastCoinSpinAt)
        coinSpinEventDayKey = try? c.decode(String.self, forKey: .coinSpinEventDayKey)
        coinBoostExpiresAt = try? c.decode(Double.self, forKey: .coinBoostExpiresAt)
        lastBoostGiftAt = try? c.decode(Double.self, forKey: .lastBoostGiftAt)
        onlineDiscoverable = try? c.decode(Bool.self, forKey: .onlineDiscoverable)
        onlineAllowsFriendRequests = try? c.decode(Bool.self, forKey: .onlineAllowsFriendRequests)
        rewardedFriendSessionIDs = try? c.decode([String].self, forKey: .rewardedFriendSessionIDs)
        hiddenPilotIDs = try? c.decode(Set<String>.self, forKey: .hiddenPilotIDs)
        coinEarningsDayKey = try? c.decode(String.self, forKey: .coinEarningsDayKey)
        coinsEarnedOnDay = try? c.decode(Int.self, forKey: .coinsEarnedOnDay)
        observedBadgeKeys = try? c.decode(Set<String>.self, forKey: .observedBadgeKeys)
        badgeUnlockEventDayKey = try? c.decode(String.self, forKey: .badgeUnlockEventDayKey)
    }
}
