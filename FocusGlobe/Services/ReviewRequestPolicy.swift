import Foundation

/// When FocusGlobe may ask StoreKit to CONSIDER showing the App Store rating
/// prompt.
///
/// ## What this can and cannot know
///
/// It can decide whether to CALL StoreKit. It cannot know whether a prompt was
/// shown, and it certainly cannot know whether anyone left a review — the system
/// deliberately tells the app nothing, and rate-limits the prompt itself. So
/// there is no `hasReviewed` flag here and never should be: everything recorded
/// is "FocusGlobe asked, at this time, at this flight count".
///
/// ## Why a separate type
///
/// The policy is a pure function of state, so it can be reasoned about and
/// checked without a running app — which matters for something whose real
/// behaviour is invisible in TestFlight (the system prompt does not appear in
/// TestFlight builds at all; it has to be validated in a development build and
/// then observed in production).
///
/// ## The shape of the ladder
///
/// Three opportunities, each further apart than the last, each requiring more
/// evidence that the pilot actually uses FocusGlobe:
///
///   * FIRST — 3 completed flights across 2 distinct days. Both, not either:
///     three flights in one afternoon is a pilot trying the app out, and asking
///     them to rate it is asking about a first impression. Two days means they
///     came back.
///   * SECOND — 10 completed flights or a real streak, and at least 14 days
///     since the last attempt.
///   * THEREAFTER — every 15 further completed flights, and at least 21 days.
///
/// ## What is deliberately NOT here
///
/// A version gate. The previous policy re-opened the door on every new
/// marketing version, which turns a shipping cadence into a prompting cadence —
/// exactly backwards. Engagement and elapsed time decide; a release does not.
enum ReviewRequestPolicy {

    /// The positive break that produced this evaluation.
    ///
    /// There are only two, and both are moments where the pilot is looking at
    /// something good and is not in the middle of anything.
    enum Moment: Equatable {
        /// A qualifying flight landed, its rewards were shown, and the pilot has
        /// come back to a stable screen. The strongest moment FocusGlobe has.
        case landingSettled
        /// Returning to Home from a section they went and looked at — the Store,
        /// Friends, the Passport. Calm, and nothing is being interrupted.
        case calmReturn
    }

    /// The sections whose return to Home counts as "finished looking around".
    static let qualifyingOrigins: Set<AppRouter.Tab> = [.shop, .friends, .passport]

    // MARK: The ladder

    static let firstMilestoneFlights = 3
    static let firstMilestoneDistinctDays = 2

    static let secondMilestoneFlights = 10
    /// "An existing meaningful streak milestone." A week of consecutive focus
    /// days is the first streak FocusGlobe itself treats as an achievement.
    static let secondMilestoneStreak = 7
    static let secondMilestoneCooldownDays = 14

    static let repeatMilestoneFlightStep = 15
    static let repeatMilestoneCooldownDays = 21

    struct Context {
        var moment: Moment?
        /// `progress.landings` — the canonical count, incremented only by a
        /// flight that banked the qualifying five minutes.
        var completedFlights: Int
        /// Distinct calendar days on which a qualifying flight landed.
        var distinctFocusDays: Int
        var currentStreak: Int
        /// The most recent flight reached its destination. A cancelled or
        /// under-five-minute flight is the wrong thing to follow with a rating
        /// request, and it is the commonest negative moment the app has.
        var lastFlightWasSuccessful: Bool
        /// Something visibly went wrong recently — a denied permission, an
        /// abandoned flight. Suppresses the ask for a short while.
        var hadRecentFailure: Bool
        var hasAttemptedFirstMilestone: Bool
        /// The flight count at the previous attempt; 0 when never asked.
        var flightsAtLastAttempt: Int
        /// Unix time of the last attempt; 0 when never.
        var lastAttemptAt: TimeInterval
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
        guard let moment = c.moment else { return .skip("no positive moment") }
        guard !c.isBusy else { return .skip("a flight, paywall, purchase or modal is active") }

        // §14. Only successful engagement opens a rating opportunity.
        guard c.lastFlightWasSuccessful else {
            return .skip("the last flight did not complete")
        }
        guard !c.hadRecentFailure else { return .skip("a recent failure") }

        // FIRST OPPORTUNITY — both conditions, never either.
        guard c.hasAttemptedFirstMilestone else {
            guard c.completedFlights >= firstMilestoneFlights else {
                return .skip("first milestone: \(c.completedFlights)/\(firstMilestoneFlights) flights")
            }
            guard c.distinctFocusDays >= firstMilestoneDistinctDays else {
                return .skip("first milestone: \(c.distinctFocusDays)/\(firstMilestoneDistinctDays) distinct days")
            }
            return .request
        }

        // Past this line an attempt has definitely been made, so a missing
        // timestamp is missing DATA, not permission. `recordReviewRequestAttempt`
        // writes all three values together and cannot produce this — but if it
        // ever did, treating the gap as "no cooldown" would let FocusGlobe ask
        // twice in a row, which is the single worst thing this type can do.
        // Zero elapsed is the safe reading.
        let elapsedDays = c.lastAttemptAt > 0 ? (c.now - c.lastAttemptAt) / 86_400 : 0

        // SECOND OPPORTUNITY — the next strong milestone, two weeks on.
        if c.flightsAtLastAttempt < secondMilestoneFlights {
            let reachedMilestone = c.completedFlights >= secondMilestoneFlights
                || c.currentStreak >= secondMilestoneStreak
            guard reachedMilestone else {
                return .skip("second milestone: \(c.completedFlights)/\(secondMilestoneFlights) flights, "
                             + "streak \(c.currentStreak)/\(secondMilestoneStreak)")
            }
            guard elapsedDays >= Double(secondMilestoneCooldownDays) else {
                return .skip(cooldown(elapsedDays, secondMilestoneCooldownDays))
            }
            return .request
        }

        // THEREAFTER — every 15 further flights, three weeks apart.
        let nextAt = c.flightsAtLastAttempt + repeatMilestoneFlightStep
        guard c.completedFlights >= nextAt else {
            return .skip("repeat milestone: \(c.completedFlights)/\(nextAt) flights")
        }
        guard elapsedDays >= Double(repeatMilestoneCooldownDays) else {
            return .skip(cooldown(elapsedDays, repeatMilestoneCooldownDays))
        }
        // The moment is not part of the arithmetic above, but it is what made
        // this evaluation happen at all, and naming it in the log is the only
        // way to tell a post-landing opportunity from a calm-return one.
        _ = moment
        return .request
    }

    private static func cooldown(_ elapsed: Double, _ required: Int) -> String {
        String(format: "cooldown: %.1f of %d days elapsed", elapsed, Double(required))
    }

    // MARK: - Metrics

    /// Distinct calendar days on which a qualifying flight landed.
    ///
    /// Derived from the canonical history rather than counted into a new
    /// stat: `progress` already has every number FocusGlobe needs, and a
    /// parallel counter is a number that can disagree with the Passport.
    static func distinctFocusDays(history: [FocusSessionRecord],
                                  calendar: Calendar = .current) -> Int {
        Set(history.lazy.filter(\.completed).map { calendar.startOfDay(for: $0.date) }).count
    }

    /// The most recent flight reached its destination.
    ///
    /// `true` for a pilot with no history at all: there is nothing negative to
    /// hold against them, and the flight-count gates above keep them out until
    /// they have actually flown.
    static func lastFlightWasSuccessful(history: [FocusSessionRecord]) -> Bool {
        guard let latest = history.max(by: { $0.date < $1.date }) else { return true }
        return latest.completed
    }

    // MARK: - Diagnostics

    /// DEBUG-only. Deliberately never surfaced in the UI — a rating prompt that
    /// explains itself on screen is a rating prompt nobody wants.
    ///
    /// It says "opportunity submitted", never "prompt shown": StoreKit does not
    /// report the second, and a log line that claims it would be a lie the next
    /// reader believes.
    static func log(_ decision: Decision, context c: Context) {
        #if DEBUG
        if decision.isRequest {
            print("[Review] requestReview opportunity submitted — "
                  + "moment: \(c.moment.map(String.init(describing:)) ?? "nil"), "
                  + "flights: \(c.completedFlights), days: \(c.distinctFocusDays), "
                  + "streak: \(c.currentStreak)")
        } else {
            print("[Review] skipped: \(decision.reason)")
        }
        #endif
    }
}
