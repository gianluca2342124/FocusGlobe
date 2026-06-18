import SwiftUI

/// A route's accent palette. Drives the route polyline colour, the vehicle
/// glow and small highlight touches. Independent from `RouteMood` so designers
/// have two knobs: the *scene* (mood) and the *accent* (theme).
enum RouteTheme: String, Codable, CaseIterable, Identifiable, Hashable {
    case blush
    case gold
    case indigo
    case aurora
    case teal
    case slate
    case lavender
    case mint
    case coral

    var id: String { rawValue }

    /// The primary accent (used for the route line and highlights).
    var accent: Color {
        switch self {
        case .blush:    return Color(hex: 0xE8728C)
        case .gold:     return Color(hex: 0xE0A23E)
        case .indigo:   return Color(hex: 0x5B6CF0)
        case .aurora:   return Color(hex: 0x34C79E)
        case .teal:     return Color(hex: 0x2FA9C2)
        case .slate:    return Color(hex: 0x7E91AE)
        case .lavender: return Color(hex: 0x9C86E8)
        case .mint:     return Color(hex: 0x5CC894)
        case .coral:    return Color(hex: 0xF2795A)
        }
    }

    /// A softer tint of the accent for fills and glows.
    var soft: Color {
        switch self {
        case .blush:    return Color(hex: 0xF2A6B3)
        case .gold:     return Color(hex: 0xF2C879)
        case .indigo:   return Color(hex: 0x8E9BFF)
        case .aurora:   return Color(hex: 0x6FE0C0)
        case .teal:     return Color(hex: 0x5FD0E0)
        case .slate:    return Color(hex: 0xA9B7CE)
        case .lavender: return Color(hex: 0xC3B6F2)
        case .mint:     return Color(hex: 0x9FE6C2)
        case .coral:    return Color(hex: 0xFFB29A)
        }
    }
}
