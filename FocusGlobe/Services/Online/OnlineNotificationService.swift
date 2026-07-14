import Foundation
import CloudKit

/// CloudKit change subscriptions: silent pushes trigger targeted refreshes
/// (friend requests, shared-room changes). Never assumes pushes are instant or
/// guaranteed; the coordinator also refreshes on foreground and on demand.
/// User-visible alerting stays with the app's existing notification system.
actor OnlineNotificationService {
    private var container: CKContainer { CloudKitConfig.container }

    /// Install (idempotently) the silent subscriptions for this user.
    func installSubscriptions(publicID: String) async {
        // Friend requests addressed to me — silent content-available push.
        let requestSub = CKQuerySubscription(
            recordType: CloudKitConfig.RecordType.friendRequest,
            predicate: NSPredicate(format: "recipientPublicID == %@", publicID),
            subscriptionID: "friend-requests-\(publicID)",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate])
        let silent = CKSubscription.NotificationInfo()
        silent.shouldSendContentAvailable = true
        requestSub.notificationInfo = silent
        _ = try? await container.publicCloudDatabase.save(requestSub)

        // Answers to requests I sent (recipient-owned FriendResponse records).
        let responseSub = CKQuerySubscription(
            recordType: CloudKitConfig.RecordType.friendResponse,
            predicate: NSPredicate(format: "senderPublicID == %@", publicID),
            subscriptionID: "friend-responses-\(publicID)",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate])
        responseSub.notificationInfo = silent
        _ = try? await container.publicCloudDatabase.save(responseSub)

        // Any change in the shared database (rooms I've joined).
        let sharedSub = CKDatabaseSubscription(subscriptionID: "shared-db-changes")
        sharedSub.notificationInfo = silent
        _ = try? await container.sharedCloudDatabase.save(sharedSub)
    }

    func removeSubscriptions(publicID: String) async {
        _ = try? await container.publicCloudDatabase.deleteSubscription(withID: "friend-requests-\(publicID)")
        _ = try? await container.publicCloudDatabase.deleteSubscription(withID: "friend-responses-\(publicID)")
        _ = try? await container.sharedCloudDatabase.deleteSubscription(withID: "shared-db-changes")
    }

    /// Classify an incoming remote notification (best-effort, background-safe).
    nonisolated static func kind(of userInfo: [AnyHashable: Any]) -> RefreshKind? {
        guard let note = CKNotification(fromRemoteNotificationDictionary: userInfo) else { return nil }
        switch note.notificationType {
        case .query:    return .friends
        case .database: return .rooms
        default:        return nil
        }
    }

    enum RefreshKind: Sendable { case friends, rooms }
}
