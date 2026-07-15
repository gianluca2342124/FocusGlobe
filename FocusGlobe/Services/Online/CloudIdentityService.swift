import Foundation
import CloudKit

/// The private cross-device identity: one fixed record in the private database.
/// Created once, cached locally, reused everywhere. Exposes no Apple ID, email,
/// phone, CloudKit user ID, or onboarding answers.
actor CloudIdentityService {
    private let recordName = "current-user-identity"
    private var database: CKDatabase { CloudKitConfig.container.privateCloudDatabase }

    /// Fetch-or-create the identity. Cached value is returned instantly by the
    /// coordinator; this refreshes/creates against CloudKit.
    func ensureIdentity() async throws -> FocusIdentity {
        let id = CKRecord.ID(recordName: recordName)
        do {
            let record = try await database.record(for: id)
            // Reuse the existing identity when it decodes; otherwise repair the
            // same fixed record in place (never create a second identity).
            if let identity = Self.identity(from: record) {
                return identity
            }
            return try await create(overwriting: record)
        } catch let error as CKError where error.code == .unknownItem {
            return try await create(overwriting: nil)
        }
    }

    /// Update the anonymous alias (validated + rate-limited by the coordinator).
    func updateAlias(_ alias: String) async throws {
        let id = CKRecord.ID(recordName: recordName)
        let record = try await database.record(for: id)
        record["anonymousHandle"] = alias as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        _ = try await database.modifyRecords(saving: [record], deleting: [],
                                             savePolicy: .changedKeys, atomically: true)
    }

    private func create(overwriting existing: CKRecord?) async throws -> FocusIdentity {
        let identity = FocusIdentity.makeNew()
        let record = existing ?? CKRecord(recordType: CloudKitConfig.RecordType.identity,
                                          recordID: CKRecord.ID(recordName: recordName))
        record["publicID"] = identity.publicID as CKRecordValue
        record["anonymousHandle"] = identity.anonymousHandle as CKRecordValue
        record["createdAt"] = identity.createdAt as CKRecordValue
        record["updatedAt"] = identity.updatedAt as CKRecordValue
        record["schemaVersion"] = 1 as CKRecordValue
        _ = try await database.modifyRecords(saving: [record], deleting: [],
                                             savePolicy: .changedKeys, atomically: true)
        return identity
    }

    private static func identity(from record: CKRecord) -> FocusIdentity? {
        guard let publicID = record["publicID"] as? String,
              let handle = record["anonymousHandle"] as? String else { return nil }
        return FocusIdentity(publicID: publicID,
                             anonymousHandle: handle,
                             createdAt: record["createdAt"] as? Date ?? Date(),
                             updatedAt: record["updatedAt"] as? Date ?? Date(),
                             schemaVersion: Int(record["schemaVersion"] as? Int64 ?? 1))
    }
}
