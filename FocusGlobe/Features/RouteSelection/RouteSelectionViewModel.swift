import Combine
import Foundation

@MainActor
final class RouteSelectionViewModel: ObservableObject {
    @Published var selectedCategory: RouteCategory?

    let categories = RouteCategory.allCases.sorted { $0.order < $1.order }

    /// Real journeys generated from the current origin coordinate, filtered by
    /// the selected chip. Free Short set first.
    func journeys(from origin: JourneyOrigin) -> [PlannedJourney] {
        JourneyPlanner.plan(from: origin, category: selectedCategory)
    }
}
