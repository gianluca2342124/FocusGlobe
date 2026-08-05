import Foundation

// ============================================================================
// The semantic vocabulary of FocusGlobe's first run.
//
// Every answer is a STABLE ID, never the localized text the pilot tapped. That
// is what lets the copy be rewritten or translated without silently changing
// what a stored answer means, and what lets the plan builder be tested.
//
// No user-facing words live in this file. Each case maps to a `FocusStringKey`
// (see FocusStrings.swift) and the words themselves live once, in
// `FocusStringTable`. Keeping an English `displayName` here as well would mean
// two places to change a line of copy and only one of them translated.
//
// The rule this file exists to enforce: an answer that changes nothing must not
// be asked. The previous onboarding collected six answers and read exactly one
// of them — age, year-goal, obstacle and shield intent were written to the
// profile and never looked at again. Each type below is referenced by
// `OnboardingPlanBuilder`, and there is a compile-time-adjacent check at the
// bottom of that file asserting every case influences the plan.
// ============================================================================

/// What the pilot wants more focus for. Drives the recommended duration, the
/// benefit ordering and the personalized copy.
enum FocusGoal: String, Codable, CaseIterable, Sendable {
    case study
    case deepWork
    case buildProject
    case readLearn
    case reduceScreenTime
    case consistency

    var systemImage: String {
        switch self {
        case .study:            return "book.closed.fill"
        case .deepWork:         return "brain.head.profile"
        case .buildProject:     return "hammer.fill"
        case .readLearn:        return "text.book.closed.fill"
        case .reduceScreenTime: return "iphone.slash"
        case .consistency:      return "flame.fill"
        }
    }
}

/// What actually breaks the pilot's focus. This is the highest-signal answer in
/// the flow: it orders the PRO benefits, moves the recommended duration, and
/// decides whether Focus Shield is recommended at all.
enum FocusObstacle: String, Codable, CaseIterable, Sendable {
    case distractingApps
    case procrastination
    case losingMomentum
    case overwhelm
    case environment
    case unsureDuration

    var systemImage: String {
        switch self {
        case .distractingApps: return "hand.tap.fill"
        case .procrastination: return "clock.badge.exclamationmark.fill"
        case .losingMomentum:  return "chart.line.downtrend.xyaxis"
        case .overwhelm:       return "wind"
        case .environment:     return "speaker.wave.3.fill"
        case .unsureDuration:  return "questionmark.circle.fill"
        }
    }
}

/// How the pilot focuses best. Maps to a real `OnlineFlightMode` recommendation
/// — it never signs anyone in or opens a room, it only pre-selects.
enum FocusCompany: String, Codable, CaseIterable, Sendable {
    case alone
    case withFriends
    case aroundOthers
    case mixed

    /// The existing canonical mode type — deliberately not a parallel enum.
    var recommendedMode: OnlineFlightMode {
        switch self {
        case .alone:        return .solo
        case .withFriends:  return .privateRoom
        case .aroundOthers: return .publicSky
        case .mixed:        return .publicSky
        }
    }
}

/// How often the pilot wants to fly. `nil` weekly target means "flexible" —
/// deliberately a real option, because a target nobody chose is a target nobody
/// keeps.
enum FocusCadence: String, Codable, CaseIterable, Sendable {
    case threeDays
    case fiveDays
    case everyDay
    case flexible

    var weeklyTarget: Int? {
        switch self {
        case .threeDays: return 3
        case .fiveDays:  return 5
        case .everyDay:  return 7
        case .flexible:  return nil
        }
    }

    /// Whether a reminder is worth offering. Someone who chose "flexible" has
    /// just told us they do not want a schedule, so we do not ask to nag them.
    var suggestsReminders: Bool { self != .flexible }
}

/// The pilot's answer to "how long today". `.recommended` defers to the builder
/// rather than pre-selecting a value the pilot never chose.
enum FocusSessionChoice: String, Codable, CaseIterable, Sendable {
    case fifteen
    case twentyFive
    case fortyFive
    case sixty
    case recommended

    /// Nil for `.recommended`; the builder resolves it.
    var explicitMinutes: Int? {
        switch self {
        case .fifteen:     return 15
        case .twentyFive:  return 25
        case .fortyFive:   return 45
        case .sixty:       return 60
        case .recommended: return nil
        }
    }
}

/// Whether the pilot wants apps blocked during flights. Intent only — the
/// Family Controls prompt is never triggered from a question screen.
enum ShieldIntent: String, Codable, CaseIterable, Sendable {
    case yes
    case later
}

/// The PRO benefits the bridge and paywall may lead with, ordered per pilot.
///
/// Deliberately excludes anything PRO does not actually double or unlock: the
/// Free Coin Spin still requires a rewarded video for PRO, and the Daily Gift
/// is unchanged, so neither appears here.
enum ProBenefit: String, Codable, CaseIterable, Sendable {
    case focusShield
    case unlimitedTime
    case onlineAndFriends
    case exclusiveSkies
    case skinsAndItems
    case widgetsAndPassport
    case doubleCoins

    var systemImage: String {
        switch self {
        case .focusShield:        return "shield.lefthalf.filled"
        case .unlimitedTime:      return "infinity"
        case .onlineAndFriends:   return "person.2.fill"
        case .exclusiveSkies:     return "sparkles"
        case .skinsAndItems:      return "paintpalette.fill"
        case .widgetsAndPassport: return "square.grid.2x2.fill"
        case .doubleCoins:        return "circle.hexagongrid.fill"
        }
    }
}
