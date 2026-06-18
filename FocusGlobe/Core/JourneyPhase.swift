import Foundation

/// The narrative state of a journey, derived purely from progress.
///
/// This is provider-independent business logic. The map renderer never decides
/// the phase — it only reflects it.
enum JourneyPhase: String, CaseIterable {
    case boarding
    case takingOff
    case cruising
    case approaching
    case landing

    /// Phase from a `0...1` progress value.
    ///
    /// - Boarding: exactly 0%
    /// - Taking Off: 0–10%
    /// - Cruising: 10–80%
    /// - Approaching: 80–95%
    /// - Landing: 95–100%
    init(progress: Double) {
        switch progress {
        case ..<0.0001:      self = .boarding
        case ..<0.10:        self = .takingOff
        case ..<0.80:        self = .cruising
        case ..<0.95:        self = .approaching
        default:             self = .landing
        }
    }

    var title: String {
        switch self {
        case .boarding:    return "Boarding"
        case .takingOff:   return "Taking off"
        case .cruising:    return "Cruising"
        case .approaching: return "Approaching"
        case .landing:     return "Landing"
        }
    }

    /// A short, calm caption for the top island.
    var caption: String {
        switch self {
        case .boarding:    return "Settle in and breathe"
        case .takingOff:   return "Leaving distractions below"
        case .cruising:    return "Stay with your focus"
        case .approaching: return "Almost there — keep going"
        case .landing:     return "Bringing you down gently"
        }
    }

    var systemImage: String {
        switch self {
        case .boarding:    return "figure.seated.side"
        case .takingOff:   return "arrow.up.forward"
        case .cruising:    return "wind"
        case .approaching: return "arrow.down.forward"
        case .landing:     return "checkmark.circle"
        }
    }
}
