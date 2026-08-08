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
///     forRegionCode:)` is the right source, so this type is only the plumbing
///     that gets an ISO code out of the data we have.
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
    static func name(forRegionCode code: String,
                     language: FocusLanguage? = nil) -> String? {
        let identifier = code.uppercased()
        guard !identifier.isEmpty else { return nil }
        let locale = Locale(identifier: (language ?? FocusLocalization.current).code)
        return locale.localizedString(forRegionCode: identifier)
    }

    /// The FocusGlobe-language name for a country we only have as text.
    ///
    /// Returns the input unchanged when it is not a country at all — which is
    /// the common case, because the same call also runs over region names like
    /// "Catalonia" that must survive untouched.
    ///
    /// Matching is done against every language FocusGlobe ships, not only
    /// English. Most of the data is canonical English, but `LocationService`
    /// hands back whatever the geocoder said, and that is already localized. A
    /// pilot who resolves their location in Spanish and then switches to French
    /// should see "Allemagne", not the "Alemania" that happened to be stored.
    static func localized(country name: String,
                          language: FocusLanguage? = nil) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return name }
        guard let code = regionCode(forName: trimmed) else { return name }
        return Self.name(forRegionCode: code, language: language) ?? name
    }

    /// The ISO code behind a country name written in any of our languages.
    static func regionCode(forName name: String) -> String? {
        index[fold(name)]
    }

    // MARK: - The reverse index

    /// `folded name -> ISO code`, built once from Foundation's own tables.
    ///
    /// Built for the eleven languages FocusGlobe ships rather than English
    /// alone, so a name that arrived from the geocoder in one language can
    /// still be re-rendered in another.
    ///
    /// English is inserted LAST and wins ties on purpose: the bundled JSON is
    /// English, and a collision between an English country name and some other
    /// language's name for a different country must resolve to the English
    /// reading of what is in our data.
    private static let index: [String: String] = {
        var table: [String: String] = [:]
        // Two-letter identifiers only. `isoRegions` also carries the numeric
        // macro-regions ("150" Europe, "001" World), which are not countries
        // and whose names would collide with nothing useful.
        let codes = Locale.Region.isoRegions
            .map(\.identifier)
            .filter { $0.count == 2 }

        var languages = FocusLanguage.allCases.map(\.code).filter { $0 != "en" }
        languages.append("en")

        for language in languages {
            let locale = Locale(identifier: language)
            for code in codes {
                guard let name = locale.localizedString(forRegionCode: code)
                else { continue }
                table[fold(name)] = code
            }
        }

        // Names our data uses that CLDR files under a different primary form.
        // Kept short on purpose: anything that can be answered by Foundation
        // must be, and this exists only for the handful it cannot.
        for (alias, code) in ["turkey": "TR", "holland": "NL",
                              "czech republic": "CZ", "burma": "MM",
                              "ivory coast": "CI", "cape verde": "CV",
                              "swaziland": "SZ", "macedonia": "MK",
                              "united states of america": "US",
                              "great britain": "GB", "russian federation": "RU",
                              "republic of korea": "KR", "uae": "AE"] {
            table[fold(alias)] = code
        }
        return table
    }()

    /// Case-, accent- and article-insensitive, so "Türkiye", "TURKIYE" and
    /// "The Bahamas" all reach the same row.
    private static func fold(_ value: String) -> String {
        var folded = value.folding(options: [.diacriticInsensitive,
                                             .caseInsensitive,
                                             .widthInsensitive],
                                   locale: Locale(identifier: "en_US_POSIX"))
        folded = folded.trimmingCharacters(in: .whitespacesAndNewlines)
        for article in ["the ", "les ", "la ", "le ", "los ", "el "] {
            if folded.hasPrefix(article) {
                folded = String(folded.dropFirst(article.count))
                break
            }
        }
        return folded
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

    // MARK: - Proof

    #if DEBUG
    /// Every country name in the bundled geography that this cannot resolve.
    ///
    /// Empty is the passing result. A non-empty answer means the JSON gained a
    /// spelling Foundation does not use, and that country is about to show in
    /// English on a Spanish phone — the exact defect this type exists to close.
    static func _unresolvedCountryNames() -> [String] {
        var names = Set(WorldCityCatalog.countries.map(\.country))
        names.formUnion(TravelNetworkCatalog.allNodes.map(\.country))
        return names.filter { !$0.isEmpty && regionCode(forName: $0) == nil }.sorted()
    }
    #endif
}
