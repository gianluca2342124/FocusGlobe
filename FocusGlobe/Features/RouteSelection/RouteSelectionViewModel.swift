import Combine
import Foundation

@MainActor
final class RouteSelectionViewModel: ObservableObject {
    @Published var selectedCategory: RouteCategory?

    let categories = RouteCategory.allCases.sorted { $0.order < $1.order }

    /// Destinations reachable from the current origin, nearest first, filtered
    /// by the selected category chip.
    func journeys(for origin: JourneyOrigin) -> [PlannedJourney] {
        JourneyPlanner.plan(from: origin, category: selectedCategory)
    }
}
