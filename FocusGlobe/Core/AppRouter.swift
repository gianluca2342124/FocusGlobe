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
    /// Set when the Landing screen asks for a fresh flight; Home observes it and
    /// opens the flight setup as soon as the journey cover has dismissed.
    @Published var pendingNewFlight = false

    // MARK: Pushes

    func openRouteSelection() {
        if path.last != .routeSelection { path.append(.routeSelection) }
    }
    /// Open the pre-boarding focus ritual for the chosen route.
    func openFocusLoadout(_ route: Route) { path.append(.focusLoadout(route)) }
    /// Open the boarding ticket, optionally pre-filled with the chosen focus.
    func openBoarding(_ route: Route, focus: FocusPreset? = nil) { path.append(.boarding(route, focus)) }
    /// Proceed from the focus ritual into Boarding by **replacing** the loadout
    /// step in the stack — so a back/swipe from Boarding returns straight to
    /// Choose Journey (never a stale, lifted loadout screen).
    func proceedToBoarding(_ route: Route, focus: FocusPreset?) {
        if let last = path.indices.last, case .focusLoadout = path[last] {
            path[last] = .boarding(route, focus)
        } else {
            path.append(.boarding(route, focus))
        }
    }
    func openPassport() { path.append(.passport) }
    func openHistory() { path.append(.history) }
    func openSettings() { path.append(.settings) }
    func presentPaywall() { showPaywall = true }

    // MARK: Deep links (widgets)

    /// Route an incoming `focusglobe://…` deep link (e.g. from a Home Screen
    /// widget) to the right place. Always lands somewhere safe; unknown links
    /// open Home. Clears any active journey cover first so navigation is visible.
    func handleDeepLink(_ url: URL) {
        guard url.scheme == FocusGlobeShared.urlScheme else { return }
        let target = (url.host ?? url.path.replacingOccurrences(of: "/", with: "")).lowercased()
        activeJourney = nil
        switch target {
        case "choose", "journey", "start":
            // The flight setup flow lives on Home now (no map route selection).
            path.removeAll()
        case "passport", "stats", "goals", "missions", "collection":
            path = [.passport]
        case "streak", "resume", "current", "home", "":
            // Home is where the live streak lives and it auto-offers a resume
            // when an unfinished journey is saved.
            path.removeAll()
        case "pro", "paywall":
            // A locked (non-Pro) widget taps straight into the paywall.
            path.removeAll()
            presentPaywall()
        default:
            path.removeAll()
        }
    }

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

    /// Dismiss the journey cover to Home and ask it to open the flight setup —
    /// the Landing screen's "Start another flight".
    func startAnotherFlight() {
        activeJourney = nil
        path.removeAll()
        pendingNewFlight = true
    }

    /// Dismiss the journey cover and open the Passport.
    func finishToPassport() {
        activeJourney = nil
        path = [.passport]
    }
}
