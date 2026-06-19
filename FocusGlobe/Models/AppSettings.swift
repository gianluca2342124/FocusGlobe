import Foundation

/// User preferences. Persisted locally (UserDefaults) — never leaves the device.
struct AppSettings: Codable, Equatable {
    /// FocusGlobe is dark-first: the very first launch (and a data reset) starts
    /// in Dark Mode. The user can switch to Light or System in Settings and the
    /// choice is remembered.
    var appearance: AppearanceMode = .dark
    var soundEnabled: Bool = true
    var hapticsEnabled: Bool = true
    var pureModeDefault: Bool = false

    static let `default` = AppSettings()
}
