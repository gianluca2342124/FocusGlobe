import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// FocusGlobe's first run.
///
/// The host, and deliberately only the host: it owns the answers, the current
/// step and the hand-off to the app. Every screen is a separate value type that
/// takes a binding and reports a tap — none of them decides what comes next.
/// That is what the previous onboarding could not do. Its position was an `Int`
/// into an eleven-case `switch`, each screen called `advance()` and computed its
/// own skip rules, and the progress bar measured a step count no branch agreed
/// with. Inserting a screen renumbered every later one, and a force-quit at step
/// nine restarted at the welcome screen with nothing kept.
///
/// Here the order lives in `OnboardingFlow` — one pure, self-checked function —
/// so the bar cannot lie, back navigation is an array index, and a resumed
/// session lands on a step that still exists.
struct OnboardingView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.focusStrings) private var strings
    @Environment(\.scenePhase) private var scenePhase

    @State private var answers = OnboardingAnswers()
    @State private var step: OnboardingStepID = .welcome
    @State private var plan: OnboardingFocusPlan?
    @State private var variant: OnboardingVariant = .productionDefault
    @State private var didRestore = false
    /// The paywall is a coordinated modal, so "it closed" is the signal to move
    /// on. Latched, because `showPaywall` is false both before it opens and
    /// after it closes, and advancing on the first would skip the offer.
    @State private var paywallDidOpen = false
    /// Guards a double tap on a warm-up from requesting the same authorization
    /// twice or advancing twice.
    @State private var permissionInFlight = false

    private var flow: OnboardingFlow {
        OnboardingFlow(variant: variant,
                       answers: answers,
                       isPro: appModel.isPro,
                       shieldAvailable: appModel.focusShield.isSupported)
    }

    var body: some View {
        ZStack {
            OnboardingBackdrop()
            VStack(spacing: 0) {
                OnboardingHeader(step: step,
                                 progress: flow.progress(at: step),
                                 canGoBack: canGoBack,
                                 onBack: goBack)
                stepBody
                    .id(step)
                    .transition(.onboardingStep(reduceMotion: reduceMotion))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .task { restoreIfNeeded() }
        .onChange(of: router.showPaywall) { _, isUp in
            if isUp { paywallDidOpen = true }
            else if paywallDidOpen { paywallDidOpen = false; advance() }
        }
        // Buying PRO removes the paywall from the flow entirely. Without this,
        // a pilot who purchases is left standing on a step that no longer
        // exists, and the next tap has nowhere to go.
        // Backgrounding an unfinished first run is the funnel's most important
        // signal and the previous onboarding emitted nothing at all. Recorded
        // with the step reached — never with anything about the pilot.
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active, step != .completion else { return }
            appModel.analytics.log(.onboardingAbandoned,
                                   ["step": step.rawValue, "variant": variant.rawValue])
        }
        .onChange(of: appModel.isPro) { _, isPro in
            guard isPro, step == .paywall else { return }
            router.dismissModal()
            paywallDidOpen = false
            advance()
        }
    }

    private var canGoBack: Bool {
        step.showsBack && flow.previous(before: step) != nil
    }

    // MARK: - Steps

    @ViewBuilder private var stepBody: some View {
        switch step {
        case .welcome:
            OnboardingWelcomeStep(onStart: advance)

        case .primaryGoal:
            OnboardingGoalStep(selection: $answers.goal, onContinue: advance)

        case .focusObstacle:
            OnboardingObstacleStep(selection: $answers.obstacle, onContinue: advance)

        case .sessionLength:
            OnboardingDurationStep(selection: $answers.sessionChoice,
                                   goal: answers.goal,
                                   obstacle: answers.obstacle,
                                   onContinue: advance)

        case .weeklyFrequency:
            OnboardingCadenceStep(selection: $answers.cadence, onContinue: advance)

        case .focusStyle:
            OnboardingCompanyStep(selection: $answers.company, onContinue: advance)

        case .shieldPreference:
            OnboardingShieldIntentStep(selection: $answers.shieldIntent, onContinue: advance)

        case .skySelection:
            OnboardingSkyStep(selection: $answers.skyID,
                              unlockedIDs: unlockedSkyIDs,
                              onContinue: advance)

        case .soundSelection:
            OnboardingSoundStep(selection: $answers.soundID,
                                choseSilence: $answers.choseSilence,
                                unlockedIDs: unlockedSoundIDs,
                                onContinue: advance)

        case .planReveal:
            if let plan {
                OnboardingPlanRevealStep(plan: plan,
                                         skyName: FocusSky.byID(plan.selectedSkyID)?.name ?? "",
                                         soundName: soundName(for: plan),
                                         onContinue: advance,
                                         onRevealed: {
                    appModel.analytics.log(.onboardingPlanRevealed, [
                        "variant": variant.rawValue,
                        "minutes": plan.recommendedDurationMinutes,
                    ])
                })
            } else {
                // Unreachable in practice — the plan is built on the way into
                // this step. If it somehow is not, rebuild; and if the answers
                // genuinely cannot produce one, move on rather than leaving the
                // pilot on a screen waiting for something that is not coming.
                Color.clear.onAppear { if !buildAndApplyPlan() { advance() } }
            }

        case .flightPreview:
            OnboardingFlightPreviewStep(sky: previewSky,
                                        onContinue: completePreview,
                                        onStarted: {
                appModel.analytics.log(.onboardingPreviewStarted, ["sky": previewSky.id])
            })

        case .paywall:
            // The paywall is the standard one — Annual and Monthly, the plan
            // selector, the real localized StoreKit prices — presented as the
            // app's one coordinated modal. Onboarding does not own a second
            // purchase screen; it opens the same one the Home PRO button does.
            Color.clear.onAppear(perform: presentOnboardingPaywall)

        case .notificationWarmup:
            OnboardingNotificationWarmupStep(onAllow: requestNotifications,
                                             onSkip: { skipWarmup("notifications") },
                                             onAppearAnalytics: { warmupViewed("notifications") })

        case .shieldWarmup:
            OnboardingShieldWarmupStep(onAllow: requestShield,
                                       onSkip: { skipWarmup("screen_time") },
                                       onAppearAnalytics: { warmupViewed("screen_time") })

        case .completion:
            OnboardingCompletionStep(minutes: plan?.recommendedDurationMinutes
                                     ?? appModel.settings.preferredFlightMinutes ?? 25,
                                     onStart: finish)
        }
    }

    // MARK: - Catalogs

    private var unlockedSkyIDs: Set<String> {
        Set(FocusSky.all.filter { appModel.isSkyUnlocked($0) }.map(\.id))
    }

    private var unlockedSoundIDs: Set<String> {
        Set(JourneyAudioOption.all.filter { appModel.isAudioUnlocked($0) }.map(\.id))
    }

    /// The Sky the preview flies through: the pilot's own choice, falling back
    /// to the free default rather than to whichever Sky happens to be first.
    private var previewSky: FocusSky {
        FocusSky.byID(answers.skyID) ?? FocusSky.defaultFree
    }

    private func soundName(for plan: OnboardingFocusPlan) -> String? {
        guard let id = plan.selectedSoundID else { return nil }
        return JourneyAudioOption.all.first { $0.id == id }?.displayName
    }

    // MARK: - Navigation

    private func restoreIfNeeded() {
        guard !didRestore else { return }
        didRestore = true
        if let storedVariant = appModel.profile.onboardingVariantID,
           let decoded = OnboardingVariant(rawValue: storedVariant) {
            variant = decoded
        } else {
            // Rolled once here and persisted on the first `move(to:)`. Never
            // re-rolled: `saveOnboardingProgress` only writes it when the
            // profile holds none.
            variant = OnboardingVariant.assignForNewInstall()
        }
        if let stored = appModel.profile.onboardingAnswers { answers = stored }
        plan = appModel.profile.onboardingPlan
        let storedStep = appModel.profile.onboardingStepID.flatMap(OnboardingStepID.init(rawValue:))
        step = flow.resolvedResume(storedStep)
        appModel.analytics.log(storedStep == nil ? .onboardingStarted : .onboardingResumed,
                               ["variant": variant.rawValue, "step": step.rawValue])
    }

    private func advance() {
        appModel.tapFeedback()
        logAnswer(for: step)
        appModel.analytics.log(.onboardingStepCompleted,
                               ["step": step.rawValue, "variant": variant.rawValue])
        guard let next = flow.nextReachable(after: step) else { finish(); return }
        // The plan is built ON THE WAY INTO the reveal, so the checklist the
        // pilot sees is running alongside work that genuinely happened.
        if next == .planReveal { _ = buildAndApplyPlan() }
        // Give the soundscape screen a sensible starting point: the Sky's own
        // recommended ambience. A pre-selection the pilot can change beats an
        // empty screen with a disabled button.
        if next == .soundSelection, answers.soundID == nil, !answers.choseSilence {
            answers.soundID = previewSky.soundscapeID
        }
        move(to: next)
    }

    /// The answer a step produced, as its STABLE id.
    ///
    /// Never the localized text the pilot tapped: a copy rewrite would silently
    /// re-label every historical event, and a funnel that changes meaning
    /// between releases is worse than one that reports nothing.
    private func logAnswer(for step: OnboardingStepID) {
        let answer: String?
        switch step {
        case .primaryGoal:      answer = answers.goal?.rawValue
        case .focusObstacle:    answer = answers.obstacle?.rawValue
        case .sessionLength:    answer = answers.sessionChoice?.rawValue
        case .weeklyFrequency:  answer = answers.cadence?.rawValue
        case .focusStyle:       answer = answers.company?.rawValue
        case .shieldPreference: answer = answers.shieldIntent?.rawValue
        case .skySelection:     answer = answers.skyID
        case .soundSelection:   answer = answers.choseSilence ? "silence" : answers.soundID
        default:                answer = nil
        }
        guard let answer else { return }
        appModel.analytics.log(.onboardingAnswerSelected,
                               ["step": step.rawValue, "answer": answer,
                                "variant": variant.rawValue])
    }

    private func completePreview() {
        appModel.analytics.log(.onboardingPreviewCompleted, ["sky": previewSky.id])
        advance()
    }

    private func goBack() {
        guard let previous = flow.previous(before: step) else { return }
        appModel.tapFeedback()
        appModel.analytics.log(.onboardingBackTapped, ["from": step.rawValue])
        move(to: previous)
    }

    private func move(to next: OnboardingStepID) {
        withAnimation(reduceMotion ? nil : AppMotion.soft) { step = next }
        announce(next)
        // Persisted on every move, which is what makes the flow resumable: the
        // previous onboarding kept its position in `@State` alone, so a
        // force-quit discarded every answer.
        appModel.saveOnboardingProgress(answers: answers,
                                        stepID: next.rawValue,
                                        variantID: variant.rawValue)
        appModel.analytics.log(.onboardingStepViewed,
                               ["step": next.rawValue, "variant": variant.rawValue])
    }

    /// Tell VoiceOver the screen changed.
    ///
    /// A SwiftUI transition is invisible to assistive technology: without this,
    /// focus stays wherever the previous screen's Continue button was and the
    /// pilot hears nothing about the question they are now on. `.screenChanged`
    /// (rather than an announcement) also moves focus to the top of the new
    /// screen, which is where the question is.
    private func announce(_ step: OnboardingStepID) {
        guard let key = step.section.titleKey else { return }
        #if canImport(UIKit)
        UIAccessibility.post(notification: .screenChanged, argument: strings(key))
        #endif
    }

    // MARK: - Plan

    @discardableResult
    private func buildAndApplyPlan() -> Bool {
        guard let built = OnboardingPlanBuilder.build(from: answers,
                                                      fallbackSkyID: FocusSky.defaultFree.id)
        else { return false }
        plan = built
        // Applied, not just displayed. This writes the first-flight length, the
        // weekly target, the Sky, the soundscape and the Shield intent into the
        // canonical settings every other screen reads.
        appModel.applyOnboardingPlan(built)
        return true
    }

    // MARK: - Offer

    private func presentOnboardingPaywall() {
        guard !router.showPaywall else { return }
        // The SAME paywall the Home PRO button opens — Annual and Monthly, the
        // plan selector, the real localized StoreKit prices. Only the argument
        // it leads with is the pilot's: their headline, their Sky, their three
        // benefits, and a named free path.
        let personalization = plan.map { PaywallPersonalization(plan: $0) }
        appModel.analytics.log(.onboardingPaywallViewed, [
            "variant": variant.rawValue,
            "lead": personalization?.leadBenefit.rawValue ?? "",
        ])
        router.presentPaywall(context: .general, personalization: personalization)
    }

    // MARK: - Permissions

    private func warmupViewed(_ kind: String) {
        appModel.analytics.log(.onboardingPermissionWarmupViewed, ["kind": kind])
    }

    /// Declining is an ANSWER, not an absence of one: it is recorded, so the
    /// funnel can tell "was never asked" from "was asked and said no".
    private func skipWarmup(_ kind: String) {
        appModel.analytics.log(.onboardingPermissionResult, ["kind": kind, "granted": false,
                                                             "asked": false])
        advance()
    }

    private func requestNotifications() {
        guard !permissionInFlight else { return }
        permissionInFlight = true
        appModel.analytics.log(.onboardingPermissionRequested, ["kind": "notifications"])
        Task { @MainActor in
            let granted = await appModel.requestOnboardingNotificationPermission()
            appModel.analytics.log(.onboardingPermissionResult, ["kind": "notifications",
                                                                 "granted": granted,
                                                                 "asked": true])
            permissionInFlight = false
            advance()
        }
    }

    private func requestShield() {
        guard !permissionInFlight else { return }
        permissionInFlight = true
        appModel.analytics.log(.onboardingPermissionRequested, ["kind": "screen_time"])
        Task { @MainActor in
            await appModel.focusShield.requestAuthorization()
            // Only arm the feature if the pilot actually granted it. Enabling a
            // shield that cannot apply would show "on" in Settings for
            // something that never blocks anything.
            if appModel.focusShield.authState == .approved {
                appModel.focusShield.setEnabled(true)
            }
            appModel.analytics.log(.onboardingPermissionResult, [
                "kind": "screen_time",
                "granted": appModel.focusShield.authState == .approved,
                "asked": true,
            ])
            permissionInFlight = false
            advance()
        }
    }

    // MARK: - Hand-off

    /// Finish and cross-fade onto Home.
    ///
    /// The tab and the navigation path are set BEFORE `hasCompletedOnboarding`
    /// flips, so `AppShell` can never restore a stale tab behind the fade.
    private func finish() {
        appModel.tapFeedback()
        router.dismissModal()
        router.path.removeAll()
        router.selectedTab = .home
        appModel.completeOnboarding(answers: answers, plan: plan)
        // Onboarding has already made the PRO offer; Home must not open a
        // second one on top of the arrival.
        appModel.markPremiumIntroSeen()
    }
}
