import Foundation

/// Country names, rendered in the language FocusGlobe is set to.
///
/// THE PROBLEM
///     FocusGlobe's geography ships as English text. `WorldCities.json` says
///     `"country": "Germany"`, `TravelDestinations.json` says `"Spain"`, and
///     both are drawn straight into the starting-city picker and the journey
///     subtitle. Switching the app to Spanish translated every label around
///     them and left the countries in English.
///
/// WHY NOT A CATALOG
///     Because these are ISO 3166-1 regions, and the system already knows all
///     of their names in all eleven of our languages. Ten hand-written
///     translations of "Germany" would be ten chances to be wrong, would need
///     extending for every country added to the JSON, and would duplicate a
///     table Apple ships and keeps current. `Locale.localizedString(
///     forRegionCode:)` is the right source — ONCE YOU KNOW THE CODE. Getting
///     the code is the part that must not be a guess, and it is not one: it
///     comes from `CanonicalRegionCodes`, a fixed table, or from an ISO code the
///     data already carries.
///
/// WHAT THIS TYPE NO LONGER DOES
///     It used to derive the code by asking Foundation for every region's name
///     in all eleven languages and looking the bundled string up in the result.
///     That made a DISPLAY string the lookup key, so resolution depended on
///     Apple's wording matching ours exactly — and the first time it did not,
///     the app refused to launch. Nothing here compares translated text any
///     more. See `CanonicalRegionCodes` for the full argument.
///
/// WHAT IS *NOT* HANDLED HERE, DELIBERATELY
///     * CITIES. "Paris", "Barcelona", "Tokyo" are proper names and stay as
///       they are. Foundation has no city table to consult, and inventing one
///       is a product decision, not a localization fix.
///     * SUBDIVISIONS. "Catalonia", "Lazio", "Île-de-France". ISO 3166-2 has
///       codes for these, but Foundation exposes no display names for them, so
///       there is nothing locale-aware to call. They stay canonical rather than
///       becoming ten more strings to maintain by hand.
///     * IDENTIFIERS. `countryCode`, `code`, `routeID`, anything persisted.
///       Nothing here writes; every entry point takes a name and returns a name
///       for a label that is about to be drawn.
enum RegionDisplayNames {

    /// The name of an ISO 3166-1 region in the FocusGlobe language.
    /// `nil` when the code is not a region Foundation recognises.
    ///
    /// The language is FocusGlobe's selected one, never the phone's: a pilot
    /// running the app in Spanish on an English handset reads "Alemania".
    static func name(forRegionCode code: String,
                     language: FocusLanguage? = nil) -> String? {
        let identifier = code.uppercased()
        guard !identifier.isEmpty else { return nil }
        let locale = Locale(identifier: (language ?? FocusLocalization.current).code)
        return locale.localizedString(forRegionCode: identifier)
    }

    /// The FocusGlobe-language name for a country we only have as text.
    ///
    /// Returns the input unchanged when the name is not one of the countries
    /// FocusGlobe ships — which is the common case, because the same call also
    /// runs over subdivision names like "Catalonia" that must survive
    /// untouched, and over whatever a geocoder happened to say.
    ///
    /// This is the SAFE path in every direction. An unknown value is displayed
    /// exactly as it was supplied; a known value whose code Foundation cannot
    /// name is displayed exactly as it was supplied. Nothing here can fail a
    /// launch, empty a label, or invent a country.
    static func localized(country name: String,
                          language: FocusLanguage? = nil) -> String {
        guard let code = regionCode(forName: name) else {
            #if DEBUG
            logUnresolved(name)
            #endif
            return name
        }
        return Self.name(forRegionCode: code, language: language) ?? name
    }

    /// The ISO 3166-1 alpha-2 code behind a written country name.
    ///
    /// One table lookup against `CanonicalRegionCodes`. No locale is consulted,
    /// no display string is compared, and the answer is the same on every OS
    /// version and in every app language — which is the entire point.
    static func regionCode(forName name: String) -> String? {
        CanonicalRegionCodes.code(for: name)
    }

    // MARK: - Ordering

    /// Sort country names the way the selected language sorts them.
    ///
    /// The catalog is stored alphabetically by its ENGLISH name, which puts
    /// Germany between France and Greece. In Spanish that list reads Francia,
    /// Alemania, Grecia — sorted by nothing at all. Display order has to follow
    /// the displayed text.
    static func sortedByLocalizedName<T>(_ items: [T],
                                         language: FocusLanguage? = nil,
                                         name: (T) -> String) -> [T] {
        let locale = Locale(identifier: (language ?? FocusLocalization.current).code)
        return items.sorted {
            name($0).compare(name($1), options: [.caseInsensitive, .diacriticInsensitive],
                             range: nil, locale: locale) == .orderedAscending
        }
    }

    // MARK: - Diagnostics

    #if DEBUG
    /// Names already reported, so a list that redraws on every keystroke does
    /// not fill the console with the same line.
    private static var reportedUnresolved = Set<String>()
    private static let reportLock = NSLock()

    /// Note, once, that a value reached a country label without a region code.
    ///
    /// SUBDIVISIONS APPEAR HERE AND THAT IS CORRECT. "Catalonia", "Lazio" and
    /// "Hokkaido" are not countries, have no ISO 3166-1 code, and are supposed
    /// to print exactly as written. The line is worth having anyway, because it
    /// is also where a country arrives spelled in a way nothing recognises —
    /// which is the condition that used to be discovered by the app refusing to
    /// launch. It is a `print`, and only in DEBUG: a country we cannot name is a
    /// cosmetic problem, and cosmetic problems do not stop launches.
    private static func logUnresolved(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        reportLock.lock()
        let isNew = reportedUnresolved.insert(trimmed).inserted
        reportLock.unlock()
        guard isNew else { return }
        print("[Localization] not an ISO region: \"\(trimmed)\" — shown as supplied")
    }

    /// Every country name in the bundled geography that this cannot resolve.
    ///
    /// Empty is the passing result, and after the canonical table it IS empty.
    /// A non-empty answer means the JSON gained a country nobody added to
    /// `CanonicalRegionCodes`, and that country is about to show in English on
    /// a Spanish phone.
    ///
    /// It is a REPORT, not an assertion. The startup path logs it; the strict
    /// version that fails is `Tools/region_audit.py`, which reads the same two
    /// JSON files and the same table without needing the app to run at all.
    static func _unresolvedCountryNames() -> [String] {
        bundledCountryNames().filter { regionCode(forName: $0) == nil }.sorted()
    }

    /// `(total, resolved, unresolved)` — the one line worth printing at launch,
    /// because "72 of 72" is the fact being claimed.
    static func _countryCoverage() -> (total: Int, resolved: Int, unresolved: [String]) {
        let total = bundledCountryNames().count
        let unresolved = _unresolvedCountryNames()
        return (total, total - unresolved.count, unresolved)
    }

    /// Every distinct, non-empty country value FocusGlobe ships.
    private static func bundledCountryNames() -> Set<String> {
        var names = Set(WorldCityCatalog.countries.map(\.country))
        names.formUnion(TravelNetworkCatalog.allNodes.map(\.country))
        names = names.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return names
    }
    #endif
}
