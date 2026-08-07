import Foundation

/// Resolving FocusGlobe's chosen language OUTSIDE the SwiftUI view tree.
///
/// `.environment(\.locale, …)` at the window root is enough for SwiftUI: `Text`
/// and every `LocalizedStringKey` overload resolve through it. Three surfaces
/// are not SwiftUI views in this process and get nothing from it:
///
///  * **Notifications** — `UNMutableNotificationContent.title` is a plain
///    `String`, built when the notification is SCHEDULED, days before it is
///    shown. `String(localized:)` alone would resolve against the system
///    language, so a pilot running FocusGlobe in French on an English phone
///    would get English reminders.
///  * **The Shield extensions** — separate processes. They never see the app's
///    environment at all.
///  * **Widgets** — a separate process with its own timeline reloads.
///
/// All three read the same App Group mirror written by the app, then look up
/// strings in the matching `.lproj` bundle. `String(localized:locale:)` is NOT
/// sufficient on its own: `locale:` steers formatting, not which language's
/// table is consulted. Only a language-specific `Bundle` does that.
///
/// Every lookup falls back — missing bundle, missing key, missing translation —
/// to the development language. A pilot never sees a raw key.
enum FocusLocalization {

    /// The App Group key the app writes and the extensions read. Shared with
    /// `FocusGlobeShared.appGroupID`, so this adds no new storage mechanism.
    static let languageDefaultsKey = "fg.selectedLanguageCode"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: FocusGlobeShared.appGroupID) ?? .standard
    }

    /// The app writes here whenever the selection changes. Extensions only ever
    /// read: the app is the single source of truth for language, and a widget
    /// or shield must never be able to change it.
    static func mirror(_ language: FocusLanguage) {
        defaults.set(language.code, forKey: languageDefaultsKey)
    }

    /// The language every non-SwiftUI surface should use.
    ///
    /// Falls back to the device's preference when the mirror has never been
    /// written — a widget added before the app was first opened, for instance.
    static var current: FocusLanguage {
        guard let code = defaults.string(forKey: languageDefaultsKey) else {
            return .devicePreferred
        }
        return FocusLanguage.resolve(code)
    }

    static var currentLocale: Locale { Locale(identifier: current.code) }

    /// Bundles are resolved once and kept: `Bundle(path:)` touches the file
    /// system, and notification scheduling can ask for a dozen strings in a row.
    private static var bundleCache: [String: Bundle] = [:]
    private static let cacheLock = NSLock()

    /// The `.lproj` bundle for a language, or `nil` when this target does not
    /// ship that language — in which case the caller uses `.main` and gets the
    /// development language.
    ///
    /// `zh-Hans` and `pt-BR` are tried whole first and then by their base
    /// subtag, because Xcode may write either directory name depending on how
    /// the catalog was authored.
    static func bundle(for language: FocusLanguage) -> Bundle {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = bundleCache[language.code] { return cached }

        var resolved = Bundle.main
        for candidate in [language.code, String(language.code.split(separator: "-")[0])] {
            if let path = Bundle.main.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                resolved = bundle
                break
            }
        }
        bundleCache[language.code] = resolved
        return resolved
    }

    /// Look up a string in FocusGlobe's chosen language.
    ///
    /// For notification bodies, Shield copy and widget text — anywhere a plain
    /// `String` is needed rather than a SwiftUI `Text`. The key IS the English
    /// source string, matching how the String Catalog is authored, so an
    /// untranslated key degrades to readable English rather than to a token.
    static func string(_ key: String, language: FocusLanguage? = nil) -> String {
        let target = language ?? current
        let bundle = bundle(for: target)
        let value = bundle.localizedString(forKey: key, value: nil, table: nil)
        // `localizedString` returns the key itself when there is no entry. The
        // key is the English source, so that is already the correct fallback.
        return value
    }

    /// Interpolating variant. Arguments are positional (`%@`, `%lld`) so a
    /// translation may reorder them — which several of these languages need.
    static func string(_ key: String, _ arguments: CVarArg...,
                       language: FocusLanguage? = nil) -> String {
        String(format: string(key, language: language),
               locale: Locale(identifier: (language ?? current).code),
               arguments: arguments)
    }
}
