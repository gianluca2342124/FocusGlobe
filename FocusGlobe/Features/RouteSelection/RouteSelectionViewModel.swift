import Combine
import Foundation

@MainActor
final class RouteSelectionViewModel: ObservableObject {
    @Published var selectedCategory: RouteCategory?

    let categories = RouteCategory.allCases.sorted { $0.order < $1.order }

    /// Precompute and cache the full plan the moment the origin is known, so the
    /// destination strip renders immediately and the Book Journey tap never pays
    /// a planning cost. Idempotent — backed by JourneyPlanner's in-memory cache.
    func prepare(from origin: JourneyOrigin) {
        _ = JourneyPlanner.plan(from: origin)
    }

    /// Real journeys generated from the current origin coordinate, filtered by
    /// the selected chip. O(1) after `prepare` — reads JourneyPlanner's cache.
    func journeys(from origin: JourneyOrigin) -> [PlannedJourney] {
        JourneyPlanner.plan(from: origin, category: selectedCategory)
    }
}
