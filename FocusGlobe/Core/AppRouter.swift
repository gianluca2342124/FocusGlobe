import Combine
import Foundation

/// A journey the user is about to take or is currently on. Always departs from
/// the user's real current location (`origin`) toward the chosen destination.
struct Journey: Identifiable, Hashable {
    let id = UUID()
    let origin: JourneyOrigin
    let route: Route
    let intention: String?
    /// When resuming an unfinished journey, the elapsed seconds to start from.
    /// `nil` for a fresh journey.
    var resumeElapsedSeconds: Int? = nil
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
        /// Pre-boarding focus-selection ritual (between Choose Journey and Boarding).
        case focusLoadout(Route)
        /// Boarding, carrying the focus chosen in the loadout step (if any).
        case boarding(Route, FocusPreset?)
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
    /// Open the pre-boarding focus ritual for the chosen route.
    func openFocusLoadout(_ route: Route) { path.append(.focusLoadout(route)) }
    /// Open the boarding ticket, optionally pre-filled with the chosen focus.
    func openBoarding(_ route: Route, focus: FocusPreset? = nil) { path.append(.boarding(route, focus)) }
    func openPassport() { path.append(.passport) }
    func openHistory() { path.append(.history) }
    func openSettings() { path.append(.settings) }
    func presentPaywall() { showPaywall = true }

    // MARK: Journey lifecycle

    func startJourney(origin: JourneyOrigin, route: Route, intention: String?) {
        activeJourney = Journey(origin: origin, route: route, intention: intention)
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
