import Foundation

/// Every translatable string FocusGlobe currently owns.
///
/// A typed key rather than a bare `String` literal, for one specific reason:
/// with `NSLocalizedString("ob.welcome.title", ...)` a typo compiles, ships, and
/// renders the key itself on a customer's screen. With this enum a typo does not
/// build, and `allCases` makes "is this language complete?" a computation rather
/// than a claim (see `LocalizationCoverage`).
///
/// The raw value's first component names the surface, and
/// `FocusStringKey.surface` derives from it. That is checked in `_selfCheck()`,
/// so a key cannot be filed under a surface it does not belong to.
enum FocusStringKey: String, CaseIterable, Hashable, Sendable {

    // MARK: Shared onboarding chrome
    case obContinue                 = "ob.common.continue"
    case obBack                     = "ob.common.back"
    case obSkip                     = "ob.common.skip"
    case obNotNow                   = "ob.common.notNow"
    case obRecommended              = "ob.common.recommended"
    case obStepOfFormat             = "ob.common.stepOfFormat"

    // MARK: Progress sections
    case obSectionAbout             = "ob.section.about"
    case obSectionRhythm            = "ob.section.rhythm"
    case obSectionAtmosphere        = "ob.section.atmosphere"
    case obSectionPlan              = "ob.section.plan"
    case obSectionOffer             = "ob.section.offer"
    case obSectionFinish            = "ob.section.finish"

    // MARK: Welcome
    case obWelcomeTitle             = "ob.welcome.title"
    case obWelcomeSubtitle          = "ob.welcome.subtitle"
    case obWelcomeCTA               = "ob.welcome.cta"
    case obWelcomeLanguage          = "ob.welcome.language"
    /// The "follow the device" row in the language control. Filed under
    /// onboarding because the welcome screen is where the control first appears;
    /// the Settings row reuses the same two strings rather than owning a second
    /// copy of the same words.
    case obLanguageSystem           = "ob.language.system"

    // MARK: Goal
    case obGoalTitle                = "ob.goal.title"
    case obGoalSubtitle             = "ob.goal.subtitle"
    case obGoalStudy                = "ob.goal.option.study"
    case obGoalDeepWork             = "ob.goal.option.deepWork"
    case obGoalBuildProject         = "ob.goal.option.buildProject"
    case obGoalReadLearn            = "ob.goal.option.readLearn"
    case obGoalReduceScreenTime     = "ob.goal.option.reduceScreenTime"
    case obGoalConsistency          = "ob.goal.option.consistency"

    // MARK: Obstacle
    case obObstacleTitle            = "ob.obstacle.title"
    case obObstacleSubtitle         = "ob.obstacle.subtitle"
    case obObstacleApps             = "ob.obstacle.option.distractingApps"
    case obObstacleProcrastination  = "ob.obstacle.option.procrastination"
    case obObstacleMomentum         = "ob.obstacle.option.losingMomentum"
    case obObstacleOverwhelm        = "ob.obstacle.option.overwhelm"
    case obObstacleEnvironment      = "ob.obstacle.option.environment"
    case obObstacleUnsure           = "ob.obstacle.option.unsureDuration"

    // MARK: First-flight length (with the personalized commitment line on top)
    case obDurationTitle            = "ob.duration.title"
    case obDurationSubtitle         = "ob.duration.subtitle"
    case obDurationBridgeStudy      = "ob.duration.bridge.goal.study"
    case obDurationBridgeDeepWork   = "ob.duration.bridge.goal.deepWork"
    case obDurationBridgeBuild      = "ob.duration.bridge.goal.buildProject"
    case obDurationBridgeRead       = "ob.duration.bridge.goal.readLearn"
    case obDurationBridgeScreen     = "ob.duration.bridge.goal.reduceScreenTime"
    case obDurationBridgeConsistency = "ob.duration.bridge.goal.consistency"
    case obDurationReasonApps       = "ob.duration.bridge.obstacle.distractingApps"
    case obDurationReasonProcrast   = "ob.duration.bridge.obstacle.procrastination"
    case obDurationReasonMomentum   = "ob.duration.bridge.obstacle.losingMomentum"
    case obDurationReasonOverwhelm  = "ob.duration.bridge.obstacle.overwhelm"
    case obDurationReasonEnvironment = "ob.duration.bridge.obstacle.environment"
    case obDurationReasonUnsure     = "ob.duration.bridge.obstacle.unsureDuration"
    case obDurationMinutesFormat    = "ob.duration.option.minutesFormat"
    case obDurationChooseForMe      = "ob.duration.option.chooseForMe"

    // MARK: Weekly cadence
    case obCadenceTitle             = "ob.cadence.title"
    case obCadenceSubtitle          = "ob.cadence.subtitle"
    case obCadenceThree             = "ob.cadence.option.threeDays"
    case obCadenceFive              = "ob.cadence.option.fiveDays"
    case obCadenceEvery             = "ob.cadence.option.everyDay"
    case obCadenceFlexible          = "ob.cadence.option.flexible"

    // MARK: Company / flight style
    case obCompanyTitle             = "ob.company.title"
    case obCompanySubtitle          = "ob.company.subtitle"
    case obCompanyAlone             = "ob.company.option.alone"
    case obCompanyFriends           = "ob.company.option.withFriends"
    case obCompanyOthers            = "ob.company.option.aroundOthers"
    case obCompanyMixed             = "ob.company.option.mixed"

    // MARK: Shield preference
    case obShieldTitle              = "ob.shield.title"
    case obShieldSubtitle           = "ob.shield.subtitle"
    case obShieldYes                = "ob.shield.option.yes"
    case obShieldLater              = "ob.shield.option.later"

    // MARK: Sky
    case obSkyTitle                 = "ob.sky.title"
    case obSkySubtitle              = "ob.sky.subtitle"
    case obSkyLocked                = "ob.sky.locked"

    // MARK: Soundscape
    case obSoundTitle               = "ob.sound.title"
    case obSoundSubtitle            = "ob.sound.subtitle"
    case obSoundSilence             = "ob.sound.silence"

    // MARK: Plan preparation (runs inside the reveal, never its own screen)
    case obPlanBuildingTitle        = "ob.plan.building.title"
    case obPlanBuildingGoal         = "ob.plan.building.step.goal"
    case obPlanBuildingLength       = "ob.plan.building.step.length"
    case obPlanBuildingAtmosphere   = "ob.plan.building.step.atmosphere"

    // MARK: Plan reveal
    case obPlanTitle                = "ob.plan.title"
    case obPlanRowFlight            = "ob.plan.row.firstFlight"
    case obPlanRowWeekly            = "ob.plan.row.weeklyTarget"
    case obPlanRowMode              = "ob.plan.row.mode"
    case obPlanRowSky               = "ob.plan.row.sky"
    case obPlanRowSound             = "ob.plan.row.sound"
    case obPlanRowShield            = "ob.plan.row.shield"
    case obPlanMinutesFormat        = "ob.plan.value.minutesFormat"
    case obPlanDaysFormat           = "ob.plan.value.daysPerWeekFormat"
    case obPlanFlexible             = "ob.plan.value.flexible"
    case obPlanShieldOn             = "ob.plan.value.shieldRecommended"
    case obPlanShieldOff            = "ob.plan.value.shieldOff"
    case obPlanModeSolo             = "ob.plan.value.modeSolo"
    case obPlanModePrivate          = "ob.plan.value.modePrivate"
    case obPlanModePublic           = "ob.plan.value.modePublic"
    case obPlanRationaleApps        = "ob.plan.rationale.distractingApps"
    case obPlanRationaleProcrast    = "ob.plan.rationale.procrastination"
    case obPlanRationaleMomentum    = "ob.plan.rationale.losingMomentum"
    case obPlanRationaleOverwhelm   = "ob.plan.rationale.overwhelm"
    case obPlanRationaleEnvironment = "ob.plan.rationale.environment"
    case obPlanRationaleUnsure      = "ob.plan.rationale.unsureDuration"
    case obPlanCTA                  = "ob.plan.cta"
    case obPlanAdjust               = "ob.plan.adjust"

    // MARK: Flight preview
    case obPreviewTitle             = "ob.preview.title"
    case obPreviewSubtitle          = "ob.preview.subtitle"
    case obPreviewCTA               = "ob.preview.cta"
    case obPreviewSkip              = "ob.preview.skip"

    // MARK: Reminder warm-up
    case obNotifyTitle              = "ob.notify.title"
    case obNotifySubtitle           = "ob.notify.subtitle"
    case obNotifyCTA                = "ob.notify.cta"

    // MARK: Focus Shield warm-up
    case obShieldWarmTitle          = "ob.shieldWarmup.title"
    case obShieldWarmSubtitle       = "ob.shieldWarmup.subtitle"
    case obShieldWarmCTA            = "ob.shieldWarmup.cta"

    // MARK: Completion
    case obDoneTitle                = "ob.done.title"
    case obDoneSubtitle             = "ob.done.subtitle"
    case obDoneCTA                  = "ob.done.cta"
    case obDoneSignIn               = "ob.done.signIn"
    case obDoneSignInDetail         = "ob.done.signInDetail"

    // MARK: Paywall — personalized headlines (one per lead benefit)
    case paywallHeadShield          = "paywall.headline.focusShield"
    case paywallHeadTime            = "paywall.headline.unlimitedTime"
    case paywallHeadOnline          = "paywall.headline.onlineAndFriends"
    case paywallHeadSkies           = "paywall.headline.exclusiveSkies"
    case paywallHeadSkins           = "paywall.headline.skinsAndItems"
    case paywallHeadWidgets         = "paywall.headline.widgetsAndPassport"
    case paywallHeadCoins           = "paywall.headline.doubleCoins"
    case paywallSubhead             = "paywall.subhead"
    case paywallFreePath            = "paywall.freePath"

    // MARK: Paywall — benefits
    case benefitShieldTitle         = "paywall.benefit.focusShield.title"
    case benefitShieldDetail        = "paywall.benefit.focusShield.detail"
    case benefitTimeTitle           = "paywall.benefit.unlimitedTime.title"
    case benefitTimeDetail          = "paywall.benefit.unlimitedTime.detail"
    case benefitOnlineTitle         = "paywall.benefit.onlineAndFriends.title"
    case benefitOnlineDetail        = "paywall.benefit.onlineAndFriends.detail"
    case benefitSkiesTitle          = "paywall.benefit.exclusiveSkies.title"
    case benefitSkiesDetail         = "paywall.benefit.exclusiveSkies.detail"
    case benefitSkinsTitle          = "paywall.benefit.skinsAndItems.title"
    case benefitSkinsDetail         = "paywall.benefit.skinsAndItems.detail"
    case benefitWidgetsTitle        = "paywall.benefit.widgetsAndPassport.title"
    case benefitWidgetsDetail       = "paywall.benefit.widgetsAndPassport.detail"
    case benefitCoinsTitle          = "paywall.benefit.doubleCoins.title"
    case benefitCoinsDetail         = "paywall.benefit.doubleCoins.detail"

    // MARK: Paywall — chrome
    case paywallRestore             = "paywall.restore"
    case paywallTerms               = "paywall.terms"
    case paywallPrivacy             = "paywall.privacy"
    case paywallBestValue           = "paywall.bestValue"

    /// Derived from the raw value's first component. Never hand-assigned, so a
    /// key cannot drift away from the surface its prefix says it is on.
    var surface: LocalizationSurface {
        let prefix = String(rawValue.prefix { $0 != "." })
        switch prefix {
        case "ob":      return .onboarding
        case "paywall": return .paywalls
        default:        return .onboarding
        }
    }

    /// True when the string is a format that consumes arguments. Checked against
    /// the translations so a language cannot drop a placeholder and crash
    /// `String(format:)` — or, worse, silently render "%@".
    var placeholderCount: Int {
        switch self {
        case .obStepOfFormat:         return 2   // "Step %1$d of %2$d"
        case .obDurationMinutesFormat,
             .obPlanMinutesFormat,
             .obPlanDaysFormat:       return 1
        default:                      return 0
        }
    }

    #if DEBUG
    static func _selfCheck() -> String? {
        // Raw values must be unique (the compiler guarantees it) and every
        // prefix must map to a surface that exists and routes through the table.
        var seen = Set<String>()
        for key in allCases {
            if !seen.insert(key.rawValue).inserted { return "duplicate key \(key.rawValue)" }
            let prefix = String(key.rawValue.prefix { $0 != "." })
            if prefix != "ob" && prefix != "paywall" {
                return "key \(key.rawValue) has no recognised surface prefix"
            }
            if !key.surface.routesThroughStringTable {
                return "key \(key.rawValue) belongs to a surface that does not route through the table"
            }
            if key.rawValue.hasSuffix(".") || key.rawValue.contains("..") {
                return "malformed key \(key.rawValue)"
            }
        }
        return nil
    }
    #endif
}
