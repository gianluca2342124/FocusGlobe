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
    /// Fly without ambient fellow pilots (solo/offline mode).
    var soloFlights: Bool? = nil
    /// Per-Sky unlocks earned by invites: a Sky unlocks individually once its
    /// own 3 invites are accepted. (Premium bypasses this while active.)
    var unlockedSkyIDs: Set<String>? = nil
    /// Accepted invites counted per Sky (the honest, backend-fed tally).
    var inviteProgressBySkyID: [String: Int]? = nil

    static let empty = UserProfile()
}
