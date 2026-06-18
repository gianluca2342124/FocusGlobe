import Combine
import Foundation

/// A journey the user is about to take or is currently on.
struct Journey: Identifiable, Hashable {
    let id = UUID()
    let route: Route
    let intention: String?
}

/// Centralised navigation. Provider-independent and view-independent so flows
/// are easy to reason about and to test.
///
/// The journey flow is: Home → RouteSelection → Boarding → (full-screen)
/// FocusSession → Landing. The focus session is presented as a full-screen
/// cover that also hosts the Landing screen, so the take-off → land transition
/// stays seamless.
@MainActor
final class AppRouter: ObservableObject {

    enum Destination: Hashable {
        case routeSelection
        case boarding(Route)
        case passport
        case history
        case settings
    }

    @Published var path: [Destination] = []
    @Published var activeJourney: Journey?
    @Published var showPaywall = false

    // MARK: Pushes

    func openRouteSelection() {
        if path.last != .routeSelection { path.append(.routeSelection) }
    }
    func openBoarding(_ route: Route) { path.append(.boarding(route)) }
    func openPassport() { path.append(.passport) }
    func openHistory() { path.append(.history) }
    func openSettings() { path.append(.settings) }
    func presentPaywall() { showPaywall = true }

    // MARK: Journey lifecycle

    func startJourney(route: Route, intention: String?) {
        activeJourney = Journey(route: route, intention: intention)
    }

    /// Dismiss the journey cover and return to the Home root.
    func finishToHome() {
        activeJourney = nil
        path.removeAll()
    }

    /// Dismiss the journey cover and go choose another route.
    func startAnotherJourney() {
        activeJourney = nil
        path = [.routeSelection]
    }

    /// Dismiss the journey cover and open the Passport.
    func finishToPassport() {
        activeJourney = nil
        path = [.passport]
    }
}
