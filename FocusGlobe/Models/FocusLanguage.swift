import Foundation

/// THE list of languages FocusGlobe offers, in the order it offers them.
///
/// One canonical list, deliberately. The Welcome selector used to derive its
/// options from `Bundle.main.localizations`, which sounds principled and is
/// exactly wrong for a chooser: an option vanishes the moment its `.lproj` is
/// missing, so shipping a translation and *offering* it become the same
/// deployment step, and a half-finished bundle silently removes languages from
/// the menu. What a pilot may choose is a product decision; what the bundle
/// happens to contain is a build artefact. This is the product decision.
///
/// Codes are BCP-47 and are what `Locale(identifier:)` receives, so Chinese is
/// `zh-Hans` — script-qualified, because "zh" alone leaves iOS to guess between
/// Simplified and Traditional and FocusGlobe only offers Simplified.
enum FocusLanguage: String, CaseIterable, Identifiable, Codable {
    case english        = "en"
    case simplifiedChinese = "zh-Hans"
    case hindi          = "hi"
    case spanish        = "es"
    case french         = "fr"
    case german         = "de"
    case russian        = "ru"
    case portuguese     = "pt"
    case italian        = "it"
    case romanian       = "ro"
    case dutch          = "nl"

    var id: String { rawValue }

    /// The BCP-47 identifier handed to `Locale(identifier:)`.
    var code: String { rawValue }

    var flag: String {
        switch self {
        case .english:           return "🇺🇸"
        case .simplifiedChinese: return "🇨🇳"
        case .hindi:             return "🇮🇳"
        case .spanish:           return "🇪🇸"
        case .french:            return "🇫🇷"
        case .german:            return "🇩🇪"
        case .russian:           return "🇷🇺"
        // Brazil, not Portugal: the overwhelming majority of Portuguese
        // speakers who will see this screen are Brazilian.
        case .portuguese:        return "🇧🇷"
        case .italian:           return "🇮🇹"
        case .romanian:          return "🇷🇴"
        case .dutch:             return "🇳🇱"
        }
    }

    /// The closed capsule's label. Kept genuinely short so the control stays a
    /// capsule — except where a two-letter Latin abbreviation would be
    /// meaningless to the people who read that language, in which case the
    /// native name IS the short form.
    var shortLabel: String {
        switch self {
        case .english:           return "EN"
        case .simplifiedChinese: return "中文"
        case .hindi:             return "हिन्दी"
        case .spanish:           return "ES"
        case .french:            return "FR"
        case .german:            return "DE"
        case .russian:           return "RU"
        case .portuguese:        return "PT"
        case .italian:           return "IT"
        case .romanian:          return "RO"
        case .dutch:             return "NL"
        }
    }

    /// The menu row. Endonyms — each language named as its own speakers name
    /// it — never "Chinese" rendered in English to someone who reads Chinese.
    /// Hardcoded rather than taken from `Locale.localizedString`, which returns
    /// the name in the CURRENT locale and would list every option in English
    /// until the app is already running in the language being chosen.
    var nativeName: String {
        switch self {
        case .english:           return "English"
        case .simplifiedChinese: return "中文"
        case .hindi:             return "हिन्दी"
        case .spanish:           return "Español"
        case .french:            return "Français"
        case .german:            return "Deutsch"
        case .russian:           return "Русский"
        case .portuguese:        return "Português"
        case .italian:           return "Italiano"
        case .romanian:          return "Română"
        case .dutch:             return "Nederlands"
        }
    }

    /// The fallback for everything: an unknown stored code, an unmatched device
    /// language, a corrupted preference.
    static let fallback: FocusLanguage = .english

    /// Resolve a stored or incoming code. Never fails — the selector always has
    /// a valid selection, and a code this build no longer offers resolves to
    /// English rather than leaving the capsule blank.
    static func resolve(_ code: String?) -> FocusLanguage {
        guard let code, !code.isEmpty else { return fallback }
        if let exact = FocusLanguage(rawValue: code) { return exact }
        return match(bcp47: code) ?? fallback
    }

    /// What to open on for a pilot who has never chosen.
    ///
    /// Walks the device's own ordered preference list, so someone whose phone is
    /// set to French-then-English gets French. Anything outside these eleven —
    /// Japanese, Arabic, Traditional Chinese — lands on English, which is the
    /// only honest answer while those are not offered.
    static var devicePreferred: FocusLanguage {
        for preferred in Locale.preferredLanguages {
            if let matched = match(bcp47: preferred) { return matched }
        }
        return fallback
    }

    /// Match a BCP-47 tag ("pt-BR", "zh-Hans-CN", "en_US") to an offered
    /// language, ignoring region and normalising separators.
    ///
    /// Chinese is the case worth spelling out: iOS reports Simplified as
    /// `zh-Hans-CN`, `zh-Hans` or, on older configurations, `zh-CN` / `zh-SG`.
    /// All of those mean Simplified and map here. `zh-Hant` and its regions
    /// (TW, HK, MO) mean Traditional, which FocusGlobe does NOT offer, so they
    /// deliberately fall through to English instead of being handed a script
    /// their readers would find wrong.
    static func match(bcp47 tag: String) -> FocusLanguage? {
        let normalized = tag.replacingOccurrences(of: "_", with: "-").lowercased()
        let parts = normalized.split(separator: "-").map(String.init)
        guard let language = parts.first else { return nil }

        if language == "zh" {
            let rest = Set(parts.dropFirst())
            if rest.contains("hant") || rest.contains("tw") || rest.contains("hk") || rest.contains("mo") {
                return nil
            }
            return .simplifiedChinese
        }
        return allCases.first { $0.code.lowercased() == language }
    }
}
