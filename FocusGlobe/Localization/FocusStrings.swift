import SwiftUI

/// The app's string lookup, as a value.
///
/// Deliberately NOT an `ObservableObject` and not a singleton. The pilot's
/// language already lives in `AppSettings` — the one canonical, account-scoped
/// store — and a second observable holding the same choice is exactly the kind
/// of parallel state that drifts. This is a tiny immutable value carried in the
/// SwiftUI environment: change the language on `AppModel` and every view that
/// reads `\.focusStrings` re-renders, with no synchronisation to get wrong.
struct FocusStrings: Equatable, Sendable {
    /// The language as CHOSEN, which may be `.system`.
    let language: AppLanguage

    init(_ language: AppLanguage = .system) {
        self.language = language
    }

    /// The concrete language whose strings are actually used.
    var resolved: AppLanguage { language.resolved }

    /// The locale to format dates, numbers and durations with.
    var locale: Locale { language.locale }

    /// `strings(.obWelcomeTitle)`.
    func callAsFunction(_ key: FocusStringKey) -> String {
        FocusStringTable.string(key, language: language)
    }

    /// `strings(.obPlanMinutesFormat, 25)` — formatted in the pilot's locale, so
    /// a number is grouped the way they expect rather than the way `en_US` does.
    ///
    /// The first argument is separate from the variadic tail so this overload
    /// can never tie with the no-argument one above; an ambiguity there would
    /// resolve differently depending on the call site.
    func callAsFunction(_ key: FocusStringKey,
                        _ first: CVarArg,
                        _ rest: CVarArg...) -> String {
        String(format: FocusStringTable.string(key, language: language),
               locale: locale,
               arguments: [first] + rest)
    }
}

// MARK: - Environment

private struct FocusStringsKey: EnvironmentKey {
    static let defaultValue = FocusStrings(.system)
}

extension EnvironmentValues {
    /// Read with `@Environment(\.focusStrings) private var strings`.
    var focusStrings: FocusStrings {
        get { self[FocusStringsKey.self] }
        set { self[FocusStringsKey.self] = newValue }
    }
}

extension View {
    /// Applies a language to this subtree: the string table AND the locale.
    ///
    /// Both, together, on purpose. Setting only the table would leave dates and
    /// numbers formatted for whatever the device was set to; setting only the
    /// locale would leave the copy in the previous language. Applied at the
    /// window root, this makes a language change take effect on the next frame
    /// with no relaunch and nothing to invalidate by hand.
    func focusLanguage(_ language: AppLanguage) -> some View {
        environment(\.focusStrings, FocusStrings(language))
            .environment(\.locale, language.locale)
    }
}

// MARK: - Domain keys

extension FocusGoal {
    var titleKey: FocusStringKey {
        switch self {
        case .study:            return .obGoalStudy
        case .deepWork:         return .obGoalDeepWork
        case .buildProject:     return .obGoalBuildProject
        case .readLearn:        return .obGoalReadLearn
        case .reduceScreenTime: return .obGoalReduceScreenTime
        case .consistency:      return .obGoalConsistency
        }
    }

    /// The personalized first half of the commitment line at the top of the
    /// duration screen.
    var commitmentKey: FocusStringKey {
        switch self {
        case .study:            return .obDurationBridgeStudy
        case .deepWork:         return .obDurationBridgeDeepWork
        case .buildProject:     return .obDurationBridgeBuild
        case .readLearn:        return .obDurationBridgeRead
        case .reduceScreenTime: return .obDurationBridgeScreen
        case .consistency:      return .obDurationBridgeConsistency
        }
    }
}

extension FocusObstacle {
    var titleKey: FocusStringKey {
        switch self {
        case .distractingApps: return .obObstacleApps
        case .procrastination: return .obObstacleProcrastination
        case .losingMomentum:  return .obObstacleMomentum
        case .overwhelm:       return .obObstacleOverwhelm
        case .environment:     return .obObstacleEnvironment
        case .unsureDuration:  return .obObstacleUnsure
        }
    }

    /// The second half of the commitment line — why the suggested length is what
    /// it is, in terms of the obstacle the pilot just named.
    var commitmentReasonKey: FocusStringKey {
        switch self {
        case .distractingApps: return .obDurationReasonApps
        case .procrastination: return .obDurationReasonProcrast
        case .losingMomentum:  return .obDurationReasonMomentum
        case .overwhelm:       return .obDurationReasonOverwhelm
        case .environment:     return .obDurationReasonEnvironment
        case .unsureDuration:  return .obDurationReasonUnsure
        }
    }

    /// The one honest sentence under the plan card.
    var rationaleKey: FocusStringKey {
        switch self {
        case .distractingApps: return .obPlanRationaleApps
        case .procrastination: return .obPlanRationaleProcrast
        case .losingMomentum:  return .obPlanRationaleMomentum
        case .overwhelm:       return .obPlanRationaleOverwhelm
        case .environment:     return .obPlanRationaleEnvironment
        case .unsureDuration:  return .obPlanRationaleUnsure
        }
    }
}

extension FocusCompany {
    var titleKey: FocusStringKey {
        switch self {
        case .alone:        return .obCompanyAlone
        case .withFriends:  return .obCompanyFriends
        case .aroundOthers: return .obCompanyOthers
        case .mixed:        return .obCompanyMixed
        }
    }

    /// The mode shown on the plan card. `.mixed` recommends Online, so it reads
    /// as Online here — the plan must state what it actually set.
    var modeKey: FocusStringKey {
        switch recommendedMode {
        case .solo:        return .obPlanModeSolo
        case .privateRoom: return .obPlanModePrivate
        case .publicSky:   return .obPlanModePublic
        }
    }
}

extension FocusCadence {
    var titleKey: FocusStringKey {
        switch self {
        case .threeDays: return .obCadenceThree
        case .fiveDays:  return .obCadenceFive
        case .everyDay:  return .obCadenceEvery
        case .flexible:  return .obCadenceFlexible
        }
    }
}

extension FocusSessionChoice {
    /// "15 min" is a number in a format, not a translated phrase — a language
    /// that writes durations differently changes the format, not five separate
    /// hard-coded labels.
    func title(_ strings: FocusStrings) -> String {
        guard let minutes = explicitMinutes else { return strings(.obDurationChooseForMe) }
        return strings(.obDurationMinutesFormat, minutes)
    }
}

extension ShieldIntent {
    var titleKey: FocusStringKey {
        switch self {
        case .yes:   return .obShieldYes
        case .later: return .obShieldLater
        }
    }
}

extension ProBenefit {
    var titleKey: FocusStringKey {
        switch self {
        case .focusShield:        return .benefitShieldTitle
        case .unlimitedTime:      return .benefitTimeTitle
        case .onlineAndFriends:   return .benefitOnlineTitle
        case .exclusiveSkies:     return .benefitSkiesTitle
        case .skinsAndItems:      return .benefitSkinsTitle
        case .widgetsAndPassport: return .benefitWidgetsTitle
        case .doubleCoins:        return .benefitCoinsTitle
        }
    }

    var detailKey: FocusStringKey {
        switch self {
        case .focusShield:        return .benefitShieldDetail
        case .unlimitedTime:      return .benefitTimeDetail
        case .onlineAndFriends:   return .benefitOnlineDetail
        case .exclusiveSkies:     return .benefitSkiesDetail
        case .skinsAndItems:      return .benefitSkinsDetail
        case .widgetsAndPassport: return .benefitWidgetsDetail
        case .doubleCoins:        return .benefitCoinsDetail
        }
    }

    /// The paywall headline when this benefit leads for a given pilot.
    var headlineKey: FocusStringKey {
        switch self {
        case .focusShield:        return .paywallHeadShield
        case .unlimitedTime:      return .paywallHeadTime
        case .onlineAndFriends:   return .paywallHeadOnline
        case .exclusiveSkies:     return .paywallHeadSkies
        case .skinsAndItems:      return .paywallHeadSkins
        case .widgetsAndPassport: return .paywallHeadWidgets
        case .doubleCoins:        return .paywallHeadCoins
        }
    }
}

extension OnboardingSection {
    var titleKey: FocusStringKey? {
        switch self {
        case .welcome:    return nil
        case .about:      return .obSectionAbout
        case .rhythm:     return .obSectionRhythm
        case .atmosphere: return .obSectionAtmosphere
        case .plan:       return .obSectionPlan
        case .offer:      return .obSectionOffer
        case .finish:     return .obSectionFinish
        }
    }
}

#if DEBUG
extension FocusStrings {
    /// Every domain case must map to a key that exists in the table, and no two
    /// cases of the same enum may share one — a shared key means two different
    /// answers render the same words, which is how an option list stops being a
    /// choice.
    static func _selfCheck() -> String? {
        func distinct<T: CaseIterable & Hashable>(_ cases: T.Type,
                                                  _ key: (T) -> FocusStringKey,
                                                  _ label: String) -> String? {
            let keys = T.allCases.map(key)
            if Set(keys).count != keys.count { return "\(label) reuses a string key" }
            return nil
        }
        if let f = distinct(FocusGoal.self, { $0.titleKey }, "FocusGoal.titleKey") { return f }
        if let f = distinct(FocusGoal.self, { $0.commitmentKey }, "FocusGoal.commitmentKey") { return f }
        if let f = distinct(FocusObstacle.self, { $0.titleKey }, "FocusObstacle.titleKey") { return f }
        if let f = distinct(FocusObstacle.self, { $0.commitmentReasonKey }, "FocusObstacle.commitmentReasonKey") { return f }
        if let f = distinct(FocusObstacle.self, { $0.rationaleKey }, "FocusObstacle.rationaleKey") { return f }
        if let f = distinct(FocusCompany.self, { $0.titleKey }, "FocusCompany.titleKey") { return f }
        if let f = distinct(FocusCadence.self, { $0.titleKey }, "FocusCadence.titleKey") { return f }
        if let f = distinct(ShieldIntent.self, { $0.titleKey }, "ShieldIntent.titleKey") { return f }
        if let f = distinct(ProBenefit.self, { $0.titleKey }, "ProBenefit.titleKey") { return f }
        if let f = distinct(ProBenefit.self, { $0.detailKey }, "ProBenefit.detailKey") { return f }
        if let f = distinct(ProBenefit.self, { $0.headlineKey }, "ProBenefit.headlineKey") { return f }
        // Section titles must exist for every measured section, or the progress
        // bar renders a blank label.
        for section in OnboardingSection.measured where section.titleKey == nil {
            return "measured section \(section) has no title key"
        }
        return nil
    }
}
#endif
