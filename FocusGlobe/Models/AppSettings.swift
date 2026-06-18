import Foundation

/// User preferences. Persisted locally (UserDefaults) — never leaves the device.
struct AppSettings: Codable, Equatable {
    var appearance: AppearanceMode = .system
    var soundEnabled: Bool = true
    var hapticsEnabled: Bool = true
    var pureModeDefault: Bool = false

    static let `default` = AppSettings()
}
