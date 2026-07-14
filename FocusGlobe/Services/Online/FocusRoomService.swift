import Foundation
import CloudKit

/// Private focus rooms via CKShare: the room root lives in the owner's private
/// custom zone; invitees accept the share URL and read/write through the
/// shared database. Rooms carry a purpose — a shared flight, or a Sky-unlock
/// invitation campaign.
actor FocusRoomService {
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
    func createRoom(title: String, skyID: String, owner: OnlineProfile,
                    purpose: FocusRoom.Purpose) async throws -> FocusRoom {
        try await ensureZone()
        let roomID = UUID().uuidString
        let recordID = CKRecord.ID(recordName: "room-\(roomID)", zoneID: zoneID)
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
        // Link-based invitations: anyone with the private URL may join and
        // write their own participant record. Documented in the schema notes.
        share.publicPermission = .readWrite

        _ = try await privateDB.modifyRecords(saving: [root, share], deleting: [],
                                              savePolicy: .ifServerRecordUnchanged, atomically: true)
        var room = Self.room(from: root, isOwned: true)
        room?.shareURL = share.url
        // Owner joins their own room as the first participant.
        if let room {
            try? await upsertParticipant(room: room, in: privateDB, zone: recordID.zoneID,
                                         profile: owner, status: .joined)
            return room
        }
        throw OnlineError.requestFailed
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

    /// Refresh the share URL for an owned room (after relaunch).
    func shareURL(for room: FocusRoom) async -> URL? {
        guard room.isOwned else { return room.shareURL }
        let id = CKRecord.ID(recordName: "room-\(room.id)", zoneID: zoneID)
        guard let root = try? await privateDB.record(for: id),
              let shareRef = root.share else { return nil }
        let share = try? await privateDB.record(for: shareRef.recordID) as? CKShare
        return share?.url
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
