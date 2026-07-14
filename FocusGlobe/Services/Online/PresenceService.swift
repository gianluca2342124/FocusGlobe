import Foundation
import CloudKit
import OSLog

/// Public Sky presence: ONE record per user (record ID == publicID), updated —
/// never re-created — on heartbeat (~45 s), start, pause, resume, and skin or
/// foreground changes; deleted on every termination path. Remaining time is
/// interpolated locally from `expectedEndAt`; there are no per-second writes.
actor PresenceService {
    private var database: CKDatabase { CloudKitConfig.container.publicCloudDatabase }
    private var heartbeatTask: Task<Void, Never>?
    private var current: OnlinePresence?
    private var identity: (publicID: String, displayName: String, countryCode: String?, acceptsInvites: Bool)?
    private(set) var lastHeartbeatAt: Date?

    func configure(publicID: String, displayName: String, countryCode: String?, acceptsInvites: Bool) {
        identity = (publicID, displayName, countryCode, acceptsInvites)
    }

    // MARK: Publishing

    func startPublishing(_ presence: OnlinePresence) {
        current = presence
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.pushHeartbeat()
                try? await Task.sleep(nanoseconds: UInt64(CloudKitConfig.presenceHeartbeatInterval * 1_000_000_000))
            }
        }
    }

    func setPaused(_ paused: Bool) async {
        guard current != nil else { return }
        current?.isPaused = paused
        await pushHeartbeat()
    }

    func heartbeatNow() async { await pushHeartbeat() }

    /// Stop publishing and remove the record (all flight termination paths,
    /// visibility off, switch to Solo).
    func stopPublishing() async {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        current = nil
        guard let publicID = identity?.publicID else { return }
        _ = try? await database.deleteRecord(withID: CKRecord.ID(recordName: publicID))
    }

    private func pushHeartbeat() async {
        guard let presence = current, let who = identity else { return }
        let id = CKRecord.ID(recordName: who.publicID)
        do {
            let record: CKRecord
            do {
                record = try await database.record(for: id)
            } catch let error as CKError where error.code == .unknownItem {
                record = CKRecord(recordType: CloudKitConfig.RecordType.presence, recordID: id)
                record["publicID"] = who.publicID as CKRecordValue
            }
            record["sessionID"] = presence.sessionID as CKRecordValue
            record["skyID"] = presence.skyID as CKRecordValue
            record["mode"] = presence.mode.rawValue as CKRecordValue
            record["roomPublicID"] = presence.roomPublicID as CKRecordValue?
            record["startedAt"] = presence.startedAt as CKRecordValue
            record["expectedEndAt"] = presence.expectedEndAt as CKRecordValue?
            record["lastHeartbeatAt"] = Date() as CKRecordValue
            record["isPaused"] = (presence.isPaused ? 1 : 0) as CKRecordValue
            record["focusCategory"] = presence.focusCategory as CKRecordValue
            record["balloonSkinID"] = presence.balloonSkinID as CKRecordValue
            record["displayName"] = who.displayName as CKRecordValue
            record["countryCode"] = who.countryCode as CKRecordValue?
            record["acceptsInvites"] = (who.acceptsInvites ? 1 : 0) as CKRecordValue
            record["updatedAt"] = Date() as CKRecordValue
            _ = try await database.modifyRecords(saving: [record], deleting: [],
                                                 savePolicy: .changedKeys, atomically: true)
            lastHeartbeatAt = Date()
        } catch {
            CloudKitEnvironment.log.error("presence heartbeat failed: \(OnlineError.category(for: error), privacy: .public)")
            if let delay = OnlineError.retryAfter(error) {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    // MARK: Fetching pilots

    /// Fresh pilots in a Sky (excluding self), deduplicated, stale-filtered.
    func fetchPilots(skyID: String, excluding publicID: String?, limit: Int = 24) async -> [OnlinePilot] {
        let cutoff = Date().addingTimeInterval(-CloudKitConfig.presenceStaleInterval)
        let predicate = NSPredicate(format: "skyID == %@ AND lastHeartbeatAt > %@",
                                    skyID, cutoff as NSDate)
        let query = CKQuery(recordType: CloudKitConfig.RecordType.presence, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "lastHeartbeatAt", ascending: false)]
        do {
            let (matches, _) = try await database.records(
                matching: query, inZoneWith: nil,
                desiredKeys: ["publicID", "sessionID", "skyID", "mode", "startedAt",
                              "expectedEndAt", "lastHeartbeatAt", "isPaused", "focusCategory",
                              "balloonSkinID", "displayName", "countryCode", "acceptsInvites"],
                resultsLimit: limit)
            var seen = Set<String>()
            var pilots: [OnlinePilot] = []
            for (_, result) in matches {
                guard let record = try? result.get(),
                      let pilot = Self.pilot(from: record) else { continue }
                guard pilot.id != publicID, !seen.contains(pilot.id), !pilot.isStale else { continue }
                seen.insert(pilot.id)
                pilots.append(pilot)
            }
            return pilots
        } catch {
            CloudKitEnvironment.log.error("pilot fetch failed: \(OnlineError.category(for: error), privacy: .public)")
            return []
        }
    }

    static func pilot(from record: CKRecord) -> OnlinePilot? {
        guard let publicID = record["publicID"] as? String,
              let sessionID = record["sessionID"] as? String,
              let skyID = record["skyID"] as? String,
              let heartbeat = record["lastHeartbeatAt"] as? Date else { return nil }
        return OnlinePilot(id: publicID,
                           sessionID: sessionID,
                           displayName: record["displayName"] as? String ?? "Sky Pilot",
                           countryCode: record["countryCode"] as? String,
                           balloonSkinID: record["balloonSkinID"] as? String ?? "default",
                           skyID: skyID,
                           startedAt: record["startedAt"] as? Date ?? heartbeat,
                           expectedEndAt: record["expectedEndAt"] as? Date,
                           lastHeartbeatAt: heartbeat,
                           isPaused: (record["isPaused"] as? Int64 ?? 0) == 1,
                           focusCategory: record["focusCategory"] as? String ?? "Focus",
                           allowsFriendRequest: (record["acceptsInvites"] as? Int64 ?? 1) == 1)
    }
}
