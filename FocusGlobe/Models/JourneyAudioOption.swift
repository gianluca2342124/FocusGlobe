import SwiftUI

/// A selectable ambience that loops during an active journey.
///
/// `Wind` is the free default. The rest require an **active** Pro subscription
/// (they re-lock if Pro lapses; see `AppModel.isAudioUnlocked`). Each option
/// maps to a bundled audio file named `assetName` (see AUDIO_SETUP.md). If a
/// file is missing the audio engine falls back to a procedural wind loop, so the
/// feature works before any audio is added and never crashes.
struct JourneyAudioOption: Identifiable, Hashable {
    let id: String
    let displayName: String
    /// Bundled audio file name (without extension). The player searches common
    /// extensions (.mp3, .m4a, .wav, .caf) in `Bundle.main`.
    let assetName: String
    let isPremium: Bool
    let sortOrder: Int
    /// SF Symbol for the selection row.
    let systemImage: String

    // MARK: Catalog

    /// All options in display order. `Wind` first (free), then the premium set.
    static let all: [JourneyAudioOption] = [
        JourneyAudioOption(id: "wind", displayName: "Wind",
                           assetName: "JourneyAudioWind", isPremium: false,
                           sortOrder: 0, systemImage: "wind"),
        JourneyAudioOption(id: "focus-music", displayName: "Focus Music",
                           assetName: "JourneyAudioFocusMusic", isPremium: true,
                           sortOrder: 1, systemImage: "music.note"),
        JourneyAudioOption(id: "alpha-waves", displayName: "Alpha Waves",
                           assetName: "JourneyAudioAlphaWaves", isPremium: true,
                           sortOrder: 2, systemImage: "waveform"),
        JourneyAudioOption(id: "rain", displayName: "Rain",
                           assetName: "JourneyAudioRain", isPremium: true,
                           sortOrder: 3, systemImage: "cloud.rain.fill"),
        JourneyAudioOption(id: "ocean", displayName: "Ocean",
                           assetName: "JourneyAudioOcean", isPremium: true,
                           sortOrder: 4, systemImage: "water.waves"),
        JourneyAudioOption(id: "relaxing", displayName: "Relaxing",
                           assetName: "JourneyAudioRelaxing", isPremium: true,
                           sortOrder: 5, systemImage: "leaf.fill"),
        JourneyAudioOption(id: "jazz", displayName: "Jazz",
                           assetName: "JourneyAudioJazz", isPremium: true,
                           sortOrder: 6, systemImage: "music.quarternote.3"),
    ]

    /// The free default ambience.
    static let wind = all[0]

    static func option(id: String?) -> JourneyAudioOption {
        guard let id else { return wind }
        return all.first { $0.id == id } ?? wind
    }
}
