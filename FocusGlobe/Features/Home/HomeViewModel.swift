import Combine
import Foundation

/// Lightweight view model for the Home screen — contextual copy only.
@MainActor
final class HomeViewModel: ObservableObject {
    var greeting: String { Formatters.greeting() }
    let headline = "Ready to drift?"
    let subtitle = "Pick a route. Stay focused until you land."
    let tagline = "Leave distractions below."
}
