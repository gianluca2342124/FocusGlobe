import Foundation

/// User preferences. Persisted locally (UserDefaults) — never leaves the device.
struct AppSettings: Codable, Equatable {
    /// FocusGlobe is dark-first: the very first launch (and a data reset) starts
    /// in Dark Mode. The user can switch to Light or System in Settings and the
    /// choice is remembered.
    var appearance: AppearanceMode = .dark
    var soundEnabled: Bool = true
    var hapticsEnabled: Bool = true
    /// Default map presentation for backdrops (overridable live in-session).
    /// Monochrome (dark/muted Apple Maps) by default — Standard/Satellite opt-in.
    var mapStyle: MapDisplayStyle = .monochrome

    /// A manually chosen starting city. Used only when real location is
    /// unavailable (and, in DEBUG, as a Simulator override). `nil` means "use my
    /// current location".
    var startingCity: JourneyOrigin? = nil

    /// The virtual location reached by completing journeys — "travelling the
    /// world." Once set it becomes the origin for the next journey (it is NOT
    /// overwritten by GPS). Cleared by "Return to my real location".
    var virtualOrigin: JourneyOrigin? = nil

    /// The city the user departed from on the most recent completed journey, so
    /// Choose Journey can offer a "back to …" return trip. Optional so older
    /// saved settings keep decoding.
    var previousOrigin: JourneyOrigin? = nil

    /// The selected balloon skin id (see `BalloonSkin`). `nil` → the default
    /// Sky Balloon. Optional so older saved settings keep decoding.
    var selectedSkinID: String? = nil

    /// The selected journey audio ambience id (see `JourneyAudioOption`). `nil`
    /// → Wind (the free default). Optional so older saved settings keep decoding.
    var selectedJourneyAudioID: String? = nil

    /// Legacy flag (the launch paywall is now gated per-session in memory, not
    /// persisted). Retained only so older saved settings keep decoding.
    var premiumIntroSeen: Bool? = nil

    static let `default` = AppSettings()
}
