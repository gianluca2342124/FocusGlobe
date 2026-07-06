import Foundation

/// Duration buckets used for filtering and grouping routes.
/// Journeys start at 30 minutes — there is no ultra-short category.
enum RouteCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case short
    case deep
    case long
    case ultra

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .short: return "Short"
        case .deep:  return "Deep"
        case .long:  return "Long"
        case .ultra: return "Grand"   // user-facing "Grand Expedition"; internal case name stays `.ultra`
        }
    }

    /// Short helper shown under the title in the picker.
    var subtitle: String {
        switch self {
        case .short: return "30 min"
        case .deep:  return "45–90 min"
        case .long:  return "2–4 hours"
        case .ultra: return "6–12 hours"
        }
    }

    var systemImage: String {
        switch self {
        case .short: return "leaf"
        case .deep:  return "mountain.2"
        case .long:  return "moon.stars"
        case .ultra: return "infinity"
        }
    }

    /// Sort order for display.
    var order: Int {
        switch self {
        case .short: return 0
        case .deep:  return 1
        case .long:  return 2
        case .ultra: return 3
        }
    }
}
