import Foundation
import CloudKit

/// The Crew system: friend requests + connections in the public database, with
/// deterministic IDs, duplicate/self protection and simple rate limiting.
/// Also hosts the invite-unlock campaign store (real accepted invitations).
actor FriendService {
    private var database: CKDatabase { CloudKitConfig.container.publicCloudDatabase }
    private var privateDB: CKDatabase { CloudKitConfig.container.privateCloudDatabase }

    // MARK: Requests

    func sendRequest(from sender: OnlineProfile, to recipient: OnlinePilot) async throws {
        guard sender.publicID != recipient.id else { throw OnlineError.requestFailed }
        guard recipient.allowsFriendRequest else { throw OnlineError.requestFailed }
        if let last = OnlineCache.lastFriendRequestAt, Date().timeIntervalSince(last) < 10 {
            throw OnlineError.rateLimited
        }
        // Already connected?
        if await connectionExists(sender.publicID, recipient.id) { throw OnlineError.requestFailed }
        let requestID = FriendRequest.requestID(sender: sender.publicID, recipient: recipient.id)
        let id = CKRecord.ID(recordName: requestID)
        // Duplicate pending request?
        if let existing = try? await database.record(for: id),
           (existing["status"] as? String) == FriendRequest.Status.pending.rawValue {
            throw OnlineError.requestFailed
        }
        let record = (try? await database.record(for: id))
            ?? CKRecord(recordType: CloudKitConfig.RecordType.friendRequest, recordID: id)
        record["requestID"] = requestID as CKRecordValue
        record["senderPublicID"] = sender.publicID as CKRecordValue
        record["recipientPublicID"] = recipient.id as CKRecordValue
        record["senderDisplayName"] = sender.displayName as CKRecordValue
        record["senderBalloonSkinID"] = sender.balloonSkinID as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        record["status"] = FriendRequest.Status.pending.rawValue as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        _ = try await database.modifyRecords(saving: [record], deleting: [],
                                             savePolicy: .changedKeys, atomically: true)
        OnlineCache.lastFriendRequestAt = Date()
    }

    func respond(to request: FriendRequest, accept: Bool, me: OnlineProfile) async throws {
        guard request.recipientPublicID == me.publicID else { throw OnlineError.requestFailed }
        let id = CKRecord.ID(recordName: request.id)
        let record = try await database.record(for: id)
        record["status"] = (accept ? FriendRequest.Status.accepted : .declined).rawValue as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        var saves: [CKRecord] = [record]
        if accept {
            let connID = FriendRequest.connectionID(request.senderPublicID, me.publicID)
            let conn = CKRecord(recordType: CloudKitConfig.RecordType.friendConnection,
                                recordID: CKRecord.ID(recordName: connID))
            conn["connectionID"] = connID as CKRecordValue
            conn["participantA"] = min(request.senderPublicID, me.publicID) as CKRecordValue
            conn["participantB"] = max(request.senderPublicID, me.publicID) as CKRecordValue
            conn["createdAt"] = Date() as CKRecordValue
            conn["status"] = "active" as CKRecordValue
            conn["updatedAt"] = Date() as CKRecordValue
            saves.append(conn)
        }
        _ = try await database.modifyRecords(saving: saves, deleting: [],
                                             savePolicy: .changedKeys, atomically: false)
    }

    func cancelRequest(_ request: FriendRequest, me: OnlineProfile) async throws {
        guard request.senderPublicID == me.publicID else { throw OnlineError.requestFailed }
        _ = try? await database.deleteRecord(withID: CKRecord.ID(recordName: request.id))
    }

    func removeConnection(_ connectionID: String) async {
        _ = try? await database.deleteRecord(withID: CKRecord.ID(recordName: connectionID))
    }

    // MARK: Fetching

    func incomingRequests(for publicID: String) async -> [FriendRequest] {
        await fetchRequests(NSPredicate(format: "recipientPublicID == %@ AND status == %@",
                                        publicID, FriendRequest.Status.pending.rawValue))
    }
    func outgoingRequests(for publicID: String) async -> [FriendRequest] {
        await fetchRequests(NSPredicate(format: "senderPublicID == %@ AND status == %@",
                                        publicID, FriendRequest.Status.pending.rawValue))
    }

    private func fetchRequests(_ predicate: NSPredicate) async -> [FriendRequest] {
        let query = CKQuery(recordType: CloudKitConfig.RecordType.friendRequest, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        guard let (matches, _) = try? await database.records(matching: query, inZoneWith: nil,
                                                             desiredKeys: nil, resultsLimit: 40) else { return [] }
        return matches.compactMap { _, result in
            guard let record = try? result.get(),
                  let requestID = record["requestID"] as? String,
                  let sender = record["senderPublicID"] as? String,
                  let recipient = record["recipientPublicID"] as? String else { return nil }
            return FriendRequest(id: requestID,
                                 senderPublicID: sender,
                                 recipientPublicID: recipient,
                                 senderDisplayName: record["senderDisplayName"] as? String ?? "Sky Pilot",
                                 senderBalloonSkinID: record["senderBalloonSkinID"] as? String ?? "default",
                                 createdAt: record["createdAt"] as? Date ?? Date(),
                                 status: .pending)
        }
    }

    func connections(for publicID: String) async -> [(connectionID: String, otherPublicID: String, since: Date)] {
        var out: [(String, String, Date)] = []
        for key in ["participantA", "participantB"] {
            let predicate = NSPredicate(format: "\(key) == %@ AND status == %@", publicID, "active")
            let query = CKQuery(recordType: CloudKitConfig.RecordType.friendConnection, predicate: predicate)
            guard let (matches, _) = try? await database.records(matching: query, inZoneWith: nil,
                                                                 desiredKeys: nil, resultsLimit: 100) else { continue }
            for (_, result) in matches {
                guard let record = try? result.get(),
                      let connID = record["connectionID"] as? String,
                      let a = record["participantA"] as? String,
                      let b = record["participantB"] as? String else { continue }
                let other = a == publicID ? b : a
                if !out.contains(where: { $0.0 == connID }) {
                    out.append((connID, other, record["createdAt"] as? Date ?? Date()))
                }
            }
        }
        return out
    }

    private func connectionExists(_ a: String, _ b: String) async -> Bool {
        let id = CKRecord.ID(recordName: FriendRequest.connectionID(a, b))
        return (try? await database.record(for: id)) != nil
    }

    // MARK: Invite-unlock campaigns (real accepted invitations only)

    /// Persist campaign progress in the PRIVATE database — one record per Sky.
    /// Accepted counts come from unique participants who actually accepted the
    /// campaign room's CKShare (never from share-button taps).
    func recordCampaignProgress(skyID: String, ownerPublicID: String,
                                acceptedUniquePublicIDs: [String], required: Int) async {
        let id = CKRecord.ID(recordName: "campaign-\(skyID)")
        let record: CKRecord
        if let existing = try? await privateDB.record(for: id) {
            record = existing
        } else {
            record = CKRecord(recordType: CloudKitConfig.RecordType.unlockCampaign, recordID: id)
            record["campaignID"] = "campaign-\(skyID)" as CKRecordValue
            record["createdAt"] = Date() as CKRecordValue
        }
        record["ownerPublicID"] = ownerPublicID as CKRecordValue
        record["skyID"] = skyID as CKRecordValue
        record["requiredAcceptedUsers"] = Int64(required) as CKRecordValue
        record["acceptedUniquePublicIDs"] = acceptedUniquePublicIDs as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        if acceptedUniquePublicIDs.count >= required, record["unlockedAt"] == nil {
            record["unlockedAt"] = Date() as CKRecordValue
        }
        _ = try? await privateDB.modifyRecords(saving: [record], deleting: [],
                                               savePolicy: .changedKeys, atomically: true)
    }

    func campaignAcceptedIDs(skyID: String) async -> [String] {
        let id = CKRecord.ID(recordName: "campaign-\(skyID)")
        guard let record = try? await privateDB.record(for: id) else { return [] }
        return record["acceptedUniquePublicIDs"] as? [String] ?? []
    }
}
