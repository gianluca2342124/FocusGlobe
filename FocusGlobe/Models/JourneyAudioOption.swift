import SwiftUI

/// A selectable ambience that loops during an active journey.
///
/// `Wind` is the free default. The rest require an **active** Pro subscription
/// (they re-lock if Pro lapses; see `AppModel.isAudioUnlocked`). Each option
/// maps to a bundled audio file named `assetName` (see AUDIO_SETUP.md). If a
/// file is missing the audio engine falls back to a procedural wind loop, so the
/// feature works before any audio is added and never crashes.
struct JourneyAudioOption: Identifiable, Hashable {
    /// The identity. Persisted in `settings.selectedJourneyAudioID`, sent to
    /// Supabase, matched against `loopFileName` — it is never shown and never
    /// translated.
    let id: String
    /// The English display copy, which doubles as the catalog key. Kept as
    /// plain text so it can be handed to `Text(LocalizedStringKey(_:))` inside a
    /// view or resolved through `localizedName` outside one.
    let displayName: String

    /// The name to SHOW, in the language FocusGlobe is set to.
    ///
    /// Use this anywhere the soundscape's name is composed into a String — a
    /// results row, an accessibility label, a summary line. Inside a view body
    /// `Text(LocalizedStringKey(displayName))` is equivalent and preferred,
    /// because it redraws when the language changes.
    var localizedName: String { FocusLocalization.string(displayName) }
    /// Bundled audio file name (without extension). The player searches common
    /// extensions (.mp3, .m4a, .wav, .caf) in `Bundle.main`.
    let assetName: String
    let isPremium: Bool
    let sortOrder: Int
    /// SF Symbol for the selection row.
    let systemImage: String

    /// Preferred local loop file base name — drop `<name>.mp3` (or .m4a/.wav/.caf)
    /// into the app bundle. Underscored variant of the id, e.g. `wind_loop`,
    /// `focus_music_loop`, `rain_loop`, `jazz_loop`.
    var loopFileName: String { "\(id.replacingOccurrences(of: "-", with: "_"))_loop" }

    /// Accepted bundled file base names, in priority order: the `*_loop`
    /// convention first, then the legacy `JourneyAudio…` name. The audio engine
    /// plays the first one that exists, so a selected premium option plays its
    /// own file (never silently falling back to Wind) when the file is present.
    var assetCandidates: [String] { [loopFileName, assetName] }

    /// Optional bundled cover art for the soundscape carousel/cards —
    /// `SoundCover_<PascalId>` (e.g. `SoundCover_AlphaWaves`). Rendered when
    /// present; otherwise a premium procedural gradient card stands in.
    var coverAssetName: String {
        "SoundCover_" + id.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    /// The soundscape's signature colour — drives the procedural cover gradient
    /// and any accenting when no cover image is present.
    var accent: Color {
        switch id {
        case "wind":        return Color(hex: 0x6FB7C9)
        case "focus-music": return Color(hex: 0x8F7BE8)
        case "alpha-waves": return Color(hex: 0x6E7BE0)
        case "rain":        return Color(hex: 0x5A8FC9)
        case "ocean":       return Color(hex: 0x2E9CA6)
        case "relaxing":    return Color(hex: 0x5FB98C)
        case "jazz":        return Color(hex: 0xD9A24E)
        default:            return Color(hex: 0x6FB7C9)
        }
    }

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
