import SwiftUI

/// The scenic mood of a route. Drives the sky gradient used on cards, passes
/// and the fallback map.
///
/// Important: a mood gradient represents the *scene's* time of day (a "night"
/// route looks night-like even in Light Mode). It is intentionally fixed and
/// does NOT follow the app's light/dark appearance — that's the job of
/// `AppColors`, which themes the surrounding UI chrome.
enum RouteMood: String, Codable, CaseIterable, Identifiable, Hashable {
    case sunrise
    case sunset
    case night
    case aurora
    case ocean
    case mountains
    case city
    case calm
    case clouds

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sunrise:   return "Sunrise"
        case .sunset:    return "Sunset"
        case .night:     return "Night"
        case .aurora:    return "Aurora"
        case .ocean:     return "Ocean"
        case .mountains: return "Mountains"
        case .city:      return "City"
        case .calm:      return "Calm"
        case .clouds:    return "Clouds"
        }
    }

    var systemImage: String {
        switch self {
        case .sunrise:   return "sunrise"
        case .sunset:    return "sunset"
        case .night:     return "moon.stars"
        case .aurora:    return "sparkles"
        case .ocean:     return "water.waves"
        case .mountains: return "mountain.2"
        case .city:      return "building.2"
        case .calm:      return "wind"
        case .clouds:    return "cloud"
        }
    }

    /// Top-to-bottom scenic gradient stops.
    var skyColors: [Color] {
        switch self {
        case .sunrise:
            return [hex(0x2B2A5A), hex(0xE9826B), hex(0xFFD9A0)]
        case .sunset:
            return [hex(0x3A2A6A), hex(0xC2557E), hex(0xF2A65A)]
        case .night:
            return [hex(0x0A1026), hex(0x131F44), hex(0x274270)]
        case .aurora:
            return [hex(0x0A1430), hex(0x1C6E5A), hex(0x3E2E73)]
        case .ocean:
            return [hex(0x073042), hex(0x0E6E86), hex(0x67C2D6)]
        case .mountains:
            return [hex(0x2A3A55), hex(0x5C7596), hex(0xC7D6E6)]
        case .city:
            return [hex(0x1A2240), hex(0x3B3A66), hex(0x8A6E9E)]
        case .calm:
            return [hex(0x3E4E7A), hex(0x7E92C4), hex(0xD8E2F2)]
        case .clouds:
            return [hex(0x5C7FB5), hex(0x9FBEE0), hex(0xECF3FB)]
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: skyColors, startPoint: .top, endPoint: .bottom)
    }

    /// Whether the scene reads as dark (used to pick legible text on top).
    var isDarkScene: Bool {
        switch self {
        case .night, .aurora, .ocean, .city, .sunrise, .sunset: return true
        case .mountains, .calm, .clouds: return false
        }
    }

    /// Preferred foreground for text drawn directly on the mood gradient.
    var preferredForeground: Color {
        isDarkScene ? .white : hex(0x1B2436)
    }
}

extension RouteMood {
    fileprivate func hex(_ value: UInt) -> Color { Color(hex: value) }
}
