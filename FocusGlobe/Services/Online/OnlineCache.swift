import CryptoKit
import Foundation

/// Account-scoped display cache for Online/Friends state. Supabase remains the
/// authority: a successful refresh replaces this cache, while an offline launch
/// can show the last known safe aliases/skins without inventing mutations.
struct OnlineCache {
    private static let d = UserDefaults.standard

    private enum K {
        static let activeScope = "online.activeScope.v2"
        static let profile = "profile"
        static let mode = "lastFlightMode"
        static let disclosure = "disclosureSeen"
        static let aliasChangedAt = "aliasChangedAt"
        static let requestSentAt = "requestSentAt"
        static let campaignProgress = "campaignProgress"
        static let lastStatus = "lastStatus"
        static let roomRetryAfter = "roomRetryAfter"
        static let socialSnapshot = "socialSnapshot"
        // Invite links opened before sign-in are intentionally device-scoped so
        // the account selected by the user can consume them after authentication.
        static let pendingInviteToken = "online.pendingInviteToken"
        static let legacyAdoption = "online.legacyAdoption.v2"
    }

    private struct CachedFriend: Codable {
        let id: String
        let publicID: String
        let displayName: String
        let balloonSkinID: String
        let countryCode: String?
        let since: Date

        init(_ friend: FocusFriend) {
            id = friend.id
            publicID = friend.publicID
            displayName = friend.displayName
            balloonSkinID = friend.balloonSkinID
            countryCode = friend.countryCode
            since = friend.since
        }

        var model: FocusFriend {
            FocusFriend(id: id, publicID: publicID, displayName: displayName,
                        balloonSkinID: balloonSkinID, countryCode: countryCode,
                        since: since, activePilot: nil)
        }
    }

    private struct CachedRequest: Codable {
        let id: String
        let senderPublicID: String
        let recipientPublicID: String
        let senderDisplayName: String
        let senderBalloonSkinID: String
        let createdAt: Date

        init(_ request: FriendRequest) {
            id = request.id
            senderPublicID = request.senderPublicID
            recipientPublicID = request.recipientPublicID
            senderDisplayName = request.senderDisplayName
            senderBalloonSkinID = request.senderBalloonSkinID
            createdAt = request.createdAt
        }

        var model: FriendRequest {
            FriendRequest(id: id, senderPublicID: senderPublicID,
                          recipientPublicID: recipientPublicID,
                          senderDisplayName: senderDisplayName,
                          senderBalloonSkinID: senderBalloonSkinID,
                          createdAt: createdAt)
        }
    }

    private struct SocialSnapshot: Codable {
        let crew: [CachedFriend]
        let incoming: [CachedRequest]
        let outgoing: [CachedRequest]
        let fetchedAt: Date
    }

    static func activateAccount(_ stableUserID: String?) {
        let scope = storageScope(stableUserID ?? "anonymous")
        d.set(scope, forKey: K.activeScope)

        // Preserve the previous single-account cache only when its canonical
        // public ID proves it belongs to this same authenticated account.
        guard let stableUserID,
              d.string(forKey: K.legacyAdoption) == nil,
              d.data(forKey: "online.profile") != nil,
              let legacy: OnlineProfile = decodeRaw("online.profile"),
              legacy.publicID.lowercased() == stableUserID.lowercased(),
              loadProfile() == nil else { return }
        save(profile: legacy)
        for (legacyKey, newKey) in [
            ("online.aliasChangedAt", K.aliasChangedAt),
            ("online.requestSentAt", K.requestSentAt),
            ("online.campaignProgress", K.campaignProgress),
            ("online.lastStatus", K.lastStatus),
            ("online.roomRetryAfter", K.roomRetryAfter)
        ] {
            if let value = d.object(forKey: legacyKey) { d.set(value, forKey: scoped(newKey)) }
        }
        d.set(scope, forKey: K.legacyAdoption)
    }

    static func loadProfile() -> OnlineProfile? { decode(scoped(K.profile)) }
    static func save(profile: OnlineProfile) { encode(profile, scoped(K.profile)) }

    static var lastFlightMode: OnlineFlightMode {
        get { OnlineFlightMode(rawValue: d.string(forKey: scoped(K.mode)) ?? "") ?? .solo }
        set { d.set(newValue.rawValue, forKey: scoped(K.mode)) }
    }
    static var disclosureSeen: Bool {
        get { d.bool(forKey: scoped(K.disclosure)) }
        set { d.set(newValue, forKey: scoped(K.disclosure)) }
    }
    static var aliasLastChangedAt: Date? {
        get { d.object(forKey: scoped(K.aliasChangedAt)) as? Date }
        set { d.set(newValue, forKey: scoped(K.aliasChangedAt)) }
    }
    static var lastFriendRequestAt: Date? {
        get { d.object(forKey: scoped(K.requestSentAt)) as? Date }
        set { d.set(newValue, forKey: scoped(K.requestSentAt)) }
    }
    static var campaignProgress: [String: Int] {
        get { d.dictionary(forKey: scoped(K.campaignProgress)) as? [String: Int] ?? [:] }
        set { d.set(newValue, forKey: scoped(K.campaignProgress)) }
    }
    static var lastOnlineStatus: String? {
        get { d.string(forKey: scoped(K.lastStatus)) }
        set { d.set(newValue, forKey: scoped(K.lastStatus)) }
    }
    static var roomCreationRetryAfterDate: Date? {
        get { d.object(forKey: scoped(K.roomRetryAfter)) as? Date }
        set {
            if let newValue { d.set(newValue, forKey: scoped(K.roomRetryAfter)) }
            else { d.removeObject(forKey: scoped(K.roomRetryAfter)) }
        }
    }
    static var pendingInviteToken: String? {
        get { d.string(forKey: K.pendingInviteToken) }
        set {
            if let newValue { d.set(newValue, forKey: K.pendingInviteToken) }
            else { d.removeObject(forKey: K.pendingInviteToken) }
        }
    }

    static func loadSocial() -> (crew: [FocusFriend], incoming: [FriendRequest], outgoing: [FriendRequest])? {
        guard let snapshot: SocialSnapshot = decode(scoped(K.socialSnapshot)) else { return nil }
        return (snapshot.crew.map(\.model),
                snapshot.incoming.map(\.model),
                snapshot.outgoing.map(\.model))
    }

    static func saveSocial(crew: [FocusFriend],
                           incoming: [FriendRequest],
                           outgoing: [FriendRequest]) {
        let snapshot = SocialSnapshot(crew: crew.map(CachedFriend.init),
                                      incoming: incoming.map(CachedRequest.init),
                                      outgoing: outgoing.map(CachedRequest.init),
                                      fetchedAt: Date())
        encode(snapshot, scoped(K.socialSnapshot))
    }

    /// Clears session-only state for the active scope without deleting the last
    /// known profile, Friends display cache, preferences, or another account.
    static func clearEphemeralState() {
        d.removeObject(forKey: scoped(K.lastStatus))
        d.removeObject(forKey: scoped(K.roomRetryAfter))
    }

    private static func scoped(_ key: String) -> String {
        "online.v2.\(d.string(forKey: K.activeScope) ?? storageScope("anonymous")).\(key)"
    }

    private static func storageScope(_ accountID: String) -> String {
        let digest = SHA256.hash(data: Data("focusglobe-online:\(accountID.lowercased())".utf8))
        return digest.prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    private static func decode<T: Decodable>(_ key: String) -> T? {
        guard let data = d.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    private static func decodeRaw<T: Decodable>(_ key: String) -> T? { decode(key) }
    private static func encode<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { d.set(data, forKey: key) }
    }
}
