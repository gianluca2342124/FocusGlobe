import Foundation
import SwiftUI
import CloudKit
import OSLog

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

    func createRoom(skyID: String, title: String, purpose: FocusRoom.Purpose = .flight) async -> RoomInvitation? {
        guard availability.isAvailable else { return nil }
        await ensureIdentityAndProfile()
        guard let profile else { return nil }
        do {
            let room = try await roomService.createRoom(title: title, skyID: skyID,
                                                        owner: profile, purpose: purpose)
            if purpose == .flight { pendingRoom = room }
            await refreshRooms()
            return RoomInvitation(id: room.id, room: room, url: room.shareURL)
        } catch {
            lastErrorCategory = OnlineError.category(for: error)
            return nil
        }
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
        if pendingRoom?.id == room.id { pendingRoom = nil }
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
        guard availability.isAvailable else { return nil }
        await ensureIdentityAndProfile()
        guard let profile else { return nil }
        let all = await roomService.ownedRooms()
        if let existing = all.first(where: { $0.purpose == .skyUnlock && $0.skyID == sky.id }) {
            let url = await roomService.shareURL(for: existing)
            return RoomInvitation(id: existing.id, room: existing, url: url)
        }
        do {
            let room = try await roomService.createRoom(title: "Fly \(sky.name) with me",
                                                        skyID: sky.id, owner: profile,
                                                        purpose: .skyUnlock)
            return RoomInvitation(id: room.id, room: room, url: room.shareURL)
        } catch {
            lastErrorCategory = OnlineError.category(for: error)
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
        appModel?.profile.onlineDiscoverable = false
    }

    // MARK: Diagnostics helpers (DEBUG screen reads these)

    var shortPublicID: String { String((profile?.publicID ?? "—").prefix(8)) }
    var realPilotCount: Int { realPilots.count }
}
