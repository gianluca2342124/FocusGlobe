import Foundation
import ObjectiveC.runtime

/// The ONE thing that decides which language FocusGlobe renders in.
///
/// WHY THIS EXISTS AT ALL — AND WHY `.environment(\.locale)` IS NOT ENOUGH
///
/// It is easy to believe that
///
///     .environment(\.locale, Locale(identifier: "es"))
///
/// at the window root makes `Text("Welcome")` Spanish. It does not, and this
/// app shipped a build that proved it on a real device: every screen stayed
/// English while the selector correctly showed Español.
///
/// The reason is that the two things are answered by different systems:
///
///   * `\.locale` answers "how do I FORMAT a value?" — date order, decimal
///     separator, grouping, and which CLDR plural category a number falls into.
///   * The BUNDLE answers "which localization table do I READ?" — and every
///     SwiftUI API that takes a `LocalizedStringKey` (`Text`, `Button`, `Label`,
///     `Link`, `navigationTitle`, `alert`, `confirmationDialog`,
///     `accessibilityLabel`, …) resolves through
///     `Bundle.main.localizedString(forKey:value:table:)`.
///
/// `Bundle.main` picks its table from the app's PREFERRED LOCALIZATIONS, which
/// come from the device's language settings. Nothing in the SwiftUI environment
/// changes that. On an English iPhone the answer is always English, whatever
/// the environment locale says.
///
/// So FocusGlobe has to change the answer at the bundle. `activate(_:)` does
/// exactly one thing: it points `Bundle.main`'s string lookup at the `.lproj`
/// of the chosen language. Every existing call site is then correct with no
/// edit — including the ones that could not be fixed individually, because
/// `Button(_:)`, `Label(_:)`, `Link(_:)` and the `navigationTitle` /
/// `alert` / `accessibilityLabel` modifiers take a `LocalizedStringKey` and
/// offer no `bundle:` parameter to steer.
///
/// THE THREE CONTEXTS, kept deliberately separate:
///
///   A. STATIC SWIFTUI COPY — `Text("…")` and friends. Resolves through the
///      swapped `Bundle.main`, so it follows the FocusGlobe selection and
///      re-renders when `\.locale` changes at the root.
///   B. COPY THAT MUST BE A `String` — model titles, notification bodies,
///      anything composed before it reaches a view. Uses `string(_:)` /
///      `localized(_:)` below, which read the SAME selection.
///   C. SEPARATE PROCESSES — widgets and the Shield extensions compile none of
///      this. They carry their own read-only copy of the resolver and read the
///      language code from the App Group mirror `activate(_:)` writes.
///
/// Nothing here consults `Locale.current`. When FocusGlobe has an explicit
/// language, the device language is not consulted at all.
enum FocusLocalization {

    // MARK: - Selection

    /// The App Group key the app writes and the extensions read. Shared with
    /// `FocusGlobeShared.appGroupID`, so this adds no new storage mechanism.
    static let languageDefaultsKey = "fg.selectedLanguageCode"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: FocusGlobeShared.appGroupID) ?? .standard
    }

    private static let lock = NSLock()
    /// The `.lproj` every string lookup is answered from. `nil` means "use the
    /// bundle's own development language", which is the correct answer for
    /// English and the only safe answer when a localization is genuinely absent.
    private static var activeLproj: Bundle?
    /// The in-process selection. Authoritative over the App Group mirror, which
    /// exists for the OTHER processes.
    private static var activeLanguage: FocusLanguage?
    private static var didInstallBundleOverride = false
    private static var lprojCache: [String: Bundle?] = [:]

    /// Make `language` the language FocusGlobe renders in, for this process.
    ///
    /// Call it once at launch — before the first view is built — and again on
    /// every change. It is idempotent and cheap after the first call.
    ///
    /// The class swap is installed on the FIRST call regardless of which
    /// language it is, because English needs the override in place too: it is
    /// what lets a later switch to Spanish take effect without a relaunch.
    static func activate(_ language: FocusLanguage) {
        let resolved = lproj(for: language)

        lock.lock()
        activeLanguage = language
        activeLproj = resolved
        let needsInstall = !didInstallBundleOverride
        didInstallBundleOverride = true
        lock.unlock()

        if needsInstall {
            // `object_setClass` is public Objective-C runtime API and this
            // replaces no system behaviour: the subclass overrides ONE method
            // and forwards to `super` whenever there is no active override.
            object_setClass(Bundle.main, FocusLocalizedMainBundle.self)
        }
        mirror(language)
    }

    /// Read by the bundle subclass on every lookup, so it stays cheap.
    fileprivate static var currentLproj: Bundle? {
        lock.lock()
        defer { lock.unlock() }
        return activeLproj
    }

    /// The app writes here whenever the selection changes. Extensions only ever
    /// read: the app is the single source of truth for language, and a widget
    /// or shield must never be able to change it.
    static func mirror(_ language: FocusLanguage) {
        defaults.set(language.code, forKey: languageDefaultsKey)
    }

    /// The language every surface should use.
    ///
    /// The in-process selection wins; the App Group mirror is the fallback for
    /// the moment before `activate(_:)` has run. Falls back to the device
    /// preference only when FocusGlobe has never been told anything.
    static var current: FocusLanguage {
        lock.lock()
        let inProcess = activeLanguage
        lock.unlock()
        if let inProcess { return inProcess }
        guard let code = defaults.string(forKey: languageDefaultsKey) else {
            return .devicePreferred
        }
        return FocusLanguage.resolve(code)
    }

    static var currentLocale: Locale { Locale(identifier: current.code) }

    // MARK: - Finding the localization the BUILD actually emitted

    /// The `.lproj` bundle for a language, or `nil` when this target ships no
    /// localization for it.
    ///
    /// `nil` — never `Bundle.main` — is load-bearing twice over. It is what
    /// stops `FocusLocalizedMainBundle` recursing into itself, and it is what
    /// distinguishes "fall back to English because the translation is genuinely
    /// absent" from "silently show English even though Spanish shipped".
    ///
    /// Directory names are AUDITED rather than guessed. `Bundle.main
    /// .localizations` is what the build actually produced, and
    /// `preferredLocalizations(from:forPreferences:)` is the system's own
    /// matcher — it is what correctly maps a request for `pt-BR` onto whichever
    /// of `pt-BR` / `pt` shipped, and `zh-Hans` onto `zh-Hans`. Its result is
    /// then checked against the requested language, because left alone that API
    /// answers "en" for a language it cannot match, which is precisely the
    /// silent-English failure this must not reintroduce.
    static func lproj(for language: FocusLanguage) -> Bundle? {
        lock.lock()
        if let cached = lprojCache[language.code] { lock.unlock(); return cached }
        lock.unlock()

        let base = String(language.code.split(separator: "-")[0]).lowercased()
        var candidates: [String] = []
        if let matched = Bundle.preferredLocalizations(
            from: Bundle.main.localizations, forPreferences: [language.code]).first,
           matched.lowercased().hasPrefix(base) {
            candidates.append(matched)
        }
        candidates.append(language.code)
        candidates.append(base)

        var resolved: Bundle?
        for candidate in candidates {
            guard let path = Bundle.main.path(forResource: candidate, ofType: "lproj"),
                  let bundle = Bundle(path: path),
                  bundle !== Bundle.main
            else { continue }
            resolved = bundle
            break
        }

        lock.lock()
        lprojCache[language.code] = resolved
        lock.unlock()
        return resolved
    }

    /// Which of the eleven this target actually shipped a localization for.
    /// Used by the DEBUG self-check and useful when diagnosing a build.
    static var availableLanguages: [FocusLanguage] {
        FocusLanguage.allCases.filter { $0 == .english || lproj(for: $0) != nil }
    }

    // MARK: - Context B: copy that has to be a `String`

    /// Look up a key in FocusGlobe's chosen language.
    ///
    /// The key IS the English source string, matching how the String Catalog is
    /// authored, so an untranslated key degrades to readable English rather
    /// than to a token.
    ///
    /// For a key whose wording depends on a NUMBER, use `localized(_:)` — this
    /// returns the raw `.stringsdict` rule for a pluralised key, not a sentence.
    static func string(_ key: String, language: FocusLanguage? = nil) -> String {
        let target = language ?? current
        let bundle = lproj(for: target) ?? .main
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    /// Interpolating variant. Arguments are positional (`%@`, `%lld`) so a
    /// translation may reorder them — which several of these languages need.
    static func string(_ key: String, _ arguments: CVarArg...,
                       language: FocusLanguage? = nil) -> String {
        String(format: string(key, language: language),
               locale: Locale(identifier: (language ?? current).code),
               arguments: arguments)
    }

    /// The same lookup for a *literal* with interpolation, e.g.
    /// `FocusLocalization.localized("\(days) day")`.
    ///
    /// Written as a separate name rather than an overload of `string(_:)`: both
    /// `String` and `String.LocalizationValue` are expressible by string
    /// literal, so an overload pair would be ambiguous at every literal call
    /// site.
    ///
    /// This is the form to use whenever the result depends on a NUMBER. The
    /// `locale:` argument is what picks the plural category, and the catalog
    /// carries a `plural` variation per language — Russian has four categories
    /// and Chinese has one, so appending an English "s" is wrong nearly
    /// everywhere.
    static func localized(_ value: String.LocalizationValue,
                          language: FocusLanguage? = nil) -> String {
        let target = language ?? current
        return String(localized: value,
                      bundle: lproj(for: target) ?? .main,
                      locale: Locale(identifier: target.code))
    }

    // MARK: - Proof

    #if DEBUG
    /// Structurally proves the resolver reaches a non-English table.
    ///
    /// A green catalog audit says the translations EXIST; it says nothing about
    /// whether the running app can reach them. This asks the question the
    /// device asked: for a key that certainly has a Spanish value, does the
    /// resolver return the Spanish one?
    ///
    /// Returns `nil` on success, else the first failure. Never ships UI.
    static func _selfCheck(key: String = "Continue") -> String? {
        let english = lproj(for: .english)?
            .localizedString(forKey: key, value: nil, table: nil)
            ?? Bundle.main.localizedString(forKey: key, value: nil, table: nil)

        for language in [FocusLanguage.spanish, .german, .simplifiedChinese, .portuguese] {
            guard let bundle = lproj(for: language) else {
                return "[Localization] no .lproj shipped for \(language.code) — "
                     + "the catalog is not being emitted for that language"
            }
            let value = bundle.localizedString(forKey: key, value: nil, table: nil)
            if value == key {
                return "[Localization] \(language.code) has no entry for \(key.debugDescription)"
            }
            if value == english {
                return "[Localization] \(language.code) resolved to the English value "
                     + "\(value.debugDescription) — the wrong table is being read"
            }
        }
        return nil
    }
    #endif
}

/// `Bundle.main` with its string lookup redirected.
///
/// Installed once by `FocusLocalization.activate(_:)` via `object_setClass`.
/// One override, and it forwards to `super` whenever there is no active
/// language bundle — so with no selection the app behaves exactly as an
/// unmodified app would.
///
/// It cannot recurse: `FocusLocalization.lproj(for:)` returns `nil` rather than
/// `Bundle.main` when a localization is missing, so `currentLproj` is never
/// this object.
private final class FocusLocalizedMainBundle: Bundle {
    override func localizedString(forKey key: String,
                                  value: String?,
                                  table tableName: String?) -> String {
        guard let target = FocusLocalization.currentLproj else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return target.localizedString(forKey: key, value: value, table: tableName)
    }
}
