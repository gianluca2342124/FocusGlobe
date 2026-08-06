import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// First-run onboarding.
///
/// Six screens, then the paywall — and the paywall is the REAL one, the same
/// `PaywallView(context: .general)` the Home PRO button opens, rendered against
/// this flow's own sky so the hand-off is a change of subject rather than a
/// change of app.
///
/// The previous version had ten screens before the offer. An audit of what each
/// answer fed found four of them were write-only: the free-text year goal, the
/// age band, the free-text struggle and the Shield opt-in were stored on the
/// profile and read by nothing in the codebase. A screen that collects data
/// nobody consumes is a screen spent for nothing, so those questions are gone
/// rather than restyled. The name screen is gone too — not because the field is
/// unused (Home and Passport read it) but because Settings already asks for it,
/// and a keyboard on screen three is the most expensive thing in a first run.
///
/// Every remaining question has a named reader:
/// * focus intent -> `profile.focusStyle`: the Online flight category, and the
///   pre-selected focus token in the flight-setup ritual.
/// * first-flight length -> `settings.preferredFlightMinutes`: the opening value
///   of the setup dial.
/// * atmosphere -> `settings.selectedJourneyAudioID`: what a flight plays.
///
/// The friction question is the one exception and is deliberate: its answer
/// never leaves the flow. It exists to be named by the pilot and then answered,
/// three screens later, by the summary that leads into the offer. That is its
/// job, and it is the only screen here whose value is entirely about the arrival
/// at the paywall.
///
/// No review request, no testimonials, no back button, no skip labels, no
/// permission prompts. Notifications and Screen Time are asked for later, in
/// context, where they already were — a system dialog before the offer buys
/// friction at the worst possible moment.
struct OnboardingView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The screens BEFORE the offer. The paywall is a seventh surface but not a
    /// question, so the progress bar completes as the pilot reaches it.
    private static let questionCount = 6

    private enum Step: Int, CaseIterable {
        case welcome, intent, friction, duration, atmosphere, reveal, offer
    }

    @State private var step: Step = .welcome
    @State private var intent: FocusPreset?
    @State private var friction: FocusFriction?
    @State private var minutes: Int?
    @State private var soundIndex = 0
    @State private var introFloat: CGFloat = 0
    /// The final Continue was tapped while RevenueCat was still resolving. The
    /// intent is held WITHOUT showing an offer, then either finishes for an owner
    /// or opens the paywall for a confirmed Free pilot.
    @State private var pendingEntitlementResolution = false
    /// True between a choice tap and the deferred advance it scheduled.
    @State private var isAdvancing = false
    /// Both the paywall's own exit and this view's entitlement observer can
    /// reach `finish()` in the same instant when a purchase lands. Handing off
    /// twice would set the tab and rewrite the profile twice for no reason.
    @State private var didFinish = false
    /// How long the reveal's Continue may wait on RevenueCat before showing the
    /// offer anyway. Falling through to the paywall is the SAFE default: it
    /// grants nothing, and the paywall closes itself the moment the entitlement
    /// turns out to be premium. Waiting forever is not safe — offline, a first
    /// run could never be finished at all.
    private static let entitlementGraceSeconds: TimeInterval = 2.5

    var body: some View {
        ZStack {
            if step == .offer {
                // The offer owns the whole screen. It paints the SAME sky as its
                // own background, so the root backdrop must not also be drawn:
                // two copies composite the gold bloom over itself and draw 140
                // stars where every previous screen drew 70, producing a visible
                // brightening at exactly the hand-off this is meant to make
                // seamless. It also drops the 560 pt column and the progress bar,
                // so the paywall lays itself out from the real window the way it
                // does everywhere else.
                offerStep
            } else {
                OnboardingBackdrop()
                VStack(spacing: 0) {
                    progressBar
                    stepBody
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: reduceMotion ? 0 : 20)),
                            removal: .opacity.combined(with: .offset(y: reduceMotion ? 0 : -14))))
                        .id(step)
                        .frame(maxWidth: 560)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: appModel.entitlement) { _, access in
            // An owner never sees an offer. If the entitlement resolves to
            // premium at any point — including while the paywall is on screen —
            // onboarding simply finishes.
            if access == .premium, step == .offer || pendingEntitlementResolution {
                pendingEntitlementResolution = false
                finish()
            } else if access == .free, pendingEntitlementResolution {
                pendingEntitlementResolution = false
                move(to: .offer)
            }
        }
        .onDisappear { appModel.stopJourneyAudioPreview() }
    }

    // MARK: - Chrome

    /// One thin bar. No back control and no step numbers: this flow is short
    /// enough that a count invites counting, and a forward-only run is what keeps
    /// it feeling like an arrival rather than a form.
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                Capsule().fill(AppColors.brand)
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 4)
        .opacity(step == .welcome ? 0 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: step)
        .padding(.horizontal, AppSpacing.screen)
        .padding(.top, AppSpacing.md)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Setup progress")
        .accessibilityValue("\(Int((progress * 100).rounded()))%")
    }

    private var progress: CGFloat {
        // The offer completes the bar rather than extending it: the questions
        // are what the bar measures, and pretending the purchase screen is a
        // seventh step would make the bar a sales device.
        CGFloat(min(step.rawValue, Self.questionCount)) / CGFloat(Self.questionCount)
    }

    @ViewBuilder private var stepBody: some View {
        switch step {
        case .welcome:    welcomeStep
        case .intent:     intentStep
        case .friction:   frictionStep
        case .duration:   durationStep
        case .atmosphere: atmosphereStep
        case .reveal:     revealStep
        // `.offer` is handled by `body` directly: it replaces the chrome rather
        // than living inside it.
        case .offer:      EmptyView()
        }
    }

    // MARK: - 1. Welcome

    private var welcomeStep: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer(minLength: 0)
            hero.offset(y: introFloat)
            VStack(spacing: AppSpacing.sm) {
                Text("Welcome to FocusGlobe")
                    .font(.system(size: Layout.pad(34, 44), weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                Text("A calmer way to focus, one flight at a time.")
                    .font(AppTypography.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            AppPrimaryButton(title: "Begin", systemImage: "arrow.right", iconTrailing: true) {
                advance()
            }
            .padding(.bottom, AppSpacing.xl)
        }
        .padding(.horizontal, AppSpacing.screen)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                introFloat = -14
            }
        }
    }

    @ViewBuilder private var hero: some View {
        ZStack {
            // Light, not a lit shape: the gradient reaches fully clear before it
            // meets its own frame, so no edge can slice a still-visible ring and
            // leave the balloon sitting on a disc.
            RadialGradient(colors: [AppColors.gold.opacity(0.27),
                                    Color(hex: 0x8F7BE8).opacity(0.08),
                                    .clear],
                           center: .center, startRadius: 2, endRadius: 128)
                .frame(width: 300, height: 300)
                .scaleEffect(x: 1, y: 1.14)
                .blur(radius: 18)
                .allowsHitTesting(false)
            #if canImport(UIKit)
            if let ui = UIImage(named: "OnboardingHero_Balloon") {
                Image(uiImage: ui).resizable().scaledToFit().frame(height: 170)
            } else {
                BalloonView(height: 156, showBurner: true, showGlow: true,
                            glow: AppColors.gold.opacity(0.7))
            }
            #else
            BalloonView(height: 156, showBurner: true, showGlow: true,
                        glow: AppColors.gold.opacity(0.7))
            #endif
        }
        .accessibilityHidden(true)
    }

    // MARK: - 2. Intent

    /// The options ARE the app's real focus tokens. Inventing a separate intent
    /// vocabulary would mean the answer either mapped to nothing or needed a
    /// translation table nobody maintains; these titles are already the flight
    /// category and the focus token, so the answer is wired the moment it is
    /// given.
    private var intentStep: some View {
        questionScaffold(
            title: "What do you want FocusGlobe to help with most?",
            subtitle: "We'll shape your first flight around it."
        ) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: AppSpacing.xs),
                                GridItem(.flexible(), spacing: AppSpacing.xs)],
                      spacing: AppSpacing.xs) {
                ForEach(FocusPreset.all) { preset in
                    choiceTile(preset.title,
                               systemImage: preset.systemImage,
                               isSelected: intent?.title == preset.title) {
                        intent = preset
                        advanceAfterChoice()
                    }
                }
            }
        }
    }

    // MARK: - 3. Friction

    private var frictionStep: some View {
        questionScaffold(
            title: "What usually breaks your focus?",
            subtitle: "So FocusGlobe can meet you where you are."
        ) {
            VStack(spacing: AppSpacing.xs) {
                ForEach(FocusFriction.allCases) { item in
                    choiceRow(item.title,
                              systemImage: item.systemImage,
                              isSelected: friction == item) {
                        friction = item
                        advanceAfterChoice()
                    }
                }
            }
        }
    }

    // MARK: - 4. First flight length

    private var durationStep: some View {
        questionScaffold(
            title: "How long can you focus today?",
            subtitle: "We'll set up your first flight. You can change it before every take-off."
        ) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: AppSpacing.xs),
                                GridItem(.flexible(), spacing: AppSpacing.xs)],
                      spacing: AppSpacing.xs) {
                ForEach(Self.flightLengths, id: \.self) { value in
                    choiceTile(Formatters.durationLabel(minutes: value),
                               systemImage: nil,
                               isSelected: minutes == value) {
                        minutes = value
                        advanceAfterChoice()
                    }
                }
            }
        }
    }

    /// The offered first-flight lengths.
    ///
    /// Six, because six fills three even rows of a two-column grid — seven would
    /// leave an orphan tile and a lopsided screen. 90 min is the common
    /// deep-work block and 120 is the ceiling; 75 was dropped in their favour as
    /// the rarer choice. Every value is an exact stop on `DurationScale`, so the
    /// setup dial can open on it precisely rather than snapping to a neighbour,
    /// and none of them is PRO-gated — only `infinite` is — so a free pilot can
    /// actually fly whatever they pick here.
    static let flightLengths = [15, 25, 45, 60, 90, 120]

    // MARK: - 5. Atmosphere

    private var atmosphereStep: some View {
        questionScaffold(
            title: "Pick your focus atmosphere",
            subtitle: "Choose the sound you want to lift off with. Every one is free."
        ) {
            soundCarousel
        } footer: {
            AppPrimaryButton(title: "Continue", systemImage: "arrow.right", iconTrailing: true) {
                advance()
            }
            .padding(.bottom, AppSpacing.xl)
        }
    }

    private var soundOptions: [JourneyAudioOption] { JourneyAudioOption.all }

    private var soundCarousel: some View {
        let opts = soundOptions
        let option = opts[max(0, min(opts.count - 1, soundIndex))]
        return VStack(spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                carouselArrow(system: "chevron.left", enabled: soundIndex > 0) {
                    selectSound(at: soundIndex - 1)
                }
                SoundCoverCard(option: option)
                    .frame(maxWidth: .infinity)
                    // One element that names the soundscape AND its state, so
                    // VoiceOver never reads decorative artwork.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(option.displayName)
                    .accessibilityValue("Selected, playing")
                    .accessibilityHint("Swipe up or down to hear another soundscape.")
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: selectSound(at: soundIndex + 1)
                        case .decrement: selectSound(at: soundIndex - 1)
                        @unknown default: break
                        }
                    }
                    .gesture(DragGesture(minimumDistance: 24).onEnded { v in
                        if v.translation.width < -30 { selectSound(at: soundIndex + 1) }
                        else if v.translation.width > 30 { selectSound(at: soundIndex - 1) }
                    })
                carouselArrow(system: "chevron.right", enabled: soundIndex < opts.count - 1) {
                    selectSound(at: soundIndex + 1)
                }
            }
            VStack(spacing: 3) {
                Text(option.displayName)
                    .font(.system(size: Layout.pad(23, 28), weight: .bold, design: .default))
                    .foregroundStyle(.white)
                Text(soundBlurb(option))
                    .font(AppTypography.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            nowPlayingIndicator
            HStack(spacing: 6) {
                ForEach(opts.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == soundIndex ? AppColors.selectionGold : .white.opacity(0.28))
                        .frame(width: i == soundIndex ? 18 : 6, height: 6)
                }
            }
            .accessibilityHidden(true)
        }
        .onAppear {
            let index = soundOptions.firstIndex { $0.id == appModel.selectedJourneyAudio.id } ?? 0
            soundIndex = index
            appModel.previewJourneyAudio(soundOptions[index])
        }
    }

    /// Browsing IS choosing here. The soundscape a pilot is listening to is the
    /// one committed, so there is no separate confirm step and no way to leave
    /// this screen having heard one sound and saved another.
    private func selectSound(at index: Int) {
        let clamped = max(0, min(soundOptions.count - 1, index))
        guard clamped != soundIndex else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { soundIndex = clamped }
        let option = soundOptions[clamped]
        appModel.selectJourneyAudio(option)
        appModel.previewJourneyAudio(option)
    }

    // MARK: - 6. Reveal

    /// The bridge into the offer.
    ///
    /// It restates only things the pilot actually chose, and only things the app
    /// has genuinely configured — this card is a receipt, not a promise. The
    /// three lines under it are the honest consequences of the setup, phrased
    /// against the friction they named.
    private var revealStep: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer(minLength: 0)

            VStack(spacing: AppSpacing.sm) {
                Text("Your first focus flight is ready")
                    .font(.system(size: Layout.pad(30, 38), weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("A calmer, clearer way to stay with what matters.")
                    .font(AppTypography.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                summaryRow("target", "Focus", intent?.title ?? "Fly")
                summaryDivider
                summaryRow("timer", "First flight", "\(minutes ?? 25) min")
                summaryDivider
                summaryRow("waveform", "Atmosphere", appModel.selectedJourneyAudio.displayName)
            }
            .padding(AppSpacing.md)
            .background(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                .fill(.white.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1))

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                ForEach(revealBenefits, id: \.self) { line in
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(AppColors.selectionGold)
                            .frame(width: 18)
                        Text(line)
                            .font(AppTypography.callout)
                            .foregroundStyle(.white.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            AppPrimaryButton(title: "Continue", systemImage: "arrow.right", iconTrailing: true) {
                advance()
            }
            .padding(.bottom, AppSpacing.xl)
        }
        .padding(.horizontal, AppSpacing.screen)
    }

    /// Three consequences of the setup, led by the one that answers the friction
    /// the pilot named. Nothing here claims an outcome, a statistic or a study.
    private var revealBenefits: [String] {
        let lead = friction?.reassurance ?? "A calmer place to start"
        return [lead, "One clear flight at a time", "Progress you can actually see"]
    }

    private func summaryRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.gold)
                .frame(width: 22)
            Text(label)
                .font(AppTypography.callout)
                .foregroundStyle(.white.opacity(0.66))
            Spacer(minLength: AppSpacing.xs)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .default))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }

    private var summaryDivider: some View {
        Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
    }

    // MARK: - 7. The offer

    /// The SAME paywall the Home PRO button opens — same carousel, same
    /// comparison table, same Annual and Monthly products, same real StoreKit
    /// prices, same trial eligibility, same restore and legal links, same
    /// purchase path. Onboarding does not own a paywall; it borrows the one the
    /// app already has, and the only thing it changes is the sky behind it.
    ///
    /// Rendered inline rather than presented as a cover, because a modal sliding
    /// over the last screen would announce "now you are being sold to". Here the
    /// sky is continuous and the offer is simply the next thing in the flow.
    private var offerStep: some View {
        PaywallView(context: .general, backdrop: .onboarding, onClose: finish)
            .environmentObject(appModel)
            .environmentObject(router)
    }

    // MARK: - Navigation

    /// A single-choice question needs no Continue: the tap IS the answer, and
    /// making the pilot confirm it doubles the taps for no information.
    ///
    /// The short delay lets the selected state be seen before the screen moves,
    /// which is why it has to be guarded twice over: `isAdvancing` drops a
    /// second tap inside the window, and the captured step means a queued
    /// advance that is no longer relevant simply does nothing. Without both, two
    /// taps 100 ms apart ran two advances and skipped an entire question — the
    /// pilot never saw it, and the answer it collects stayed nil.
    private func advanceAfterChoice() {
        guard !isAdvancing else { return }
        isAdvancing = true
        appModel.tapFeedback()
        let from = step
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            isAdvancing = false
            guard step == from else { return }
            advance(withFeedback: false)
        }
    }

    /// `withFeedback` is false when the caller already played the tap, so one
    /// answer produces one haptic and one earcon rather than two 180 ms apart.
    private func advance(withFeedback: Bool = true) {
        // Once the offer is up, ITS controls own every exit. Without this a
        // second tap on the reveal's Continue — easy while it is still sliding
        // away — ran off the end of the step list and completed onboarding,
        // skipping the paywall entirely.
        guard step != .offer else { return }
        if withFeedback { appModel.tapFeedback() }
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        guard next == .offer else { move(to: next) ; return }

        // The offer is skipped entirely for someone who already owns PRO, and
        // never flashed at someone whose entitlement has not resolved.
        switch appModel.entitlement {
        case .premium:
            finish()
        case .free:
            move(to: .offer)
        case .loading:
            pendingEntitlementResolution = true
            appModel.refreshSubscriptionStatus()
            // Bounded, not indefinite. RevenueCat may never answer — no network
            // on a fresh install is enough — and without this the pilot is left
            // on the reveal with a Continue that gives no feedback and no way
            // forward, unable to finish the first run at all.
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.entitlementGraceSeconds) {
                guard pendingEntitlementResolution, step == .reveal else { return }
                pendingEntitlementResolution = false
                move(to: .offer)
            }
        }
    }

    private func move(to next: Step) {
        if next != .atmosphere { appModel.stopJourneyAudioPreview() }
        withAnimation(reduceMotion ? nil : AppMotion.soft) { step = next }
    }

    /// Persist and hand off to Home.
    ///
    /// The tab and the navigation path are set BEFORE `hasCompletedOnboarding`
    /// flips, so `AppShell` can never restore a stale tab behind the cross-fade.
    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        appModel.stopJourneyAudioPreview()
        router.path.removeAll()
        router.selectedTab = .home
        appModel.completeOnboarding(focusPresetTitle: intent?.title,
                                    preferredMinutes: minutes)
        // Onboarding has already made the PRO offer; Home must not open a second
        // one on top of the arrival.
        appModel.markPremiumIntroSeen()
    }

    // MARK: - Shared pieces

    private func questionScaffold<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        questionScaffold(title: title, subtitle: subtitle, content: content) { EmptyView() }
    }

    private func questionScaffold<Content: View, Footer: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.system(size: Layout.pad(28, 36), weight: .bold, design: .default))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(subtitle)
                            .font(AppTypography.callout)
                            .foregroundStyle(.white.opacity(0.66))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                    content()
                }
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppSpacing.lg)
            }
            footer()
        }
        .padding(.horizontal, AppSpacing.screen)
    }

    /// A full-width answer. Used where the copy is a sentence.
    private func choiceRow(_ title: String,
                           systemImage: String?,
                           isSelected: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isSelected ? Color(hex: 0x14120E) : AppColors.gold)
                        .frame(width: 26)
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(isSelected ? Color(hex: 0x14120E) : .white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 15)
            // A floor, not a fixed height: a long answer at an accessibility
            // text size grows the row instead of being clipped inside it.
            .frame(minHeight: 56)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color(hex: 0xF4EFE4) : Color.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(isSelected ? 0 : 0.12), lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle(scale: 0.985))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// A half-width answer. Used where the copy is a word or a number.
    private func choiceTile(_ title: String,
                            systemImage: String?,
                            isSelected: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(isSelected ? Color(hex: 0x14120E) : AppColors.gold)
                }
                Text(title)
                    .font(.system(size: 16.5, weight: .semibold, design: .default))
                    .foregroundStyle(isSelected ? Color(hex: 0x14120E) : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 74)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color(hex: 0xF4EFE4) : Color.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(isSelected ? 0 : 0.12), lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle(scale: 0.98))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var nowPlayingIndicator: some View {
        HStack(spacing: 8) {
            EqualizerBars()
            Text("Now playing")
                .font(.system(size: 13.5, weight: .semibold, design: .default))
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(.horizontal, 15).padding(.vertical, 9)
        .background(Capsule().fill(.white.opacity(0.08)))
        .overlay(Capsule().strokeBorder(AppColors.selectionGold.opacity(0.32), lineWidth: 1))
        .accessibilityHidden(true)
    }

    private func carouselArrow(system: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white.opacity(enabled ? 0.9 : 0.25))
                .frame(width: 40, height: 40)
                .background(Circle().fill(.white.opacity(0.1)))
                .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle())
        .disabled(!enabled)
        .accessibilityHidden(true)
    }

    private func soundBlurb(_ option: JourneyAudioOption) -> String {
        switch option.id {
        case "wind":        return "The classic — a soft breeze at altitude."
        case "focus-music": return "Warm, wordless music for deep work."
        case "alpha-waves": return "Gentle tones tuned for concentration."
        case "rain":        return "Steady rain against the cabin window."
        case "ocean":       return "Slow waves rolling far below."
        case "relaxing":    return "Calm ambience to settle the mind."
        case "jazz":        return "Easy late-night jazz for long flights."
        default:            return "A calm atmosphere for focus."
        }
    }
}

/// What gets in a pilot's way.
///
/// Deliberately NOT persisted: nothing outside this flow reads it, and writing
/// it to the profile would recreate exactly the dead field this redesign
/// removed. It exists to be named on screen three and answered on screen six.
enum FocusFriction: String, CaseIterable, Identifiable {
    case phone
    case procrastination
    case momentum
    case overwhelm
    case starting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .phone:           return "My phone pulls me in"
        case .procrastination: return "I put things off"
        case .momentum:        return "I lose momentum partway"
        case .overwhelm:       return "It all feels like a lot"
        case .starting:        return "I struggle to get started"
        }
    }

    var systemImage: String {
        switch self {
        case .phone:           return "iphone.slash"
        case .procrastination: return "clock.badge.exclamationmark.fill"
        case .momentum:        return "chart.line.downtrend.xyaxis"
        case .overwhelm:       return "wind"
        case .starting:        return "flag.slash.fill"
        }
    }

    /// The first line of the reveal, phrased against this friction. A statement
    /// about the setup that was just made — never a claim about results.
    var reassurance: String {
        switch self {
        case .phone:           return "One place to be, with the rest further away"
        case .procrastination: return "A first flight small enough to just start"
        case .momentum:        return "A flight you can finish, then come back to"
        case .overwhelm:       return "One thing at a time, for as long as you chose"
        case .starting:        return "Take-off is one tap, already set up"
        }
    }
}
/// A large soundscape "cover" for the atmosphere carousel — the bundled
/// `SoundCover_<Id>` art if present, otherwise a premium procedural gradient
/// with the soundscape's icon.
private struct SoundCoverCard: View {
    let option: JourneyAudioOption

    private var coverImage: Image? {
        #if canImport(UIKit)
        if let ui = UIImage(named: option.coverAssetName) { return Image(uiImage: ui) }
        #endif
        return nil
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [option.accent, option.accent.opacity(0.5), Color(hex: 0x0B1024)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            if let img = coverImage {
                img.resizable().scaledToFill()
            } else {
                RadialGradient(colors: [.white.opacity(0.22), .clear],
                               center: UnitPoint(x: 0.3, y: 0.24), startRadius: 4, endRadius: 170)
                Image(systemName: option.systemImage)
                    .font(.system(size: 62, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
            }
            // No play affordance of any kind. This card used to carry a
            // `play.circle.fill` in the bottom corner with no action behind it:
            // the soundscape already auto-plays and switches on swipe, so the
            // icon could only ever look broken. A control that appears to play
            // something must actually do it, or not be there.
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(.white.opacity(0.16), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 10)
    }
}

/// A minimal animated equalizer — four gold bars gently pulsing — the "audio is
/// playing" cue on the auto-playing soundscape step (no Play button). Static
/// under Reduce Motion.
private struct EqualizerBars: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false
    /// (rest, peak) heights per bar, so the four bars never move in lock-step.
    private let bars: [(CGFloat, CGFloat)] = [(6, 16), (13, 5), (8, 18), (11, 7)]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(bars.indices, id: \.self) { i in
                Capsule()
                    .fill(AppColors.gold)
                    .frame(width: 3, height: animate ? bars[i].1 : bars[i].0)
                    .animation(reduceMotion ? nil
                               : .easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(Double(i) * 0.11),
                               value: animate)
            }
        }
        .frame(height: 18)
        .onAppear { if !reduceMotion { animate = true } }
    }
}
