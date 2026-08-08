import Foundation

// ============================================================================
//  Shield-extension copy of the language resolver.
//
//  WHY A COPY: `FocusGlobe/Shared/FocusLocalization.swift` belongs to the app
//  target's file-system-synchronised group, and one file cannot auto-belong to
//  two targets. The shield extension also cannot import the widget target's
//  copy — the same reason `primaryOpensFocusGlobe` is duplicated between the
//  two shield extensions rather than shared.
//
//  Keep the resolution rules here identical to the app's. They are: read the
//  code the app wrote to the App Group, resolve its `.lproj`, fall back to the
//  development language.
// ============================================================================

/// The language FocusGlobe is running in, inside the Screen Time shield.
///
/// A shield extension is its own process, launched by the system at
/// unpredictable moments and never handed anything by the app. Without this it
/// would render in the DEVICE's language, so a pilot running FocusGlobe in
/// Romanian on an English phone would be blocked by an English screen.
///
/// **Read only**, and deliberately allocation-light: a shield extension is
/// memory-constrained, so this does no formatting and holds one cached bundle.
enum FocusLocalization {

    /// The canonical App Group, defined for the app in
    /// `FocusGlobe/Shared/WidgetSharedData.swift`. Repeated here because this
    /// target compiles none of the app's files; the two must stay identical.
    private static let appGroupID = "group.com.focusglobe.app"

    /// Written by the app's `AppModel.preferredLanguage`.
    private static let languageDefaultsKey = "fg.selectedLanguageCode"

    private static var currentCode: String? {
        UserDefaults(suiteName: appGroupID)?.string(forKey: languageDefaultsKey)
    }

    private static var cachedBundle: Bundle?
    private static var cachedCode: String?
    private static let cacheLock = NSLock()

    private static func bundle() -> Bundle {
        let code = currentCode
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = cachedBundle, cachedCode == code { return cached }

        var resolved = Bundle.main
        if let code {
            // `zh-Hans` and `pt-BR` are tried whole first and then by base
            // subtag, because Xcode may write either directory name.
            for candidate in [code, String(code.split(separator: "-")[0])] {
                if let path = Bundle.main.path(forResource: candidate, ofType: "lproj"),
                   let loaded = Bundle(path: path) {
                    resolved = loaded
                    break
                }
            }
        }
        cachedBundle = resolved
        cachedCode = code
        return resolved
    }

    /// The key IS the English source string, so a missing translation shows
    /// readable English rather than a token on a screen the pilot cannot leave.
    static func string(_ key: String) -> String {
        bundle().localizedString(forKey: key, value: nil, table: nil)
    }
}
