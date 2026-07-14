import Foundation

/// Lightweight local cache for online state (fast UI, never authoritative for
/// live presence, request status, share acceptance, or unlock completion).
/// One iCloud identity at a time: `resetForAccountChange` wipes social data
/// while leaving unrelated local app progress untouched.
struct OnlineCache {
    private static let d = UserDefaults.standard
    private enum K {
        static let identity = "online.identity"
        static let profile = "online.profile"
        static let mode = "online.lastFlightMode"
        static let disclosure = "online.disclosureSeen"
        static let aliasChangedAt = "online.aliasChangedAt"
        static let requestSentAt = "online.requestSentAt"
        static let campaignProgress = "online.campaignProgress"   // [skyID: Int]
        static let lastStatus = "online.lastStatus"
    }

    static func loadIdentity() -> FocusIdentity? { decode(K.identity) }
    static func save(identity: FocusIdentity) { encode(identity, K.identity) }

    static func loadProfile() -> OnlineProfile? { decode(K.profile) }
    static func save(profile: OnlineProfile) { encode(profile, K.profile) }

    static var lastFlightMode: OnlineFlightMode {
        get { OnlineFlightMode(rawValue: d.string(forKey: K.mode) ?? "") ?? .solo }
        set { d.set(newValue.rawValue, forKey: K.mode) }
    }
    static var disclosureSeen: Bool {
        get { d.bool(forKey: K.disclosure) }
        set { d.set(newValue, forKey: K.disclosure) }
    }
    static var aliasLastChangedAt: Date? {
        get { d.object(forKey: K.aliasChangedAt) as? Date }
        set { d.set(newValue, forKey: K.aliasChangedAt) }
    }
    static var lastFriendRequestAt: Date? {
        get { d.object(forKey: K.requestSentAt) as? Date }
        set { d.set(newValue, forKey: K.requestSentAt) }
    }
    static var campaignProgress: [String: Int] {
        get { d.dictionary(forKey: K.campaignProgress) as? [String: Int] ?? [:] }
        set { d.set(newValue, forKey: K.campaignProgress) }
    }
    static var lastOnlineStatus: String? {
        get { d.string(forKey: K.lastStatus) }
        set { d.set(newValue, forKey: K.lastStatus) }
    }

    /// Clear cached social data (iCloud account changed / online data deleted).
    static func resetForAccountChange() {
        for key in [K.identity, K.profile, K.aliasChangedAt, K.requestSentAt,
                    K.campaignProgress, K.lastStatus] {
            d.removeObject(forKey: key)
        }
    }

    private static func decode<T: Decodable>(_ key: String) -> T? {
        guard let data = d.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    private static func encode<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { d.set(data, forKey: key) }
    }
}
