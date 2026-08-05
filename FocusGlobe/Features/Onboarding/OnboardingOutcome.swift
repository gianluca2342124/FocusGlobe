import SwiftUI

// ============================================================================
// Everything after the questions: the plan, the preview, the permission
// warm-ups and the arrival.
//
// The rule these screens exist to honour: the plan card must be a decision, not
// a picture of one. `AppModel.applyOnboardingPlan(_:)` runs the moment the
// reveal appears, writing the pilot's answers into the same canonical settings
// the rest of the app reads — so what is shown here is what Home, flight setup,
// the Passport and the Shield warm-up will actually do.
// ============================================================================

/// Plan preparation and reveal, on ONE screen.
///
/// Preparation is not a separate step. As its own screen it would be a
/// full-screen spinner between two real screens: the pilot taps Continue, waits,
/// then taps again to see what they waited for. Here the checklist runs inside
/// the reveal and crossfades into the finished card, so the wait is the reveal.
///
/// The checklist is short (~1.2 s) and describes work that genuinely happens:
/// the plan is built and applied while it runs. It is a reveal, not a fake
/// progress bar — nothing here waits longer than the work takes in order to
/// look like it did more.
struct OnboardingPlanRevealStep: View {
    let plan: OnboardingFocusPlan
    let skyName: String
    let soundName: String?
    let onContinue: () -> Void
    /// Fired when the finished card actually appears — not when the step is
    /// entered. The gap between the two is the checklist, and counting a reveal
    /// that a pilot backgrounded through would overstate the funnel.
    var onRevealed: () -> Void = {}

    @Environment(\.focusStrings) private var strings
    @Environment(\.focusViewport) private var viewport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How many checklist lines have ticked so far.
    @State private var completedLines = 0
    @State private var showsPlan = false

    private var checklist: [FocusStringKey] {
        [.obPlanBuildingGoal, .obPlanBuildingLength, .obPlanBuildingAtmosphere]
    }

    var body: some View {
        ZStack {
            if showsPlan {
                planCard.transition(.opacity)
            } else {
                buildingList.transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: showsPlan)
        .task { await runPreparation() }
    }

    /// Reduce Motion skips the reveal entirely rather than replaying it slowly:
    /// someone who has asked for less motion has not asked for a longer wait.
    private func runPreparation() async {
        guard !showsPlan else { return }
        guard !reduceMotion else {
            completedLines = checklist.count
            showsPlan = true
            onRevealed()
            return
        }
        for index in checklist.indices {
            try? await Task.sleep(nanoseconds: 380_000_000)
            guard !Task.isCancelled else { return }
            completedLines = index + 1
        }
        try? await Task.sleep(nanoseconds: 120_000_000)
        guard !Task.isCancelled else { return }
        showsPlan = true
        onRevealed()
    }

    // MARK: Preparation

    private var buildingList: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Text(strings(.obPlanBuildingTitle))
                .font(.system(size: viewport.titleSize * 0.8, weight: .bold))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ForEach(Array(checklist.enumerated()), id: \.offset) { index, key in
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: index < completedLines ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(index < completedLines ? AppColors.gold : .white.opacity(0.3))
                        Text(strings(key))
                            .font(AppTypography.callout)
                            .foregroundStyle(.white.opacity(index < completedLines ? 0.92 : 0.5))
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, viewport.pagePadding)
            Spacer()
        }
        .frame(maxWidth: viewport.readableContentWidth)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(strings(.obPlanBuildingTitle)))
    }

    // MARK: The plan

    private var planCard: some View {
        OnboardingScaffold(title: strings(.obPlanTitle),
                           subtitle: strings(plan.rationaleKey)) {
            VStack(spacing: 0) {
                row(strings(.obPlanRowFlight),
                    strings(.obPlanMinutesFormat, plan.recommendedDurationMinutes),
                    "timer")
                divider
                row(strings(.obPlanRowWeekly),
                    plan.weeklyTarget.map { strings(.obPlanDaysFormat, $0) } ?? strings(.obPlanFlexible),
                    "calendar")
                divider
                row(strings(.obPlanRowMode), modeLabel, "person.2.fill")
                divider
                row(strings(.obPlanRowSky), skyName, "sparkles")
                divider
                row(strings(.obPlanRowSound), soundName ?? strings(.obSoundSilence),
                    soundName == nil ? "speaker.slash.fill" : "waveform")
                divider
                row(strings(.obPlanRowShield),
                    plan.recommendsFocusShield ? strings(.obPlanShieldOn) : strings(.obPlanShieldOff),
                    "shield.lefthalf.filled")
            }
            .padding(AppSpacing.md)
            .background(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                .fill(Color.white.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1))
        } footer: {
            OnboardingFooter(title: strings(.obPlanCTA), action: onContinue)
        }
    }

    private var modeLabel: String {
        switch plan.recommendedMode {
        case .solo:        return strings(.obPlanModeSolo)
        case .privateRoom: return strings(.obPlanModePrivate)
        case .publicSky:   return strings(.obPlanModePublic)
        }
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
    }

    private func row(_ label: String, _ value: String, _ icon: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.gold)
                .frame(width: 24)
            Text(label)
                .font(AppTypography.callout)
                .foregroundStyle(.white.opacity(0.7))
            Spacer(minLength: AppSpacing.xs)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }
}

/// A short, skippable look at what a flight is.
///
/// Explicitly NOT a real flight. It starts no session, credits no Coins, touches
/// no streak, writes no resume snapshot and publishes no Online presence — it
/// renders the pilot's chosen Sky with a balloon crossing it, and that is all.
/// The subtitle says so, because a preview that looks like the real thing and
/// says nothing is a preview a pilot will think they just wasted.
struct OnboardingFlightPreviewStep: View {
    let sky: FocusSky
    let onContinue: () -> Void
    var onStarted: () -> Void = {}

    @Environment(\.focusStrings) private var strings
    @Environment(\.focusViewport) private var viewport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The preview's own clock. A `TimelineView` schedule rather than a
    /// `repeatForever` animation on `@State`, so pausing it for Reduce Motion is
    /// one flag instead of an animation that has to be cancelled.
    @State private var startedAt = Date()

    /// Long enough to read as a journey, short enough that nobody waits it out.
    private let duration: TimeInterval = 8

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            TimelineView(.animation(paused: reduceMotion)) { context in
                let elapsed = context.date.timeIntervalSince(startedAt)
                let t = reduceMotion ? 0.5 : min(1, max(0, elapsed / duration))
                stage(progress: t)
            }
            .frame(height: viewport.isShort ? 210 : 280)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .padding(.horizontal, viewport.pagePadding)
            .accessibilityHidden(true)

            VStack(spacing: AppSpacing.xs) {
                Text(strings(.obPreviewTitle))
                    .font(.system(size: viewport.titleSize * 0.8, weight: .bold))
                    .foregroundStyle(.white)
                Text(strings(.obPreviewSubtitle))
                    .font(AppTypography.callout)
                    .foregroundStyle(.white.opacity(0.66))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, viewport.pagePadding)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 0)

            // Continue is live from the first frame. A preview that withholds
            // its own exit for eight seconds is not skippable, whatever the
            // secondary label says.
            OnboardingFooter(title: strings(.obPreviewCTA), action: onContinue,
                             secondaryTitle: strings(.obPreviewSkip),
                             secondaryAction: onContinue)
                .padding(.horizontal, viewport.pagePadding)
        }
        .padding(.top, AppSpacing.md)
        .padding(.bottom, viewport.isShort ? AppSpacing.md : AppSpacing.lg)
        .frame(maxWidth: viewport.readableContentWidth)
        .frame(maxWidth: .infinity)
        .onAppear { startedAt = Date(); onStarted() }
    }

    private func stage(progress t: Double) -> some View {
        GeometryReader { geo in
            ZStack {
                SkyStillPreview(sky: sky, landscape: true)
                // A gentle arc across the Sky: in from the left, up over the
                // middle, out to the right.
                BalloonView(height: 54, showBurner: false, showGlow: true,
                            glow: AppColors.gold.opacity(0.5))
                    .position(x: geo.size.width * (0.12 + 0.76 * t),
                              y: geo.size.height * (0.62 - 0.18 * sin(t * .pi)))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// Reminder warm-up. Shown only when the pilot chose a weekly cadence — someone
/// who picked "keep it flexible" has already said they do not want a schedule.
struct OnboardingNotificationWarmupStep: View {
    let onAllow: () -> Void
    let onSkip: () -> Void
    var onAppearAnalytics: () -> Void = {}

    @Environment(\.focusStrings) private var strings
    @Environment(\.focusViewport) private var viewport

    var body: some View {
        OnboardingWarmupLayout(systemImage: "bell.badge.fill",
                               title: strings(.obNotifyTitle),
                               message: strings(.obNotifySubtitle)) {
            OnboardingFooter(title: strings(.obNotifyCTA), action: onAllow,
                             secondaryTitle: strings(.obNotNow),
                             secondaryAction: onSkip)
        }
        .padding(.horizontal, viewport.pagePadding)
        .onAppear(perform: onAppearAnalytics)
    }
}

/// Focus Shield warm-up. Explains what iOS is about to ask for BEFORE iOS asks —
/// the whole point of a warm-up is that the system dialog is never the first
/// time a pilot hears about the permission.
struct OnboardingShieldWarmupStep: View {
    let onAllow: () -> Void
    let onSkip: () -> Void
    var onAppearAnalytics: () -> Void = {}

    @Environment(\.focusStrings) private var strings
    @Environment(\.focusViewport) private var viewport

    var body: some View {
        OnboardingWarmupLayout(systemImage: "shield.lefthalf.filled",
                               title: strings(.obShieldWarmTitle),
                               message: strings(.obShieldWarmSubtitle)) {
            OnboardingFooter(title: strings(.obShieldWarmCTA), action: onAllow,
                             secondaryTitle: strings(.obNotNow),
                             secondaryAction: onSkip)
        }
        .padding(.horizontal, viewport.pagePadding)
        .onAppear(perform: onAppearAnalytics)
    }
}

/// Shared warm-up layout — icon, title, one honest paragraph, two real choices.
private struct OnboardingWarmupLayout<Footer: View>: View {
    let systemImage: String
    let title: String
    let message: String
    @ViewBuilder var footer: () -> Footer

    @Environment(\.focusViewport) private var viewport

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer(minLength: 0)
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(AppColors.gold)
                .accessibilityHidden(true)
            VStack(spacing: AppSpacing.sm) {
                Text(title)
                    .font(.system(size: viewport.titleSize * 0.82, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(AppTypography.callout)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            footer()
        }
        .padding(.bottom, viewport.isShort ? AppSpacing.md : AppSpacing.lg)
        .frame(maxWidth: viewport.readableContentWidth)
        .frame(maxWidth: .infinity)
    }
}

/// The arrival.
///
/// Sign in with Apple is offered here as a genuinely secondary action, not as a
/// step of its own and never as a gate: signing in is how a pilot recovers an
/// account and an entitlement they already own, and giving it a full screen
/// implies it is required to fly.
struct OnboardingCompletionStep: View {
    let minutes: Int
    let onStart: () -> Void

    @Environment(\.focusStrings) private var strings
    @Environment(\.focusViewport) private var viewport
    @State private var signInError: String?

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(AppColors.gold)
                .accessibilityHidden(true)
            VStack(spacing: AppSpacing.sm) {
                Text(strings(.obDoneTitle))
                    .font(.system(size: viewport.titleSize * 0.9, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(strings(.obDoneSubtitle))
                    .font(AppTypography.callout)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                Text(strings(.obPlanMinutesFormat, minutes))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColors.gold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AppColors.gold.opacity(0.14)))
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            VStack(spacing: AppSpacing.sm) {
                AppPrimaryButton(title: strings(.obDoneCTA), systemImage: "arrow.right",
                                 iconTrailing: true, action: onStart)
                VStack(spacing: 6) {
                    FocusAppleSignInButton { error in signInError = error }
                    Text(strings(.obDoneSignInDetail))
                        .font(AppTypography.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                    if let signInError {
                        Text(signInError)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.danger.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.horizontal, viewport.pagePadding)
        .padding(.bottom, viewport.isShort ? AppSpacing.md : AppSpacing.lg)
        .frame(maxWidth: viewport.readableContentWidth)
        .frame(maxWidth: .infinity)
    }
}
