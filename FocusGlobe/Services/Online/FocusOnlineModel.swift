import Foundation
import SwiftUI
import CloudKit
import OSLog

/// A friendly, Release-safe reason a private room couldn't be created (never a
/// raw `CKError` — that stays in DEBUG diagnostics / OSLog).
struct RoomCreationFailure: Equatable, Sendable {
    let message: String
}

/// The ONE authoritative state for private-room creation. Every online surface
/// (flight selector, invite sheet, Friends) reads this — never a cached boolean
/// and never the selected flight mode — so "Private room ready" can only ever
/// appear when a room truly exists with a live CKShare URL.
enum RoomCreationState: Equatable {
    case idle                       // nothing created yet
    case creating                   // a single create operation is in flight
    case waitingUntil(Date)         // CloudKit throttle/quota — retry-after window
    case ready(FocusRoom)           // saved record + saved CKShare + non-nil url
    case failed(RoomCreationFailure)
}

/// **FocusGlobe Online** — the single @MainActor coordinator between the UI and
/// the CloudKit service actors. Views never touch CloudKit directly; Solo
/// flights never touch this class's network paths. Every failure degrades to a
/// friendly state and never blocks the local timer or coins.
@MainActor
final class FocusOnlineModel: ObservableObject {

    // MARK: Published state

    @Published private(set) var availability: CloudAvailability = .checking
    @Published private(set) var identity: FocusIdentity?
    @Published private(set) var profile: OnlineProfile?

    /// The mode selected in the pre-flight ritual (persisted last choice).
    @Published var flightMode: OnlineFlightMode = OnlineCache.lastFlightMode {
        didSet { OnlineCache.lastFlightMode = flightMode }
    }
    /// The private room chosen/created for the NEXT flight (privateRoom mode).
    @Published var pendingRoom: FocusRoom?

    /// The ONE authoritative private-room creation state. Flight selector, invite
    /// sheet and Friends all read this — never a cached bool or the flight mode —
    /// so "Private room ready" appears only for a real room with a live CKShare.
    @Published private(set) var roomCreationState: RoomCreationState = .idle

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
    /// The full one-line breakdown of the most recent room-creation failure
    /// (exact CKError code + description + underlying/partial errors). DEBUG
    /// diagnostics only — never shown as Release UI copy.
    @Published private(set) var lastRoomErrorDetail: String?

    // MARK: Services

    private let environment = CloudKitEnvironment()
    private let identityService = CloudIdentityService()
    private let profileService = PublicProfileService()
    private let presenceService = PresenceService()
    private let friendService = FriendService()
    private let roomService = FocusRoomService()
    private let notificationService = OnlineNotificationService()

    private weak var appModel: AppModel?
    private var pilotPollTask: Task<Void, Never>?
    private var accountObserver: NSObjectProtocol?

    // Room-creation pipeline (single-flight + throttle-aware).
    /// The in-flight create operation, if any — guarantees ONE create at a time
    /// and lets concurrent callers await the same result (no duplicate writes,
    /// no duplicate room IDs).
    private var roomCreateTask: Task<FocusRoom?, Never>?
    /// Reused across retries of a failed attempt so one user action can't spawn
    /// many room IDs; cleared on success or a terminal (non-throttle) failure.
    private var pendingAttemptRoomID: String?
    /// Auto-clears `.waitingUntil` back to `.idle` when the retry window elapses.
    private var throttleResetTask: Task<Void, Never>?
    /// How many throttles in a row (drives backoff when no retryAfter is given).
    private var consecutiveThrottles = 0

    // Friend-bonus overlap tracking for the CURRENT flight.
    private var flightSessionID: String?
    private var flightRoom: FocusRoom?
    private var overlapSeconds: Double = 0
    private var lastOverlapSample: Date?
    /// Verified overlap needed for the friend bonus (≥ 5 focused minutes).
    static let friendBonusOverlap: Double = 300

    nonisolated init() {}

    // MARK: Bootstrap / availability

    func bootstrap(appModel: AppModel) {
        self.appModel = appModel
        identity = OnlineCache.loadIdentity()
        profile = OnlineCache.loadProfile()
        // Restore any live CloudKit throttle window so we don't hammer the
        // server on launch and the countdown survives a relaunch.
        if let retry = OnlineCache.roomCreationRetryAfterDate, retry > Date() {
            roomCreationState = .waitingUntil(retry)
            scheduleThrottleReset(until: retry)
        } else {
            OnlineCache.roomCreationRetryAfterDate = nil
        }
        if accountObserver == nil {
            accountObserver = NotificationCenter.default.addObserver(
                forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
                Task { await self?.handleAccountChange() }
            }
        }
        Task { await refreshAvailability() }
    }

    func refreshAvailability() async {
        availability = await environment.currentAvailability()
        OnlineCache.lastOnlineStatus = availability.userMessage
        if availability.isAvailable, identity == nil || profile == nil {
            await ensureIdentityAndProfile()
        }
    }

    /// The ONE authoritative reaction to a failed CloudKit operation. Account
    /// status alone can read `.available` from cache even with no network, so a
    /// genuine network failure only surfaces when an actual op fails — this
    /// flips the single `availability` state so EVERY online surface agrees
    /// (no more "Live" here + "You're offline" there). Non-network CloudKit
    /// errors keep `.available`; the caller shows a retry, never "offline".
    private func applyOperationError(_ error: Error) {
        let category = OnlineError.category(for: error)
        lastErrorCategory = category
        switch category {
        case "network":    availability = .networkUnavailable
        case "no-account": availability = .noAccount
        default:           break
        }
    }

    private func handleAccountChange() async {
        // Never mix two iCloud identities: clear cached social data, keep local
        // app progress, and rebuild identity from the new account.
        OnlineCache.resetForAccountChange()
        identity = nil
        profile = nil
        crew = []
        incomingRequests = []
        outgoingRequests = []
        ownedRooms = []
        joinedRooms = []
        realPilots = []
        pendingRoom = nil
        resetRoomCreation()
        await refreshAvailability()
    }

    /// Fetch-or-create identity + public profile. Safe to call repeatedly.
    func ensureIdentityAndProfile() async {
        guard availability.isAvailable else { return }
        do {
            let id = try await identityService.ensureIdentity()
            identity = id
            OnlineCache.save(identity: id)
            var current = profile ?? OnlineProfile(
                publicID: id.publicID,
                displayName: id.anonymousHandle,
                balloonSkinID: appModel?.equippedSkinIDForOnline ?? "default",
                countryCode: Locale.current.region?.identifier,
                isDiscoverable: appModel?.profile.onlineDiscoverable ?? false,
                allowsFriendRequests: appModel?.profile.onlineAllowsFriendRequests ?? true,
                createdAt: Date(), updatedAt: Date())
            current.balloonSkinID = appModel?.equippedSkinIDForOnline ?? current.balloonSkinID
            try await profileService.upsertProfile(current)
            profile = current
            OnlineCache.save(profile: current)
            await presenceService.configure(publicID: current.publicID,
                                            displayName: current.displayName,
                                            countryCode: current.countryCode,
                                            acceptsInvites: current.allowsFriendRequests)
            await notificationService.installSubscriptions(publicID: current.publicID)
        } catch {
            lastErrorCategory = OnlineError.category(for: error)
        }
    }

    // MARK: Settings controls

    func setDiscoverable(_ on: Bool) {
        appModel?.profile.onlineDiscoverable = on
        guard var p = profile else { return }
        p.isDiscoverable = on
        profile = p
        OnlineCache.save(profile: p)
        Task {
            try? await profileService.upsertProfile(p)
            if !on { await presenceService.stopPublishing() }
        }
    }

    func setAllowsFriendRequests(_ on: Bool) {
        appModel?.profile.onlineAllowsFriendRequests = on
        guard var p = profile else { return }
        p.allowsFriendRequests = on
        profile = p
        OnlineCache.save(profile: p)
        Task { try? await profileService.upsertProfile(p) }
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
        do {
            try await identityService.updateAlias(alias)
            identity?.anonymousHandle = alias
            if var p = profile {
                p.displayName = alias
                try await profileService.upsertProfile(p)
                profile = p
                OnlineCache.save(profile: p)
            }
            if let id = identity { OnlineCache.save(identity: id) }
            OnlineCache.aliasLastChangedAt = Date()
            return nil
        } catch {
            lastErrorCategory = OnlineError.category(for: error)
            return OnlineError.requestFailed.userMessage
        }
    }

    // MARK: Flight lifecycle (called from AppModel hooks — never blocks Solo)

    func flightDidStart(skyID: String, sessionID: String, expectedEndAt: Date?, category: String) {
        guard flightMode.isOnline, availability.isAvailable, let profile else { return }
        flightSessionID = sessionID
        flightRoom = flightMode == .privateRoom ? pendingRoom : nil
        overlapSeconds = 0
        lastOverlapSample = Date()
        let presence = OnlinePresence(sessionID: sessionID, skyID: skyID,
                                      mode: flightMode,
                                      roomPublicID: flightRoom?.id,
                                      startedAt: Date(), expectedEndAt: expectedEndAt,
                                      isPaused: false, focusCategory: category,
                                      balloonSkinID: profile.balloonSkinID)
        Task {
            // Public presence only for publicSky (room membership stays in
            // private/shared records; a room flight isn't broadcast publicly).
            if flightMode == .publicSky, appModel?.profile.onlineDiscoverable ?? false {
                await presenceService.startPublishing(presence)
            }
            if let room = flightRoom {
                await roomService.markFlying(room, profile: profile, sessionID: sessionID)
            }
        }
        startPilotPolling(skyID: skyID)
    }

    func flightPauseChanged(isPaused: Bool) {
        guard flightMode.isOnline else { return }
        Task { await presenceService.setPaused(isPaused) }
        if isPaused { sampleOverlap(activeOthers: 0) } else { lastOverlapSample = Date() }
    }

    func flightDidEnd(sessionID: String) {
        guard flightSessionID == sessionID else { return }
        pilotPollTask?.cancel()
        pilotPollTask = nil
        let room = flightRoom
        flightRoom = nil
        flightSessionID = nil
        realPilots = []
        reconnecting = false
        Task {
            await presenceService.stopPublishing()
            if let room, let profile { await roomService.setReady(room, profile: profile, ready: false) }
        }
    }

    func appDidEnterForeground() {
        Task {
            await refreshAvailability()
            await presenceService.heartbeatNow()
        }
    }

    // MARK: Pilot polling (online flights; ~35 s, never per-frame)

    private func startPilotPolling(skyID: String) {
        pilotPollTask?.cancel()
        pilotPollTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.pollOnce(skyID: skyID)
                try? await Task.sleep(nanoseconds: UInt64(CloudKitConfig.publicRefreshInterval * 1_000_000_000))
            }
        }
    }

    private func pollOnce(skyID: String) async {
        guard flightMode.isOnline else { return }
        let me = profile?.publicID
        if flightMode == .publicSky {
            let pilots = await presenceService.fetchPilots(skyID: skyID, excluding: me)
            realPilots = pilots
            reconnecting = pilots.isEmpty && !availability.isAvailable
        } else if let room = flightRoom {
            let participants = await roomService.participants(of: room)
            let others = participants.filter { $0.publicID != me }
            realPilots = others.map { p in
                OnlinePilot(id: p.publicID, sessionID: p.activeSessionID ?? p.id,
                            displayName: p.displayName, countryCode: p.countryCode,
                            balloonSkinID: p.balloonSkinID, skyID: room.skyID,
                            startedAt: p.joinedAt, expectedEndAt: nil,
                            lastHeartbeatAt: p.lastHeartbeatAt ?? .distantPast,
                            isPaused: false, focusCategory: "Focus",
                            allowsFriendRequest: true)
            }
            // Verified friend-flight overlap: another participant actively
            // flying with a fresh heartbeat.
            let activeOthers = others.filter {
                $0.status == .flying &&
                ($0.lastHeartbeatAt.map { Date().timeIntervalSince($0) < CloudKitConfig.presenceStaleInterval } ?? false)
            }.count
            sampleOverlap(activeOthers: activeOthers)
            if let profile, let sessionID = flightSessionID {
                await roomService.markFlying(room, profile: profile, sessionID: sessionID)
            }
        }
        lastPilotFetchAt = Date()
        await refreshAvailabilityQuietly()
    }

    private func refreshAvailabilityQuietly() async {
        let status = await environment.currentAvailability()
        if status != availability { availability = status }
        reconnecting = flightMode.isOnline && !status.isAvailable
    }

    private func sampleOverlap(activeOthers: Int) {
        let now = Date()
        if let last = lastOverlapSample, activeOthers > 0 {
            overlapSeconds += now.timeIntervalSince(last)
        }
        lastOverlapSample = now
    }

    /// True once for a verified friend flight (≥5 min real overlap in a private
    /// room). Decorative pilots and public strangers never qualify.
    func friendBonusEligible(sessionID: String) -> Bool {
        flightMode == .privateRoom
            && flightRoom != nil
            && flightSessionID == sessionID
            && overlapSeconds >= Self.friendBonusOverlap
    }

    // MARK: Rooms

    /// Back-compat entry (CreateRoomView etc.): create a private flight room and
    /// return an invitation. Routes through the single-flight state machine so
    /// every surface stays consistent and two creates never race.
    @discardableResult
    func createRoom(skyID: String, title: String, purpose: FocusRoom.Purpose = .flight) async -> RoomInvitation? {
        guard let room = await requestPrivateFlightRoom(skyID: skyID, title: title) else { return nil }
        return RoomInvitation(id: room.id, room: room, url: room.shareURL)
    }

    /// The `Date` until which any room-creating write must wait (nil if clear).
    /// Reads the authoritative state first, then the persisted window.
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
    /// that promotes a room to `.ready`/`pendingRoom`, and only with a real saved
    /// CKShare URL. Repeated calls while `.creating` join the in-flight attempt;
    /// calls during a throttle window do nothing (the UI shows the countdown).
    @discardableResult
    func requestPrivateFlightRoom(skyID: String, title: String = "FocusGlobe Flight") async -> FocusRoom? {
        if case .ready(let room) = roomCreationState { return room }   // reuse existing
        if roomThrottledUntil != nil { return nil }                    // throttled → no write
        if let task = roomCreateTask { return await task.value }       // join in-flight attempt
        let task = Task { [weak self] () -> FocusRoom? in
            guard let self else { return nil }
            return await self.performRoomCreation(skyID: skyID, title: title)
        }
        roomCreateTask = task
        let result = await task.value
        roomCreateTask = nil
        return result
    }

    private func performRoomCreation(skyID: String, title: String) async -> FocusRoom? {
        await refreshAvailability()
        guard availability.isAvailable else {
            roomCreationState = .failed(RoomCreationFailure(message: availability.userMessage))
            return nil
        }
        await ensureIdentityAndProfile()
        guard let profile else {
            roomCreationState = .failed(RoomCreationFailure(message: OnlineError.notSignedIn.userMessage))
            return nil
        }
        // Re-check the throttle after the awaits above (state may have changed).
        if let until = roomThrottledUntil {
            roomCreationState = .waitingUntil(until)
            return nil
        }
        roomCreationState = .creating
        // Reuse the same room ID across retries of a failed attempt (an atomic
        // save that failed left nothing on the server) — one user action, one ID.
        let attemptID = pendingAttemptRoomID ?? UUID().uuidString
        pendingAttemptRoomID = attemptID
        do {
            let room = try await roomService.createRoom(reusingRoomID: attemptID, title: title,
                                                        skyID: skyID, owner: profile, purpose: .flight)
            guard room.shareURL != nil else {
                lastRoomErrorDetail = "room saved without a share URL (share.url==nil)"
                lastErrorCategory = "share-url-missing"
                pendingAttemptRoomID = nil
                roomCreationState = .failed(RoomCreationFailure(message: "Private room unavailable"))
                return nil
            }
            // Success — clear all throttle/attempt bookkeeping and go ready.
            consecutiveThrottles = 0
            pendingAttemptRoomID = nil
            lastRoomErrorDetail = nil
            OnlineCache.roomCreationRetryAfterDate = nil
            throttleResetTask?.cancel()
            pendingRoom = room
            roomCreationState = .ready(room)
            await refreshRooms()
            return room
        } catch {
            applyOperationError(error)
            lastRoomErrorDetail = OnlineError.detail(for: error)
            if OnlineError.isThrottled(error) {
                // CloudKit quota / rate limit: honour retry-after, block further
                // writes until it elapses, and KEEP the attempt ID so a later
                // retry reuses it instead of minting a new room ID. This is the
                // exact fix for the observed quotaExceeded (retryAfter≈318s).
                consecutiveThrottles += 1
                let until = OnlineError.throttleRetryDate(for: error, consecutive: consecutiveThrottles)
                    ?? Date().addingTimeInterval(300)
                OnlineCache.roomCreationRetryAfterDate = until
                roomCreationState = .waitingUntil(until)
                scheduleThrottleReset(until: until)
            } else {
                pendingAttemptRoomID = nil
                roomCreationState = .failed(RoomCreationFailure(message: friendlyMessage(for: error)))
            }
            return nil
        }
    }

    /// Human-friendly, Release-safe copy for a room-creation failure.
    private func friendlyMessage(for error: Error) -> String {
        switch OnlineError.category(for: error) {
        case "no-account": return OnlineError.notSignedIn.userMessage
        case "network":    return "You're offline right now."
        case "quota":      return "CloudKit is temporarily busy."
        default:           return OnlineError.requestFailed.userMessage
        }
    }

    /// Auto-return `.waitingUntil` to `.idle` when the retry window elapses, so
    /// the create button re-enables itself without a manual refresh.
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
                // Fresh idle episode — drop the reused attempt ID and backoff count.
                self.pendingAttemptRoomID = nil
                self.consecutiveThrottles = 0
                self.roomCreationState = .idle
            }
        }
    }

    /// Reset the creation pipeline (account change / data delete / room closed).
    private func resetRoomCreation() {
        throttleResetTask?.cancel(); throttleResetTask = nil
        pendingAttemptRoomID = nil
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

    func refreshRooms() async {
        guard availability.isAvailable else { return }
        ownedRooms = await roomService.ownedRooms().filter { $0.purpose == .flight }
        joinedRooms = await roomService.joinedRooms()
    }

    func loadParticipants(of room: FocusRoom) async {
        activeRoomParticipants = await roomService.participants(of: room)
    }

    func joinRoom(_ room: FocusRoom) async {
        guard let profile else { return }
        try? await roomService.joinRoom(room, profile: profile)
        await loadParticipants(of: room)
    }

    func setReady(_ room: FocusRoom, ready: Bool) async {
        guard let profile else { return }
        await roomService.setReady(room, profile: profile, ready: ready)
        await loadParticipants(of: room)
    }

    func ownerStart(_ room: FocusRoom, durationSeconds: Int?) async {
        try? await roomService.startRoom(room, durationSeconds: durationSeconds)
        pendingRoom?.status = .active
    }

    func leaveRoom(_ room: FocusRoom) async {
        guard let profile else { return }
        if room.isOwned {
            await roomService.closeRoom(room)
        } else {
            await roomService.leaveRoom(room, publicID: profile.publicID)
        }
        if pendingRoom?.id == room.id {
            pendingRoom = nil
            // The pending/ready room is gone — return the pipeline to idle so the
            // selector offers "Create a Private Flight" again (leave any active
            // throttle window untouched).
            if case .ready = roomCreationState { roomCreationState = .idle }
        }
        await refreshRooms()
    }

    func shareURL(for room: FocusRoom) async -> URL? {
        await roomService.shareURL(for: room) ?? room.shareURL
    }

    /// The room's live CKShare (owner only) — feeds the system sharing UI,
    /// which also handles participant management (remove / stop sharing).
    func share(for room: FocusRoom) async -> CKShare? {
        await roomService.share(for: room)
    }

    /// Explicitly invite a picked contact as a private CKShare participant.
    /// Returns a friendly error message, or nil on success. The email/phone is
    /// used once for the CloudKit lookup and never stored.
    func addRoomParticipant(_ room: FocusRoom, email: String?, phone: String?) async -> String? {
        do {
            try await roomService.addParticipant(to: room, email: email, phone: phone)
            return nil
        } catch {
            lastErrorCategory = OnlineError.category(for: error)
            return "That contact couldn't be added directly — use the invite sheet instead."
        }
    }

    /// A CKShare invitation was accepted (app-delegate hook).
    func handleAcceptedShare(_ metadata: CKShare.Metadata) async {
        do {
            try await roomService.acceptShare(metadata: metadata)
            await ensureIdentityAndProfile()
            await refreshRooms()
            // Join every newly visible room we haven't joined (writes our own
            // participant record so the owner sees a REAL acceptance).
            guard let profile else { return }
            for room in joinedRooms {
                let participants = await roomService.participants(of: room)
                if !participants.contains(where: { $0.publicID == profile.publicID }) {
                    try? await roomService.joinRoom(room, profile: profile)
                }
            }
        } catch {
            lastErrorCategory = OnlineError.category(for: error)
        }
    }

    // MARK: Crew

    func refreshSocial() async {
        guard availability.isAvailable, let me = profile else { return }
        // Incoming requests are creator-verified; answering never touches the
        // sender's record. Outgoing resolution mirrors accepted responses into
        // MY private CrewMember records (each side owns its own membership).
        incomingRequests = await friendService.incomingRequests(for: me.publicID)
        outgoingRequests = await friendService.outgoingPendingRequests(for: me.publicID)
        var list = await friendService.crewMembers()
        let profiles = await profileService.fetchProfiles(publicIDs: list.map(\.publicID))
        for index in list.indices {
            if let p = profiles.first(where: { $0.publicID == list[index].publicID }) {
                list[index].displayName = p.displayName
                list[index].balloonSkinID = p.balloonSkinID
                list[index].countryCode = p.countryCode
            }
            // "Focusing now" only from a real fresh presence record.
            if let record = try? await CloudKitConfig.container.publicCloudDatabase
                .record(for: CKRecord.ID(recordName: list[index].publicID)),
               let pilot = PresenceService.pilot(from: record), !pilot.isStale {
                list[index].activePilot = pilot
            }
        }
        crew = list.sorted { $0.displayName < $1.displayName }
    }

    func sendFriendRequest(to pilot: OnlinePilot) async -> String? {
        guard availability.isAvailable else { return availability.userMessage }
        await ensureIdentityAndProfile()
        guard let me = profile else { return OnlineError.notSignedIn.userMessage }
        do {
            try await friendService.sendRequest(from: me, to: pilot)
            await refreshSocial()
            return nil
        } catch let error as OnlineError {
            return error.userMessage
        } catch {
            lastErrorCategory = OnlineError.category(for: error)
            return OnlineError.requestFailed.userMessage
        }
    }

    func respond(to request: FriendRequest, accept: Bool) async {
        guard let me = profile else { return }
        try? await friendService.respond(to: request, accept: accept, me: me)
        await refreshSocial()
    }

    func cancelRequest(_ request: FriendRequest) async {
        guard let me = profile else { return }
        try? await friendService.cancelRequest(request, me: me)
        await refreshSocial()
    }

    func removeFriend(_ friend: FocusFriend) async {
        // Deletes MY OWN private CrewMember record only — never the other
        // pilot's records.
        await friendService.removeCrew(otherPublicID: friend.publicID)
        await refreshSocial()
    }

    /// Report a pilot for moderation. Reporter-owned; anonymous data only.
    /// Returns a friendly error message, or nil on success.
    func reportPilot(_ pilot: OnlinePilot, reason: String) async -> String? {
        guard availability.isAvailable else { return availability.userMessage }
        await ensureIdentityAndProfile()
        guard let me = profile else { return OnlineError.notSignedIn.userMessage }
        do {
            try await friendService.reportPilot(reporter: me, reportedPublicID: pilot.id,
                                                reportedSessionID: pilot.sessionID, reason: reason)
            return nil
        } catch let error as OnlineError {
            return error.userMessage
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

    // MARK: Invite-based Sky unlocks (verified acceptances only)

    /// The campaign room for a locked Sky (created on demand). Its CKShare URL
    /// is the invitation; only ACCEPTED unique participants count.
    func campaignInvitation(for sky: FocusSky) async -> RoomInvitation? {
        await refreshAvailability()
        guard availability.isAvailable else { return nil }
        await ensureIdentityAndProfile()
        guard let profile else { return nil }
        let all = await roomService.ownedRooms()
        if let existing = all.first(where: { $0.purpose == .skyUnlock && $0.skyID == sky.id }) {
            let url = await roomService.shareURL(for: existing)
            return RoomInvitation(id: existing.id, room: existing, url: url)
        }
        // Respect the account-wide CloudKit throttle window — never create a new
        // campaign room while quota-limited (same quota that room flights hit).
        if roomThrottledUntil != nil { return nil }
        do {
            let room = try await roomService.createRoom(title: "Fly \(sky.name) with me",
                                                        skyID: sky.id, owner: profile,
                                                        purpose: .skyUnlock)
            guard room.shareURL != nil else {
                lastRoomErrorDetail = "campaign room saved without a share URL (share.url==nil)"
                lastErrorCategory = "share-url-missing"
                return nil
            }
            lastRoomErrorDetail = nil
            return RoomInvitation(id: room.id, room: room, url: room.shareURL)
        } catch {
            applyOperationError(error)
            lastRoomErrorDetail = OnlineError.detail(for: error)
            if OnlineError.isThrottled(error) {
                consecutiveThrottles += 1
                let until = OnlineError.throttleRetryDate(for: error, consecutive: consecutiveThrottles)
                    ?? Date().addingTimeInterval(300)
                OnlineCache.roomCreationRetryAfterDate = until
                scheduleThrottleReset(until: until)
            }
            return nil
        }
    }

    /// Recount verified acceptances for a Sky's campaign and cache the result.
    /// Counts ONLY explicitly invited CKShare participants who actually
    /// accepted, deduplicated by their stable CloudKit user record ID (owner
    /// excluded by role) — never link opens, share-sheet taps, display names
    /// or self-written participant records.
    func refreshCampaignProgress(skyID: String, required: Int) async {
        guard availability.isAvailable, let me = profile else { return }
        let rooms = await roomService.ownedRooms().filter { $0.purpose == .skyUnlock && $0.skyID == skyID }
        var unique = Set<String>()
        for room in rooms {
            for stableID in await roomService.acceptedShareParticipantIDs(for: room) {
                unique.insert(stableID)
            }
        }
        var progress = OnlineCache.campaignProgress
        progress[skyID] = unique.count
        OnlineCache.campaignProgress = progress
        await friendService.recordCampaignProgress(skyID: skyID, ownerPublicID: me.publicID,
                                                   acceptedUniquePublicIDs: Array(unique),
                                                   required: required)
        if required > 0, unique.count >= required {
            appModel?.unlockSkyFromVerifiedInvites(skyID: skyID)
        }
        objectWillChange.send()
    }

    /// Cached verified acceptance count (synchronised across devices).
    func campaignProgress(skyID: String) -> Int {
        OnlineCache.campaignProgress[skyID] ?? 0
    }

    // MARK: Remote notifications

    nonisolated func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        guard let kind = OnlineNotificationService.kind(of: userInfo) else { return }
        Task { @MainActor in
            switch kind {
            case .friends: await refreshSocial()
            case .rooms:   await refreshRooms()
            }
        }
    }

    // MARK: Delete online data

    func deleteOnlineData() async {
        let publicID = profile?.publicID ?? identity?.publicID
        await presenceService.stopPublishing()
        if let publicID {
            await profileService.deleteProfile(publicID: publicID)
            await notificationService.removeSubscriptions(publicID: publicID)
            // Each deletion below removes ONLY records this account owns.
            for request in outgoingRequests { try? await friendService.cancelRequest(request, me: profile ?? OnlineProfile(publicID: publicID, displayName: "", balloonSkinID: "", countryCode: nil, isDiscoverable: false, allowsFriendRequests: false, createdAt: Date(), updatedAt: Date())) }
            await friendService.deleteMyResponses(me: publicID)
            await friendService.deleteAllCrew()
        }
        for room in await roomService.ownedRooms() { await roomService.closeRoom(room) }
        for room in joinedRooms { if let publicID { await roomService.leaveRoom(room, publicID: publicID) } }
        _ = try? await CloudKitConfig.container.privateCloudDatabase
            .deleteRecord(withID: CKRecord.ID(recordName: "current-user-identity"))
        OnlineCache.resetForAccountChange()
        identity = nil
        profile = nil
        crew = []
        incomingRequests = []
        outgoingRequests = []
        ownedRooms = []
        joinedRooms = []
        realPilots = []
        pendingRoom = nil
        resetRoomCreation()
        appModel?.profile.onlineDiscoverable = false
    }

    // MARK: Diagnostics helpers (DEBUG screen reads these)

    var shortPublicID: String { String((profile?.publicID ?? "—").prefix(8)) }
    var realPilotCount: Int { realPilots.count }

    #if DEBUG
    /// DEBUG-only: delete this account's owned rooms (clears orphaned test rooms
    /// left by earlier attempts) and reset the creation pipeline. Never touches
    /// joined rooms or other users' records. Returns the count deleted.
    func debugPurgeOwnedRooms() async -> Int {
        let deleted = await roomService.deleteOwnedRooms()
        pendingRoom = nil
        resetRoomCreation()
        await refreshRooms()
        return deleted
    }
    #endif
}
