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
    /// A synchronized shared deadline for a guest joining an in-progress Private
    /// Flight — the timer counts down to THIS absolute instant instead of a
    /// private duration. `nil` for every ordinary flight.
    var sharedEndsAt: Date? = nil
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
        case store
        case friends
    }

    /// The five persistent tabs of the app shell. Home is the centre. Switching
    /// a tab swaps the shell's content in place — it never pushes a page, so the
    /// bottom bar stays visible and there is no back button on a tab root.
    enum Tab: Hashable { case passport, shop, home, friends, settings }

    /// The visible tab. `path` is the *pushed* flow on top of the shell (the
    /// ritual/boarding/history), which is empty while you are simply on a tab.
    @Published var selectedTab: Tab = .home

    /// Switch tabs inside the shell. Clears any pushed flow first so a tab
    /// always shows its own root, never a stale pushed screen underneath.
    func select(_ tab: Tab) {
        if !path.isEmpty { path.removeAll() }
        selectedTab = tab
    }

    @Published var path: [Destination] = []
    @Published var activeJourney: Journey?

    /// The ONE app-wide modal presented over the shell. Every cross-screen sheet
    /// (paywall, Online sign-in, Coin Spin, Coins Boost, Streak, Daily Gift,
    /// share) routes through this single coordinator so SwiftUI never has two
    /// sheets contending ("Currently, only presenting a single sheet is
    /// supported"). Setting it replaces whatever was up — one modal at a time.
    @Published var activeModal: AppModal?

    /// Present a coordinated modal (replaces any current one).
    func present(_ modal: AppModal) { activeModal = modal }
    /// Dismiss the coordinated modal.
    func dismissModal() { activeModal = nil }

    /// Read-only compatibility: `true` while the coordinated paywall is up.
    var showPaywall: Bool {
        if case .paywall = activeModal { return true }
        return false
    }
    /// The context of the currently presented paywall (or `.general`).
    var paywallContext: PaywallContext {
        if case .paywall(let ctx) = activeModal { return ctx }
        return .general
    }
    /// An opaque root curtain raised for the Boarding-cut → journey hand-off so
    /// Home can never flash between the two presentation layers. The journey
    /// container lowers it the moment it is mounted (plus a watchdog fallback).
    @Published var takeoffCurtain = false
    /// The Sky id the curtain should match (nil → neutral fallback). Colouring
    /// the curtain with the flight's OWN first-frame sky makes the setup →
    /// flight hand-off read as one continuous sky instead of a dark flash.
    @Published var takeoffCurtainSkyID: String? = nil
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
    // The four tab destinations switch the shell tab in place (no push); History
    // remains a genuine pushed detail off the Passport tab.
    func openPassport() { select(.passport) }
    func openStore() { select(.shop) }
    func openFriends() { select(.friends) }
    func openHistory() { path.append(.history) }
    func openSettings() { select(.settings) }
    func presentPaywall(context: PaywallContext = .general) {
        present(.paywall(context))
    }

    /// Raise the take-off curtain (with a 3 s watchdog so an interrupted
    /// hand-off can never leave the app stuck behind an opaque cover).
    func raiseTakeoffCurtain(skyID: String? = nil) {
        takeoffCurtainSkyID = skyID
        takeoffCurtain = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.takeoffCurtain = false
        }
    }
    func lowerTakeoffCurtain() { takeoffCurtain = false }

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
            path.removeAll(); selectedTab = .home
        case "passport", "stats", "goals", "missions", "collection", "badges":
            path.removeAll(); selectedTab = .passport
        case "streak", "resume", "current", "flight", "home", "":
            // Home is where the live streak lives and it auto-offers a resume
            // when an unfinished journey is saved.
            path.removeAll(); selectedTab = .home
        case "pro", "paywall":
            // A locked (non-Pro) widget taps straight into the paywall.
            path.removeAll(); selectedTab = .home
            presentPaywall()
        default:
            path.removeAll(); selectedTab = .home
        }
    }

    // MARK: Journey lifecycle

    func startJourney(origin: JourneyOrigin, route: Route, intention: String?,
                      sharedEndsAt: Date? = nil) {
        activeJourney = Journey(origin: origin, route: route, intention: intention,
                                sharedEndsAt: sharedEndsAt)
    }

    /// Dismiss the journey cover and return to the Home root.
    func finishToHome() {
        activeJourney = nil
        path.removeAll()
        selectedTab = .home
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

    /// Dismiss the journey cover and open the Passport tab.
    func finishToPassport() {
        activeJourney = nil
        path.removeAll()
        selectedTab = .passport
    }
}


/// The ONE coordinated modal shown over the shell. `.sheet(item:)` at the root
/// renders exactly one at a time (see `AppRouter.activeModal`).
enum AppModal: Identifiable {
    case paywall(PaywallContext)
    case onlineSignIn
    case coinSpin
    case coinBoostGift
    case streak
    case dailyGift
    /// A native share sheet — carries the items (e.g. a rendered UIImage).
    case share([Any])

    var id: String {
        switch self {
        case .paywall(let ctx): return "paywall.\(String(describing: ctx))"
        case .onlineSignIn:     return "onlineSignIn"
        case .coinSpin:         return "coinSpin"
        case .coinBoostGift:    return "coinBoostGift"
        case .streak:           return "streak"
        case .dailyGift:        return "dailyGift"
        case .share:            return "share"
        }
    }
}

/// The reason a FocusGlobe PRO paywall was opened — one reusable paywall view
/// renders a context-appropriate headline + hero from this, so a balloon-skin
/// tap never shows Sky imagery (and vice versa).
enum PaywallContext: Equatable {
    case general          // crown / broad entry: "Upgrade to FocusGlobe PRO"
    case sky              // locked Sky:          "Unlock All Skies with PRO"
    case balloonSkin      // premium skin:        "Unlock Exclusive Balloons with PRO"
    case interior         // premium cabin item:  "Unlock Premium Cabin Items with PRO"
    case sound            // locked sound:        "Unlock Every Focus Sound with PRO"
    case widget           // locked widget:       "Unlock All Widgets with PRO"
    case rewards          // 2x rewards:          "Double Every Reward with PRO"
    case online           // Online flight:       "Focus Together with PRO"
    case invite           // invite friends:      "Invite Friends with PRO"
    case infinite         // infinite duration:   "Focus Without Limits with PRO"
    case pause            // pause a flight:       "Pause Your Flight with PRO"

    var headline: String {
        switch self {
        case .general:     return "Upgrade to FocusGlobe PRO"
        case .sky:         return "Unlock All Skies with PRO"
        case .balloonSkin: return "Unlock Exclusive Balloons with PRO"
        case .interior:    return "Unlock Premium Cabin Items with PRO"
        case .sound:       return "Unlock Every Focus Sound with PRO"
        case .widget:      return "Unlock All Widgets with PRO"
        case .rewards:     return "Double Every Reward with PRO"
        case .online:      return "Focus Together with PRO"
        case .invite:      return "Invite Friends with PRO"
        case .infinite:    return "Focus Without Limits with PRO"
        case .pause:       return "Pause Your Flight with PRO"
        }
    }

    /// The single comparison-table benefit row to spotlight for this entry point
    /// (nil for broad / general entries). Titles match `PaywallComparisonTable`
    /// exactly.
    var comparisonHighlight: String? {
        switch self {
        case .online:                return "Online Mode"
        case .invite:                return "Invite Friends"
        case .infinite:              return "Infinite Focus  ∞"
        case .widget:                return "Exclusive Widgets"
        case .sky:                   return "Exclusive Skies"
        case .balloonSkin:           return "Premium Skins"
        case .interior, .sound:      return "Premium Items"
        case .general, .rewards, .pause: return nil
        }
    }
}
