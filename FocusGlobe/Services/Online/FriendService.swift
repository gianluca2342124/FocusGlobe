import Foundation
import CloudKit

/// The Crew system, ownership-safe:
///
///  • `FriendRequest` (public) — SENDER-owned, immutable. Sender may delete it
///    (cancel); the recipient never modifies it.
///  • `FriendResponse` (public) — RECIPIENT-owned answer with a deterministic
///    ID (`resp_<requestID>`), so duplicates collapse. The sender never
///    modifies it. Request state is derived from request + response.
///  • `CrewMember` (private) — each side stores its OWN membership record in
///    its OWN private database after acceptance. There is no world-readable
///    connection graph, and no user ever has to write a record the other user
///    owns. Removal = deleting your own private record.
///
/// Creator verification: a request's claimed `senderPublicID` is only trusted
/// when the request record's CloudKit `creatorUserRecordID` matches the
/// creator of the `PublicProfile` record with that publicID — a client cannot
/// impersonate another pilot by writing an arbitrary sender field.
/// Also hosts the invite-unlock campaign store (real accepted invitations).
actor FriendService {
    private var database: CKDatabase { CloudKitConfig.container.publicCloudDatabase }
    private var privateDB: CKDatabase { CloudKitConfig.container.privateCloudDatabase }

    // MARK: Requests (sender-owned, immutable)

    func sendRequest(from sender: OnlineProfile, to recipient: OnlinePilot) async throws {
        guard sender.publicID != recipient.id else { throw OnlineError.requestFailed }
        guard recipient.allowsFriendRequest else { throw OnlineError.requestFailed }
        if let last = OnlineCache.lastFriendRequestAt, Date().timeIntervalSince(last) < 10 {
            throw OnlineError.rateLimited
        }
        // Already crew (own private record)?
        if await crewRecordExists(otherPublicID: recipient.id) { throw OnlineError.requestFailed }
        // A live request already pending in either direction?
        for requestID in [FriendRequest.requestID(sender: sender.publicID, recipient: recipient.id),
                          FriendRequest.requestID(sender: recipient.id, recipient: sender.publicID)] {
            if (try? await database.record(for: CKRecord.ID(recordName: requestID))) != nil {
                throw OnlineError.requestFailed
            }
        }
        let requestID = FriendRequest.requestID(sender: sender.publicID, recipient: recipient.id)
        let record = CKRecord(recordType: CloudKitConfig.RecordType.friendRequest,
                              recordID: CKRecord.ID(recordName: requestID))
        record["requestID"] = requestID as CKRecordValue
        record["senderPublicID"] = sender.publicID as CKRecordValue
        record["recipientPublicID"] = recipient.id as CKRecordValue
        record["senderDisplayName"] = sender.displayName as CKRecordValue
        record["senderBalloonSkinID"] = sender.balloonSkinID as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        _ = try await database.modifyRecords(saving: [record], deleting: [],
                                             savePolicy: .ifServerRecordUnchanged, atomically: true)
        OnlineCache.lastFriendRequestAt = Date()
    }

    /// Sender deletes their own request (the only mutation a sender makes).
    func cancelRequest(_ request: FriendRequest, me: OnlineProfile) async throws {
        guard request.senderPublicID == me.publicID else { throw OnlineError.requestFailed }
        _ = try? await database.deleteRecord(withID: CKRecord.ID(recordName: request.id))
    }

    // MARK: Responses (recipient-owned)

    /// The recipient answers by creating their OWN `FriendResponse` record —
    /// the sender's request is never touched. On accept, the recipient also
    /// stores its own private `CrewMember` record immediately.
    func respond(to request: FriendRequest, accept: Bool, me: OnlineProfile) async throws {
        guard request.recipientPublicID == me.publicID else { throw OnlineError.requestFailed }
        let responseID = FriendRequest.responseID(for: request.id)
        let record = (try? await database.record(for: CKRecord.ID(recordName: responseID)))
            ?? CKRecord(recordType: CloudKitConfig.RecordType.friendResponse,
                        recordID: CKRecord.ID(recordName: responseID))
        record["responseID"] = responseID as CKRecordValue
        record["requestID"] = request.id as CKRecordValue
        record["senderPublicID"] = request.senderPublicID as CKRecordValue
        record["recipientPublicID"] = me.publicID as CKRecordValue
        record["response"] = (accept ? "accepted" : "declined") as CKRecordValue
        if record["createdAt"] == nil { record["createdAt"] = Date() as CKRecordValue }
        record["updatedAt"] = Date() as CKRecordValue
        _ = try await database.modifyRecords(saving: [record], deleting: [],
                                             savePolicy: .changedKeys, atomically: true)
        if accept {
            await saveCrewMember(otherPublicID: request.senderPublicID,
                                 displayName: request.senderDisplayName,
                                 balloonSkinID: request.senderBalloonSkinID,
                                 sourceRequestID: request.id)
        }
    }

    // MARK: Fetching + derived state

    /// Requests addressed to me that I haven't answered, with the sender's
    /// identity verified against the actual CloudKit record creator.
    func incomingRequests(for publicID: String) async -> [FriendRequest] {
        let raw = await fetchRequestRecords(
            NSPredicate(format: "recipientPublicID == %@", publicID))
        var out: [FriendRequest] = []
        for (request, creatorID) in raw {
            // Skip anything I've already answered (deterministic response ID).
            let responseID = FriendRequest.responseID(for: request.id)
            if (try? await database.record(for: CKRecord.ID(recordName: responseID))) != nil { continue }
            // Creator verification: the request must have been created by the
            // same iCloud user who owns the claimed sender's PublicProfile.
            guard let creatorID,
                  let profileCreator = await profileCreatorID(request.senderPublicID),
                  creatorID == profileCreator else { continue }
            out.append(request)
        }
        return out
    }

    /// My own sent requests that are still unanswered. Answered ones are
    /// resolved here: accepted → my own private CrewMember is created;
    /// either answer → my request record is cleaned up (I own it).
    func outgoingPendingRequests(for publicID: String) async -> [FriendRequest] {
        let raw = await fetchRequestRecords(
            NSPredicate(format: "senderPublicID == %@", publicID))
        var pending: [FriendRequest] = []
        for (request, _) in raw {
            let responseID = FriendRequest.responseID(for: request.id)
            guard let response = try? await database.record(for: CKRecord.ID(recordName: responseID)) else {
                pending.append(request)
                continue
            }
            // Only trust a response created by the actual recipient's account.
            if let responseCreator = response.creatorUserRecordID,
               let recipientCreator = await profileCreatorID(request.recipientPublicID),
               responseCreator != recipientCreator { continue }
            if (response["response"] as? String) == "accepted" {
                // The other pilot accepted — mirror it into MY private records.
                let other = await fetchProfileRecord(request.recipientPublicID)
                await saveCrewMember(otherPublicID: request.recipientPublicID,
                                     displayName: other?["displayName"] as? String ?? "Sky Pilot",
                                     balloonSkinID: other?["balloonSkinID"] as? String ?? "default",
                                     sourceRequestID: request.id)
            }
            // Resolved either way → delete my own request record (sender-owned).
            _ = try? await database.deleteRecord(withID: CKRecord.ID(recordName: request.id))
        }
        return pending
    }

    private func fetchRequestRecords(_ predicate: NSPredicate) async -> [(FriendRequest, CKRecord.ID?)] {
        let query = CKQuery(recordType: CloudKitConfig.RecordType.friendRequest, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        guard let (matches, _) = try? await database.records(matching: query, inZoneWith: nil,
                                                             desiredKeys: nil, resultsLimit: 40) else { return [] }
        return matches.compactMap { _, result in
            guard let record = try? result.get(),
                  let requestID = record["requestID"] as? String,
                  let sender = record["senderPublicID"] as? String,
                  let recipient = record["recipientPublicID"] as? String else { return nil }
            let request = FriendRequest(id: requestID,
                                        senderPublicID: sender,
                                        recipientPublicID: recipient,
                                        senderDisplayName: record["senderDisplayName"] as? String ?? "Sky Pilot",
                                        senderBalloonSkinID: record["senderBalloonSkinID"] as? String ?? "default",
                                        createdAt: record["createdAt"] as? Date ?? Date())
            return (request, record.creatorUserRecordID)
        }
    }

    /// The CloudKit account that owns a publicID (creator of its PublicProfile).
    private func profileCreatorID(_ publicID: String) async -> CKRecord.ID? {
        (await fetchProfileRecord(publicID))?.creatorUserRecordID
    }

    private func fetchProfileRecord(_ publicID: String) async -> CKRecord? {
        try? await database.record(for: CKRecord.ID(recordName: publicID))
    }

    // MARK: Private Crew membership (my own records, my own database)

    private func crewRecordID(_ otherPublicID: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "crew-\(otherPublicID)")
    }

    private func crewRecordExists(otherPublicID: String) async -> Bool {
        guard let record = try? await privateDB.record(for: crewRecordID(otherPublicID)) else { return false }
        return (record["status"] as? String ?? "active") == "active"
    }

    private func saveCrewMember(otherPublicID: String, displayName: String,
                                balloonSkinID: String, sourceRequestID: String) async {
        let id = crewRecordID(otherPublicID)
        let record = (try? await privateDB.record(for: id))
            ?? CKRecord(recordType: CloudKitConfig.RecordType.crewMember, recordID: id)
        record["otherPublicID"] = otherPublicID as CKRecordValue
        record["displayName"] = displayName as CKRecordValue
        record["balloonSkinID"] = balloonSkinID as CKRecordValue
        if record["connectedAt"] == nil { record["connectedAt"] = Date() as CKRecordValue }
        record["sourceRequestID"] = sourceRequestID as CKRecordValue
        record["status"] = "active" as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        _ = try? await privateDB.modifyRecords(saving: [record], deleting: [],
                                               savePolicy: .changedKeys, atomically: true)
    }

    /// My Crew, from my own private records (synchronises across my devices).
    func crewMembers() async -> [FocusFriend] {
        let query = CKQuery(recordType: CloudKitConfig.RecordType.crewMember,
                            predicate: NSPredicate(format: "status == %@", "active"))
        guard let (matches, _) = try? await privateDB.records(matching: query, inZoneWith: nil,
                                                              desiredKeys: nil, resultsLimit: 100) else { return [] }
        var seen = Set<String>()
        var out: [FocusFriend] = []
        for (_, result) in matches {
            guard let record = try? result.get(),
                  let other = record["otherPublicID"] as? String, !seen.contains(other) else { continue }
            seen.insert(other)
            out.append(FocusFriend(id: other,
                                   publicID: other,
                                   displayName: record["displayName"] as? String ?? "Sky Pilot",
                                   balloonSkinID: record["balloonSkinID"] as? String ?? "default",
                                   countryCode: nil,
                                   since: record["connectedAt"] as? Date ?? Date(),
                                   activePilot: nil))
        }
        return out
    }

    /// Remove someone from MY crew — deletes my own private record only.
    func removeCrew(otherPublicID: String) async {
        _ = try? await privateDB.deleteRecord(withID: crewRecordID(otherPublicID))
    }

    // MARK: Delete-online-data helpers (each deletes only records I own)

    func deleteMyResponses(me publicID: String) async {
        let query = CKQuery(recordType: CloudKitConfig.RecordType.friendResponse,
                            predicate: NSPredicate(format: "recipientPublicID == %@", publicID))
        guard let (matches, _) = try? await database.records(matching: query, inZoneWith: nil,
                                                             desiredKeys: [], resultsLimit: 100) else { return }
        for (id, result) in matches where (try? result.get()) != nil {
            _ = try? await database.deleteRecord(withID: id)
        }
    }

    func deleteAllCrew() async {
        let query = CKQuery(recordType: CloudKitConfig.RecordType.crewMember,
                            predicate: NSPredicate(value: true))
        guard let (matches, _) = try? await privateDB.records(matching: query, inZoneWith: nil,
                                                              desiredKeys: [], resultsLimit: 200) else { return }
        for (id, result) in matches where (try? result.get()) != nil {
            _ = try? await privateDB.deleteRecord(withID: id)
        }
    }

    // MARK: Moderation (reporter-owned reports)

    /// File a report against a pilot. Reporter-owned public record with a
    /// deterministic ID (`report_<reporter>_<reported>`) so one reporter can't
    /// flood the same pilot with new records. Stores only anonymous publicIDs,
    /// the flagged session, a closed reason category and a timestamp — never
    /// email, phone or any focus text. Not readable by other users in the app.
    func reportPilot(reporter: OnlineProfile, reportedPublicID: String,
                     reportedSessionID: String, reason: String) async throws {
        guard reporter.publicID != reportedPublicID else { throw OnlineError.requestFailed }
        let reportID = "report_\(reporter.publicID)_\(reportedPublicID)"
        let record = (try? await database.record(for: CKRecord.ID(recordName: reportID)))
            ?? CKRecord(recordType: CloudKitConfig.RecordType.pilotReport,
                        recordID: CKRecord.ID(recordName: reportID))
        record["reportID"] = reportID as CKRecordValue
        record["reporterPublicID"] = reporter.publicID as CKRecordValue
        record["reportedPublicID"] = reportedPublicID as CKRecordValue
        record["reportedSessionID"] = reportedSessionID as CKRecordValue
        record["reason"] = reason as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        _ = try await database.modifyRecords(saving: [record], deleting: [],
                                             savePolicy: .changedKeys, atomically: true)
    }

    // MARK: Invite-unlock campaigns (real accepted invitations only)

    /// Persist campaign progress in the PRIVATE database — one record per Sky.
    /// Accepted counts come from unique CKShare participants who actually
    /// accepted the campaign room's invitation (never from share-button taps).
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
