import Foundation
import CloudKit

/// The user's public profile record (anonymous by default) plus lookups of
/// other pilots' profiles for the Crew page.
actor PublicProfileService {
    private var database: CKDatabase { CloudKitConfig.container.publicCloudDatabase }

    /// Create-or-update the caller's own profile (record ID == publicID).
    func upsertProfile(_ profile: OnlineProfile) async throws {
        let id = CKRecord.ID(recordName: profile.publicID)
        let record: CKRecord
        do {
            record = try await database.record(for: id)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: CloudKitConfig.RecordType.publicProfile, recordID: id)
            record["publicID"] = profile.publicID as CKRecordValue
            record["createdAt"] = profile.createdAt as CKRecordValue
        }
        record["displayName"] = profile.displayName as CKRecordValue
        record["balloonSkinID"] = profile.balloonSkinID as CKRecordValue
        record["countryCode"] = profile.countryCode as CKRecordValue?
        record["isDiscoverable"] = (profile.isDiscoverable ? 1 : 0) as CKRecordValue
        record["allowsFriendRequests"] = (profile.allowsFriendRequests ? 1 : 0) as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        _ = try await database.modifyRecords(saving: [record], deleting: [],
                                             savePolicy: .changedKeys, atomically: true)
    }

    func deleteProfile(publicID: String) async {
        _ = try? await database.deleteRecord(withID: CKRecord.ID(recordName: publicID))
    }

    /// Fetch a batch of profiles by publicID (Crew display).
    func fetchProfiles(publicIDs: [String]) async -> [OnlineProfile] {
        var out: [OnlineProfile] = []
        for chunk in stride(from: 0, to: publicIDs.count, by: 20).map({ Array(publicIDs[$0..<min($0 + 20, publicIDs.count)]) }) {
            for pid in chunk {
                if let record = try? await database.record(for: CKRecord.ID(recordName: pid)),
                   let profile = Self.profile(from: record) {
                    out.append(profile)
                }
            }
        }
        return out
    }

    static func profile(from record: CKRecord) -> OnlineProfile? {
        guard let publicID = record["publicID"] as? String,
              let name = record["displayName"] as? String else { return nil }
        return OnlineProfile(publicID: publicID,
                             displayName: name,
                             balloonSkinID: record["balloonSkinID"] as? String ?? "default",
                             countryCode: record["countryCode"] as? String,
                             isDiscoverable: (record["isDiscoverable"] as? Int64 ?? 0) == 1,
                             allowsFriendRequests: (record["allowsFriendRequests"] as? Int64 ?? 1) == 1,
                             createdAt: record["createdAt"] as? Date ?? Date(),
                             updatedAt: record["updatedAt"] as? Date ?? Date())
    }
}
