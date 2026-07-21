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
    /// "What do you want to achieve this year?" — kept for personalisation.
    var yearGoal: String? = nil
    /// Optional age band ("18–24" …). Stored as the display string.
    var ageRange: String? = nil
    /// "When you try to focus, what usually happens?"
    var focusStruggle: String? = nil
    /// "What are you focusing on most?" (matches a FocusPreset title).
    var focusStyle: String? = nil
    /// The user opted into Focus Shield during onboarding (intent only until
    /// the full Screen Time infrastructure ships).
    var focusShieldOptIn: Bool = false
    /// The currently selected Sky (see `FocusSky`). `nil` → Golden Hour.
    var selectedSkyID: String? = nil
    /// This pilot's shareable invite code (generated lazily, then stable).
    var referralCode: String? = nil
    /// Friends who joined from this pilot's invite. Driven by a real referral
    /// backend later — production code must never fabricate this. 3 unlocks
    /// every Sky (see `SkyUnlock`).
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
    /// LEGACY (pre-FocusGlobe-Online "fly with others" toggle). Kept only so
    /// older saved profiles keep decoding; the flight mode now lives in the
    /// pre-flight ritual (`OnlineFlightMode`, persisted by `OnlineCache`).
    var soloFlights: Bool? = nil
    /// Per-Sky unlocks earned by invites: a Sky unlocks individually once its
    /// own 3 invites are accepted. (Premium bypasses this while active.)
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
    /// Unix time at which an *equipped* Coins Boost expires (nil = no boost armed).
    /// While armed and unexpired, the next flight's coins are doubled up to 1 hour.
    var coinBoostExpiresAt: Double? = nil
    /// Unix time the Coins Boost gift popup was last offered (so it isn't shown
    /// every launch).
    var lastBoostGiftAt: Double? = nil
    /// FocusGlobe Online: appear in Public Skies (presence visible to others).
    var onlineDiscoverable: Bool? = nil
    /// FocusGlobe Online: allow Crew (friend) requests from met pilots.
    var onlineAllowsFriendRequests: Bool? = nil
    /// Sessions already granted the friend-flight coin bonus (idempotency).
    var rewardedFriendSessionIDs: [String]? = nil
    /// Online pilots the user chose to hide locally.
    var hiddenPilotIDs: Set<String>? = nil

    static let empty = UserProfile()
}
