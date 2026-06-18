import Combine
import Foundation

@MainActor
final class RouteSelectionViewModel: ObservableObject {
    @Published var selectedCategory: RouteCategory?

    var filteredRoutes: [Route] {
        guard let selectedCategory else { return RouteCatalog.all }
        return RouteCatalog.routes(in: selectedCategory)
    }

    let categories = RouteCategory.allCases.sorted { $0.order < $1.order }
}
