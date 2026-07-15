import Foundation
import CloudKit
import OSLog

/// Private focus rooms via CKShare: the room root lives in the owner's private
/// custom zone; invitees accept the share URL and read/write through the
/// shared database. Rooms carry a purpose — a shared flight, or a Sky-unlock
/// invitation campaign.
actor FocusRoomService {
    /// The EXACT CloudKit failure for room creation goes here (Console.app,
    /// subsystem `com.focusglobe.app`, category `online`) — never a generic
    /// message. Includes CKError code name + raw value, localizedDescription,
    /// underlying NSError, server message, and every partial error, plus the
    /// operation, record type, database, zone and container.
    static let log = Logger(subsystem: "com.focusglobe.app", category: "online")

    private var container: CKContainer { CloudKitConfig.container }
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var sharedDB: CKDatabase { container.sharedCloudDatabase }
    private var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: CloudKitConfig.roomsZoneName, ownerName: CKCurrentUserDefaultName)
    }
    private var zoneReady = false

    private func ensureZone() async throws {
        guard !zoneReady else { return }
        let zone = CKRecordZone(zoneID: zoneID)
        _ = try await privateDB.save(zone)
        zoneReady = true
    }

    // MARK: Create + share

    /// Create a room and its CKShare atomically; returns the room with its
    /// invitation URL. The share link carries access (no insecure room codes).
    ///
    /// Contract for requirement #2 (no false "Ready"): this NEVER returns a room
    /// unless the CKRecord saved, the CKShare saved, AND the saved share carries
    /// a non-nil `url`. Any failure throws — with the EXACT CloudKit error logged
    /// (requirement #1) — so the caller can never promote a half-created room to
    /// the invite-ready state.
    func createRoom(title: String, skyID: String, owner: OnlineProfile,
                    purpose: FocusRoom.Purpose) async throws -> FocusRoom {
        let roomID = UUID().uuidString
        let recordID = CKRecord.ID(recordName: "room-\(roomID)", zoneID: zoneID)
        do {
            try await ensureZone()
            let root = CKRecord(recordType: CloudKitConfig.RecordType.room, recordID: recordID)
            root["roomPublicID"] = roomID as CKRecordValue
            root["ownerPublicID"] = owner.publicID as CKRecordValue
            root["title"] = title as CKRecordValue
            root["skyID"] = skyID as CKRecordValue
            root["createdAt"] = Date() as CKRecordValue
            root["expiresAt"] = Date().addingTimeInterval(7 * 24 * 3600) as CKRecordValue
            root["maximumParticipants"] = Int64(FocusRoom.participantLimit) as CKRecordValue
            root["status"] = FocusRoom.Status.lobby.rawValue as CKRecordValue
            root["allowsLateJoin"] = 1 as CKRecordValue
            root["requiresReadyState"] = 0 as CKRecordValue
            root["purpose"] = purpose.rawValue as CKRecordValue
            root["schemaVersion"] = 1 as CKRecordValue

            let share = CKShare(rootRecord: root)
            share[CKShare.SystemFieldKey.title] = "FocusGlobe Flight" as CKRecordValue
            // PRIVATE rooms are private: no public permission on the share. Only
            // explicitly invited CKShare participants (added via the system
            // sharing UI or a resolved contact lookup) can accept — a forwarded
            // URL grants an uninvited account nothing.
            share.publicPermission = .none

            let result = try await privateDB.modifyRecords(saving: [root, share], deleting: [],
                                                           savePolicy: .ifServerRecordUnchanged,
                                                           atomically: true)
            // Surface a per-record failure that an atomic batch may report inside
            // saveResults rather than as the top-level throw.
            _ = try result.saveResults[root.recordID]?.get()
            // The share URL is populated only AFTER the save round-trips through
            // the server — read it from the SAVED share instance, never from the
            // local `share` (whose `url` is still nil here). This was the bug that
            // returned a "ready" room with no invitation link.
            let savedShare = (try result.saveResults[share.recordID]?.get()) as? CKShare
            guard let shareURL = savedShare?.url else {
                Self.log.error("createRoom: CKShare saved but url==nil [op=modifyRecords type=\(CloudKitConfig.RecordType.room, privacy: .public) db=private zone=\(CloudKitConfig.roomsZoneName, privacy: .public) container=\(CloudKitConfig.containerIdentifier, privacy: .public)]")
                throw OnlineError.roomUnavailable
            }
            guard var room = Self.room(from: root, isOwned: true) else { throw OnlineError.requestFailed }
            room.shareURL = shareURL
            // Owner joins their own room as the first participant.
            try? await upsertParticipant(room: room, in: privateDB, zone: recordID.zoneID,
                                         profile: owner, status: .joined)
            Self.log.log("createRoom: OK room=\(room.id, privacy: .public) purpose=\(purpose.rawValue, privacy: .public) url=present")
            return room
        } catch {
            // The EXACT CloudKit failure — code name + raw value, description,
            // underlying NSError, server message and partial errors — with the
            // failing operation and full CloudKit context. Requirement #1.
            Self.log.error("createRoom FAILED: \(OnlineError.detail(for: error), privacy: .public) [op=modifyRecords type=\(CloudKitConfig.RecordType.room, privacy: .public) db=private zone=\(CloudKitConfig.roomsZoneName, privacy: .public) container=\(CloudKitConfig.containerIdentifier, privacy: .public) purpose=\(purpose.rawValue, privacy: .public)]")
            throw error
        }
    }

    /// Accept an invitation from a CKShare URL's metadata (app delegate hook).
    func acceptShare(metadata: CKShare.Metadata) async throws {
        _ = try await container.accept(metadata)
    }

    // MARK: Participants

    /// Write/refresh the CURRENT USER's own participant record for a room.
    func joinRoom(_ room: FocusRoom, profile: OnlineProfile) async throws {
        let db = room.isOwned ? privateDB : sharedDB
        guard let zone = try await zoneForRoom(room, in: db) else { throw OnlineError.roomUnavailable }
        try await upsertParticipant(room: room, in: db, zone: zone, profile: profile, status: .joined)
    }

    func setReady(_ room: FocusRoom, profile: OnlineProfile, ready: Bool) async {
        let db = room.isOwned ? privateDB : sharedDB
        guard let zone = try? await zoneForRoom(room, in: db) else { return }
        try? await upsertParticipant(room: room, in: db, zone: zone, profile: profile,
                                     status: ready ? .ready : .joined)
    }

    func markFlying(_ room: FocusRoom, profile: OnlineProfile, sessionID: String) async {
        let db = room.isOwned ? privateDB : sharedDB
        guard let zone = try? await zoneForRoom(room, in: db) else { return }
        try? await upsertParticipant(room: room, in: db, zone: zone, profile: profile,
                                     status: .flying, sessionID: sessionID)
    }

    private func upsertParticipant(room: FocusRoom, in db: CKDatabase, zone: CKRecordZone.ID,
                                   profile: OnlineProfile, status: RoomParticipant.Status,
                                   sessionID: String? = nil) async throws {
        let name = "participant-\(room.id)-\(profile.publicID)"
        let id = CKRecord.ID(recordName: name, zoneID: zone)
        let record: CKRecord
        if let existing = try? await db.record(for: id) {
            record = existing
        } else {
            record = CKRecord(recordType: CloudKitConfig.RecordType.roomParticipant, recordID: id)
            record["roomPublicID"] = room.id as CKRecordValue
            record["publicID"] = profile.publicID as CKRecordValue
            record["joinedAt"] = Date() as CKRecordValue
            record.setParent(CKRecord.ID(recordName: "room-\(room.id)", zoneID: zone))
        }
        record["displayName"] = profile.displayName as CKRecordValue
        record["balloonSkinID"] = profile.balloonSkinID as CKRecordValue
        record["countryCode"] = profile.countryCode as CKRecordValue?
        record["status"] = status.rawValue as CKRecordValue
        if status == .ready { record["readyAt"] = Date() as CKRecordValue }
        if let sessionID { record["activeSessionID"] = sessionID as CKRecordValue }
        record["lastHeartbeatAt"] = Date() as CKRecordValue
        _ = try await db.modifyRecords(saving: [record], deleting: [],
                                       savePolicy: .changedKeys, atomically: true)
    }

    // MARK: Room state

    /// Owner starts the flight: shared `startedAt`; every device computes its
    /// own local countdown from the shared timestamps (no ms-sync needed).
    func startRoom(_ room: FocusRoom, durationSeconds: Int?) async throws {
        guard room.isOwned else { throw OnlineError.requestFailed }
        let id = CKRecord.ID(recordName: "room-\(room.id)", zoneID: zoneID)
        let record = try await privateDB.record(for: id)
        record["status"] = FocusRoom.Status.active.rawValue as CKRecordValue
        record["startedAt"] = Date() as CKRecordValue
        if let durationSeconds {
            record["expiresAt"] = Date().addingTimeInterval(TimeInterval(durationSeconds) + 3600) as CKRecordValue
        }
        _ = try await privateDB.modifyRecords(saving: [record], deleting: [],
                                              savePolicy: .changedKeys, atomically: true)
    }

    func closeRoom(_ room: FocusRoom) async {
        guard room.isOwned else { return }
        let id = CKRecord.ID(recordName: "room-\(room.id)", zoneID: zoneID)
        if let record = try? await privateDB.record(for: id) {
            record["status"] = FocusRoom.Status.closed.rawValue as CKRecordValue
            _ = try? await privateDB.modifyRecords(saving: [record], deleting: [],
                                                   savePolicy: .changedKeys, atomically: true)
        }
    }

    /// Leave a shared room: remove the caller's own participant record.
    func leaveRoom(_ room: FocusRoom, publicID: String) async {
        let db = room.isOwned ? privateDB : sharedDB
        guard let zone = try? await zoneForRoom(room, in: db) else { return }
        let id = CKRecord.ID(recordName: "participant-\(room.id)-\(publicID)", zoneID: zone)
        _ = try? await db.deleteRecord(withID: id)
    }

    // MARK: Fetching

    func ownedRooms() async -> [FocusRoom] {
        try? await ensureZone()
        let predicate = NSPredicate(format: "status != %@", FocusRoom.Status.closed.rawValue)
        let query = CKQuery(recordType: CloudKitConfig.RecordType.room, predicate: predicate)
        guard let (matches, _) = try? await privateDB.records(matching: query, inZoneWith: zoneID,
                                                              desiredKeys: nil, resultsLimit: 25) else { return [] }
        return matches.compactMap { _, r in (try? r.get()).flatMap { Self.room(from: $0, isOwned: true) } }
    }

    /// Rooms shared WITH the user (accepted invitations) across shared zones.
    func joinedRooms() async -> [FocusRoom] {
        guard let zones = try? await sharedDB.allRecordZones() else { return [] }
        var rooms: [FocusRoom] = []
        for zone in zones {
            let query = CKQuery(recordType: CloudKitConfig.RecordType.room,
                                predicate: NSPredicate(value: true))
            guard let (matches, _) = try? await sharedDB.records(matching: query, inZoneWith: zone.zoneID,
                                                                 desiredKeys: nil, resultsLimit: 10) else { continue }
            for (_, result) in matches {
                if let record = try? result.get(), let room = Self.room(from: record, isOwned: false) {
                    if room.status != .closed { rooms.append(room) }
                }
            }
        }
        return rooms
    }

    func participants(of room: FocusRoom) async -> [RoomParticipant] {
        let db = room.isOwned ? privateDB : sharedDB
        guard let zone = try? await zoneForRoom(room, in: db) else { return [] }
        let query = CKQuery(recordType: CloudKitConfig.RecordType.roomParticipant,
                            predicate: NSPredicate(format: "roomPublicID == %@", room.id))
        guard let (matches, _) = try? await db.records(matching: query, inZoneWith: zone,
                                                       desiredKeys: nil, resultsLimit: 30) else { return [] }
        var seen = Set<String>()
        var out: [RoomParticipant] = []
        for (_, result) in matches {
            guard let record = try? result.get(),
                  let pid = record["publicID"] as? String, !seen.contains(pid) else { continue }
            seen.insert(pid)
            out.append(RoomParticipant(
                id: "\(room.id)_\(pid)",
                roomPublicID: room.id,
                publicID: pid,
                displayName: record["displayName"] as? String ?? "Sky Pilot",
                balloonSkinID: record["balloonSkinID"] as? String ?? "default",
                countryCode: record["countryCode"] as? String,
                joinedAt: record["joinedAt"] as? Date ?? Date(),
                status: RoomParticipant.Status(rawValue: record["status"] as? String ?? "") ?? .joined,
                readyAt: record["readyAt"] as? Date,
                activeSessionID: record["activeSessionID"] as? String,
                lastHeartbeatAt: record["lastHeartbeatAt"] as? Date))
        }
        return out.sorted { $0.joinedAt < $1.joinedAt }
    }

    /// The live CKShare for an OWNED room (used by the system sharing UI and
    /// participant management). Participants don't fetch the owner's share.
    /// Retries once for the brief window where a just-saved root record's
    /// `share` reference hasn't propagated yet — otherwise the invite sheet
    /// would show "couldn't create your room" for a room that WAS created.
    func share(for room: FocusRoom) async -> CKShare? {
        guard room.isOwned else { return nil }
        let id = CKRecord.ID(recordName: "room-\(room.id)", zoneID: zoneID)
        for attempt in 0..<2 {
            do {
                let root = try await privateDB.record(for: id)
                guard let shareRef = root.share else {
                    if attempt == 0 { try? await Task.sleep(nanoseconds: 400_000_000); continue }
                    Self.log.error("share(for:): root has no share reference room=\(room.id, privacy: .public)")
                    return nil
                }
                return (try await privateDB.record(for: shareRef.recordID)) as? CKShare
            } catch {
                Self.log.error("share(for:) FAILED (attempt \(attempt)): \(OnlineError.detail(for: error), privacy: .public) room=\(room.id, privacy: .public)")
                if attempt == 0 { try? await Task.sleep(nanoseconds: 400_000_000); continue }
                return nil
            }
        }
        return nil
    }

    /// Refresh the share URL for an owned room (after relaunch). With
    /// `publicPermission = .none` this URL only works for invited participants.
    func shareURL(for room: FocusRoom) async -> URL? {
        guard room.isOwned else { return room.shareURL }
        return await share(for: room)?.url
    }

    /// Explicitly invite one person (resolved from an email or phone number
    /// the user just picked) as a private read/write CKShare participant.
    /// Nothing about the contact is stored — the lookup value is used once.
    func addParticipant(to room: FocusRoom, email: String?, phone: String?) async throws {
        guard room.isOwned else { throw OnlineError.requestFailed }
        guard let share = await share(for: room) else { throw OnlineError.roomUnavailable }
        let participant = try await lookupParticipant(email: email, phone: phone)
        participant.permission = .readWrite
        share.addParticipant(participant)
        _ = try await privateDB.modifyRecords(saving: [share], deleting: [],
                                              savePolicy: .ifServerRecordUnchanged, atomically: true)
    }

    private func lookupParticipant(email: String?, phone: String?) async throws -> CKShare.Participant {
        let container = self.container
        // Each completion handler is a fresh closure literal passed directly to
        // the SDK's `@Sendable` parameter (no stored non-Sendable variable), so
        // no "converting non-Sendable function value" data-race warning. Each
        // continuation is resumed exactly once.
        if let email, !email.isEmpty {
            return try await withCheckedThrowingContinuation { continuation in
                container.fetchShareParticipant(withEmailAddress: email) { participant, error in
                    if let participant {
                        continuation.resume(returning: participant)
                    } else {
                        continuation.resume(throwing: error ?? OnlineError.requestFailed)
                    }
                }
            }
        }
        if let phone, !phone.isEmpty {
            return try await withCheckedThrowingContinuation { continuation in
                container.fetchShareParticipant(withPhoneNumber: phone) { participant, error in
                    if let participant {
                        continuation.resume(returning: participant)
                    } else {
                        continuation.resume(throwing: error ?? OnlineError.requestFailed)
                    }
                }
            }
        }
        throw OnlineError.requestFailed
    }

    /// The users who ACTUALLY accepted this room's invitation, identified by
    /// their stable CloudKit user record ID (never display names, never
    /// self-reported fields). Owner excluded by role. This is the only input
    /// to invite-based Sky unlocks.
    func acceptedShareParticipantIDs(for room: FocusRoom) async -> [String] {
        guard let share = await share(for: room) else { return [] }
        var out = Set<String>()
        for participant in share.participants
        where participant.role != .owner && participant.acceptanceStatus == .accepted {
            if let stable = participant.userIdentity.userRecordID?.recordName {
                out.insert(stable)
            }
        }
        return Array(out)
    }

    private func zoneForRoom(_ room: FocusRoom, in db: CKDatabase) async throws -> CKRecordZone.ID? {
        if room.isOwned { return zoneID }
        guard let zones = try? await db.allRecordZones() else { return nil }
        for zone in zones {
            let id = CKRecord.ID(recordName: "room-\(room.id)", zoneID: zone.zoneID)
            if (try? await db.record(for: id)) != nil { return zone.zoneID }
        }
        return nil
    }

    static func room(from record: CKRecord, isOwned: Bool) -> FocusRoom? {
        guard let roomID = record["roomPublicID"] as? String,
              let owner = record["ownerPublicID"] as? String else { return nil }
        return FocusRoom(id: roomID,
                         ownerPublicID: owner,
                         title: record["title"] as? String ?? "FocusGlobe Flight",
                         skyID: record["skyID"] as? String ?? "golden-hour",
                         createdAt: record["createdAt"] as? Date ?? Date(),
                         expiresAt: record["expiresAt"] as? Date,
                         maximumParticipants: Int(record["maximumParticipants"] as? Int64 ?? 8),
                         status: FocusRoom.Status(rawValue: record["status"] as? String ?? "") ?? .lobby,
                         allowsLateJoin: (record["allowsLateJoin"] as? Int64 ?? 1) == 1,
                         purpose: FocusRoom.Purpose(rawValue: record["purpose"] as? String ?? "") ?? .flight,
                         startedAt: record["startedAt"] as? Date,
                         isOwned: isOwned,
                         shareURL: nil)
    }
}
