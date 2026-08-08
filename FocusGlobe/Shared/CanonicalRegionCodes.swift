import Foundation

/// The one place a FocusGlobe country VALUE becomes a country IDENTITY.
///
/// WHY THIS EXISTS
///     FocusGlobe's geography ships country names as English text, and the app
///     needs those names in ten other languages. The obvious shortcut is to ask
///     Foundation for every region's English name and look the bundled string up
///     in the result. That shortcut shipped, and it crashed the app on launch:
///     Apple's own English name for `CN` is not the word our JSON uses, so
///     "China" — alone out of seventy-two countries — matched nothing.
///
///     The bug is not the missing row. The bug is the strategy. A display name
///     is PRESENTATION: Apple revises it (Turkey became Türkiye, the Czech
///     Republic became Czechia), varies it by platform, and is free to render a
///     region however reads best in each language. Nothing about it is promised
///     to be stable, and nothing about it is an identifier. An ISO 3166-1
///     alpha-2 code is: two letters, assigned once, unchanged when the name
///     changes.
///
/// THE DIRECTION OF RESOLUTION
///     bundled value  ->  ISO 3166-1 alpha-2  ->  selected language  ->  display
///     Only the first arrow lives here, and it is a fixed table rather than a
///     search. The second is `Locale.localizedString(forRegionCode:)`, which is
///     the right tool once you know WHICH region you are naming. At no point
///     does a translated string get compared to another translated string.
///
/// WHAT IS IN THE TABLE
///     Every distinct country value in `WorldCities.json` and
///     `TravelDestinations.json` — all seventy-two, audited, not sampled — plus
///     the handful of legacy English spellings for those same countries that a
///     stored preference or an older build can still hand us. Nothing else. This
///     is deliberately NOT a world gazetteer: a code for a country FocusGlobe
///     does not ship is a row nobody can reach and nobody can verify.
///
/// ADDING A COUNTRY
///     Add the destination to the JSON, add its name here, and run
///     `python3 Tools/region_audit.py`, which fails if the two ever disagree.
enum CanonicalRegionCodes {

    /// The ISO 3166-1 alpha-2 code for a country name, or `nil` when the name
    /// is not one of the countries FocusGlobe ships.
    ///
    /// `nil` is an ordinary answer, not a failure. The same call runs over
    /// subdivision names — "Catalonia", "Lazio", "Hokkaido" — which are not
    /// countries and must come back untouched.
    static func code(for name: String) -> String? {
        table[normalize(name)]
    }

    // MARK: - Normalization

    /// Reduce a written country name to its lookup key.
    ///
    /// Case, accents, full-width forms, stray or non-breaking whitespace, the
    /// separating comma in "Korea, South" and the full stops in "U.S.A." are all
    /// noise around the same name, so they are removed. That is the whole of it:
    /// this normalises PUNCTUATION, it does not guess. Two different countries
    /// never collapse onto one key, and a name that is not in the table stays
    /// unresolved rather than being matched to whatever it resembles.
    static func normalize(_ value: String) -> String {
        var folded = value.folding(options: [.diacriticInsensitive,
                                             .caseInsensitive,
                                             .widthInsensitive],
                                   locale: Locale(identifier: "en_US_POSIX"))
        folded = folded.replacingOccurrences(of: ".", with: "")
        folded = folded.replacingOccurrences(of: ",", with: " ")
        // Collapses runs, tabs and U+00A0 alike — `isWhitespace` covers them all.
        var key = folded.split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        // English keeps an optional article on a few country names ("The
        // Bahamas"); the table stores the bare form.
        if key.hasPrefix("the ") { key = String(key.dropFirst(4)) }
        return key
    }

    // MARK: - The table

    /// `normalized name -> ISO 3166-1 alpha-2`.
    ///
    /// Keys are stored already normalised — lower case, unaccented — and the
    /// DEBUG self-check proves it, so no key can rot into something
    /// `normalize` would never produce.
    ///
    /// Every code below was cross-checked two ways: against the `countryCode`
    /// already carried by `WorldCities.json`, and against ISO 3166-1 itself.
    /// The forty-nine countries that appear in both agreed on all forty-nine.
    static let table: [String: String] = [

        // ---- Europe ------------------------------------------------------
        "andorra": "AD",
        "austria": "AT",
        "belgium": "BE",
        "croatia": "HR",
        "czechia": "CZ",
        "denmark": "DK",
        "finland": "FI",
        "france": "FR",
        "germany": "DE",
        "greece": "GR",
        "hungary": "HU",
        "iceland": "IS",
        "ireland": "IE",
        "italy": "IT",
        "luxembourg": "LU",
        "netherlands": "NL",
        "norway": "NO",
        "poland": "PL",
        "portugal": "PT",
        "spain": "ES",
        "sweden": "SE",
        "switzerland": "CH",
        "turkiye": "TR",
        "united kingdom": "GB",

        // ---- Africa ------------------------------------------------------
        "algeria": "DZ",
        "egypt": "EG",
        "kenya": "KE",
        "mauritius": "MU",
        "morocco": "MA",
        "mozambique": "MZ",
        "namibia": "NA",
        "rwanda": "RW",
        "seychelles": "SC",
        "south africa": "ZA",
        "tanzania": "TZ",
        "tunisia": "TN",
        "uganda": "UG",
        "zimbabwe": "ZW",

        // ---- Middle East -------------------------------------------------
        "bahrain": "BH",
        "israel": "IL",
        "jordan": "JO",
        "lebanon": "LB",
        "oman": "OM",
        "qatar": "QA",
        "saudi arabia": "SA",
        "united arab emirates": "AE",

        // ---- Asia --------------------------------------------------------
        // `china` is the row whose absence crashed the app. It is here as a
        // fact about ISO 3166-1, not as a guess about what Apple calls CN.
        "china": "CN",
        "india": "IN",
        "indonesia": "ID",
        "japan": "JP",
        "malaysia": "MY",
        "maldives": "MV",
        "philippines": "PH",
        "singapore": "SG",
        "south korea": "KR",
        "thailand": "TH",
        "vietnam": "VN",

        // ---- Americas ----------------------------------------------------
        "argentina": "AR",
        "bahamas": "BS",
        "brazil": "BR",
        "canada": "CA",
        "chile": "CL",
        "colombia": "CO",
        "cuba": "CU",
        "mexico": "MX",
        "peru": "PE",
        "united states": "US",
        "uruguay": "UY",

        // ---- Oceania -----------------------------------------------------
        "australia": "AU",
        "fiji": "FJ",
        "french polynesia": "PF",
        "new zealand": "NZ",

        // ---- Subdivision values with a stable ISO 3166-1 code ------------
        // `JourneyPlanner.subtitle` sends the region slot through the same
        // resolver, and this one region is an ISO-coded territory in its own
        // right, so it can be named properly in ten languages instead of
        // staying English. Every other subdivision in the data — Catalonia,
        // Lazio, Hokkaido — has no such code and is left alone.
        "canary islands": "IC",

        // ---- Legacy and alternate English spellings ----------------------
        // ONLY for countries FocusGlobe actually ships, and only forms that can
        // genuinely reach us: a preference persisted by an older build, a hand
        // written value, an import that used the ISO long form. This is not a
        // place to collect synonyms — every row below names a country that is
        // already in the table under its current spelling.
        "turkey": "TR",                     // pre-2022 English name for Türkiye
        "czech republic": "CZ",             // pre-2016 English name for Czechia
        "holland": "NL",                    // colloquial, and was already shipped
        "great britain": "GB",
        "uk": "GB",
        "united states of america": "US",   // ISO 3166-1 long form
        "usa": "US",
        "korea south": "KR",                // "Korea, South" once the comma folds
        "republic of korea": "KR",          // ISO 3166-1 long form
        "uae": "AE",
        "viet nam": "VN",                   // ISO 3166-1 two-word form
        // Russia is NOT in the bundled geography. These two rows exist because
        // the shipped alias list carried "Russian Federation", so a persisted
        // starting city could hold one of them; they cost nothing and losing
        // them would be a silent regression.
        "russia": "RU",
        "russian federation": "RU",
    ]

    // MARK: - Proof

    #if DEBUG
    /// Structural faults in the table itself, independent of any bundled data.
    ///
    /// Cheap, and it catches the two mistakes a hand-written table invites: a
    /// key written in a form `normalize` would never produce (so it can never
    /// match), and a code that is not a well-formed alpha-2 identifier.
    static func _selfCheck() -> String? {
        for (key, code) in table {
            if normalize(key) != key {
                return "[Region] table key \"\(key)\" is not normalised "
                     + "(normalize gives \"\(normalize(key))\")"
            }
            guard code.count == 2, code.allSatisfy({ $0.isASCII && $0.isUppercase }) else {
                return "[Region] \"\(key)\" maps to \"\(code)\", which is not an "
                     + "ISO 3166-1 alpha-2 code"
            }
        }
        return nil
    }
    #endif
}
