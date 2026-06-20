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
    /// Default map presentation for journeys (overridable live in-session).
    /// Standard 2D by default — satellite is opt-in.
    var mapStyle: MapDisplayStyle = .standard

    /// A manually chosen starting city. Used only when real location is
    /// unavailable (and, in DEBUG, as a Simulator override). `nil` means "use my
    /// current location".
    var startingCity: JourneyOrigin? = nil

    /// The virtual location reached by completing journeys — "travelling the
    /// world." Once set it becomes the origin for the next journey (it is NOT
    /// overwritten by GPS). Cleared by "Return to my real location".
    var virtualOrigin: JourneyOrigin? = nil

    static let `default` = AppSettings()
}
