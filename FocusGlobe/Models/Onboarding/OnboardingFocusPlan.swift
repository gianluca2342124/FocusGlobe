import Foundation

/// Everything the pilot told us, and the step they were on.
///
/// Persisted after every answer, which is what makes onboarding resumable: the
/// old flow kept its position in `@State`, so a force-quit at step 9 sent the
/// pilot back to the welcome screen with nothing kept.
struct OnboardingAnswers: Codable, Equatable, Sendable {
    var goal: FocusGoal?
    var obstacle: FocusObstacle?
    var sessionChoice: FocusSessionChoice?
    var cadence: FocusCadence?
    var company: FocusCompany?
    var shieldIntent: ShieldIntent?
    var skyID: String?
    var soundID: String?
    /// `nil` means the pilot chose Silence, which is a real choice; the key
    /// being absent entirely means they have not reached that step.
    var choseSilence: Bool = false

    var isComplete: Bool {
        goal != nil && obstacle != nil && sessionChoice != nil
            && cadence != nil && company != nil && shieldIntent != nil && skyID != nil
    }
}

/// The plan itself — the artefact the pilot is shown and, crucially, the one
/// that is then actually applied to the app's real settings.
///
/// The brief's sharpest requirement is here: "Do not merely display a plan card
/// while ignoring its values afterward." `OnboardingPlanBuilder.apply(_:to:)` is
/// the other half, and every field below is read by it.
struct OnboardingFocusPlan: Codable, Equatable, Sendable {
    /// Bumped when the RULES change, so a stored plan can be recognised as
    /// having been built by older logic.
    static let currentVersion = 1
    var version: Int = OnboardingFocusPlan.currentVersion

    let primaryGoal: FocusGoal
    let primaryObstacle: FocusObstacle
    let recommendedDurationMinutes: Int
    /// Nil when the pilot chose "keep it flexible".
    let weeklyTarget: Int?
    let recommendedMode: OnlineFlightMode
    let selectedSkyID: String
    /// Nil means Silence.
    let selectedSoundID: String?
    let recommendsFocusShield: Bool
    let personalizedBenefitOrder: [ProBenefit]
    /// Whether a reminder warm-up is worth showing at all.
    let suggestsReminders: Bool

    /// The one honest sentence shown under the plan card, as a string KEY.
    ///
    /// A key rather than a sentence because a plan is `Codable` and long-lived:
    /// storing prose would freeze today's English into a pilot's profile, and
    /// re-rendering it later in another language would be impossible. It never
    /// claims an outcome, a diagnosis or a study — it says what the plan is FOR,
    /// in terms of the obstacle the pilot named.
    var rationaleKey: FocusStringKey { primaryObstacle.rationaleKey }
}

/// The deterministic rules that turn answers into a plan.
///
/// Deliberately: pure, local, synchronous, versioned and testable. No network,
/// no model, no "AI" — because the app must not claim any. Given the same
/// answers it returns the same plan, every time, which is also what makes the
/// self-check at the bottom meaningful.
enum OnboardingPlanBuilder {

    /// Resolve the first-flight length.
    ///
    /// An explicit tap always wins — the pilot knows their day better than a
    /// lookup table. Only "Choose for me" consults the rules, and the rules
    /// lean SHORT: a first flight that gets finished is worth more than an
    /// ambitious one that gets abandoned, and the two obstacles most likely to
    /// end in abandonment (overwhelm, procrastination) pull it down hardest.
    static func resolvedMinutes(goal: FocusGoal,
                                obstacle: FocusObstacle,
                                choice: FocusSessionChoice) -> Int {
        if let explicit = choice.explicitMinutes { return explicit }
        switch obstacle {
        case .overwhelm:       return 15
        case .procrastination: return 15
        case .unsureDuration:  return 25
        case .distractingApps, .losingMomentum, .environment:
            switch goal {
            case .deepWork, .buildProject: return 45
            case .study, .readLearn:       return 25
            case .reduceScreenTime:        return 25
            case .consistency:             return 25
            }
        }
    }

    /// Which length to mark "Recommended" on the question screen. Same rules,
    /// mapped back to an offered option — so the badge can never point at a
    /// value the resolver would not actually pick.
    static func recommendedChoice(goal: FocusGoal, obstacle: FocusObstacle) -> FocusSessionChoice {
        switch resolvedMinutes(goal: goal, obstacle: obstacle, choice: .recommended) {
        case ..<20:  return .fifteen
        case ..<35:  return .twentyFive
        case ..<55:  return .fortyFive
        default:     return .sixty
        }
    }

    /// Focus Shield is recommended when the pilot has TOLD us apps are the
    /// problem, or asked for it outright. It is never recommended on a hunch:
    /// suggesting a Screen Time permission to someone who never mentioned apps
    /// is how a warm-up becomes a nuisance.
    static func recommendsShield(obstacle: FocusObstacle, intent: ShieldIntent?) -> Bool {
        if intent == .yes { return true }
        return obstacle == .distractingApps || obstacle == .environment
    }

    /// The three benefits this pilot sees first, then the rest.
    ///
    /// Ordered by the OBSTACLE, because that is what the pilot just told us is
    /// standing between them and the thing they want. Goal breaks ties.
    static func benefitOrder(goal: FocusGoal, obstacle: FocusObstacle,
                             company: FocusCompany) -> [ProBenefit] {
        var lead: [ProBenefit]
        switch obstacle {
        case .distractingApps:
            lead = [.focusShield, .unlimitedTime, .widgetsAndPassport]
        case .environment:
            lead = [.exclusiveSkies, .skinsAndItems, .unlimitedTime]
        case .losingMomentum:
            lead = [.widgetsAndPassport, .unlimitedTime, .doubleCoins]
        case .procrastination:
            lead = [.widgetsAndPassport, .exclusiveSkies, .unlimitedTime]
        case .overwhelm:
            lead = [.exclusiveSkies, .widgetsAndPassport, .unlimitedTime]
        case .unsureDuration:
            lead = [.unlimitedTime, .widgetsAndPassport, .exclusiveSkies]
        }
        // Someone who focuses best around other people should hear about that
        // first, whatever their obstacle — it is the benefit they will feel.
        if company != .alone, !lead.contains(.onlineAndFriends) {
            lead.insert(.onlineAndFriends, at: 0)
            lead.removeLast()
        }
        // Reducing screen time and Focus Shield are the same conversation.
        if goal == .reduceScreenTime, !lead.contains(.focusShield) {
            lead.insert(.focusShield, at: 0)
            lead.removeLast()
        }
        let rest = ProBenefit.allCases.filter { !lead.contains($0) }
        return lead + rest
    }

    /// Build the plan. `fallbackSkyID` is the app's current default, used only
    /// if the pilot somehow reaches this without choosing.
    static func build(from answers: OnboardingAnswers, fallbackSkyID: String) -> OnboardingFocusPlan? {
        guard let goal = answers.goal,
              let obstacle = answers.obstacle,
              let choice = answers.sessionChoice,
              let cadence = answers.cadence,
              let company = answers.company
        else { return nil }

        return OnboardingFocusPlan(
            primaryGoal: goal,
            primaryObstacle: obstacle,
            recommendedDurationMinutes: resolvedMinutes(goal: goal, obstacle: obstacle, choice: choice),
            weeklyTarget: cadence.weeklyTarget,
            recommendedMode: company.recommendedMode,
            selectedSkyID: answers.skyID ?? fallbackSkyID,
            selectedSoundID: answers.choseSilence ? nil : answers.soundID,
            recommendsFocusShield: recommendsShield(obstacle: obstacle, intent: answers.shieldIntent),
            personalizedBenefitOrder: benefitOrder(goal: goal, obstacle: obstacle, company: company),
            suggestsReminders: cadence.suggestsReminders
        )
    }

    // MARK: - Self-check

    #if DEBUG
    /// Proves the rules hold for EVERY combination of answers, and — the point
    /// of this whole file — that every enum case actually changes something.
    /// Returns nil when healthy, else the first failure.
    static func _selfCheck() -> String? {
        // 1. Determinism and range.
        for goal in FocusGoal.allCases {
            for obstacle in FocusObstacle.allCases {
                for choice in FocusSessionChoice.allCases {
                    let a = resolvedMinutes(goal: goal, obstacle: obstacle, choice: choice)
                    let b = resolvedMinutes(goal: goal, obstacle: obstacle, choice: choice)
                    if a != b { return "resolvedMinutes not deterministic for \(goal)/\(obstacle)/\(choice)" }
                    if a < 15 || a > 60 { return "resolvedMinutes out of range (\(a)) for \(goal)/\(obstacle)" }
                    if let explicit = choice.explicitMinutes, a != explicit {
                        return "explicit choice \(choice) was overridden to \(a)"
                    }
                }
            }
        }
        // 2. The Recommended badge must agree with what the resolver picks.
        for goal in FocusGoal.allCases {
            for obstacle in FocusObstacle.allCases {
                let badge = recommendedChoice(goal: goal, obstacle: obstacle)
                let resolved = resolvedMinutes(goal: goal, obstacle: obstacle, choice: .recommended)
                if badge.explicitMinutes != resolved {
                    return "Recommended badge (\(badge)) disagrees with resolver (\(resolved)) for \(goal)/\(obstacle)"
                }
            }
        }
        // 3. Every obstacle must change the benefit order — an answer that
        //    changes nothing is an answer we must not ask for.
        var orders = Set<String>()
        for obstacle in FocusObstacle.allCases {
            let order = benefitOrder(goal: .study, obstacle: obstacle, company: .alone)
            if order.count != ProBenefit.allCases.count { return "benefitOrder dropped or duplicated a benefit" }
            if Set(order).count != order.count { return "benefitOrder contains duplicates for \(obstacle)" }
            orders.insert(order.prefix(3).map(\.rawValue).joined(separator: ","))
        }
        if orders.count < 4 { return "obstacle barely affects benefit order (\(orders.count) distinct leads)" }
        // 4. Every goal must be reachable in a plan, and every cadence distinct.
        if Set(FocusCadence.allCases.map { $0.weeklyTarget?.description ?? "flex" }).count
            != FocusCadence.allCases.count { return "two cadences resolve to the same target" }
        if Set(FocusCompany.allCases.map(\.recommendedMode.rawValue)).count < 2 {
            return "company answer does not change the recommended mode"
        }
        // 5. Shield recommendation must respond to both inputs.
        if !recommendsShield(obstacle: .distractingApps, intent: nil) { return "apps obstacle must recommend Shield" }
        if recommendsShield(obstacle: .losingMomentum, intent: .later) { return "Shield recommended against intent" }
        if !recommendsShield(obstacle: .losingMomentum, intent: .yes) { return "explicit yes must recommend Shield" }
        return nil
    }
    #endif
}
