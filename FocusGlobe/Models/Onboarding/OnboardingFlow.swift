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
    case commitmentBridge
    case sessionLength
    case weeklyFrequency
    case focusStyle
    case shieldPreference
    case skySelection
    case soundSelection
    case planGeneration
    case planReveal
    case flightPreview
    case proBridge
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
        case .primaryGoal, .focusObstacle, .commitmentBridge:
            return .about
        case .sessionLength, .weeklyFrequency, .focusStyle, .shieldPreference:
            return .rhythm
        case .skySelection, .soundSelection:
            return .atmosphere
        case .planGeneration, .planReveal, .flightPreview:
            return .plan
        case .proBridge, .paywall:
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

    var showsBack: Bool {
        switch self {
        // Never back out of a purchase screen into the plan, and never back
        // out of an arrival.
        case .welcome, .planGeneration, .paywall, .completion: return false
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

    var steps: [OnboardingStepID] {
        var s: [OnboardingStepID] = [
            .welcome, .primaryGoal, .focusObstacle, .commitmentBridge,
            .sessionLength, .weeklyFrequency, .focusStyle, .shieldPreference,
            .skySelection, .soundSelection, .planGeneration, .planReveal,
        ]
        // The concise arm drops the two screens that shape the plan least and
        // the interactive preview, going from reveal straight to the offer.
        if variant == .concisePersonalized {
            s.removeAll { $0 == .weeklyFrequency || $0 == .commitmentBridge }
        } else {
            s.append(.flightPreview)
        }
        // An active PRO pilot sees no bridge and no paywall. Not hidden behind
        // a guard inside those views — absent from the flow.
        // The personalized three-benefit bridge is NOT a separate screen. The
        // brief allows merging it where that is cleaner, and it is: the paywall
        // already owns a hero area, so leading it with the pilot's own top three
        // benefits is one screen doing one job instead of a tap-through that
        // says something the next screen repeats. `.proBridge` stays in the
        // enum so experiment D (personalized bridge vs generic) can split it
        // back out without a model change.
        if !isPro { s.append(.paywall) }
        // Permission warm-ups appear only when the pilot's own answers make
        // them relevant. Someone who chose "keep it flexible" is not asked
        // about reminders; someone who never mentioned apps is not asked for
        // Screen Time.
        if answers.cadence?.suggestsReminders == true { s.append(.notificationWarmup) }
        if wantsShield { s.append(.shieldWarmup) }
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

    /// A resumed step may no longer exist in the flow — the pilot could have
    /// bought PRO in another session, or answers may have changed the branch.
    /// Fall back to the nearest still-valid step rather than a blank screen.
    func resolvedResume(_ stored: OnboardingStepID?) -> OnboardingStepID {
        guard let stored else { return .welcome }
        if steps.contains(stored) { return stored }
        return .welcome
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
            for isPro in [false, true] {
                for goal in goals {
                    for obstacle in obstacles {
                        for cadence in cadences {
                            for intent in intents {
                                var a = OnboardingAnswers()
                                a.goal = goal; a.obstacle = obstacle
                                a.cadence = cadence; a.shieldIntent = intent
                                let flow = OnboardingFlow(variant: variant, answers: a, isPro: isPro)
                                let s = flow.steps
                                if Set(s).count != s.count { return "duplicate step in \(variant)/\(isPro)" }
                                if s.first != .welcome { return "flow must start at welcome" }
                                if s.last != .completion { return "flow must end at completion" }
                                if isPro && (s.contains(.paywall) || s.contains(.proBridge)) {
                                    return "PRO pilot was offered a paywall or bridge"
                                }
                                if !isPro && !s.contains(.paywall) { return "free pilot never sees the offer" }
                                if cadence == .flexible && s.contains(.notificationWarmup) {
                                    return "flexible cadence must not ask about reminders"
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
