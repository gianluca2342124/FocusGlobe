import Foundation

/// User preferences. Persisted locally (UserDefaults) — never leaves the device.
struct AppSettings: Codable, Equatable {
    /// FocusGlobe is dark-first: the very first launch (and a data reset) starts
    /// in Dark Mode. The user can switch to Light or System in Settings and the
    /// choice is remembered.
    /// Retained ONLY so settings saved by an older build still decode. The
    /// Appearance selector is gone and FocusGlobe forces Dark at the window
    /// root, so nothing reads this. Removing the key would make every stored
    /// AppSettings fail to decode and silently reset every other preference
    /// with it, which is a far worse trade than one ignored field.
    var appearance: AppearanceMode = .dark
    var soundEnabled: Bool = true
    var hapticsEnabled: Bool = true
    /// Default map presentation for backdrops (overridable live in-session).
    /// "Dark Earth" (dark/premium Apple Standard) by default — Standard/Satellite opt-in.
    var mapStyle: MapDisplayStyle = .terra

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

    init() {}

    static let `default` = AppSettings()

    private enum CodingKeys: String, CodingKey {
        case appearance, soundEnabled, hapticsEnabled, mapStyle
        case startingCity, virtualOrigin, previousOrigin
        case selectedSkinID, selectedJourneyAudioID, premiumIntroSeen
    }

    /// Missing or newly-added preference keys must never reset the rest of a
    /// pilot's settings. This decoder also tolerates obsolete enum values by
    /// falling back only that individual preference.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        appearance = (try? c.decodeIfPresent(AppearanceMode.self, forKey: .appearance)) ?? .dark
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
        hapticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        mapStyle = (try? c.decodeIfPresent(MapDisplayStyle.self, forKey: .mapStyle)) ?? .terra
        startingCity = try? c.decodeIfPresent(JourneyOrigin.self, forKey: .startingCity)
        virtualOrigin = try? c.decodeIfPresent(JourneyOrigin.self, forKey: .virtualOrigin)
        previousOrigin = try? c.decodeIfPresent(JourneyOrigin.self, forKey: .previousOrigin)
        selectedSkinID = try c.decodeIfPresent(String.self, forKey: .selectedSkinID)
        selectedJourneyAudioID = try c.decodeIfPresent(String.self, forKey: .selectedJourneyAudioID)
        premiumIntroSeen = try c.decodeIfPresent(Bool.self, forKey: .premiumIntroSeen)
    }
}
