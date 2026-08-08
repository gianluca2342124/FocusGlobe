import Foundation

/// The journey's starting point — the user's real current location, or a city
/// they pick manually. Journeys are always `currentOrigin → selectedDestination`,
/// so origin is never baked into a destination.
struct JourneyOrigin: Equatable, Hashable, Codable {
    var city: String
    var country: String
    var coordinate: GeoCoordinate
    var code: String

    /// The origin's ISO 3166-1 alpha-2 region, when it is known.
    ///
    /// `country` above is TEXT — whatever the catalog spells or the geocoder
    /// answered, in whatever language it happened to answer in. This is the
    /// IDENTITY, and it is what lets the country line be re-rendered in the
    /// selected language later: a pilot who resolves their location in Spanish
    /// and then switches to German reads "Deutschland", not the "Alemania" that
    /// happened to be stored.
    ///
    /// Optional and additive on purpose. An origin persisted by an older build
    /// has no code, decodes as `nil`, and simply falls back to displaying
    /// `country` as it always did.
    var countryCode: String?

    init(city: String, country: String = "", coordinate: GeoCoordinate,
         code: String? = nil, countryCode: String? = nil) {
        self.city = city
        self.country = country
        self.coordinate = coordinate
        self.code = code ?? JourneyOrigin.code(for: city)
        self.countryCode = countryCode
    }

    /// A neutral default used only as a last-resort journey origin. It is never
    /// presented on Home as if it were the user's real, detected location.
    static let `default` = JourneyOrigin(
        city: "Barcelona", country: "Spain",
        coordinate: GeoCoordinate(latitude: 41.3874, longitude: 2.1686), code: "BCN",
        countryCode: "ES"
    )

    /// An airport-style 3-letter code derived from a city name.
    static func code(for city: String) -> String {
        let letters = city.uppercased().filter { $0.isLetter }
        return letters.isEmpty ? "YOU" : String(letters.prefix(3))
    }
}
