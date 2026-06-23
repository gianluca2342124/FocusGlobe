import Foundation

/// User-selectable map presentation, surfaced as floating controls in the
/// session. On Apple Maps the user-facing set is just Dark Earth / Standard /
/// Satellite (see `selectable`); the other cases (including the legacy
/// "monochrome") are decode-only values kept so older persisted settings keep
/// decoding (they map to the closest Apple style in `AppleMapStyle`).
enum MapDisplayStyle: String, CaseIterable, Codable, Identifiable {
    case monochrome   // dark/graphite land, near-black sea — legacy, decode-only
    case terra        // "Dark Earth": Apple Standard, but dark/premium (default)
    case standard     // native Apple standard (green/yellow land, blue sea)
    case satellite    // native Apple imagery (labels via the Labels toggle)
    // Legacy (not shown in the menu; decode-only):
    case graphite
    case terrain
    case hybrid
    case night

    var id: String { rawValue }

    /// The only styles shown to the user (Apple-appropriate). "Dark Earth" is the
    /// premium default; Monochrome is intentionally not user-selectable.
    static let selectable: [MapDisplayStyle] = [.terra, .standard, .satellite]

    var displayName: String {
        switch self {
        case .monochrome: return "Monochrome"
        case .terra:      return "Dark Earth"
        case .standard:   return "Standard"
        case .satellite:  return "Satellite"
        case .graphite:   return "Monochrome"
        case .terrain:    return "Dark Earth"
        case .hybrid:     return "Satellite"
        case .night:      return "Monochrome"
        }
    }

    var systemImage: String {
        switch self {
        case .monochrome: return "circle.lefthalf.filled"
        case .terra:      return "moon.stars.fill"
        case .standard:   return "map.fill"
        case .satellite:  return "globe.americas.fill"
        case .graphite:   return "circle.lefthalf.filled"
        case .terrain:    return "moon.stars.fill"
        case .hybrid:     return "globe.americas.fill"
        case .night:      return "moon.stars.fill"
        }
    }

    /// Dark presentations (kept clean during the active flight — no extra scrim).
    var isDark: Bool {
        switch self {
        case .monochrome, .terra, .graphite, .night, .terrain: return true
        case .standard, .satellite, .hybrid:                   return false
        }
    }
}

/// Calm, minimal Google Maps style JSON for Light and Dark mode.
///
/// These hide busy POIs, businesses and transit so the map stays serene and
/// the route + balloon are the focus. Used only by the Google renderer; the
/// fallback map styles itself with the route's mood gradient.
enum MapStyles {

    /// The premium default: a calm graphite "dark terrain" look — dark grey land,
    /// near-black grey ocean, subtle grey labels. Neutral (no navy/blue), not
    /// satellite, not bright. Used as the default backdrop and session style.
    static let graphite = """
    [
      {"elementType":"geometry","stylers":[{"color":"#232a31"}]},
      {"elementType":"labels.text.fill","stylers":[{"color":"#8d96a3"}]},
      {"elementType":"labels.text.stroke","stylers":[{"color":"#161a1f"}]},
      {"featureType":"poi","stylers":[{"visibility":"off"}]},
      {"featureType":"transit","stylers":[{"visibility":"off"}]},
      {"featureType":"road","elementType":"labels","stylers":[{"visibility":"off"}]},
      {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2d343d"}]},
      {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},
      {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},
      {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#9aa3b1"}]},
      {"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#aab2c0"}]},
      {"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#262d35"}]},
      {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#222931"}]},
      {"featureType":"water","elementType":"geometry","stylers":[{"color":"#12161b"}]},
      {"featureType":"water","elementType":"labels","stylers":[{"visibility":"off"}]}
    ]
    """

    static let light = """
    [
      {"featureType":"poi","stylers":[{"visibility":"off"}]},
      {"featureType":"poi.park","elementType":"geometry","stylers":[{"visibility":"on"},{"color":"#dceccd"}]},
      {"featureType":"transit","stylers":[{"visibility":"off"}]},
      {"featureType":"road","elementType":"labels","stylers":[{"visibility":"off"}]},
      {"featureType":"road","elementType":"geometry","stylers":[{"color":"#f3f4f7"}]},
      {"featureType":"administrative","elementType":"labels","stylers":[{"lightness":20}]},
      {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},
      {"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#eef1f6"}]},
      {"featureType":"water","elementType":"geometry","stylers":[{"color":"#bcd6ea"}]},
      {"featureType":"water","elementType":"labels","stylers":[{"visibility":"off"}]}
    ]
    """

    static let dark = """
    [
      {"elementType":"geometry","stylers":[{"color":"#0c1326"}]},
      {"elementType":"labels.text.fill","stylers":[{"color":"#7b87a6"}]},
      {"elementType":"labels.text.stroke","stylers":[{"color":"#070b18"}]},
      {"featureType":"poi","stylers":[{"visibility":"off"}]},
      {"featureType":"transit","stylers":[{"visibility":"off"}]},
      {"featureType":"road","elementType":"labels","stylers":[{"visibility":"off"}]},
      {"featureType":"road","elementType":"geometry","stylers":[{"color":"#141d38"}]},
      {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},
      {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#8a96b6"}]},
      {"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#9aa6c4"}]},
      {"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#0f1730"}]},
      {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#101a36"}]},
      {"featureType":"water","elementType":"geometry","stylers":[{"color":"#070d1e"}]},
      {"featureType":"water","elementType":"labels","stylers":[{"visibility":"off"}]}
    ]
    """

    /// A calm grayscale ("Mono") style — desaturated land/water, soft labels.
    static let monochrome = """
    [
      {"elementType":"geometry","stylers":[{"color":"#e9eaec"}]},
      {"elementType":"labels.text.fill","stylers":[{"color":"#6b6f76"}]},
      {"elementType":"labels.text.stroke","stylers":[{"color":"#ffffff"}]},
      {"featureType":"poi","stylers":[{"visibility":"off"}]},
      {"featureType":"transit","stylers":[{"visibility":"off"}]},
      {"featureType":"road","elementType":"labels","stylers":[{"visibility":"off"}]},
      {"featureType":"road","elementType":"geometry","stylers":[{"color":"#dcdee1"}]},
      {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},
      {"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#dfe1e4"}]},
      {"featureType":"water","elementType":"geometry","stylers":[{"color":"#c7cacf"}]},
      {"featureType":"water","elementType":"labels","stylers":[{"visibility":"off"}]}
    ]
    """
}
