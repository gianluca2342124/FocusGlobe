import Foundation
import SwiftUI
import AuthenticationServices
import OSLog

/// A friendly, Release-safe reason a private room couldn't be created (never a
/// raw backend error — that stays in DEBUG diagnostics / OSLog).
struct RoomCreationFailure: Equatable, Sendable {
    let message: String
}

/// The ONE authoritative state for private-room creation. Every online surface
/// (flight selector, invite sheet, Friends) reads this — never a cached boolean
/// and never the selected flight mode — so "Private room ready" can only ever
/// appear when a room truly exists with a live server invite link.
enum RoomCreationState: Equatable {
    case idle                       // nothing created yet
    case creating                   // a single create operation is in flight
    case waitingUntil(Date)         // server throttle — retry-after window
    case ready(FocusRoom)           // server room + owner membership + invite URL
    case failed(RoomCreationFailure)
}

/// **FocusGlobe Online** — the single @MainActor coordinator between the UI
/// and the Supabase service actors. Views never touch the backend directly;
/// Solo flights never touch this class's network paths. Every failure degrades
/// to a friendly state and never blocks the local timer or coins.
@MainActor
final class FocusOnlineModel: ObservableObject {

    // MARK: Published state

    @Published private(set) var availability: OnlineState = .unknown
    @Published private(set) var profile: OnlineProfile?

    /// The mode selected in the pre-flight ritual (persisted last choice).
    @Published var flightMode: OnlineFlightMode = OnlineCache.lastFlightMode {
        didSet { OnlineCache.lastFlightMode = flightMode }
    }

    /// The ONE authoritative social state of the active flight. Every view reads
    /// this — never a sheet-open flag, a stray room object or a cached bool.
    ///  • solo/global               → the flight the user started
    ///  • globalInviteReady         → host shared an invite; STILL Global (real
    ///                                strangers + decorative) until someone joins
    ///  • privateActive             → a genuine remote participant joined; sticky
    ///                                for the rest of the journey (no strangers)
    enum ActiveFlightSocialState: String, Sendable {
        case solo, global, preparingInvite, globalInviteReady, privateActive
    }
    @Published private(set) var socialState: ActiveFlightSocialState = .solo
    /// The private room chosen/created for the NEXT flight (privateRoom mode).
    @Published var pendingRoom: FocusRoom?
    /// Single authoritative room-creation pipeline state.
    @Published private(set) var roomCreationState: RoomCreationState = .idle
    /// Set when the active room flips to `active` (drives member auto-start).
    @Published private(set) var activeRoomStartedID: String?
    /// A previewed (NOT yet joined) invitation — opening a link shows this; only
    /// tapping Join Flight creates membership. Drives the invitation screen.
    @Published private(set) var invitePreview: InvitePreviewState?

    /// A read-only invitation preview (no membership yet).
    struct InvitePreviewState: Identifiable, Sendable {
        let token: String
        let room: FocusRoom
        let hostAlias: String
        let hostSkin: String
        let participantCount: Int
        var id: String { room.id }
    }
    /// Friendly one-line outcome of the last invite-link join attempt.
    @Published private(set) var inviteJoinMessage: String?
    /// One-shot "<alias> joined" toast (set on a genuine new join; view clears).
    @Published private(set) var joinToastAlias: String?
    /// Members seen so far in the active room (by UUID) — the join-toast baseline.
    private var knownMemberIDs: Set<String> = []

    /// Real pilots currently visible in the active Sky (public or room).
    @Published private(set) var realPilots: [OnlinePilot] = []
    @Published private(set) var reconnecting = false

    // Crew / social
    @Published private(set) var crew: [FocusFriend] = []
    @Published private(set) var incomingRequests: [FriendRequest] = []
    @Published private(set) var outgoingRequests: [FriendRequest] = []
    @Published private(set) var ownedRooms: [FocusRoom] = []
    @Published private(set) var joinedRooms: [FocusRoom] = []
    @Published private(set) var activeRoomParticipants: [RoomParticipant] = []

    // Diagnostics (DEBUG screen)
    @Published private(set) var lastPilotFetchAt: Date?
    @Published private(set) var lastErrorCategory: String?
    /// Full breakdown of the most recent room failure. DEBUG diagnostics only.
    @Published private(set) var lastRoomErrorDetail: String?

    /// Whether a Supabase user is authenticated — the OBSERVABLE half of
    /// `isSignedIn`.
    ///
    /// `myUserID` stays private and unpublished (it is the canonical identity and
    /// must not be bound to or displayed); this publishes only the boolean fact,
    /// maintained in that property's `didSet`. Without it, `isSignedIn` changed
    /// silently and Settings ▸ Account only refreshed because `availability`
    /// happened to change in the same breath — true today, but not a guarantee.
    @Published private(set) var isAuthenticated = false

    /// Both operands are now `@Published`, so every consumer re-renders the moment
    /// a session is restored, Sign in with Apple succeeds, the pilot signs out, or
    /// the account switches.
    var isSignedIn: Bool { isAuthenticated || availability == .ready }

    /// The ONE canonical online identity: the authenticated Supabase user UUID.
    /// Every self-filter and dedupe uses THIS — never alias, skin or device.
    var currentUserID: String? { myUserID }
    /// True ONLY once the flight has genuinely become Private (a remote pilot
    /// joined). Reads the authoritative state, so sharing an invite alone never
    /// removes the Global strangers/decorative pilots. Sticky for the journey.
    var isPrivateFlight: Bool { socialState == .privateActive }
    /// The host has an outstanding invite but is STILL flying Global.
    var isInviteReady: Bool { socialState == .globalInviteReady || socialState == .preparingInvite }

    /// The shared, server-anchored, monotonic clock. Every online countdown reads
    /// its estimate of server time from here (see ServerClock), so two devices
    /// with different — even manually wrong — wall clocks still finish together.
    let serverClock = ServerClock()
    /// Best estimate of the current SERVER time (monotonic between syncs).
    var serverAdjustedNow: Date { serverClock.estimatedServerNow }
    /// serverNow − localNow, for legacy call sites (pilot bubbles, preview label)
    /// that shift a server timestamp into local `Date()` space.
    var serverClockOffset: TimeInterval { serverClock.offset }
    /// A server timestamp shifted into LOCAL clock space, so `Date()`-based label
    /// math (pilot bubbles) yields the server-correct remaining time.
    func adjustedDeadline(_ serverEnd: Date?) -> Date? {
        serverEnd.map { $0.addingTimeInterval(-serverClock.offset) }
    }
    /// Fold one `server_now` sample into the shared clock. `requestStartedAt` is
    /// stamped by the caller just before awaiting the RPC, so the round trip (and
    /// thus the local midpoint) can be estimated.
    private func syncServerClock(_ serverNow: Date?, since requestStartedAt: Date) {
        guard let serverNow else { return }
        serverClock.record(serverNow: serverNow,
                           requestStartedAt: requestStartedAt,
                           responseReceivedAt: Date(),
                           receivedUptime: ProcessInfo.processInfo.systemUptime)
    }

    /// The online HOST's server-canonical finite deadline for the CURRENT flight
    /// (nil for Solo / Infinite / guest). The active FocusSessionViewModel adopts
    /// it — matched by session id — so the host's main timer counts down to the
    /// exact same absolute instant the guests do. Republished each poll so a
    /// missed publish still lands.
    struct HostDeadline: Equatable { let sessionID: String; let deadline: Date }
    @Published private(set) var hostCanonicalDeadline: HostDeadline?

    /// Deduplicate any participant list by user UUID (stable, first-wins).
    static func dedupe(_ list: [RoomParticipant]) -> [RoomParticipant] {
        var seen = Set<String>(); var out: [RoomParticipant] = []
        for p in list where !seen.contains(p.publicID) { seen.insert(p.publicID); out.append(p) }
        return out
    }

    // MARK: Services

    private let authService = SupabaseAuthService()
    private let profileService = ProfileService()
    private let flightService = PublicFlightService()
    private let roomService = RoomService()
    private let friendService = FriendService()
    private let realtimeService = RealtimeService()
    private let moderationService = ModerationService()
    private let rewardService = OnlineRewardService()

    private weak var appModel: AppModel?
    /// The authenticated Supabase user UUID (lowercased) — nil when signed out.
    ///
    /// Every mutation routes through this one property (session restore, Sign in
    /// with Apple, sign-out), so its `didSet` is the single, centralized place
    /// RevenueCat identity is kept in step. `syncIdentity` is idempotent, so the
    /// repeated `refreshAvailability()` passes never issue a redundant `logIn`.
    private var myUserID: String? {
        didSet {
            guard oldValue != myUserID else { return }
            // Publish the authenticated FACT (never the UUID) so SwiftUI can
            // observe sign-in state directly. Derived here, in the one place the
            // identity can change, so it cannot drift from `myUserID`.
            isAuthenticated = myUserID != nil
            appModel?.subscriptions.syncIdentity(supabaseUserID: myUserID)
        }
    }
    private var pilotPollTask: Task<Void, Never>?
    private var lobbyRoomID: String?

    // Room-creation pipeline (single-flight + throttle-aware).
    private var roomCreateTask: Task<FocusRoom?, Never>?
    private var throttleResetTask: Task<Void, Never>?
    private var consecutiveThrottles = 0

    // Sign in with Apple nonce for the in-flight authorization.
    private var currentRawNonce: String?

    // Friend-bonus overlap tracking for the CURRENT flight.
    private var flightSessionID: String?
    /// An online flight whose `flightDidStart` arrived before the session/profile
    /// was ready. Replayed exactly once by `refreshAvailability()`. Nil whenever
    /// there is nothing outstanding.
    private struct PendingFlightStart {
        let skyID: String
        let sessionID: String
        let expectedEndAt: Date?
        let category: String
    }
    private var pendingFlightStart: PendingFlightStart?
    /// The session id the SERVER has confirmed an `active_flights` row for.
    ///
    /// `flightSessionID` alone was never proof of that: it is assigned
    /// synchronously at take-off, while the publish RPC runs in a detached task
    /// that was never awaited and whose failure nothing observed. Invite Friends
    /// gated on it and therefore promoted sessions the server had never seen.
    private var publishedSessionID: String?
    /// The in-flight publish work, so Invite can await the REAL server session
    /// rather than racing it.
    private var publishTask: Task<Void, Never>?
    /// The current journey's Sky and focus category, retained so the canonical
    /// session can be re-published later (Invite repair) without the caller having
    /// to hand them back.
    private var flightSkyID: String?
    private var flightCategory: String?
    /// This device's own current pause state, mirrored from `flightPauseChanged`.
    /// Needed so a session REPAIR (republish) re-asserts the pause instead of
    /// silently resuming the pilot on everyone else's screen.
    private var localPaused = false
    /// The in-flight pause/resume mutation, so a rapid double tap supersedes it
    /// rather than racing a second write to the same row.
    private var pauseSyncTask: Task<Void, Never>?
    private var flightRoom: FocusRoom?
    private var serverSessionID: String?
    /// The CURRENT flight's shared end (nil = infinite). Captured at take-off so
    /// a mid-flight Global→Private promotion can inherit the exact remaining time
    /// instead of starting a new timer.
    private var flightExpectedEnd: Date?
    /// The CURRENT flight's canonical start — copied into the private-flight
    /// record so the server carries the host's original startedAt.
    private var flightStartedAt: Date?
    private var verifiedBonusSessionIDs = Set<String>()
    private var overlapSeconds: Double = 0
    private var lastOverlapSample: Date?
    /// Verified overlap needed for the friend bonus (≥ 5 focused minutes).
    static let friendBonusOverlap: Double = 300

    nonisolated init() {}

    // MARK: Bootstrap / availability

    func bootstrap(appModel: AppModel) {
        self.appModel = appModel
        profile = OnlineCache.loadProfile()
        if let retry = OnlineCache.roomCreationRetryAfterDate, retry > Date() {
            roomCreationState = .waitingUntil(retry)
            scheduleThrottleReset(until: retry)
        } else {
            OnlineCache.roomCreationRetryAfterDate = nil
        }
        Task { await refreshAvailability() }
    }

    func refreshAvailability() async {
        guard SupabaseConfig.isConfigured else {
            availability = .projectUnavailable
            OnlineCache.lastOnlineStatus = availability.userMessage
            return
        }
        if availability == .authenticating { return }
        do {
            if let userID = try await authService.restoreSession() {
                myUserID = userID
                // Never declare `.ready` until a profile row is confirmed — a
                // cached profile for THIS user counts, otherwise the
                // server-guaranteed ensure must succeed first.
                if profile != nil, profile?.publicID == userID {
                    if availability != .ready { availability = .ready }
                    Task { await ensureIdentityAndProfile() }   // refresh in background
                } else if await ensureIdentityAndProfile() {
                    availability = .ready
                } else {
                    availability = (lastErrorCategory == "network") ? .networkUnavailable : .reconnecting
                }
            } else {
                myUserID = nil
                availability = .signedOut
            }
        } catch {
            lastErrorCategory = OnlineError.category(for: error)
            availability = (lastErrorCategory == "network") ? .networkUnavailable : .projectUnavailable
        }
        OnlineCache.lastOnlineStatus = availability.userMessage
        // Re-assert RevenueCat identity. `myUserID`'s `didSet` already handles a
        // CHANGE; this covers the two cases it cannot: the first pass running
        // before RevenueCat finished configuring, and retrying a `logIn` that
        // failed on a flaky network. `syncIdentity` is idempotent, so when the
        // identity is already correct this costs nothing.
        appModel?.subscriptions.syncIdentity(supabaseUserID: myUserID)
        // Readiness has landed — replay an online flight start that had to bail.
        // Cleared first so a replay that still can't proceed re-arms itself rather
        // than looping here.
        if availability.isAvailable, profile != nil, let pending = pendingFlightStart {
            pendingFlightStart = nil
            flightDidStart(skyID: pending.skyID, sessionID: pending.sessionID,
                           expectedEndAt: pending.expectedEndAt, category: pending.category)
        }
        // …and replay a held INVITATION for the same reason.
        //
        // This used to run only after a fresh Sign in with Apple, so a token
        // stashed by an ALREADY-signed-in pilot was never consumed: tapping an
        // invite on a cold launch (session restore / profile ensure still in
        // flight, or one flaky network moment) stored the token, showed a message,
        // and then silently dropped it — the invitation could not be opened again
        // because the link had already been "used" from the pilot's point of view.
        // Now any path back to `.ready` picks it up.
        if availability.isAvailable, profile != nil, OnlineCache.pendingInviteToken != nil {
            await consumePendingInviteIfAny()
        }
    }

    /// Wait (briefly) until an invite can actually be prepared.
    ///
    /// Returns true once `inviteBlockedReason` clears, false on timeout. Polls the
    /// existing state rather than adding a publisher: this runs at most a few times,
    /// only while the pilot is waiting on a tap they already made.
    func awaitInviteReadiness(timeout: TimeInterval = 6) async -> Bool {
        if inviteBlockedReason == nil { return true }
        // Nudge the session along — this is also what replays a bailed flight start.
        await refreshAvailability()
        // Then await the ACTUAL publish work rather than polling a local flag. This
        // is the difference that matters: `flightSessionID` is set synchronously at
        // take-off, so the old poll cleared instantly while the server row did not
        // yet exist, and the promote RPC raced ahead into `no_active_global_session`.
        await publishTask?.value
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if inviteBlockedReason == nil { return true }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return inviteBlockedReason == nil
    }

    /// The ONE authoritative reaction to a failed backend operation: a genuine
    /// network failure flips the shared availability so EVERY online surface
    /// agrees; an authentication rejection flips to sessionExpired. Other
    /// errors keep `.ready` and the caller shows a retry — never "offline".
    private func applyOperationError(_ error: Error) {
        let category = OnlineError.category(for: error)
        lastErrorCategory = category
        switch category {
        case "network":     availability = .networkUnavailable
        case "no-account":  availability = .sessionExpired
        default:            break
        }
    }

    // MARK: Sign in with Apple (native → Supabase ID-token)

    /// SHA-256 nonce for the Apple request; the raw value is kept for Supabase.
    func makeAppleNonce() -> String {
        let raw = SupabaseAuthService.makeRawNonce()
        currentRawNonce = raw
        return SupabaseAuthService.sha256(raw)
    }

    /// Completes the SwiftUI SignInWithAppleButton flow. Returns a friendly
    /// error message, or nil on success.
    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) async -> String? {
        guard let rawNonce = currentRawNonce else { return OnlineError.requestFailed.userMessage }
        currentRawNonce = nil
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return nil }
            lastErrorCategory = OnlineError.category(for: error)
            lastRoomErrorDetail = OnlineError.detail(for: error)
            return "Sign in didn't complete. Please try again."
        case .success(let authorization):
            availability = .authenticating
            do {
                let userID = try await authService.signInWithApple(authorization: authorization,
                                                                   rawNonce: rawNonce)
                // Create/load the profile row BEFORE declaring ready — Online is
                // never entered without a profile, so a room write can't hit the
                // owner FK. If profile setup fails we stay authenticated but not
                // ready and surface a retryable message.
                myUserID = userID
                if await ensureIdentityAndProfile() {
                    availability = .ready
                    await consumePendingInviteIfAny()
                    return nil
                }
                availability = (lastErrorCategory == "network") ? .networkUnavailable : .reconnecting
                return OnlineError.profileNotReady.userMessage
            } catch {
                // The token exchange may already have established a session even
                // if a follow-up step threw — reconcile before declaring
                // failure. This is the one-tap fix: a session created on the
                // FIRST authorization is picked up here instead of forcing a
                // second tap.
                if let recovered = try? await authService.restoreSession() {
                    myUserID = recovered
                    if await ensureIdentityAndProfile() {
                        availability = .ready
                        await consumePendingInviteIfAny()
                        return nil
                    }
                    availability = (lastErrorCategory == "network") ? .networkUnavailable : .reconnecting
                    return OnlineError.profileNotReady.userMessage
                }
                availability = .signedOut
                lastErrorCategory = OnlineError.category(for: error)
                lastRoomErrorDetail = OnlineError.detail(for: error)
                SupabaseService.log.error("apple sign-in FAILED: \(OnlineError.detail(for: error), privacy: .public)")
                return lastErrorCategory == "network"
                    ? OnlineState.networkUnavailable.userMessage
                    : "Sign in didn't complete. Please try again."
            }
        }
    }

    func signOut() async {
        await flightService.stopPublishing()
        await realtimeService.teardown()
        await authService.signOut()
        myUserID = nil
        resetSocialState()
        availability = .signedOut
    }

    private func resetSocialState() {
        OnlineCache.resetForAccountChange()
        profile = nil
        crew = []
        incomingRequests = []
        outgoingRequests = []
        ownedRooms = []
        joinedRooms = []
        realPilots = []
        pendingRoom = nil
        invitePreview = nil
        inviteJoinMessage = nil
        resetRoomCreation()
    }

    /// Fetch-or-create my profile row (server-guaranteed via
    /// `ensure_current_profile`) + push current skin/settings. Returns whether
    /// a valid profile is now loaded — callers must NOT declare Online `.ready`
    /// unless this succeeded, so a room write can never hit the owner FK with a
    /// missing profile row.
    @discardableResult
    func ensureIdentityAndProfile() async -> Bool {
        guard let myUserID else { return false }
        do {
            var current = try await profileService.ensureProfile(
                userID: myUserID,
                defaults: OnlineProfile(
                    publicID: myUserID,
                    displayName: "SkyPilot\(Int.random(in: 1000...9999))",
                    balloonSkinID: appModel?.equippedSkinIDForOnline ?? "default",
                    countryCode: Locale.current.region?.identifier,
                    isDiscoverable: appModel?.profile.onlineDiscoverable ?? true,
                    allowsFriendRequests: appModel?.profile.onlineAllowsFriendRequests ?? true,
                    createdAt: Date(), updatedAt: Date()))
            current.balloonSkinID = appModel?.equippedSkinIDForOnline ?? current.balloonSkinID
            // The server row wins when this device has no stored preference —
            // that row may already hold a deliberate opt-out made elsewhere, and
            // a local default must never overwrite it. Then mirror the resolved
            // value back into the profile, so the Settings toggle shows what the
            // account actually holds instead of an optimistic `?? true`.
            current.isDiscoverable = appModel?.profile.onlineDiscoverable ?? current.isDiscoverable
            if appModel?.profile.onlineDiscoverable == nil {
                appModel?.profile.onlineDiscoverable = current.isDiscoverable
            }
            // A failed settings push must not discard a valid fetched profile —
            // the row exists, which is what the FK needs.
            try? await profileService.updateProfile(current)
            profile = current
            OnlineCache.save(profile: current)
            await flightService.configure(userID: myUserID)
            return true
        } catch {
            applyOperationError(error)
            lastRoomErrorDetail = OnlineError.detail(for: error)
            return false
        }
    }

    // MARK: Settings controls

    func setDiscoverable(_ on: Bool) {
        appModel?.profile.onlineDiscoverable = on
        guard var p = profile else { return }
        p.isDiscoverable = on
        profile = p
        OnlineCache.save(profile: p)
        let inPrivateFlight = flightMode == .privateRoom
        Task {
            try? await profileService.updateProfile(p)
            // Opting out of PUBLIC discovery drops the public presence row. It must
            // NOT do that during a private flight: a room session's visibility comes
            // from room membership (`in_same_active_room`), not `is_discoverable`,
            // so deleting the row there would only destroy this pilot's own
            // authoritative timer and silently break their pause — without changing
            // what anyone can see.
            if !on && !inPrivateFlight { await flightService.stopPublishing() }
        }
    }

    func setAllowsFriendRequests(_ on: Bool) {
        appModel?.profile.onlineAllowsFriendRequests = on
        guard var p = profile else { return }
        p.allowsFriendRequests = on
        profile = p
        OnlineCache.save(profile: p)
        Task { try? await profileService.updateProfile(p) }
    }

    /// Alias validation + rate limit (one change per day).
    func updateAlias(_ raw: String) async -> String? {
        let alias = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard alias.count >= 3, alias.count <= 20 else { return "Alias must be 3–20 characters." }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_ "))
        guard alias.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return "Only letters, numbers, spaces and _ are allowed."
        }
        guard alias.rangeOfCharacter(from: .alphanumerics) != nil else { return "Add a few letters or numbers." }
        guard !alias.lowercased().contains("http") else { return "Links aren't allowed." }
        let banned = ["fuck", "shit", "bitch", "nazi", "cunt"]
        guard !banned.contains(where: { alias.lowercased().contains($0) }) else { return "Please pick a friendlier alias." }
        if let last = OnlineCache.aliasLastChangedAt, Date().timeIntervalSince(last) < 24 * 3600 {
            return "You can change your alias once a day."
        }
        guard var p = profile else { return OnlineError.notSignedIn.userMessage }
        p.displayName = alias
        do {
            try await profileService.updateProfile(p)
            profile = p
            OnlineCache.save(profile: p)
            OnlineCache.aliasLastChangedAt = Date()
            return nil
        } catch {
            applyOperationError(error)
            return OnlineError.requestFailed.userMessage
        }
    }

    // MARK: Flight lifecycle (called from AppModel hooks — never blocks Solo)

    func flightDidStart(skyID: String, sessionID: String, expectedEndAt: Date?, category: String) {
        // Every flight resets the social state; online ones then set their own.
        socialState = .solo
        hostCanonicalDeadline = nil       // this flight's server deadline arrives from publish
        // An ONLINE flight that starts before the session/profile is ready used to
        // be lost here: the guard returned and `flightSessionID` stayed nil for the
        // rest of the flight, with no retry — which is what made Invite Friends
        // permanently inert on a fast take-off, not merely slow. Remember the
        // request so `refreshAvailability()` can replay it once readiness lands.
        guard flightMode.isOnline else { pendingFlightStart = nil; return }
        guard availability.isAvailable, let profile else {
            pendingFlightStart = PendingFlightStart(skyID: skyID, sessionID: sessionID,
                                                   expectedEndAt: expectedEndAt, category: category)
            return
        }
        pendingFlightStart = nil
        // `flightMode` is sticky and persisted across launches, so a journey that
        // does NOT pass through the mode selector can start in `.privateRoom` with
        // no room at all. That combination skipped publishing entirely (the branch
        // below is `.publicSky`-only), leaving no server row, and the recovery
        // `republish()` was a no-op because the service had no presence — Invite
        // could then never succeed for the whole flight. A private mode without a
        // room is not private: normalise it to a Global flight.
        if flightMode == .privateRoom, pendingRoom == nil, flightRoom == nil {
            #if DEBUG
            SupabaseService.log.debug("online: stale privateRoom mode with no room — flying Global")
            #endif
            flightMode = .publicSky
        }
        flightSessionID = sessionID
        publishedSessionID = nil
        flightSkyID = skyID
        flightCategory = category
        flightRoom = flightMode == .privateRoom ? pendingRoom : nil
        flightExpectedEnd = expectedEndAt
        flightStartedAt = Date()
        // A guest launching straight into an invited flight is already Private;
        // a fresh online flight starts Global and only turns Private when a real
        // remote pilot joins.
        socialState = flightMode == .privateRoom ? .privateActive : .global
        serverSessionID = nil
        overlapSeconds = 0
        lastOverlapSample = Date()
        let presence = OnlinePresence(sessionID: sessionID, skyID: skyID,
                                      mode: flightMode,
                                      roomPublicID: flightRoom?.id,
                                      startedAt: Date(), expectedEndAt: expectedEndAt,
                                      isPaused: false, focusCategory: category,
                                      balloonSkinID: profile.balloonSkinID,
                                      // Display metadata: the fixed-catalog sound
                                      // id only (validated on display). PRO is not
                                      // shared — no trusted server entitlement.
                                      soundID: appModel?.selectedJourneyAudio.id)
        let myID = profile.publicID
        // Seed the join-toast baseline for a room flight so the first in-flight
        // poll never toasts pre-existing members.
        if flightMode == .privateRoom {
            knownMemberIDs = Set(activeRoomParticipants.map(\.publicID).filter { $0 != myID })
        }
        let ownsFlightRoom = flightRoom?.isOwned ?? false
        let roomEnd = expectedEndAt
        publishTask?.cancel()
        publishTask = Task {
            // Every Global flight publishes its active_flights session row — this
            // is the server-canonical record the promote RPC validates against
            // (visibility to OTHER pilots is still gated by is_discoverable in
            // RLS, so a non-discoverable flyer stays hidden). The realtime sky
            // nudge remains discoverable-only.
            // EVERY online flight — public OR private — publishes its own
            // authoritative participant session. A private/invited journey used to
            // skip this branch entirely, so an invited pilot had no `active_flights`
            // row at all: no timer of their own, nothing for pause to write to, and
            // nothing for co-members to observe. That is what made private-room
            // pause impossible rather than merely missing.
            do {
                // A private flight publishes bound to its room, so the row is
                // `session_kind = 'room'`: out of Public Sky discovery, visible to
                // co-members through the existing room RLS branch.
                if let roomID = flightRoom?.id { await flightService.noteRoomBinding(roomID) }
                // Server-canonical publish: the SERVER stamps started_at /
                // expected_end_at. Sync the shared clock from its server_now and
                // adopt the canonical deadline for THIS session so the host's main
                // timer counts down to the exact instant the guests will.
                let t0 = Date()
                // `ensurePublished` retries with a short backoff and, crucially,
                // reports success. The old call published once, un-awaited, and
                // discarded a nil result — so a failed publish left the journey
                // rendering happily with NO server row, and Invite Friends promoted
                // a session the server had never heard of
                // (`no_active_global_session`). Confirmation is now recorded and
                // gates the invite.
                let published = await flightService.ensurePublished(presence)
                syncServerClock(published?.serverNow, since: t0)
                if published != nil {
                    publishedSessionID = sessionID
                    #if DEBUG
                    SupabaseService.log.debug("online: flight session confirmed by server")
                    #endif
                } else {
                    #if DEBUG
                    SupabaseService.log.debug("online: flight session NOT published — invite will re-try on demand")
                    #endif
                }
                if let end = published?.expectedEndAt {
                    hostCanonicalDeadline = HostDeadline(sessionID: sessionID, deadline: end)
                }
                // Public discovery + the realtime Sky nudge stay public-only.
                if flightMode == .publicSky, appModel?.profile.onlineDiscoverable ?? true {
                    await realtimeService.joinSky(skyID: skyID, myID: myID) { [weak self] in
                        Task { @MainActor [weak self] in await self?.pollSoon() }
                    }
                }
            }
            // Every ONLINE flight listens for applause addressed to me (RLS-
            // scoped Postgres changes). On any change, fetch the new server-
            // written rows — the sender + alias are authoritative, never a
            // client payload. Seed the "seen" marker to now so we never replay
            // history on subscribe.
            applauseSeenAt = Date()
            await realtimeService.subscribeApplause(myID: myID) { [weak self] in
                Task { @MainActor [weak self] in await self?.pollApplause() }
            }
            if let room = flightRoom {
                // The OWNER propagates the real duration to the room so every
                // co-member's bubble shows the same synchronized remaining time.
                if ownsFlightRoom { await roomService.setFlightEnd(roomID: room.id, endsAt: roomEnd) }
                await roomService.heartbeat(roomID: room.id, myID: myID)
                serverSessionID = await roomService.mySession(roomID: room.id, myID: myID)
                // Re-read the room so flightRoom.endsAt reflects the propagated end.
                if let refreshed = await roomService.room(id: room.id, myID: myID) {
                    flightRoom = refreshed
                }
            }
        }
        startPilotPolling(skyID: skyID)
    }

    func flightPauseChanged(isPaused: Bool) {
        guard flightMode.isOnline else { return }
        localPaused = isPaused
        pauseSyncTask?.cancel()      // a rapid re-tap supersedes the in-flight one
        pauseSyncTask = Task { [weak self] in
            guard let self else { return }
            #if DEBUG
            SupabaseService.log.debug("online: \(isPaused ? "pause" : "resume", privacy: .public) requested")
            #endif
            let t0 = Date()
            var result = await flightService.setPaused(isPaused)
            if result == nil, !Task.isCancelled {
                // `setPaused` used to bail whenever the service held no presence —
                // exactly the state a promoted/joined private flight was left in,
                // so pause was a silent no-op for every invited journey. Repair the
                // canonical session (bound to the room when there is one) and apply
                // the pause to it rather than dropping the request on the floor.
                if let sessionID = self.flightSessionID {
                    await self.ensureCanonicalSession(sessionID: sessionID, roomID: self.flightRoom?.id)
                    result = await self.flightService.setPaused(isPaused)
                }
            }
            guard !Task.isCancelled else { return }
            self.syncServerClock(result?.serverNow, since: t0)
            if let result {
                // Reconcile the optimistic local flag with the server's answer.
                self.localPaused = result.isPaused
                #if DEBUG
                SupabaseService.log.debug("online: \(result.isPaused ? "pause" : "resume", privacy: .public) confirmed")
                #endif
            } else {
                #if DEBUG
                SupabaseService.log.debug("online: pause mutation failed — server state unchanged")
                #endif
            }
        }
        if isPaused { sampleOverlap(activeOthers: 0) } else { lastOverlapSample = Date() }
    }

    // MARK: Applause — SERVER-AUTHORITATIVE (see send_applause / applause_events)

    /// The alias whose applause just arrived (one-shot toast; the flight view
    /// shows and clears it).
    @Published private(set) var applauseFrom: String?
    /// The `send_applause` outcome for the pilot detail UI to reflect honestly.
    typealias ApplauseResult = PublicFlightService.ApplauseResult
    /// A light LOCAL echo of the server cooldown — for immediate button state
    /// ONLY (the real 45s enforcement lives in Postgres; this never gates
    /// security). Cleared naturally after 45 s.
    private var applauseSentAt: [String: Date] = [:]
    /// Newest applause row already shown, so a poll never replays or dupes.
    private var applauseSeenAt: Date = .distantPast
    private var lastApplauseShownAt: Date = .distantPast

    /// Applaud a real pilot. The SERVER decides: identity, co-presence, self and
    /// cooldown are all enforced in `send_applause`. Returns the real outcome —
    /// the UI only shows "applauded" when the server accepted it.
    func applaud(_ pilot: OnlinePilot) async -> ApplauseResult {
        let result = await flightService.sendApplause(to: pilot.id)
        if result == .sent { applauseSentAt[pilot.id] = Date() }
        return result
    }

    /// Local optimistic cooldown echo (UI only; never the security boundary).
    func applauseOnCooldown(for pilot: OnlinePilot) -> Bool {
        if let last = applauseSentAt[pilot.id] { return Date().timeIntervalSince(last) < 45 }
        return false
    }

    /// Pull the applause rows addressed to me since the last one shown (RLS
    /// guarantees they are mine) and surface the newest, burst-throttled.
    private func pollApplause() async {
        let events = await flightService.fetchApplause(after: applauseSeenAt)
        guard let latest = events.max(by: { $0.at < $1.at }) else { return }
        applauseSeenAt = latest.at
        guard Date().timeIntervalSince(lastApplauseShownAt) > 2 else { return }
        lastApplauseShownAt = Date()
        applauseFrom = latest.alias
        appModel?.haptics.rewardClaim()
    }

    func clearApplause() { applauseFrom = nil }

    /// REAL pilots currently in a Sky — for the pre-flight joining screen (no
    /// presence is published yet; this is a plain read). Never fabricated.
    func previewPilots(skyID: String) async -> [OnlinePilot] {
        await flightService.fetchPilots(skyID: skyID, excluding: myUserID, limit: 8)
    }

    func flightDidEnd(sessionID: String) {
        guard flightSessionID == sessionID else { return }
        pilotPollTask?.cancel()
        pilotPollTask = nil
        // Cancel any outstanding invite preparation with the journey it belonged
        // to, so a link can never arrive for a flight the pilot has left.
        publishTask?.cancel()
        publishTask = nil
        let room = flightRoom
        let wasOwnedPrivate = room?.isOwned ?? false
        let serverSession = serverSessionID
        flightRoom = nil
        flightSessionID = nil
        publishedSessionID = nil
        flightSkyID = nil
        flightCategory = nil
        pendingFlightStart = nil
        flightExpectedEnd = nil
        flightStartedAt = nil
        serverSessionID = nil
        #if DEBUG
        SupabaseService.log.debug("online: exit cleanup — session cleared")
        #endif
        realPilots = []
        reconnecting = false
        hostCanonicalDeadline = nil
        socialState = .solo               // the journey is over — clear everything
        Task {
            await flightService.stopPublishing()
            await realtimeService.leaveSky()
            await realtimeService.unsubscribeRoom()
            await realtimeService.unsubscribeApplause()
            if room != nil, let serverSession {
                // Server-verified completion: the friend bonus is decided from
                // server rows, once, idempotently.
                if let outcome = await rewardService.completeSession(sessionID: serverSession),
                   outcome.friendBonus {
                    verifiedBonusSessionIDs.insert(sessionID)
                }
            }
            // Ending the host journey CLOSES the private flight and invalidates
            // outstanding invitations (expire_stale_rooms revokes them).
            if let room {
                if wasOwnedPrivate { await roomService.closeRoom(roomID: room.id) }
                else { try? await roomService.setReady(roomID: room.id, ready: false) }
            }
        }
    }

    func appDidEnterForeground() {
        Task {
            await refreshAvailability()
            await resyncServerClock()
            if let lobbyRoomID, let myID = myUserID {
                await roomService.heartbeat(roomID: lobbyRoomID, myID: myID)
            }
        }
    }

    /// Re-sync the shared clock immediately (foreground / reconnect / a long
    /// background gap). The monotonic reference does NOT advance while the device
    /// sleeps, so the estimate must be refreshed before the countdown is trusted
    /// again. Uses the heartbeat that matches the current flight.
    func resyncServerClock() async {
        if flightMode == .publicSky {
            let t0 = Date()
            if let hb = await flightService.heartbeatNow() {
                syncServerClock(hb.serverNow, since: t0)
                if let end = hb.expectedEndAt, let sid = flightSessionID {
                    hostCanonicalDeadline = HostDeadline(sessionID: sid, deadline: end)
                }
            }
        } else if let room = flightRoom, let myID = myUserID {
            let t0 = Date()
            if let hb = await roomService.heartbeat(roomID: room.id, myID: myID) {
                syncServerClock(hb.serverNow, since: t0)
                if let end = hb.endsAt, flightRoom?.endsAt != end { flightRoom?.endsAt = end }
            }
        }
    }

    // MARK: Pilot polling (online flights; ~35 s, never per-frame)

    private func startPilotPolling(skyID: String) {
        pilotPollTask?.cancel()
        pilotPollTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.pollOnce(skyID: skyID)
                try? await Task.sleep(nanoseconds: UInt64(SupabaseConfig.publicRefreshInterval * 1_000_000_000))
            }
        }
    }

    /// A realtime presence nudge — refresh pilots soon (debounced by the poll
    /// loop's own cadence; this is just one extra read, never a write).
    private var lastNudgeAt: Date = .distantPast
    private func pollSoon() async {
        guard flightMode == .publicSky, let profile else { return }
        guard Date().timeIntervalSince(lastNudgeAt) > 5 else { return }
        lastNudgeAt = Date()
        if let skyID = realPilots.first?.skyID ?? appModel?.selectedSky.id {
            realPilots = await flightService.fetchPilots(skyID: skyID, excluding: profile.publicID)
            lastPilotFetchAt = Date()
        }
    }

    private func pollOnce(skyID: String) async {
        guard flightMode.isOnline else { return }
        let me = profile?.publicID
        if flightMode == .publicSky {
            let pilots = await flightService.fetchPilots(skyID: skyID, excluding: me)
            realPilots = pilots
            reconnecting = pilots.isEmpty && !availability.isAvailable
            // Host shared an invite but is STILL flying Global: watch the private
            // record; the FIRST genuine remote member flips us to Private.
            if socialState == .globalInviteReady, let room = flightRoom {
                let members = Self.dedupe(await roomService.participants(roomID: room.id, roomActive: true))
                if members.contains(where: { $0.publicID != myUserID }) {
                    activatePrivateFlight(room: room, members: members)
                } else if let me {
                    // No guest yet: keep the pending private record fresh — this
                    // refreshes the owner membership heartbeat and (for an Infinite
                    // flight) rolls the room's stale-cleanup window forward, so the
                    // invite survives as long as the host keeps flying.
                    await roomService.heartbeat(roomID: room.id, myID: me)
                }
            }
            // Server-canonical presence heartbeat: keep the row alive, refresh the
            // shared clock, and (finite host) re-affirm the canonical deadline so
            // the host's main timer stays locked to the exact server instant.
            let t0 = Date()
            if let hb = await flightService.heartbeatNow() {
                syncServerClock(hb.serverNow, since: t0)
                if let end = hb.expectedEndAt, let sid = flightSessionID {
                    hostCanonicalDeadline = HostDeadline(sessionID: sid, deadline: end)
                }
            }
        } else if var room = flightRoom {
            // The owner propagates the shared end asynchronously at take-off; if a
            // co-member's earlier read lost that race, re-read the room until the
            // end lands so every device converges on the same synchronized timer.
            if room.endsAt == nil, let me, let refreshed = await roomService.room(id: room.id, myID: me) {
                flightRoom = refreshed
                room = refreshed
            }
            // Keep MY OWN participant row alive too. The room branch used to
            // heartbeat only room membership, so a private flight's active_flights
            // row went stale after 120 s and vanished from every co-member's view —
            // a pilot who simply paused for a few minutes would disappear. This
            // ping never moves the deadline or the frozen remainder; while paused it
            // re-asserts the pause rather than resuming it (`localPaused`).
            let t0 = Date()
            if let hb = await flightService.heartbeatNow() {
                syncServerClock(hb.serverNow, since: t0)
                localPaused = hb.isPaused
            }
            let participants = Self.dedupe(await roomService.participants(roomID: room.id, roomActive: true))
            detectJoins(in: participants)   // "<alias> joined" for in-flight joins
            activeRoomParticipants = participants
            // Deduplicate by UUID and NEVER render myself as a remote pilot.
            let others = participants.filter { $0.publicID != myUserID }
            // Each co-member's OWN authoritative participant row: their own
            // expected_end_at, is_paused and paused_remaining_seconds. RLS scopes
            // this to exactly this room's members.
            //
            // These used to be synthesized from the room-wide `focus_rooms.ends_at`
            // with `isPaused: false` hardcoded — one shared clock for everybody,
            // which made independent per-pilot pause impossible to express.
            realPilots = await roomPilots(room: room, participants: others)
            // Verified friend-flight overlap: another participant actively
            // flying with a fresh heartbeat.
            let activeOthers = others.filter {
                $0.status == .flying &&
                ($0.lastHeartbeatAt.map { Date().timeIntervalSince($0) < SupabaseConfig.presenceStaleInterval } ?? false)
            }.count
            sampleOverlap(activeOthers: activeOthers)
            if let me {
                let t0 = Date()
                if let hb = await roomService.heartbeat(roomID: room.id, myID: me) {
                    syncServerClock(hb.serverNow, since: t0)
                    // Adopt any canonical ends_at that landed after we joined so the
                    // guest's bubbles stay locked to the host's shared deadline.
                    if let end = hb.endsAt, flightRoom?.endsAt != end { flightRoom?.endsAt = end }
                }
            }
        }
        lastPilotFetchAt = Date()
    }

    private func sampleOverlap(activeOthers: Int) {
        let now = Date()
        if let last = lastOverlapSample, activeOthers > 0 {
            overlapSeconds += now.timeIntervalSince(last)
        }
        lastOverlapSample = now
    }

    /// True once for a verified friend flight (≥5 min real overlap in a private
    /// room, or the server's own verification). Decorative pilots and public
    /// strangers never qualify.
    func friendBonusEligible(sessionID: String) -> Bool {
        if verifiedBonusSessionIDs.contains(sessionID) { return true }
        return flightMode == .privateRoom
            && flightRoom != nil
            && flightSessionID == sessionID
            && overlapSeconds >= Self.friendBonusOverlap
    }

    // MARK: Rooms — creation pipeline (single-flight, throttle-aware)

    /// Back-compat entry (CreateRoomView etc.): create a private flight room
    /// and return an invitation.
    @discardableResult
    func createRoom(skyID: String, title: String, purpose: FocusRoom.Purpose = .flight) async -> RoomInvitation? {
        if purpose == .skyUnlock { return await campaignInvitationRoom(skyID: skyID) }
        guard let room = await requestPrivateFlightRoom(skyID: skyID, title: title) else { return nil }
        return RoomInvitation(id: room.id, room: room, url: room.shareURL)
    }

    /// The `Date` until which any room-creating write must wait (nil if clear).
    var roomThrottledUntil: Date? {
        if case .waitingUntil(let d) = roomCreationState, d > Date() { return d }
        if let d = OnlineCache.roomCreationRetryAfterDate, d > Date() { return d }
        return nil
    }

    /// Short label of the current creation state (DEBUG diagnostics).
    var roomStateSummary: String {
        switch roomCreationState {
        case .idle:                return "idle"
        case .creating:            return "creating"
        case .waitingUntil(let d): return "waitingUntil(\(max(0, Int(d.timeIntervalSinceNow)))s)"
        case .ready(let r):        return "ready(\(r.id.prefix(8)))"
        case .failed(let f):       return "failed(\(f.message))"
        }
    }

    /// Explicit, DEBOUNCED, SINGLE-FLIGHT private-room creation — the only path
    /// that promotes a room to `.ready`/`pendingRoom`, and only with a real
    /// server invite URL. Repeated calls while `.creating` join the in-flight
    /// attempt; calls during a throttle window do nothing.
    @discardableResult
    func requestPrivateFlightRoom(skyID: String, title: String = "FocusGlobe Flight") async -> FocusRoom? {
        if case .ready(let room) = roomCreationState { return room }
        if roomThrottledUntil != nil { return nil }
        if let task = roomCreateTask { return await task.value }
        let task = Task { [weak self] () -> FocusRoom? in
            guard let self else { return nil }
            return await self.performRoomCreation(skyID: skyID)
        }
        roomCreateTask = task
        let result = await task.value
        roomCreateTask = nil
        return result
    }

    private func performRoomCreation(skyID: String) async -> FocusRoom? {
        await refreshAvailability()
        guard availability.isAvailable, let myID = myUserID else {
            roomCreationState = .failed(RoomCreationFailure(message: availability.userMessage))
            return nil
        }
        if let until = roomThrottledUntil {
            roomCreationState = .waitingUntil(until)
            return nil
        }
        roomCreationState = .creating
        do {
            let created = try await roomService.createRoom(skyID: skyID, durationSeconds: nil,
                                                           purpose: .flight, myID: myID)
            consecutiveThrottles = 0
            lastRoomErrorDetail = nil
            OnlineCache.roomCreationRetryAfterDate = nil
            throttleResetTask?.cancel()
            pendingRoom = created.room
            activeRoomParticipants = created.members
            roomCreationState = .ready(created.room)
            await refreshRooms()
            return created.room
        } catch {
            applyOperationError(error)
            lastRoomErrorDetail = OnlineError.detail(for: error)
            if OnlineError.isThrottled(error) {
                consecutiveThrottles += 1
                let until = OnlineError.throttleRetryDate(for: error, consecutive: consecutiveThrottles)
                    ?? Date().addingTimeInterval(60)
                OnlineCache.roomCreationRetryAfterDate = until
                roomCreationState = .waitingUntil(until)
                scheduleThrottleReset(until: until)
            } else {
                roomCreationState = .failed(RoomCreationFailure(message: OnlineError.map(error).userMessage))
            }
            return nil
        }
    }

    /// Invite Friends from within an ACTIVE Global Flight: create (or reuse) the
    /// active private-flight backend record for THIS journey, bind it, and return
    /// a fresh single-use invite URL — WITHOUT changing the visible flight. The
    /// host stays Global (strangers + decorative still visible); it only becomes
    /// Private once a real remote pilot joins (see `activatePrivateFlight`). The
    /// timer/sky/sound/shield never change. Idempotent: repeated taps reuse the
    /// one flight (server-keyed by clientSessionID) and mint a fresh link.
    /// Why `prepareInvite` cannot run right now — `nil` when it can.
    ///
    /// Mirrors `prepareInvite`'s precondition guard so the caller can say something
    /// TRUE instead of failing silently.
    ///
    /// It deliberately requires the SERVER-CONFIRMED session, not just the locally
    /// minted `flightSessionID`. The two are not the same thing: the local id is
    /// assigned synchronously at take-off while the publish RPC is still in flight
    /// (and may fail outright), which is precisely how an invite used to sail past
    /// this guard and hit `no_active_global_session`.
    var inviteBlockedReason: String? {
        if !availability.isAvailable { return availability.userMessage }
        if myUserID == nil { return "Sign in to invite friends." }
        if flightSessionID == nil { return "Your flight is still connecting — try again in a moment." }
        if publishedSessionID != flightSessionID {
            return "Your flight is still connecting — try again in a moment."
        }
        return nil
    }

    func prepareInvite(skyID: String) async -> URL? {
        guard availability.isAvailable, let myID = myUserID, let sessionID = flightSessionID else { return nil }
        // Already private → just mint a fresh link for the existing flight.
        if socialState == .privateActive, let room = flightRoom ?? pendingRoom {
            return await freshInvite(for: room)
        }
        socialState = .preparingInvite
        // Guarantee the canonical server row BEFORE promoting. If the take-off
        // publish failed (or never ran), this is where it is repaired — so the
        // promote RPC always has a real active Global session to find instead of
        // returning `no_active_global_session` and stranding the pilot.
        if publishedSessionID != sessionID {
            #if DEBUG
            SupabaseService.log.debug("online: invite needs a canonical session — publishing now")
            #endif
            await ensureCanonicalSession(sessionID: sessionID)
            guard publishedSessionID == sessionID else {
                socialState = flightMode == .privateRoom ? .privateActive : .global
                #if DEBUG
                SupabaseService.log.debug("online: invite aborted — no canonical session")
                #endif
                return nil
            }
        }
        do {
            // The ONLY input is the stable client session id; the server derives
            // sky / start / end / active-status from the caller's canonical live
            // Global row in active_flights. No client timestamps are trusted.
            let t0 = Date()
            let created = try await promoteWithSessionRetry(sessionID: sessionID, myID: myID)
            syncServerClock(created.serverNow, since: t0)
            flightRoom = created.room
            pendingRoom = created.room
            // Still Global on screen — do NOT flip flightMode yet.
            socialState = .globalInviteReady
            // Watch the private record so the first join flips us promptly.
            await realtimeService.subscribeRoom(roomID: created.room.id) { [weak self] in
                Task { @MainActor [weak self] in await self?.reconcileInviteWatch(roomID: created.room.id) }
            }
            return created.room.shareURL
        } catch {
            applyOperationError(error)
            lastRoomErrorDetail = OnlineError.detail(for: error)
            // Sharing failed — remain a normal Global Flight.
            socialState = flightMode == .privateRoom ? .privateActive : .global
            return nil
        }
    }

    /// Promote this journey to a private flight from its canonical live Global
    /// session. If the server can't yet prove that session
    /// (`no_active_global_session` — e.g. the first presence heartbeat hasn't
    /// landed), refresh presence, await it, and retry EXACTLY once before
    /// surfacing a friendly retryable error. Never falls back to client
    /// timestamps.
    private func promoteWithSessionRetry(sessionID: String, myID: String) async throws -> RoomService.CreatedRoom {
        do {
            return try await roomService.promoteToPrivate(clientSessionID: sessionID, myID: myID)
        } catch {
            guard OnlineError.isNoActiveGlobalSession(error) else { throw error }
            // (Re)publish the canonical Global presence row (server-stamped,
            // bound to this exact client_session_id), await it, then retry the
            // promotion once.
            //
            // This used to call `republish()`, which bails when the service holds
            // no presence — exactly the state on the paths that produced this error
            // in the first place, so the "retry" issued no RPC at all and the
            // second promote failed identically. Rebuilding the presence makes the
            // recovery real.
            await ensureCanonicalSession(sessionID: sessionID)
            return try await roomService.promoteToPrivate(clientSessionID: sessionID, myID: myID)
        }
    }

    /// Create (or repair) the canonical `active_flights` row for THIS journey and
    /// record the server's confirmation.
    ///
    /// Rebuilds the presence from current state rather than relying on whatever the
    /// flight service still holds, so it works even after `stopPublishing()` has
    /// cleared it (discoverability toggled off mid-flight) or when the flight never
    /// published at all. Idempotent server-side: the RPC is keyed by
    /// `client_session_id`, so re-publishing the same journey preserves its
    /// server-canonical start, deadline and pause state.
    private func ensureCanonicalSession(sessionID: String, roomID: String? = nil) async {
        guard let profile else { return }
        // A room id makes the published row `session_kind = 'room'`, so it is
        // visible to co-members and hidden from Public Sky discovery.
        if let roomID { await flightService.noteRoomBinding(roomID) }
        let presence = OnlinePresence(sessionID: sessionID,
                                      skyID: flightSkyID ?? appModel?.selectedSky.id ?? "classic",
                                      mode: roomID == nil ? .publicSky : .privateRoom,
                                      roomPublicID: roomID,
                                      startedAt: flightStartedAt ?? Date(),
                                      expectedEndAt: flightExpectedEnd,
                                      isPaused: localPaused,
                                      focusCategory: flightCategory ?? "Focus",
                                      balloonSkinID: profile.balloonSkinID,
                                      soundID: appModel?.selectedJourneyAudio.id)
        let t0 = Date()
        let published = await flightService.ensurePublished(presence)
        syncServerClock(published?.serverNow, since: t0)
        if published != nil {
            publishedSessionID = sessionID
            if let end = published?.expectedEndAt {
                hostCanonicalDeadline = HostDeadline(sessionID: sessionID, deadline: end)
            }
        }
    }

    /// Realtime nudge while an invite is outstanding: if a genuine remote member
    /// has joined the private record, flip to a Private Flight now.
    private func reconcileInviteWatch(roomID: String) async {
        guard socialState == .globalInviteReady, let room = flightRoom, room.id == roomID else { return }
        let members = Self.dedupe(await roomService.participants(roomID: roomID, roomActive: true))
        if members.contains(where: { $0.publicID != myUserID }) {
            activatePrivateFlight(room: room, members: members)
        }
    }

    /// The one-way, sticky transition Global → Private: a real invited pilot has
    /// joined. Remove strangers + decorative, keep only the crew, toast the join,
    /// and leave the public sky. The timer/sky never reload. Stays Private for
    /// the rest of the journey even if every guest later leaves.
    private func activatePrivateFlight(room: FocusRoom, members: [RoomParticipant]) {
        guard socialState != .privateActive else { return }
        socialState = .privateActive
        flightMode = .privateRoom          // isPrivateFlight/roomBubbleMode follow
        flightRoom = room
        activeRoomParticipants = members
        detectJoins(in: members)           // "<alias> joined"
        // Only invited pilots remain visible. Their authoritative rows land on the
        // next poll; until then keep whatever real pilots we already have rather
        // than fabricating a room-wide countdown for them.
        let joining = Set(members.map(\.publicID))
        realPilots = realPilots.filter { joining.contains($0.id) && $0.id != myUserID }
        Task { [weak self] in
            guard let self else { return }
            let others = members.filter { $0.publicID != myUserID }
            let pilots = await self.roomPilots(room: room, participants: others)
            guard self.flightRoom?.id == room.id else { return }
            self.realPilots = pilots
        }
        Task {
            // CONVERT the participant session instead of deleting it. The old
            // `stopPublishing()` here destroyed the one row carrying this pilot's
            // started_at / expected_end_at / paused_at / paused_remaining_seconds
            // at the exact moment the journey became private — which is why pause
            // silently no-opped for the rest of an invited flight. Binding leaves
            // Public Sky discovery (the public RLS branch requires
            // session_kind = 'public') while keeping the authoritative timer.
            await bindSessionToRoom(room.id)
            await realtimeService.leaveSky()
        }
    }

    /// The room's REAL pilots, each backed by their own authoritative
    /// `active_flights` row (own deadline, own pause, own frozen remainder).
    ///
    /// Membership is still the roster of record — a member whose participant row
    /// has not landed yet (or has gone stale) is kept visible using their
    /// membership metadata, but WITHOUT a fabricated countdown: no
    /// `expectedEndAt`, `hasLiveSession: false`, so the UI omits the timer instead
    /// of inventing one. Nothing here is ever marked paused unless the server says
    /// so.
    private func roomPilots(room: FocusRoom, participants: [RoomParticipant]) async -> [OnlinePilot] {
        let live = await flightService.fetchRoomPilots(roomID: room.id, excluding: myUserID)
        let byUser = Dictionary(live.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return participants.map { p in
            if let authoritative = byUser[p.publicID] { return authoritative }
            return OnlinePilot(id: p.publicID, sessionID: p.activeSessionID ?? p.id,
                               displayName: p.displayName, countryCode: p.countryCode,
                               balloonSkinID: p.balloonSkinID, skyID: room.skyID,
                               startedAt: p.joinedAt, expectedEndAt: nil,
                               lastHeartbeatAt: p.lastHeartbeatAt ?? .distantPast,
                               isPaused: false, focusCategory: "",
                               allowsFriendRequest: true,
                               // No authoritative row yet → no fabricated timer.
                               hasLiveSession: false)
        }
    }

    /// Attach this pilot's canonical participant session to `roomID`, repairing it
    /// first if the server has none. Used by BOTH promotion (host) and invite
    /// acceptance (guest), so every real room participant ends up backed by its own
    /// authoritative row — never a synthesized room-wide timer.
    private func bindSessionToRoom(_ roomID: String) async {
        guard let sessionID = flightSessionID else { return }
        if publishedSessionID != sessionID {
            // No confirmed session yet (e.g. a guest who just joined): create one
            // already bound to the room, then we are done.
            await ensureCanonicalSession(sessionID: sessionID, roomID: roomID)
            return
        }
        let t0 = Date()
        if let bound = await flightService.bindToRoom(roomID) {
            syncServerClock(bound.serverNow, since: t0)
            publishedSessionID = sessionID
            #if DEBUG
            SupabaseService.log.debug("online: session associated with private room")
            #endif
        } else {
            // Bind could not run (no live presence) — rebuild it bound to the room.
            await ensureCanonicalSession(sessionID: sessionID, roomID: roomID)
        }
    }

    private func scheduleThrottleReset(until date: Date) {
        throttleResetTask?.cancel()
        throttleResetTask = Task { [weak self] in
            let delay = date.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(min(delay, 3600) * 1_000_000_000))
            }
            guard let self, !Task.isCancelled else { return }
            if let d = OnlineCache.roomCreationRetryAfterDate, d <= Date() {
                OnlineCache.roomCreationRetryAfterDate = nil
            }
            if case .waitingUntil(let d) = self.roomCreationState, d <= Date() {
                self.consecutiveThrottles = 0
                self.roomCreationState = .idle
            }
        }
    }

    private func resetRoomCreation() {
        throttleResetTask?.cancel(); throttleResetTask = nil
        consecutiveThrottles = 0
        roomCreationState = .idle
        OnlineCache.roomCreationRetryAfterDate = nil
    }

    /// The lobby promotes an already-created OWNED room to the pending flight —
    /// keep the authoritative state in sync (never a bare `pendingRoom =`).
    func usePendingRoom(_ room: FocusRoom) {
        pendingRoom = room
        roomCreationState = .ready(room)
    }

    // MARK: Rooms — lifecycle

    func refreshRooms() async {
        guard availability.isAvailable, let myID = myUserID else { return }
        let (owned, joined) = await roomService.myRooms(myID: myID)
        ownedRooms = owned.filter { $0.purpose == .flight }
        joinedRooms = joined
    }

    /// `announceJoins`: when true (realtime reconcile / in-flight poll), a
    /// genuinely NEW non-self member fires a one-shot join toast. When false
    /// (first load on entering a room) the current set is seeded silently so
    /// pre-existing members never toast, and reconnects never re-toast.
    func loadParticipants(of room: FocusRoom, announceJoins: Bool = false) async {
        let fresh = Self.dedupe(await roomService.participants(roomID: room.id, roomActive: room.status == .active))
        if announceJoins { detectJoins(in: fresh) }
        else { knownMemberIDs = Set(fresh.map(\.publicID).filter { $0 != myUserID }) }
        activeRoomParticipants = fresh
    }

    /// One-shot "<alias> joined" toast for genuinely new non-self members.
    private func detectJoins(in participants: [RoomParticipant]) {
        let otherIDs = Set(participants.map(\.publicID).filter { $0 != myUserID })
        let newIDs = otherIDs.subtracting(knownMemberIDs)
        knownMemberIDs = otherIDs
        if let id = newIDs.first,
           let p = participants.first(where: { $0.publicID == id }), !p.displayName.isEmpty {
            joinToastAlias = p.displayName
        }
    }
    func clearJoinToast() { joinToastAlias = nil }

    /// Members other than me — the ONLY basis for a "joined" count. Owner is not
    /// counted as a joined friend; dedupe + self-filter are by UUID.
    var joinedOthers: [RoomParticipant] {
        activeRoomParticipants.filter { $0.publicID != myUserID }
    }
    var joinedOthersCount: Int { joinedOthers.count }

    /// Lobby entry: membership already exists (create/join RPC); heartbeat +
    /// realtime change feed keep the member list and start state live.
    func joinRoom(_ room: FocusRoom) async {
        guard let myID = myUserID else { return }
        lobbyRoomID = room.id
        joinToastAlias = nil
        await roomService.heartbeat(roomID: room.id, myID: myID)
        await loadParticipants(of: room)   // seeds the join-toast baseline silently
        await realtimeService.subscribeRoom(roomID: room.id) { [weak self] in
            Task { @MainActor [weak self] in await self?.reconcileLobby(roomID: room.id) }
        }
    }

    /// Realtime/lobby reconciliation: refresh members (announcing genuine new
    /// joins) and detect the owner's shared start so every member flies together.
    private func reconcileLobby(roomID: String) async {
        guard lobbyRoomID == roomID, let myID = myUserID else { return }
        if let fresh = await roomService.room(id: roomID, myID: myID) {
            if pendingRoom?.id == roomID { pendingRoom = fresh }
            await loadParticipants(of: fresh, announceJoins: true)
            if fresh.status == .active, activeRoomStartedID != roomID {
                activeRoomStartedID = roomID
            }
        }
    }

    func exitLobby() {
        lobbyRoomID = nil
        knownMemberIDs = []
        joinToastAlias = nil
        Task { await realtimeService.unsubscribeRoom() }
    }

    func setReady(_ room: FocusRoom, ready: Bool) async {
        do {
            try await roomService.setReady(roomID: room.id, ready: ready)
        } catch {
            applyOperationError(error)
        }
        await loadParticipants(of: room)
    }

    /// Owner starts the shared flight — server stamps the canonical start.
    func ownerStart(_ room: FocusRoom, durationSeconds: Int?) async {
        guard let myID = myUserID else { return }
        do {
            let started = try await roomService.startRoom(roomID: room.id, myID: myID)
            pendingRoom = started.room
            activeRoomParticipants = started.members
            activeRoomStartedID = started.room.id
            roomCreationState = .ready(started.room)
        } catch {
            applyOperationError(error)
            lastRoomErrorDetail = OnlineError.detail(for: error)
        }
    }

    func leaveRoom(_ room: FocusRoom) async {
        if room.isOwned {
            await roomService.closeRoom(roomID: room.id)
        } else {
            await roomService.leaveRoom(roomID: room.id)
        }
        if pendingRoom?.id == room.id {
            pendingRoom = nil
            if case .ready = roomCreationState { roomCreationState = .idle }
        }
        if lobbyRoomID == room.id { exitLobby() }
        await refreshRooms()
    }

    /// A fresh one-time invite URL for an owned room (tokens are hashed
    /// server-side, so links can't be re-derived after relaunch).
    func freshInvite(for room: FocusRoom) async -> URL? {
        do {
            return try await roomService.freshInviteURL(roomID: room.id)
        } catch {
            applyOperationError(error)
            lastRoomErrorDetail = OnlineError.detail(for: error)
            return nil
        }
    }

    // MARK: Invitations (deep links)

    /// Entry point for `focusglobe://join/<token>` and the future
    /// `https://focusglobe.app/join/<token>` universal link. Opening a link only
    /// PREVIEWS the flight — it never joins.
    func handleIncomingURL(_ url: URL) async {
        guard let token = DeepLinkService.inviteToken(from: url) else { return }
        await refreshAvailability()
        guard availability.isAvailable else {
            // Hold the invitation and explain TRUTHFULLY why it can't open yet.
            // `refreshAvailability()` replays it the moment we reach `.ready`, so
            // the pilot never has to find the link again.
            //
            // This used to say "Sign in to join this private flight" for every
            // non-ready state — including no-internet and reconnecting, which told
            // an already-signed-in pilot to do something they had already done.
            OnlineCache.pendingInviteToken = token
            switch availability {
            case .signedOut, .sessionExpired:
                inviteJoinMessage = "Sign in to join this private flight."
            default:
                inviteJoinMessage = availability.userMessage
            }
            return
        }
        await previewInvite(token: token)
    }

    private func consumePendingInviteIfAny() async {
        guard let token = OnlineCache.pendingInviteToken else { return }
        OnlineCache.pendingInviteToken = nil
        await previewInvite(token: token)
    }

    /// READ-ONLY preview: opening a link never consumes the token, creates
    /// membership, changes the count or toasts. The owner opening their own link
    /// is a silent no-op (they're already flying it).
    func previewInvite(token: String) async {
        guard let myID = myUserID else { return }
        do {
            let t0 = Date()
            let p = try await roomService.previewInvite(token: token, myID: myID)
            syncServerClock(p.serverNow, since: t0)
            inviteJoinMessage = nil
            switch p.status {
            case "owner", "already_member":
                // I'm already flying this (as host or an existing member) — opening
                // my own link is a silent no-op; the flight is already on screen.
                invitePreview = nil
            case "valid":
                guard let room = p.room else {
                    invitePreview = nil
                    inviteJoinMessage = "This invitation isn't available anymore."
                    return
                }
                invitePreview = InvitePreviewState(token: token, room: room, hostAlias: p.hostAlias,
                                                   hostSkin: p.hostSkin, participantCount: p.participantCount)
            default:
                // expired / revoked / ended / full / blocked / invalid — never leak
                // which; a single friendly, non-identifying message.
                invitePreview = nil
                inviteJoinMessage = Self.previewUnavailableMessage(for: p.status)
            }
        } catch {
            applyOperationError(error)
            lastRoomErrorDetail = OnlineError.detail(for: error)
            inviteJoinMessage = OnlineError.map(error).userMessage
            invitePreview = nil
        }
    }

    /// Friendly, non-identifying copy for an unavailable preview status. Blocked
    /// and invalid deliberately share the neutral wording so nothing about the
    /// flight (or the block) is leaked.
    private static func previewUnavailableMessage(for status: String) -> String {
        switch status {
        case "full":    return "This flight is already full."
        case "expired", "revoked":
                        return "This invitation has expired — ask for a new one."
        case "ended":   return "This flight has already landed."
        default:        return "This invitation isn't available anymore."
        }
    }

    /// The ONLY membership-creating call — runs when the guest taps Join Flight.
    /// Atomically accepts + consumes the token server-side and returns the
    /// canonical active flight (fresh ends_at) to launch, or nil on failure.
    func acceptInvitePreview() async -> FocusRoom? {
        guard let myID = myUserID, let preview = invitePreview else { return nil }
        do {
            let t0 = Date()
            let joined = try await roomService.acceptInvite(token: preview.token, myID: myID)
            syncServerClock(joined.serverNow, since: t0)
            activeRoomParticipants = Self.dedupe(joined.members)
            invitePreview = nil
            inviteJoinMessage = nil
            return joined.room
        } catch {
            applyOperationError(error)
            lastRoomErrorDetail = OnlineError.detail(for: error)
            inviteJoinMessage = OnlineError.map(error).userMessage
            invitePreview = nil
            return nil
        }
    }

    /// Guest → dismiss the invitation with NO backend mutation (nothing joined).
    func dismissInvitePreview() { invitePreview = nil }
    func clearInviteJoinMessage() { inviteJoinMessage = nil }

    /// Guest → enter the invited ACTIVE flight. Binds the room + private mode so
    /// the guest's `flightDidStart` wires the shared, synchronized timer. The
    /// caller launches the journey with the room's exact `endsAt` as the deadline.
    func enterInvitedFlight(_ room: FocusRoom) {
        flightMode = .privateRoom
        usePendingRoom(room)
        knownMemberIDs = []
        joinToastAlias = nil
        invitePreview = nil
    }

    /// Whole-minutes remaining until `endsAt` (nil = infinite) — used ONLY for
    /// the flight's symbolic distance/route visuals; the actual countdown is the
    /// exact `sharedEndsAt` deadline, never this rounded value.
    static func inheritedMinutes(until endsAt: Date?) -> (minutes: Int, infinite: Bool) {
        guard let end = endsAt else { return (0, true) }
        let secs = end.timeIntervalSinceNow
        if secs < 30 { return (1, false) }
        return (max(1, Int((secs / 60).rounded())), false)
    }

    // MARK: Crew

    func refreshSocial() async {
        guard availability.isAvailable, let myID = myUserID else { return }
        let (incomingRows, outgoingRows) = await friendService.pendingRequests(myID: myID)
        let counterpartIDs = Set(incomingRows.map(\.senderID) + outgoingRows.map(\.receiverID))
        let requestProfiles = await profileService.fetchProfiles(publicIDs: Array(counterpartIDs))
        func alias(_ id: String) -> (String, String) {
            let p = requestProfiles.first { $0.publicID == id }
            return (p?.displayName ?? "Sky Pilot", p?.balloonSkinID ?? "default")
        }
        incomingRequests = incomingRows.map { row in
            let (name, skin) = alias(row.senderID)
            return FriendRequest(id: row.id, senderPublicID: row.senderID,
                                 recipientPublicID: row.receiverID,
                                 senderDisplayName: name, senderBalloonSkinID: skin,
                                 createdAt: PostgresDate.parse(row.createdAt) ?? Date())
        }
        outgoingRequests = outgoingRows.map { row in
            FriendRequest(id: row.id, senderPublicID: row.senderID,
                          recipientPublicID: row.receiverID,
                          senderDisplayName: profile?.displayName ?? "Me",
                          senderBalloonSkinID: profile?.balloonSkinID ?? "default",
                          createdAt: PostgresDate.parse(row.createdAt) ?? Date())
        }

        let ids = await friendService.friendIDs(myID: myID)
        let profiles = await profileService.fetchProfiles(publicIDs: ids)
        var list: [FocusFriend] = ids.map { id in
            let p = profiles.first { $0.publicID == id }
            return FocusFriend(id: id, publicID: id,
                               displayName: p?.displayName ?? "Sky Pilot",
                               balloonSkinID: p?.balloonSkinID ?? "default",
                               countryCode: p?.countryCode,
                               since: Date(), activePilot: nil)
        }
        // "Focusing now" only from a real fresh flight row (cap the lookups).
        for index in list.indices.prefix(12) {
            list[index].activePilot = await flightService.activeFlight(of: list[index].publicID)
        }
        crew = list.sorted { $0.displayName < $1.displayName }
    }

    /// Returns a friendly, typed result (nil on success) — never the generic
    /// "didn't reach the sky". Self-guarded by auth UUID before any network.
    func sendFriendRequest(to pilot: OnlinePilot) async -> String? {
        guard availability.isAvailable else { return availability.userMessage }
        guard let myID = myUserID else { return OnlineError.notSignedIn.userMessage }
        guard pilot.id != myID else { return "That's you" }
        guard pilot.allowsFriendRequest else { return "This pilot isn't accepting requests." }
        do {
            try await friendService.sendRequest(from: myID, to: pilot.id)
            await refreshSocial()
            return nil
        } catch {
            lastErrorCategory = OnlineError.category(for: error)
            switch OnlineError.serverToken(from: error) {
            case "self":              return "That's you"
            case "blocked":           return "You can't add this pilot."
            case "already_friends":   return "You're already friends."
            case "requests_disabled": return "This pilot isn't accepting requests."
            case "duplicate":         return "Request already sent."
            case "rate_limited":      return OnlineError.rateLimited.userMessage
            default:                  return OnlineError.requestFailed.userMessage
            }
        }
    }

    func respond(to request: FriendRequest, accept: Bool) async {
        do {
            if accept { try await friendService.accept(requestID: request.id) }
            else { try await friendService.decline(requestID: request.id) }
        } catch {
            applyOperationError(error)
        }
        await refreshSocial()
    }

    func cancelRequest(_ request: FriendRequest) async {
        try? await friendService.cancel(requestID: request.id)
        await refreshSocial()
    }

    func removeFriend(_ friend: FocusFriend) async {
        guard let myID = myUserID else { return }
        await friendService.removeFriend(myID: myID, otherID: friend.publicID)
        await refreshSocial()
    }

    /// Block a pilot: hides them both ways, removes the friendship, cancels
    /// pending requests. Returns a friendly error message, or nil on success.
    func blockPilot(_ pilot: OnlinePilot) async -> String? {
        guard availability.isAvailable else { return availability.userMessage }
        do {
            try await moderationService.block(userID: pilot.id)
            realPilots.removeAll { $0.id == pilot.id }
            await refreshSocial()
            return nil
        } catch {
            lastErrorCategory = OnlineError.category(for: error)
            return OnlineError.requestFailed.userMessage
        }
    }

    /// Report a pilot for moderation. Returns a friendly error, or nil.
    func reportPilot(_ pilot: OnlinePilot, reason: String) async -> String? {
        guard availability.isAvailable else { return availability.userMessage }
        do {
            try await moderationService.report(userID: pilot.id, reason: reason)
            return nil
        } catch let error where OnlineError.category(for: error) == "rate-limited" {
            return OnlineError.rateLimited.userMessage
        } catch {
            lastErrorCategory = OnlineError.category(for: error)
            return OnlineError.requestFailed.userMessage
        }
    }

    func requestStatus(for pilotID: String) -> String? {
        if crew.contains(where: { $0.publicID == pilotID }) { return "Crew member" }
        if outgoingRequests.contains(where: { $0.recipientPublicID == pilotID }) { return "Request sent" }
        return nil
    }

    // MARK: Invite-based Sky unlocks (verified joins only)

    /// The campaign room for a locked Sky (created/reused on demand). Its
    /// invite URL is the invitation; only REAL joins count (server-verified).
    func campaignInvitation(for sky: FocusSky) async -> RoomInvitation? {
        await campaignInvitationRoom(skyID: sky.id)
    }

    private func campaignInvitationRoom(skyID: String) async -> RoomInvitation? {
        await refreshAvailability()
        guard availability.isAvailable, let myID = myUserID else { return nil }
        if roomThrottledUntil != nil { return nil }
        do {
            let created = try await roomService.createRoom(skyID: skyID, durationSeconds: nil,
                                                           purpose: .skyUnlock, myID: myID)
            lastRoomErrorDetail = nil
            return RoomInvitation(id: created.room.id, room: created.room, url: created.room.shareURL)
        } catch {
            applyOperationError(error)
            lastRoomErrorDetail = OnlineError.detail(for: error)
            if OnlineError.isThrottled(error) {
                consecutiveThrottles += 1
                let until = OnlineError.throttleRetryDate(for: error, consecutive: consecutiveThrottles)
                    ?? Date().addingTimeInterval(60)
                OnlineCache.roomCreationRetryAfterDate = until
                scheduleThrottleReset(until: until)
            }
            return nil
        }
    }

    /// Recount verified joins for a Sky's campaign and cache the result.
    /// Server-computed: distinct accounts that genuinely joined (owner
    /// excluded) — never link opens or share-sheet taps.
    func refreshCampaignProgress(skyID: String, required: Int) async {
        guard availability.isAvailable else { return }
        guard let count = await roomService.campaignProgress(skyID: skyID) else { return }
        var progress = OnlineCache.campaignProgress
        progress[skyID] = count
        OnlineCache.campaignProgress = progress
        if required > 0, count >= required {
            appModel?.unlockSkyFromVerifiedInvites(skyID: skyID)
        }
        objectWillChange.send()
    }

    /// Cached verified acceptance count.
    func campaignProgress(skyID: String) -> Int {
        OnlineCache.campaignProgress[skyID] ?? 0
    }

    // MARK: Delete online data

    func deleteOnlineData() async {
        await flightService.stopPublishing()
        await realtimeService.teardown()
        try? await profileService.deleteAllOnlineData()
        resetSocialState()
        // Left EXPLICITLY false, not reset to nil. Someone who just deleted
        // their online data has made a privacy decision; letting the default
        // put them back in Public Skies on next use would quietly undo it.
        appModel?.profile.onlineDiscoverable = false
        // Account session survives — the profile is recreated on next use.
        await refreshAvailability()
    }

    // MARK: Diagnostics helpers (DEBUG screen reads these)

    var shortPublicID: String { String((myUserID ?? "—").prefix(8)) }
    var realPilotCount: Int { realPilots.count }

    #if DEBUG
    /// DEBUG-only: close all my open rooms and reset the creation pipeline.
    func debugPurgeOwnedRooms() async -> Int {
        guard let myID = myUserID else { return 0 }
        let (owned, _) = await roomService.myRooms(myID: myID)
        for room in owned { await roomService.closeRoom(roomID: room.id) }
        pendingRoom = nil
        resetRoomCreation()
        await refreshRooms()
        return owned.count
    }
    #endif
}
