import Foundation

// MARK: - Connected-focus service layer (backend-ready; honest local fallback)
//
// The clean seams for real connected focus. Production ships the local
// fallbacks below — which are deliberately EMPTY (no presence, no fake
// accepted invites, no invented friends) — so nothing dishonest can render.
// When a backend arrives (CloudKit public database is the Apple-native
// choice, or any server), implement these three protocols against it and
// swap the instances in one place.
//
// MANUAL SETUP REQUIRED for the CloudKit implementation (not yet enabled):
//  • Xcode → Signing & Capabilities → + iCloud → check CloudKit,
//    container e.g. iCloud.com.<team>.focusglobe
//  • Associated Domains capability (applinks:focusglobe.app) so invite
//    links open the app and credit the right Sky
//  • A tiny CKRecord schema: Presence(skyID, sessionEnd), Invite(code,
//    skyID, accepterID), Friend(pairID)
//  • No Contacts permission is needed — invites go through the system
//    share sheet. Only add NSContactsUsageDescription if an in-app
//    contact picker ships later.

/// Live "who is in this Sky" presence.
protocol SkyPresenceService {
    /// Join a Sky for the duration of a flight (heartbeats keep it fresh).
    func join(skyID: String, plannedMinutes: Int)
    /// Refresh the pilot's presence (call every few minutes while flying).
    func heartbeat(skyID: String, remainingMinutes: Int)
    /// Leave on landing / cancel.
    func leave(skyID: String)
    /// Real pilots currently in a Sky. Empty until a backend exists.
    func participants(inSkyID skyID: String) async -> [SkyParticipant]
}

/// Referral invites — per-Sky, verified only by the backend.
protocol InviteService {
    /// This pilot's stable code.
    func referralCode() -> String
    /// Record that this pilot shared an invite for a Sky (analytics only).
    func markInviteShared(skyID: String)
    /// Called by the universal-link handler when a NEW user accepts an
    /// invite — the only path that may credit progress in production.
    func acceptInvite(code: String, skyID: String)
}

// NOTE: the old `FriendsService` seam was removed — real Crew connections are
// now served by FocusGlobe Online (`FocusOnlineModel` + `FriendService`).

/// The shipping fallback: compiles and runs with no backend, and is honest —
/// it reports nobody, credits nothing, and invents nothing. Ambient visuals
/// (`AmbientPilotsLayer`, `SkyActivity`) stay clearly ambient and separate.
/// The pilot's real referral code lives on `AppModel` (persisted with the
/// profile); this fallback just mirrors whatever the caller hands it.
final class LocalSocialFallback: SkyPresenceService, InviteService {
    /// The persisted code, injected at construction (see `AppModel.referralCode()`).
    private let storedCode: String

    init(referralCode: String = "FOCUS") {
        self.storedCode = referralCode
    }

    // Presence: no-ops locally; nobody is claimed to be online.
    func join(skyID: String, plannedMinutes: Int) {}
    func heartbeat(skyID: String, remainingMinutes: Int) {}
    func leave(skyID: String) {}
    func participants(inSkyID skyID: String) async -> [SkyParticipant] { [] }

    // Invites: acceptance only ever arrives via the (future) verified link
    // path — never simulated here.
    func referralCode() -> String { storedCode }
    func markInviteShared(skyID: String) {}
    func acceptInvite(code: String, skyID: String) {
        // Production: the backend validates the code + new-user status first,
        // then the app calls AppModel.registerAcceptedInvite(forSkyID:).
    }
}
