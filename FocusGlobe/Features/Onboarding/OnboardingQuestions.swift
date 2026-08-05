import SwiftUI
import UIKit

// ============================================================================
// The question screens.
//
// Every screen here writes to ONE field of `OnboardingAnswers`, and every one
// of those fields is read by `OnboardingPlanBuilder`. That is the rule the
// previous onboarding broke: it asked for a name, an age band, a free-text
// year goal and a struggle, wrote all four to the profile, and then read
// exactly none of them. A question that changes nothing is a question that
// costs a pilot a screen and gives them nothing back.
//
// Each screen is a small value type taking a binding and an `onSelect` — the
// host owns navigation, so a screen cannot decide to skip ahead and desync the
// progress bar.
// ============================================================================

/// The opening. No question, no progress bar — a promise and a way in.
struct OnboardingWelcomeStep: View {
    let onStart: () -> Void

    @Environment(\.focusStrings) private var strings
    @Environment(\.focusViewport) private var viewport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var float: CGFloat = 0

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // The language control sits at the very top, before any question:
            // choosing a language after answering in one you barely read is not
            // a choice. Renders nothing at all while only English is finished.
            HStack {
                Spacer()
                LanguagePicker(style: .compact)
            }
            .padding(.horizontal, viewport.pagePadding)
            Spacer(minLength: 0)
            hero
                .offset(y: float)
            VStack(spacing: AppSpacing.sm) {
                Text(strings(.obWelcomeTitle))
                    .font(.system(size: viewport.isShort ? 30 : Layout.pad(34, 44),
                                  weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                Text(strings(.obWelcomeSubtitle))
                    .font(AppTypography.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, viewport.pagePadding)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            AppPrimaryButton(title: strings(.obWelcomeCTA), systemImage: "arrow.right",
                             iconTrailing: true, action: onStart)
                .padding(.horizontal, viewport.pagePadding)
                .padding(.bottom, AppSpacing.xl)
        }
        .frame(maxWidth: viewport.readableContentWidth)
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { float = -14 }
        }
    }

    @ViewBuilder private var hero: some View {
        ZStack {
            RadialGradient(colors: [AppColors.gold.opacity(0.27),
                                    Color(hex: 0x8F7BE8).opacity(0.08),
                                    .clear],
                           center: .center, startRadius: 2, endRadius: 128)
                .frame(width: 300, height: 300)
                .scaleEffect(x: 1, y: 1.14)
                .blur(radius: 18)
                .allowsHitTesting(false)
            if let ui = UIImage(named: "OnboardingHero_Balloon") {
                Image(uiImage: ui).resizable().scaledToFit()
                    .frame(height: viewport.isShort ? 140 : 170)
            } else {
                BalloonView(height: viewport.isShort ? 130 : 156, showBurner: true,
                            showGlow: true, glow: AppColors.gold.opacity(0.7))
            }
        }
        .accessibilityHidden(true)
    }
}

/// "What do you want more focus for?" — drives the recommended duration, the
/// benefit order and the personalized line on the next screens.
struct OnboardingGoalStep: View {
    @Binding var selection: FocusGoal?
    let onContinue: () -> Void

    @Environment(\.focusStrings) private var strings

    var body: some View {
        OnboardingScaffold(title: strings(.obGoalTitle),
                           subtitle: strings(.obGoalSubtitle)) {
            VStack(spacing: AppSpacing.xs) {
                ForEach(FocusGoal.allCases, id: \.self) { goal in
                    OnboardingOptionRow(title: strings(goal.titleKey),
                                        systemImage: goal.systemImage,
                                        isSelected: selection == goal) {
                        selection = goal
                    }
                }
            }
        } footer: {
            OnboardingFooter(title: strings(.obContinue),
                             isEnabled: selection != nil,
                             action: onContinue)
        }
    }
}

/// "What usually gets in the way?" — the highest-signal answer in the flow.
struct OnboardingObstacleStep: View {
    @Binding var selection: FocusObstacle?
    let onContinue: () -> Void

    @Environment(\.focusStrings) private var strings

    var body: some View {
        OnboardingScaffold(title: strings(.obObstacleTitle),
                           subtitle: strings(.obObstacleSubtitle)) {
            VStack(spacing: AppSpacing.xs) {
                ForEach(FocusObstacle.allCases, id: \.self) { obstacle in
                    OnboardingOptionRow(title: strings(obstacle.titleKey),
                                        systemImage: obstacle.systemImage,
                                        isSelected: selection == obstacle) {
                        selection = obstacle
                    }
                }
            }
        } footer: {
            OnboardingFooter(title: strings(.obContinue),
                             isEnabled: selection != nil,
                             action: onContinue)
        }
    }
}

/// First-flight length — and the commitment line.
///
/// The personalized "you're here to X, and because Y we're starting short"
/// sentence is the PREAMBLE of this screen rather than a screen of its own. It
/// belongs next to the number it explains: as its own step it would state a
/// reason and then make the pilot tap to see what that reason changed.
struct OnboardingDurationStep: View {
    @Binding var selection: FocusSessionChoice?
    let goal: FocusGoal?
    let obstacle: FocusObstacle?
    let onContinue: () -> Void

    @Environment(\.focusStrings) private var strings

    private var commitment: String? {
        guard let goal, let obstacle else { return nil }
        return strings(goal.commitmentKey) + " " + strings(obstacle.commitmentReasonKey)
    }

    /// The option the builder would actually pick. Marking anything else
    /// "Recommended" would be a badge pointing at a value the app does not use.
    private var recommended: FocusSessionChoice? {
        guard let goal, let obstacle else { return nil }
        return OnboardingPlanBuilder.recommendedChoice(goal: goal, obstacle: obstacle)
    }

    private let columns = [GridItem(.flexible(), spacing: AppSpacing.xs),
                           GridItem(.flexible(), spacing: AppSpacing.xs)]

    var body: some View {
        OnboardingScaffold(title: strings(.obDurationTitle),
                           subtitle: strings(.obDurationSubtitle),
                           preamble: commitment) {
            VStack(spacing: AppSpacing.xs) {
                LazyVGrid(columns: columns, spacing: AppSpacing.xs) {
                    ForEach(FocusSessionChoice.allCases.filter { $0 != .recommended }, id: \.self) { choice in
                        OnboardingCompactOption(title: choice.title(strings),
                                                badge: choice == recommended ? strings(.obRecommended) : nil,
                                                isSelected: selection == choice) {
                            selection = choice
                        }
                    }
                }
                // "Choose for me" is a full-width row, not a fifth tile: it is a
                // different KIND of answer — deferring to the plan rather than
                // naming a length — and tiling it with the numbers would imply
                // it is one.
                OnboardingOptionRow(title: strings(.obDurationChooseForMe),
                                    systemImage: "wand.and.stars",
                                    isSelected: selection == .recommended) {
                    selection = .recommended
                }
            }
        } footer: {
            OnboardingFooter(title: strings(.obContinue),
                             isEnabled: selection != nil,
                             action: onContinue)
        }
    }
}

/// Weekly cadence. Feeds `AppSettings.weeklyFocusDayGoal` and decides whether a
/// reminder warm-up is offered at all.
struct OnboardingCadenceStep: View {
    @Binding var selection: FocusCadence?
    let onContinue: () -> Void

    @Environment(\.focusStrings) private var strings

    var body: some View {
        OnboardingScaffold(title: strings(.obCadenceTitle),
                           subtitle: strings(.obCadenceSubtitle)) {
            VStack(spacing: AppSpacing.xs) {
                ForEach(FocusCadence.allCases, id: \.self) { cadence in
                    OnboardingOptionRow(title: strings(cadence.titleKey),
                                        systemImage: cadence == .flexible ? "arrow.left.and.right" : "calendar",
                                        isSelected: selection == cadence) {
                        selection = cadence
                    }
                }
            }
        } footer: {
            OnboardingFooter(title: strings(.obContinue),
                             isEnabled: selection != nil,
                             action: onContinue)
        }
    }
}

/// How the pilot focuses best. Pre-selects a real `OnlineFlightMode`; it never
/// signs anyone in, opens a room or publishes presence.
struct OnboardingCompanyStep: View {
    @Binding var selection: FocusCompany?
    let onContinue: () -> Void

    @Environment(\.focusStrings) private var strings

    private func icon(_ company: FocusCompany) -> String {
        switch company {
        case .alone:        return "person.fill"
        case .withFriends:  return "person.2.fill"
        case .aroundOthers: return "person.3.fill"
        case .mixed:        return "arrow.triangle.2.circlepath"
        }
    }

    var body: some View {
        OnboardingScaffold(title: strings(.obCompanyTitle),
                           subtitle: strings(.obCompanySubtitle)) {
            VStack(spacing: AppSpacing.xs) {
                ForEach(FocusCompany.allCases, id: \.self) { company in
                    OnboardingOptionRow(title: strings(company.titleKey),
                                        systemImage: icon(company),
                                        isSelected: selection == company) {
                        selection = company
                    }
                }
            }
        } footer: {
            OnboardingFooter(title: strings(.obContinue),
                             isEnabled: selection != nil,
                             action: onContinue)
        }
    }
}

/// Focus Shield INTENT. Deliberately not a permission prompt: the Family
/// Controls dialog is never triggered from a question screen, and the subtitle
/// says so rather than leaving a pilot to discover it by tapping.
struct OnboardingShieldIntentStep: View {
    @Binding var selection: ShieldIntent?
    let onContinue: () -> Void

    @Environment(\.focusStrings) private var strings

    var body: some View {
        OnboardingScaffold(title: strings(.obShieldTitle),
                           subtitle: strings(.obShieldSubtitle)) {
            VStack(spacing: AppSpacing.xs) {
                ForEach(ShieldIntent.allCases, id: \.self) { intent in
                    OnboardingOptionRow(title: strings(intent.titleKey),
                                        systemImage: intent == .yes ? "shield.lefthalf.filled" : "clock",
                                        isSelected: selection == intent) {
                        selection = intent
                    }
                }
            }
        } footer: {
            OnboardingFooter(title: strings(.obContinue),
                             isEnabled: selection != nil,
                             action: onContinue)
        }
    }
}

/// Sky selection.
///
/// Only Skies this pilot can actually fly are selectable. A locked Sky is shown
/// — it is the aspiration the catalog is built on — but tapping it cannot set a
/// plan the app would then have to quietly override.
struct OnboardingSkyStep: View {
    @Binding var selection: String?
    let unlockedIDs: Set<String>
    let onContinue: () -> Void

    @Environment(\.focusStrings) private var strings
    @Environment(\.focusViewport) private var viewport

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: viewport.isCompact ? 132 : 168,
                            maximum: 240), spacing: AppSpacing.xs)]
    }

    var body: some View {
        OnboardingScaffold(title: strings(.obSkyTitle),
                           subtitle: strings(.obSkySubtitle)) {
            LazyVGrid(columns: columns, spacing: AppSpacing.xs) {
                ForEach(FocusSky.all, id: \.id) { sky in
                    let unlocked = unlockedIDs.contains(sky.id)
                    OnboardingSkyTile(sky: sky,
                                      isUnlocked: unlocked,
                                      isSelected: selection == sky.id,
                                      lockedBadge: strings(.obSkyLocked)) {
                        guard unlocked else { return }
                        selection = sky.id
                    }
                }
            }
        } footer: {
            OnboardingFooter(title: strings(.obContinue),
                             isEnabled: selection != nil,
                             action: onContinue)
        }
    }
}

private struct OnboardingSkyTile: View {
    let sky: FocusSky
    let isUnlocked: Bool
    let isSelected: Bool
    let lockedBadge: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    SkyStillPreview(sky: sky)
                        .frame(height: 108)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .saturation(isUnlocked ? 1 : 0.35)
                        .opacity(isUnlocked ? 1 : 0.55)
                    if !isUnlocked {
                        Text(lockedBadge)
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(Color(hex: 0x14120E))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(AppColors.gold))
                            .padding(7)
                    }
                }
                Text(sky.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(isUnlocked ? 0.92 : 0.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? AppColors.gold.opacity(0.16) : Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isSelected ? AppColors.gold : .white.opacity(0.10),
                              lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(SoftPressStyle(scale: 0.98))
        .disabled(!isUnlocked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(isUnlocked ? sky.name : "\(sky.name), \(lockedBadge)"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Soundscape selection.
///
/// Silence is a first-class option, not the absence of one: someone who focuses
/// in quiet must be able to say so, and the plan must record it rather than
/// leaving whatever was there before.
struct OnboardingSoundStep: View {
    @Binding var selection: String?
    @Binding var choseSilence: Bool
    let unlockedIDs: Set<String>
    let onContinue: () -> Void

    @Environment(\.focusStrings) private var strings

    var body: some View {
        OnboardingScaffold(title: strings(.obSoundTitle),
                           subtitle: strings(.obSoundSubtitle)) {
            VStack(spacing: AppSpacing.xs) {
                ForEach(JourneyAudioOption.all.filter { unlockedIDs.contains($0.id) }) { option in
                    OnboardingOptionRow(title: option.displayName,
                                        systemImage: option.systemImage,
                                        isSelected: !choseSilence && selection == option.id) {
                        selection = option.id
                        choseSilence = false
                    }
                }
                OnboardingOptionRow(title: strings(.obSoundSilence),
                                    systemImage: "speaker.slash.fill",
                                    isSelected: choseSilence) {
                    choseSilence = true
                    selection = nil
                }
            }
        } footer: {
            OnboardingFooter(title: strings(.obContinue),
                             isEnabled: choseSilence || selection != nil,
                             action: onContinue)
        }
    }
}
