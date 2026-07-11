import Foundation

/// Lightweight local persistence built on `UserDefaults` + `Codable`.
///
/// We deliberately use UserDefaults over SwiftData for the MVP: the data set is
/// tiny (settings, progress, a list of session records), there are no
/// relationships or queries, it never crashes on schema changes, and it's
/// trivial to reset. No backend, no account, no network — everything stays on
/// device.
final class PersistenceService {

    enum Key: String {
        case settings = "fg.settings"
        case progress = "fg.progress"
        case history = "fg.history"
        case isPro = "fg.isPro"
        case resumableJourney = "fg.resumableJourney"
        case profile = "fg.profile"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load<T: Decodable>(_ type: T.Type, for key: Key) -> T? {
        guard let data = defaults.data(forKey: key.rawValue) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    func save<T: Encodable>(_ value: T, for key: Key) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key.rawValue)
    }

    func bool(for key: Key) -> Bool {
        defaults.bool(forKey: key.rawValue)
    }

    func setBool(_ value: Bool, for key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }

    func remove(_ key: Key) {
        defaults.removeObject(forKey: key.rawValue)
    }

    /// Wipes all FocusGlobe data (used by the debug "Reset" action).
    func wipeAll() {
        [Key.settings, .progress, .history, .isPro, .resumableJourney, .profile].forEach { remove($0) }
    }
}
