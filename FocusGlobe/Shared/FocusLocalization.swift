import Foundation

/// FocusGlobe's chosen language, for the code that cannot read the SwiftUI
/// environment.
///
/// THE DIVISION OF LABOUR — deliberately only two halves, not three:
///
///   A. SWIFTUI CONTENT resolves through the environment. `Text("Continue")`,
///      `Button("Continue")`, `Label(…)`, `navigationTitle`, `alert` and
///      `Text(LocalizedStringKey(key))` all take a `LocalizedStringKey`, and
///      `.environment(\.locale, appModel.preferredLocale)` at the root is what
///      selects the language for them. Nothing in this type participates in
///      that path, and nothing here modifies `Bundle.main`.
///
///   B. EVERYTHING THAT MUST BE A `String` BEFORE IT REACHES A VIEW resolves
///      here, explicitly, against the requested language: notification titles
///      and bodies composed at scheduling time, Shield copy, widget copy, and
///      the handful of model helpers that compose a sentence around a runtime
///      value.
///
/// Separate PROCESSES — widgets and the two Shield extensions — see neither the
/// environment nor this type. They carry their own read-only copy of the same
/// idea and read the language code from the App Group mirror written below.
///
/// Nothing here consults `Locale.current`. When FocusGlobe has an explicit
/// language, the device language is not consulted at all — that is the whole
/// point of offering the setting.
enum FocusLocalization {

    // MARK: - The selection

    /// The App Group key the app writes and the extensions read. Shared with
    /// `FocusGlobeShared.appGroupID`, so this adds no new storage mechanism.
    static let languageDefaultsKey = "fg.selectedLanguageCode"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: FocusGlobeShared.appGroupID) ?? .standard
    }

    private static let lock = NSLock()
    /// The in-process selection. Authoritative over the App Group mirror, which
    /// exists for the OTHER processes.
    private static var selected: FocusLanguage?
    private static var lprojCache: [String: Bundle?] = [:]

    /// Record the language this process should resolve `String`s in, and mirror
    /// the code for the processes that cannot see it.
    ///
    /// This changes FocusGlobe's own state and nothing else. It installs
    /// nothing, replaces no class and patches no framework: SwiftUI content is
    /// not routed through here at all, it follows `.environment(\.locale, …)`.
    static func select(_ language: FocusLanguage) {
        lock.lock()
        selected = language
        lock.unlock()
        mirror(language)
    }

    /// The app writes here whenever the selection changes. Extensions only ever
    /// read: the app is the single source of truth for language, and a widget
    /// or shield must never be able to change it.
    static func mirror(_ language: FocusLanguage) {
        defaults.set(language.code, forKey: languageDefaultsKey)
    }

    /// The language every non-SwiftUI surface should use.
    ///
    /// The in-process selection wins; the App Group mirror is the fallback for
    /// the moment before `select(_:)` has run. Falls back to the device
    /// preference only when FocusGlobe has never been told anything.
    static var current: FocusLanguage {
        lock.lock()
        let inProcess = selected
        lock.unlock()
        if let inProcess { return inProcess }
        guard let code = defaults.string(forKey: languageDefaultsKey) else {
            return .devicePreferred
        }
        return FocusLanguage.resolve(code)
    }

    /// The locale for non-SwiftUI FORMATTING — dates, numbers, percentages,
    /// month and weekday names. `Locale.current` would be the device's, which
    /// is exactly what a pilot running FocusGlobe in German on an English phone
    /// does not want.
    static var currentLocale: Locale { Locale(identifier: current.code) }

    // MARK: - Finding the localization the BUILD actually emitted

    /// The `.lproj` bundle for a language, or `nil` when this target ships no
    /// localization for it.
    ///
    /// Directory names are AUDITED rather than guessed. `Bundle.main
    /// .localizations` is what the build actually produced, and
    /// `preferredLocalizations(from:forPreferences:)` is the system's own
    /// matcher — it is what maps a request for `pt-BR` onto whichever of
    /// `pt-BR` / `pt` shipped, and `zh-Hans` onto `zh-Hans`. Its result is then
    /// checked against the requested language, because left alone that API
    /// answers "en" for a language it cannot match, which would silently show
    /// English for a language that did ship.
    ///
    /// `nil` rather than `Bundle.main` on a miss, so a caller can tell
    /// "translation genuinely absent" from "wrong table read".
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
                  let bundle = Bundle(path: path)
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

    /// How `LocalizedStringResource` should be told where to look.
    private static func bundleDescription(
        for language: FocusLanguage
    ) -> LocalizedStringResource.BundleDescription {
        guard let bundle = lproj(for: language) else { return .main }
        return .atURL(bundle.bundleURL)
    }

    // MARK: - Context B: copy that has to be a `String`

    /// Resolve a literal — with or without interpolation — in the requested
    /// language, e.g. `FocusLocalization.localized("\(days) day")`.
    ///
    /// This is Foundation's supported mechanism for rendering in a language
    /// other than the device's: a `LocalizedStringResource` carries its own
    /// `locale`, and lookup is performed for that locale rather than the
    /// current one. The bundle is named explicitly as well, so table selection
    /// and plural-rule selection are both pinned rather than inferred.
    ///
    /// It is also the form to use whenever the result depends on a NUMBER: the
    /// locale picks the plural category, and the catalog carries a `plural`
    /// variation per language — Russian has four categories and Chinese has
    /// one, so appending an English "s" is wrong nearly everywhere.
    ///
    /// Written as a separate name rather than an overload of `string(_:)`
    /// because both `String` and `String.LocalizationValue` are expressible by
    /// string literal, so an overload pair would be ambiguous at every literal
    /// call site.
    static func localized(_ value: String.LocalizationValue,
                          language: FocusLanguage? = nil) -> String {
        let target = language ?? current
        return String(localized: LocalizedStringResource(
            value,
            locale: Locale(identifier: target.code),
            bundle: bundleDescription(for: target)))
    }

    /// Resolve a key that is only known at RUNTIME — a rotating notification
    /// line picked from a pool, a model's stored English title, a Shield line
    /// chosen by the day index.
    ///
    /// `LocalizedStringResource` cannot serve this: its key is a literal, by
    /// design. The supported answer for a runtime key is an explicit lookup in
    /// an explicitly resolved bundle, which is what this is — a specific
    /// `.lproj`, never a modified `Bundle.main`.
    ///
    /// The key IS the English source string, matching how the String Catalog is
    /// authored, so an untranslated key degrades to readable English rather
    /// than to a token.
    ///
    /// For a key whose wording depends on a number, use `localized(_:)` — this
    /// returns the raw `.stringsdict` rule for a pluralised key, not a sentence.
    static func string(_ key: String, language: FocusLanguage? = nil) -> String {
        let target = language ?? current
        let bundle = lproj(for: target) ?? .main
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    /// Interpolating variant of the runtime-key lookup. Arguments are
    /// positional (`%@`, `%lld`) so a translation may reorder them — which
    /// several of these languages need.
    static func string(_ key: String, _ arguments: CVarArg...,
                       language: FocusLanguage? = nil) -> String {
        String(format: string(key, language: language),
               locale: Locale(identifier: (language ?? current).code),
               arguments: arguments)
    }

    // MARK: - Proof

    #if DEBUG
    /// Structurally proves the explicit resolver reaches a non-English table.
    ///
    /// A green catalog audit says the translations EXIST; it says nothing about
    /// whether the running app can reach them. This asks the question the
    /// device asked, for both context-B paths — the runtime-key lookup and the
    /// `LocalizedStringResource` one.
    ///
    /// It does NOT exercise the SwiftUI path: that one is the environment's
    /// job, and there is no view hierarchy at launch to ask.
    ///
    /// Returns `nil` on success, else the first failure. Never ships UI.
    static func _selfCheck(key: String = "Welcome to FocusGlobe") -> String? {
        let english = (lproj(for: .english) ?? .main)
            .localizedString(forKey: key, value: nil, table: nil)

        for language in [FocusLanguage.spanish, .german, .simplifiedChinese, .portuguese] {
            guard lproj(for: language) != nil else {
                return "[Localization] no .lproj shipped for \(language.code) — "
                     + "the catalog is not being emitted for that language"
            }
            let value = string(key, language: language)
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
