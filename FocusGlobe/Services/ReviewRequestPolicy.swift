import Foundation

/// When FocusGlobe may ask StoreKit to consider showing the App Store rating
/// prompt.
///
/// ## What this can and cannot know
///
/// It can decide whether to CALL StoreKit. It cannot know whether a prompt was
/// shown, and it certainly cannot know whether anyone left a review — the system
/// deliberately tells the app nothing, and rate-limits the prompt itself. So
/// there is no `hasReviewed` flag here and never should be: everything recorded
/// is "FocusGlobe asked, on this version, at this time".
///
/// ## Why a separate type
///
/// The policy is a pure function of state, so it can be reasoned about and
/// checked without a running app — which matters for something whose real
/// behaviour is invisible in TestFlight (the system prompt does not appear in
/// TestFlight builds at all; it has to be validated in a development build and
/// then observed in production).
enum ReviewRequestPolicy {

    /// The sections whose return to Home counts as "finished looking around".
    /// Coming back from a flight is not one of them: that moment belongs to the
    /// landing, not to a rating prompt.
    static let qualifyingOrigins: Set<AppRouter.Tab> = [.shop, .friends, .passport]

    /// Meaningful usage. Either is enough — some pilots fly a few long flights,
    /// some fly many short ones, and both have seen the product properly.
    static let minimumJourneys = 3
    static let minimumFocusedMinutes = 30

    /// Conservative on purpose. StoreKit has its own annual limit; this sits
    /// well inside it so FocusGlobe is never the reason someone is asked twice.
    static let cooldownDays = 90

    struct Context {
        var cameFrom: AppRouter.Tab?
        var completedJourneys: Int
        var lifetimeFocusedMinutes: Int
        /// Nil until a version has ever been asked on.
        var lastRequestedVersion: String?
        /// Unix time of the last request; 0 when never.
        var lastRequestedAt: TimeInterval
        var currentVersion: String
        var now: TimeInterval
        /// Anything that would make a rating prompt an interruption.
        var isBusy: Bool
        /// A pilot who has never completed onboarding has nothing to rate.
        var hasOnboarded: Bool
    }

    enum Decision: Equatable {
        case request
        case skip(String)

        var isRequest: Bool { self == .request }
        var reason: String {
            if case .skip(let why) = self { return why }
            return "eligible"
        }
    }

    static func decide(_ c: Context) -> Decision {
        guard c.hasOnboarded else { return .skip("onboarding not complete") }
        guard let from = c.cameFrom else { return .skip("not a return from another section") }
        guard qualifyingOrigins.contains(from) else {
            return .skip("returned from \(from), which does not qualify")
        }
        guard !c.isBusy else { return .skip("a flight, paywall, purchase or modal is active") }
        guard c.completedJourneys >= minimumJourneys
                || c.lifetimeFocusedMinutes >= minimumFocusedMinutes else {
            return .skip("usage below threshold "
                         + "(\(c.completedJourneys)/\(minimumJourneys) journeys, "
                         + "\(c.lifetimeFocusedMinutes)/\(minimumFocusedMinutes) min)")
        }
        if let asked = c.lastRequestedVersion, asked == c.currentVersion {
            return .skip("already requested on version \(asked)")
        }
        if c.lastRequestedAt > 0 {
            let elapsedDays = (c.now - c.lastRequestedAt) / 86_400
            guard elapsedDays >= Double(cooldownDays) else {
                return .skip(String(format: "cooldown: %.1f of %d days elapsed",
                                    elapsedDays, cooldownDays))
            }
        }
        return .request
    }

    /// The app's marketing version, which is what "once per version" means to a
    /// user reading the App Store listing.
    static var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
    }

    /// DEBUG-only. Deliberately never surfaced in the UI — a rating prompt that
    /// explains itself on screen is a rating prompt nobody wants.
    static func log(_ decision: Decision, context: Context) {
        #if DEBUG
        print("[Review] \(decision.isRequest ? "REQUEST" : "skip") — \(decision.reason) "
              + "(from: \(context.cameFrom.map(String.init(describing:)) ?? "nil"), "
              + "journeys: \(context.completedJourneys), "
              + "minutes: \(context.lifetimeFocusedMinutes), "
              + "version: \(context.currentVersion))")
        #endif
    }
}
