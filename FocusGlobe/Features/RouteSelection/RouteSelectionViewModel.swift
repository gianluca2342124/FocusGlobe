import Combine
import Foundation

@MainActor
final class RouteSelectionViewModel: ObservableObject {
    @Published var selectedCategory: RouteCategory?

    let categories = RouteCategory.allCases.sorted { $0.order < $1.order }

    /// Curated journeys from the matched hub, filtered by the selected chip,
    /// free Short set first.
    func journeys(hub: OriginHub, origin: JourneyOrigin) -> [PlannedJourney] {
        JourneyPlanner.plan(hub: hub, origin: origin, category: selectedCategory)
    }
}
