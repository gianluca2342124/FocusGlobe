import Foundation

/// The steps of the first run, as stable IDs.
///
/// IDs rather than integers because the previous flow's position was an `Int`
/// into a `switch`: inserting a screen silently renumbered every later one, and
/// a resumed position pointed somewhere else entirely. A raw-value string also
/// means an analytics funnel keeps its meaning across releases.
enum OnboardingStepID: String, Codable, CaseIterable, Sendable {
    case welcome
    case primaryGoal
    case focusObstacle
    case sessionLength
    case weeklyFrequency
    case focusStyle
    case shieldPreference
    case skySelection
    case soundSelection
    case planReveal
    case flightPreview
    case paywall
    case notificationWarmup
    case shieldWarmup
    case completion

    /// Which logical section the progress bar should show. Several screens can
    /// share a section, so branching cannot make the bar jump or reverse.
    var section: OnboardingSection {
        switch self {
        case .welcome:
            return .welcome
        case .primaryGoal, .focusObstacle:
            return .about
        case .sessionLength, .weeklyFrequency, .focusStyle, .shieldPreference:
            return .rhythm
        case .skySelection, .soundSelection:
            return .atmosphere
        case .planReveal, .flightPreview:
            return .plan
        case .paywall:
            return .offer
        case .notificationWarmup, .shieldWarmup, .completion:
            return .finish
        }
    }

    /// Progress, back and the language control are all wrong on some screens:
    /// the welcome has nothing behind it, the paywall owns its own chrome, and
    /// the completion screen is an arrival, not a step.
    var showsProgress: Bool {
        switch self {
        case .welcome, .paywall, .completion: return false
        default: return true
        }
    }

    /// Position in the canonical declaration order. Used to find the nearest
    /// still-reachable step when the flow changes underneath a pilot — buying
    /// PRO mid-onboarding removes `.paywall` from the flow while they are
    /// standing on it.
    var ordinal: Int { OnboardingStepID.allCases.firstIndex(of: self) ?? 0 }

    var showsBack: Bool {
        switch self {
        // Never back out of a purchase screen into the plan, and never back
        // out of an arrival.
        case .welcome, .planReveal, .paywall, .completion: return false
        default: return true
        }
    }
}

/// Progress sections. Deliberately coarse: the bar measures how far through the
/// EXPERIENCE the pilot is, not how many views remain, so a skipped branch
/// cannot make it lie.
enum OnboardingSection: Int, CaseIterable, Sendable {
    case welcome = 0
    case about
    case rhythm
    case atmosphere
    case plan
    case offer
    case finish

    /// Sections that count toward the visible bar (welcome has no bar).
    static var measured: [OnboardingSection] { [.about, .rhythm, .atmosphere, .plan, .offer, .finish] }
}

/// A/B assignment, decided once per install and then frozen.
///
/// Random-per-launch assignment is worse than no experiment at all: it
/// attributes a pilot's behaviour to whichever arm happened to render, and the
/// result is noise that looks like data. `OnboardingFlow.variant(for:)` reads a
/// value persisted on the profile and only rolls a new one when none exists.
enum OnboardingVariant: String, Codable, CaseIterable, Sendable {
    /// The production default: the full personalized flow with the plan reveal
    /// and the interactive preview.
    case personalizedPreview
    /// The shorter arm — same questions minus the optional ones, paywall
    /// straight after the reveal. Built, not shipped: it exists so the first
    /// experiment can be turned on without another release.
    case concisePersonalized

    static let productionDefault: OnboardingVariant = .personalizedPreview

    /// Share of new installs routed to the concise arm.
    ///
    /// Zero today: the experiment is BUILT, not running. Shipping a live split
    /// before the funnel has produced a single clean baseline would compare two
    /// arms against nothing. Raising this number is the whole change needed to
    /// start it — there is no other switch, and no release required beyond this
    /// constant.
    static let concisePersonalizedRollout: Double = 0

    /// Roll an assignment for a NEW install, once.
    ///
    /// Called only when the profile holds no assignment; the result is persisted
    /// immediately and never re-rolled. Random-per-launch assignment is worse
    /// than no experiment: it attributes a pilot's behaviour to whichever arm
    /// happened to render, which is noise wearing the shape of data.
    static func assignForNewInstall(draw: Double = Double.random(in: 0..<1)) -> OnboardingVariant {
        draw < concisePersonalizedRollout ? .concisePersonalized : productionDefault
    }
}

/// The ordered flow, derived from the answers so far.
///
/// Branching lives HERE, in one pure function, rather than being scattered
/// through each screen as "if this then skip". That is what lets the progress
/// bar be accurate, back navigation be trivial, and a resumed session land on a
/// step that is still reachable.
struct OnboardingFlow: Equatable, Sendable {
    let variant: OnboardingVariant
    let answers: OnboardingAnswers
    /// True when the pilot already holds the entitlement — every promotional
    /// step drops out of the flow entirely rather than being rendered and
    /// skipped.
    let isPro: Bool
    /// Whether Screen Time blocking is usable on this device at all. A warm-up
    /// for a permission the build cannot honour is worse than no warm-up: it
    /// spends a screen and a system prompt on a feature that will not appear.
    let shieldAvailable: Bool

    /// The most app-controlled screens any branch may reach, welcome and paywall
    /// included. System permission dialogs are not app-controlled and are not
    /// counted; the warm-up screens that precede them are.
    static let maximumVisibleSteps = 15

    var steps: [OnboardingStepID] {
        var s: [OnboardingStepID] = [
            .welcome, .primaryGoal, .focusObstacle, .sessionLength,
            .weeklyFrequency, .focusStyle, .shieldPreference,
            .skySelection, .soundSelection, .planReveal,
        ]
        // The concise arm drops the two questions the plan can survive without
        // — company (which only reorders benefits) and soundscape (which has a
        // good default) — plus the interactive preview.
        if variant == .concisePersonalized {
            s.removeAll { $0 == .focusStyle || $0 == .soundSelection }
        } else {
            s.append(.flightPreview)
        }
        // An active PRO pilot sees no paywall. Not hidden behind a guard inside
        // the view — absent from the flow.
        //
        // There is no separate PRO bridge screen. The personalized three-benefit
        // pitch lives at the top of the paywall itself, which already owns a
        // hero area: one screen doing one job, rather than a tap-through that
        // says something the next screen immediately repeats.
        if !isPro { s.append(.paywall) }
        // Permission warm-ups appear only when the pilot's own answers make
        // them relevant. Someone who chose "keep it flexible" is not asked
        // about reminders; someone who never mentioned apps is not asked for
        // Screen Time.
        if answers.cadence?.suggestsReminders == true { s.append(.notificationWarmup) }
        if shieldAvailable && wantsShield { s.append(.shieldWarmup) }
        // Sign in with Apple is NOT its own step. It is an optional offer, not
        // a permission and not a gate, and giving it a full screen both pads
        // the flow and implies it is required. It lives on the completion
        // screen as a secondary action.
        s.append(.completion)
        return s
    }

    private var wantsShield: Bool {
        guard let obstacle = answers.obstacle else { return answers.shieldIntent == .yes }
        return OnboardingPlanBuilder.recommendsShield(obstacle: obstacle, intent: answers.shieldIntent)
    }

    func index(of step: OnboardingStepID) -> Int? { steps.firstIndex(of: step) }

    func next(after step: OnboardingStepID) -> OnboardingStepID? {
        guard let i = index(of: step), i + 1 < steps.count else { return nil }
        return steps[i + 1]
    }

    func previous(before step: OnboardingStepID) -> OnboardingStepID? {
        guard let i = index(of: step), i > 0 else { return nil }
        return steps[i - 1]
    }

    /// The next step to show, even when `step` is no longer part of the flow.
    ///
    /// This is the case a plain `next(after:)` cannot handle: a pilot standing
    /// on the paywall buys PRO, the paywall leaves the flow, and asking "what
    /// follows the paywall" has no answer. Falling back to declaration order
    /// lands them on the following warm-up instead of at the welcome screen.
    func nextReachable(after step: OnboardingStepID) -> OnboardingStepID? {
        if let next = next(after: step) { return next }
        guard index(of: step) == nil else { return nil }
        return steps.first { $0.ordinal > step.ordinal }
    }

    /// A resumed step may no longer exist in the flow — the pilot could have
    /// bought PRO in another session, or answers may have changed the branch.
    /// Fall back to the nearest still-valid step rather than a blank screen.
    func resolvedResume(_ stored: OnboardingStepID?) -> OnboardingStepID {
        guard let stored else { return .welcome }
        if steps.contains(stored) { return stored }
        return steps.first { $0.ordinal >= stored.ordinal } ?? .welcome
    }

    /// Progress as completed SECTIONS, so skipping a screen inside a section
    /// never moves the bar and the bar never runs backwards.
    func progress(at step: OnboardingStepID) -> Double {
        let measured = OnboardingSection.measured
        guard let position = measured.firstIndex(of: step.section) else {
            // Welcome (before everything) or an unmeasured screen.
            return step == .welcome ? 0 : 1
        }
        // Fraction THROUGH the current section, so movement inside a long
        // section is still visible without over-promising.
        let inSection = steps.filter { $0.section == step.section }
        let within = inSection.firstIndex(of: step).map { Double($0) } ?? 0
        let sectionSpan = 1.0 / Double(measured.count)
        let base = Double(position) * sectionSpan
        let advance = inSection.isEmpty ? 0 : (within / Double(inSection.count)) * sectionSpan
        return min(1, base + advance)
    }

    #if DEBUG
    /// Guards the properties the flow must never violate.
    static func _selfCheck() -> String? {
        let goals = FocusGoal.allCases
        let obstacles = FocusObstacle.allCases
        let cadences = FocusCadence.allCases
        let intents: [ShieldIntent?] = [nil, .yes, .later]
        for variant in OnboardingVariant.allCases {
            for (isPro, shieldAvailable) in [(false, false), (false, true), (true, false), (true, true)] {
                for goal in goals {
                    for obstacle in obstacles {
                        for cadence in cadences {
                            for intent in intents {
                                var a = OnboardingAnswers()
                                a.goal = goal; a.obstacle = obstacle
                                a.cadence = cadence; a.shieldIntent = intent
                                let flow = OnboardingFlow(variant: variant, answers: a,
                                                          isPro: isPro,
                                                          shieldAvailable: shieldAvailable)
                                let s = flow.steps
                                if Set(s).count != s.count { return "duplicate step in \(variant)/\(isPro)" }
                                if s.first != .welcome { return "flow must start at welcome" }
                                if s.last != .completion { return "flow must end at completion" }
                                if isPro && s.contains(.paywall) {
                                    return "PRO pilot was offered a paywall"
                                }
                                if !isPro && !s.contains(.paywall) { return "free pilot never sees the offer" }
                                // The hard ceiling. Fifteen app-controlled
                                // screens is a product decision, not a
                                // guideline, and it is exactly the kind of
                                // thing that regresses one innocuous screen at
                                // a time — so it is asserted rather than
                                // remembered.
                                if s.count > OnboardingFlow.maximumVisibleSteps {
                                    return "\(variant) reached \(s.count) screens (max \(OnboardingFlow.maximumVisibleSteps))"
                                }
                                if cadence == .flexible && s.contains(.notificationWarmup) {
                                    return "flexible cadence must not ask about reminders"
                                }
                                if !shieldAvailable && s.contains(.shieldWarmup) {
                                    return "Shield warm-up offered where Screen Time is unavailable"
                                }
                                // Every step must be reachable forwards from the
                                // one before it, and resuming onto any step must
                                // land somewhere that exists.
                                for step in OnboardingStepID.allCases {
                                    let resumed = flow.resolvedResume(step)
                                    if !s.contains(resumed) { return "resume from \(step) landed outside the flow" }
                                }
                                // EVERY variant must be able to produce a
                                // plan from the questions it actually asks.
                                // The concise arm drops two of them, and a
                                // builder that quietly returns nil would land
                                // a pilot on a plan reveal with no plan.
                                var answered = a
                                answered.sessionChoice = .recommended
                                answered.skyID = "regression-sky"
                                answered.company = flow.steps.contains(.focusStyle) ? .alone : nil
                                answered.soundID = flow.steps.contains(.soundSelection) ? "wind" : nil
                                let normalized = answered.normalized(for: flow,
                                                                     fallbackSoundID: "wind")
                                guard let built = OnboardingPlanBuilder.build(
                                    from: normalized, fallbackSkyID: "regression-sky") else {
                                    return "\(variant) cannot build a plan from the questions it asks"
                                }
                                if built.selectedSoundID == nil && !normalized.choseSilence {
                                    return "\(variant) silenced a pilot who never chose Silence"
                                }
                                if built.recommendedDurationMinutes < 15
                                    || built.recommendedDurationMinutes > 60 {
                                    return "\(variant) produced an out-of-range first flight"
                                }
                                // Progress must be monotonic across the flow.
                                var last = -1.0
                                for step in s {
                                    let p = flow.progress(at: step)
                                    if p < last - 0.0001 { return "progress ran backwards at \(step)" }
                                    if p < 0 || p > 1 { return "progress out of range at \(step)" }
                                    last = p
                                }
                            }
                        }
                    }
                }
            }
        }
        return nil
    }
    #endif
}
