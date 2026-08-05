import Foundation

/// The languages FocusGlobe can present itself in.
///
/// `.system` is the default and means "follow the device". It is a real,
/// distinct value rather than a synonym for English: a pilot who never touches
/// the setting must keep getting their device's date, number and currency
/// formatting, and must automatically pick up a new language the day that
/// language becomes release-ready — without a migration.
enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case english
    case spanish
    case italian

    var id: String { rawValue }

    /// BCP-47 code. `nil` for `.system`, which has no code of its own.
    var languageCode: String? {
        switch self {
        case .system:  return nil
        case .english: return "en"
        case .spanish: return "es"
        case .italian: return "it"
        }
    }

    /// The name of the language IN that language — correctly NOT translated:
    /// Español reads Español whatever language the rest of the UI is in, which
    /// is the whole point of a language picker. Never a flag either: flags are
    /// countries, and Spanish is not Spain any more than English is England.
    ///
    /// `.system` has no endonym; this returns the English word as a fallback for
    /// diagnostics. User-facing code calls `label(_:)`.
    var endonym: String {
        switch self {
        case .system:  return "System"
        case .english: return "English"
        case .spanish: return "Español"
        case .italian: return "Italiano"
        }
    }

    /// The label to show a pilot. Only `.system` is translated — it is a word
    /// about their device, not the name of a language.
    func label(_ strings: FocusStrings) -> String {
        self == .system ? strings(.obLanguageSystem) : endonym
    }

    /// For diagnostics and analytics only — never shown to a pilot.
    var analyticsID: String { languageCode ?? "system" }

    /// Every language except `.system`, in the order a picker should list them.
    static var concreteCases: [AppLanguage] { [.english, .spanish, .italian] }

    /// Resolve `.system` against the device's preferred languages, restricted to
    /// languages that are actually release-ready. A device set to Spanish gets
    /// Spanish only once Spanish is complete; until then it gets English, which
    /// is the truthful outcome rather than a half-translated one.
    static func resolvedFromSystem(preferred: [String] = Locale.preferredLanguages) -> AppLanguage {
        for identifier in preferred {
            let code = Locale(identifier: identifier).language.languageCode?.identifier
            guard let code else { continue }
            if let match = concreteCases.first(where: { $0.languageCode == code }),
               LocalizationCoverage.isReleaseReady(match) {
                return match
            }
        }
        return .english
    }

    /// What `.system` resolves to, decided once per process.
    ///
    /// Cached because `resolved` sits in the hot path — every string lookup in
    /// every view body calls it — and resolving walks the coverage table. iOS
    /// relaunches an app when the device language changes, so a value that
    /// lives for the process lifetime is exactly as fresh as an uncached one.
    private static let systemResolved: AppLanguage = AppLanguage.resolvedFromSystem()

    /// The concrete language whose strings should be used.
    var resolved: AppLanguage {
        guard self == .system else { return self }
        return Self.systemResolved
    }

    /// The locale to inject at the window root.
    ///
    /// `.system` deliberately returns `autoupdatingCurrent` rather than a locale
    /// built from the resolved language: a pilot in Italy who reads English must
    /// still see Italian dates, 24-hour time and comma decimals. Only an
    /// explicit choice overrides regional formatting.
    var locale: Locale {
        guard let code = languageCode else { return .autoupdatingCurrent }
        return Locale(identifier: code)
    }

    /// Decode a stored identifier, tolerating a value written by a build that
    /// offered a language this one does not.
    static func fromStoredID(_ stored: String?) -> AppLanguage {
        guard let stored, let value = AppLanguage(rawValue: stored) else { return .system }
        return value
    }

    /// The languages a pilot may actually choose right now.
    ///
    /// Derived from `LocalizationCoverage`, not hand-maintained, so a language
    /// cannot appear in the picker because someone forgot to remove it.
    static var selectable: [AppLanguage] {
        concreteCases.filter { LocalizationCoverage.isReleaseReady($0) }
    }

    /// Whether a language control should be shown at all. One choice is not a
    /// choice, so with a single release-ready language every entry point — the
    /// Settings row and the welcome-screen picker — stays hidden rather than
    /// rendering a control that cannot change anything.
    static var offersLanguageChoice: Bool { selectable.count > 1 }
}

// MARK: - Coverage

/// The user-facing surfaces a pilot reaches after onboarding.
///
/// This list is the release gate. A language ships only when EVERY surface here
/// is translated — because the failure mode being prevented is specific and
/// severe: a pilot picks Español on the welcome screen, completes a fully
/// Spanish onboarding, taps "Start my first flight", and lands on an entirely
/// English app. That is worse than never offering Spanish at all.
enum LocalizationSurface: String, CaseIterable, Sendable {
    case onboarding
    case paywalls
    case home
    case flightSetup
    case activeJourney
    case store
    case passport
    case friends
    case settings
    case account
    case widgets
    case shieldExtension
    case notifications

    var displayName: String {
        switch self {
        case .onboarding:      return "Onboarding"
        case .paywalls:        return "Paywalls"
        case .home:            return "Home"
        case .flightSetup:     return "Flight setup"
        case .activeJourney:   return "Active journey"
        case .store:           return "Store"
        case .passport:        return "Passport"
        case .friends:         return "Friends"
        case .settings:        return "Settings"
        case .account:         return "Account & sign-in"
        case .widgets:         return "Widgets"
        case .shieldExtension: return "Screen Time shield"
        case .notifications:   return "Notifications"
        }
    }

    /// Whether this surface's user-facing text is routed through the string
    /// table at all. A surface built from Swift string literals cannot be
    /// translated by adding entries to the table, so it is `false` here until
    /// its views are converted — regardless of how many keys the table holds.
    var routesThroughStringTable: Bool {
        switch self {
        case .onboarding, .paywalls:
            return true
        case .home, .flightSetup, .activeJourney, .store, .passport, .friends,
             .settings, .account, .widgets, .shieldExtension, .notifications:
            // Still built from literals. Converting them is the remaining
            // localization release task; see LOCALIZATION.md.
            return false
        }
    }
}

/// What is actually translated, computed rather than declared.
///
/// The two inputs are both mechanical: whether a surface routes through the
/// table at all, and whether that language supplies every key. Nothing here is
/// a promise someone typed — which is the point, because a hand-maintained
/// "yes we translated it" flag is exactly how a half-translated language ships.
enum LocalizationCoverage {

    enum Status: String, Sendable {
        /// Every string on this surface resolves in this language.
        case complete
        /// Routed through the table, but this language is missing some keys.
        case partial
        /// Not routed through the table yet — untranslatable by any table entry.
        case notRouted
    }

    static func status(of surface: LocalizationSurface, in language: AppLanguage) -> Status {
        let language = language.resolved
        // English is the SOURCE language: a literal sitting in a view is already
        // English, so whether that surface routes through the table has no
        // bearing on whether English is complete. It always is, by definition.
        if language == .english { return .complete }
        guard surface.routesThroughStringTable else { return .notRouted }
        let missing = FocusStringTable.missingKeys(for: language, surface: surface)
        return missing.isEmpty ? .complete : .partial
    }

    /// The languages that pass the gate, computed once per process.
    ///
    /// Cached deliberately: `isReleaseReady` is reached from `AppLanguage`'s
    /// `.system` resolution, which every string lookup touches. Re-evaluating
    /// every surface against every key on each of those would be a per-frame
    /// cost for an answer that cannot change while the app is running — the
    /// tables are compiled in.
    ///
    /// Safe from recursion: the initializer only ever asks about CONCRETE
    /// languages, and `resolved` returns those unchanged without consulting
    /// coverage.
    private static let releaseReadyLanguages: Set<AppLanguage> = Set(
        AppLanguage.concreteCases.filter { language in
            LocalizationSurface.allCases.allSatisfy {
                LocalizationCoverage.status(of: $0, in: language) == .complete
            }
        }
    )

    /// A language is release-ready only when every surface is `.complete`.
    static func isReleaseReady(_ language: AppLanguage) -> Bool {
        releaseReadyLanguages.contains(language.resolved)
    }

    /// A human-readable manifest, used by the DEBUG launch report and by
    /// `LOCALIZATION.md`. Deliberately reports the truth even when it is
    /// unflattering.
    static func manifest() -> String {
        var lines: [String] = ["Surface                | " + AppLanguage.concreteCases.map(\.endonym).joined(separator: " | ")]
        for surface in LocalizationSurface.allCases {
            let cells = AppLanguage.concreteCases.map { status(of: surface, in: $0).rawValue }
            lines.append(surface.displayName.padding(toLength: 22, withPad: " ", startingAt: 0)
                         + " | " + cells.joined(separator: " | "))
        }
        lines.append("")
        for language in AppLanguage.concreteCases {
            let ready = isReleaseReady(language) ? "release-ready" : "NOT release-ready"
            let missing = FocusStringTable.missingKeys(for: language, surface: nil).count
            lines.append("\(language.endonym): \(ready) — \(missing) untranslated key(s)")
        }
        return lines.joined(separator: "\n")
    }

    #if DEBUG
    /// Guards the gate itself. The rules that must never quietly invert.
    static func _selfCheck() -> String? {
        // English is the source language and must always be ready.
        if !isReleaseReady(.english) { return "English must always be release-ready" }
        if !AppLanguage.selectable.contains(.english) { return "English is not selectable" }
        // The CACHE must agree with the live computation. `selectable` is built
        // from the cache, so checking it against itself would prove nothing —
        // this re-derives each offered language from the tables.
        for language in AppLanguage.selectable {
            let live = LocalizationSurface.allCases.allSatisfy { status(of: $0, in: language) == .complete }
            if !live { return "\(language.endonym) is offered but is not actually complete" }
        }
        // Nothing incomplete may be reachable, by any route.
        for language in AppLanguage.concreteCases where !isReleaseReady(language) {
            if AppLanguage.selectable.contains(language) {
                return "\(language.endonym) leaked into the picker"
            }
            if AppLanguage.resolvedFromSystem(preferred: [language.languageCode ?? ""]) == language {
                return "a device set to \(language.endonym) would be given an unfinished translation"
            }
        }
        // `.system` must never appear as a concrete language, and must always
        // resolve onto a language that is finished.
        if AppLanguage.concreteCases.contains(.system) { return ".system leaked into concreteCases" }
        let resolved = AppLanguage.system.resolved
        if resolved == .system { return ".system resolved to itself" }
        if !isReleaseReady(resolved) { return ".system resolved to a language that is not ready" }
        return nil
    }
    #endif
}
