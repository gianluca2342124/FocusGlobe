import Foundation

// ============================================================================
//  Widget-target copy of the language resolver.
//
//  WHY A COPY: the app's canonical file lives at
//  `FocusGlobe/Shared/FocusLocalization.swift`, which belongs to the **app**
//  target's file-system-synchronised group. With Xcode 16 synchronised groups a
//  single file can't auto-belong to two targets — the same constraint that gave
//  `WidgetData.swift` its copy of `FocusGlobeShared`.
//
//  This copy is deliberately smaller. The app's version resolves a
//  `FocusLanguage` case; a widget only ever needs to turn the CODE the app
//  wrote into a bundle, so it carries no enum and no list of languages. Adding
//  a language to FocusGlobe therefore needs no change here.
// ============================================================================

/// The language FocusGlobe is running in, read from the App Group.
///
/// A widget is a separate process. `.environment(\.locale, …)` in the app never
/// reaches it, and `Locale.current` here is the DEVICE's language — so a pilot
/// running FocusGlobe in French on an English phone would get an English
/// widget. Reading the app's own choice is the only thing that fixes that.
///
/// **Read only.** The app is the single source of truth for language; a widget
/// must never be able to change what the app is showing.
enum FocusLocalization {

    /// Written by the app's `AppModel.preferredLanguage`. Shares the existing
    /// App Group — this adds no new storage mechanism.
    static let languageDefaultsKey = "fg.selectedLanguageCode"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: FocusGlobeShared.appGroupID) ?? .standard
    }

    /// `nil` when the app has never written a preference — a widget added
    /// before FocusGlobe was first opened. The device language is then correct.
    static var currentCode: String? {
        defaults.string(forKey: languageDefaultsKey)
    }

    /// Steers FORMATTING (numbers, plural category selection). Which language's
    /// table is read is decided by `bundle` below — `locale:` alone cannot do
    /// it, which is the whole reason this type exists.
    static var currentLocale: Locale {
        guard let code = currentCode else { return .autoupdatingCurrent }
        return Locale(identifier: code)
    }

    private static var bundleCache: [String: Bundle] = [:]
    private static let cacheLock = NSLock()

    /// The `.lproj` bundle for the chosen language, or `.main` when this target
    /// does not ship it — in which case the caller gets the development
    /// language rather than a raw key.
    ///
    /// A timeline reload asks for a dozen strings in a row and `Bundle(path:)`
    /// touches the file system, so resolved bundles are kept.
    static func bundle() -> Bundle {
        guard let code = currentCode else { return .main }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = bundleCache[code] { return cached }

        var resolved = Bundle.main
        // `zh-Hans` and `pt-BR` are tried whole first and then by base subtag,
        // because Xcode may write either directory name.
        for candidate in [code, String(code.split(separator: "-")[0])] {
            if let path = Bundle.main.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                resolved = bundle
                break
            }
        }
        bundleCache[code] = resolved
        return resolved
    }

    /// The key IS the English source string, matching how the String Catalog is
    /// authored, so a key with no translation degrades to readable English.
    static func string(_ key: String) -> String {
        bundle().localizedString(forKey: key, value: nil, table: nil)
    }

    /// Interpolating variant. Arguments are positional (`%@`, `%lld`) so a
    /// translation may reorder them.
    static func string(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: currentLocale, arguments: arguments)
    }

    /// The form to use whenever the wording depends on a NUMBER: `locale:`
    /// picks the plural category and the catalog carries one variation per
    /// language. Named differently from `string(_:)` because `String` and
    /// `String.LocalizationValue` are both expressible by string literal, so an
    /// overload pair would be ambiguous at every call site.
    static func localized(_ value: String.LocalizationValue) -> String {
        String(localized: value, bundle: bundle(), locale: currentLocale)
    }
}
