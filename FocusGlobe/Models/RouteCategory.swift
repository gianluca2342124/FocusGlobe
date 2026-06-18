import Foundation

/// Duration buckets used for filtering and grouping routes.
enum RouteCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case micro
    case short
    case deep
    case long
    case ultra

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .micro: return "Micro"
        case .short: return "Short"
        case .deep:  return "Deep"
        case .long:  return "Long"
        case .ultra: return "Ultra"
        }
    }

    /// Short helper shown under the title in the picker.
    var subtitle: String {
        switch self {
        case .micro: return "5–15 min"
        case .short: return "20–30 min"
        case .deep:  return "45–90 min"
        case .long:  return "2–4 hours"
        case .ultra: return "6–12 hours"
        }
    }

    var systemImage: String {
        switch self {
        case .micro: return "sparkle"
        case .short: return "leaf"
        case .deep:  return "mountain.2"
        case .long:  return "moon.stars"
        case .ultra: return "infinity"
        }
    }

    /// Sort order for display.
    var order: Int {
        switch self {
        case .micro: return 0
        case .short: return 1
        case .deep:  return 2
        case .long:  return 3
        case .ultra: return 4
        }
    }
}
