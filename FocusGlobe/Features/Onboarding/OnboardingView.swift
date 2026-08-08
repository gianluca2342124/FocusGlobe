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
/// No in-flow review request, no back button, no skip labels, no permission
/// prompts. Notifications and Screen Time are asked for later, in context,
/// where they already were — a system dialog before the offer buys friction at
/// the worst possible moment.
struct OnboardingView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    /// Only for the Welcome screen's Sign In sheet, which hands off to the
    /// existing Apple flow rather than owning any auth of its own.
    @EnvironmentObject private var online: FocusOnlineModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.focusViewport) private var viewport

    /// The last step's index. The offer is now counted: it is presented as the
    /// final step of the first run rather than as a separate interruption, so
    /// the bar completes ON it rather than before it. The bar still measures
    /// only what is really left — it never advances past 100% and there is no
    /// step hidden behind the purchase.
    private static let lastStepIndex = Step.allCases.count - 1

    private enum Step: Int, CaseIterable {
        case welcome, intent, friction, duration, schedule, atmosphere, setup, results, offer
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
    /// The Welcome screen's Sign In drawer.
    @State private var showSignIn = false
    /// The duration wheel's position, in `DurationScale` index space.
    @State private var durationIndex = 0
    @State private var didSeedDuration = false
    /// The weekdays the pilot plans to fly. Seeded to Mon · Wed · Fri, which is
    /// the three-a-week rhythm the results screen has always assumed.
    @State private var weeklyDays: [FocusWeekday] = FocusWeekday.defaultSchedule
    /// Both the paywall's own exit and this view's entitlement observer can
    /// reach `finish()` in the same instant when a purchase lands. Handing off
    /// twice would set the tab and rewrite the profile twice for no reason.
    @State private var didFinish = false
    /// How long the results screen's Continue may wait on RevenueCat before
    /// showing the offer anyway. Falling through to the paywall is the SAFE default: it
    /// grants nothing, and the paywall closes itself the moment the entitlement
    /// turns out to be premium. Waiting forever is not safe — offline, a first
    /// run could never be finished at all.
    private static let entitlementGraceSeconds: TimeInterval = 2.5

    var body: some View {
        ZStack {
            if step == .offer {
                // The offer paints the SAME sky as its own background, so the
                // root backdrop must not also be drawn: two copies composite the
                // gold bloom over itself and draw 140 stars where every previous
                // screen drew 70 — a visible brightening at exactly the hand-off
                // this is meant to make seamless.
                //
                // The onboarding bar rides on top as a safe-area inset rather
                // than an overlay, so the paywall lays itself out BELOW it
                // instead of underneath it, and the flow reads as one continuous
                // run of screens rather than a purchase page that appeared. It
                // is full-bleed otherwise — no 560 pt column — so the paywall
                // sizes from the real window exactly as it does from Home.
                offerStep
                    .safeAreaInset(edge: .top, spacing: 0) {
                        progressBar.padding(.bottom, AppSpacing.xs)
                    }
            } else {
                OnboardingBackdrop()
                VStack(spacing: 0) {
                    // The setup screen owns the window. It already HAS a
                    // progress bar — a PRO-gradient one, under a percentage —
                    // and a second thin bar 30 pt above it reads as a bug, not
                    // as chrome. It is removed rather than made transparent so
                    // no empty strip is reserved: the screen centres in the full
                    // height, which is the whole point of taking the bar away.
                    // It returns with the results screen, at the value it would
                    // have had anyway, so nothing about the progress semantics
                    // of any other step changes.
                    if step != .setup {
                        progressBar.transition(.opacity)
                    }
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
        .accessibilityLabel(Text("Setup progress"))
        .accessibilityValue("\(Int((progress * 100).rounded()))%")
    }

    private var progress: CGFloat {
        CGFloat(step.rawValue) / CGFloat(Self.lastStepIndex)
    }

    @ViewBuilder private var stepBody: some View {
        switch step {
        case .welcome:    welcomeStep
        case .intent:     intentStep
        case .friction:   frictionStep
        case .duration:   durationStep
        case .schedule:   scheduleStep
        case .atmosphere: atmosphereStep
        case .setup:      setupStep
        case .results:    resultsStep
        // `.offer` is handled by `body` directly: it is full-bleed with only the
        // progress bar inset above it.
        case .offer:      EmptyView()
        }
    }

    // MARK: - 1. Welcome

    private var welcomeStep: some View {
        VStack(spacing: AppSpacing.lg) {
            HStack {
                Spacer()
                languageSelector
            }
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
            VStack(spacing: AppSpacing.sm) {
                AppPrimaryButton(title: "Begin", systemImage: "arrow.right", iconTrailing: true) {
                    advance()
                }
                // Returning pilots, not new ones: the primary path is still
                // Begin. This sits under it, at caption weight, so it is found
                // by someone looking for it and ignored by everyone else.
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .foregroundStyle(.white.opacity(0.55))
                    Button("Sign In") {
                        appModel.tapFeedback()
                        showSignIn = true
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
                    .accessibilityHint(Text("Opens sign in with Apple."))
                }
                .font(AppTypography.caption)
                .padding(.top, 2)
            }
            .padding(.bottom, AppSpacing.xl)
        }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.top, AppSpacing.xs)
        .sheet(isPresented: $showSignIn) {
            OnboardingSignInSheet()
                .environmentObject(appModel)
                .environmentObject(online)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                introFloat = -14
            }
        }
    }

    /// The eleven languages FocusGlobe offers, in `FocusLanguage`'s order.
    ///
    /// It used to read `Bundle.main.localizations`, which is the wrong source
    /// for a chooser: an option disappeared the moment its `.lproj` was
    /// missing, so a half-finished translation bundle silently removed
    /// languages from the menu. What a pilot may choose is a product decision
    /// and now lives in one place; what the bundle contains only decides
    /// whether the strings arrive translated or fall back to English.
    ///
    /// Same capsule as before — same radius, padding, opacities and chevron.
    /// Only what it lists changed.
    private var languageSelector: some View {
        Menu {
            Picker("Language", selection: languageBinding) {
                ForEach(FocusLanguage.allCases) { language in
                    Text("\(language.flag)  \(language.nativeName)").tag(language)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(appModel.preferredLanguage.flag)
                    .font(.system(size: 13))
                Text(appModel.preferredLanguage.shortLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    // 中文 and हिन्दी are wider than "EN"; the capsule stays
                    // compact by letting the label shrink a little rather than
                    // by letting the control grow.
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(.white.opacity(0.08)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.13), lineWidth: 1))
        }
        .accessibilityLabel(Text("Language"))
        .accessibilityValue(appModel.preferredLanguage.nativeName)
    }

    /// Straight through to the canonical setting — no local `@State` mirror,
    /// which is what would let the capsule and the stored preference drift.
    /// Writing on every pick, including a pick that matches what is already
    /// showing, is deliberate: it turns "the device happens to be French" into
    /// "this pilot chose French", which then survives the phone changing.
    private var languageBinding: Binding<FocusLanguage> {
        Binding(
            get: { appModel.preferredLanguage },
            set: { appModel.tapFeedback(); appModel.preferredLanguage = $0 }
        )
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

    /// The real Altitude Dial, not a stand-in.
    ///
    /// A six-tile grid could only ever offer six of the scale's forty-two
    /// stops, and it taught the wrong gesture — the pilot's next encounter with
    /// this decision is the pre-flight ritual, which is a wheel. This is the
    /// SAME `DurationGauge` that ritual uses: same arc, same ticks, same drag
    /// mapping, same snapping, same haptic per stop. Only the surround is
    /// onboarding's.
    private var durationStep: some View {
        questionScaffold(
            title: "How long can you focus today?",
            subtitle: "Turn the dial. You can change it before every take-off."
        ) {
            VStack(spacing: AppSpacing.sm) {
                DurationGauge(
                    fraction: Double(durationIndex) / Double(Self.maxDurationIndex),
                    big: durationBig,
                    sub: durationSub,
                    // Onboarding is a single 560 pt column on every device, so
                    // the gauge keeps its compact proportions throughout.
                    expanded: false,
                    accessibilityLabel: "First flight length",
                    accessibilityValue: Formatters.durationLabel(minutes: selectedMinutes),
                    onFraction: { f in
                        setDuration(index: Int((f * Double(Self.maxDurationIndex)).rounded()))
                    },
                    onAdjust: { delta in setDuration(index: durationIndex + delta) }
                )
                .frame(height: viewport.isShort ? 264 : 310)
            }
            .frame(maxWidth: .infinity)
            .onAppear(perform: seedDurationIfNeeded)
        } footer: {
            AppPrimaryButton(title: "Continue", systemImage: "arrow.right", iconTrailing: true) {
                advance()
            }
            .padding(.bottom, AppSpacing.xl)
        }
    }

    /// The wheel's ceiling: 10 hours.
    ///
    /// `DurationScale.stops` runs to 720 (12 h) and then carries a trailing ∞,
    /// and ∞ is PRO. Capping the onboarding index space below both means the
    /// first run cannot reach a paywall boundary or a value outside the brief
    /// by dragging — not because a gate refuses it, but because the positions
    /// do not exist here. Derived from the scale rather than hardcoded, so it
    /// survives any future edit to the stops.
    static let maxOnboardingMinutes = 600
    static let maxDurationIndex: Int =
        DurationScale.stops.lastIndex(where: { $0 <= maxOnboardingMinutes })
            ?? (DurationScale.stops.count - 1)

    /// The value the wheel is currently on. `minutes` stays optional so an
    /// untouched answer is still distinguishable from a chosen 25.
    private var selectedMinutes: Int { DurationScale.value(at: durationIndex).minutes }

    private var durationBig: String {
        let m = selectedMinutes
        return m < 60 ? "\(m)" : Formatters.durationLabel(minutes: m)
    }

    private var durationSub: String {
        let m = selectedMinutes
        return m < 60 ? (m == 1 ? "MINUTE" : "MINUTES") : "FLIGHT TIME"
    }

    /// Open on the pilot's answer if they have one, otherwise on 25 — and
    /// commit it, so arriving and pressing Continue without dragging still
    /// records the value the dial is visibly showing.
    private func seedDurationIfNeeded() {
        guard !didSeedDuration else { return }
        didSeedDuration = true
        durationIndex = min(Self.maxDurationIndex,
                            DurationScale.index(forMinutes: minutes ?? 25, infinite: false))
        minutes = selectedMinutes
    }

    /// One stop per change, one haptic per stop — the ritual's own feel.
    private func setDuration(index newIndex: Int) {
        let clamped = max(0, min(Self.maxDurationIndex, newIndex))
        guard clamped != durationIndex else { return }
        durationIndex = clamped
        minutes = selectedMinutes
        appModel.haptics.tap()
    }

    /// The shortlist the results screen's First-flight pencil offers.
    ///
    /// The wheel can land on any of forty-two stops and a sheet cannot usefully
    /// list them all, so this is the common set — plus, always, whatever the
    /// pilot actually chose, so the editor can never open with nothing
    /// selected. Every entry is a real `DurationScale` stop inside the same
    /// 5 min … 10 h range the wheel offers.
    static func durationEditorOptions(including current: Int?) -> [Int] {
        let shortlist = [15, 25, 30, 45, 60, 90, 120, 180, 240, 360, 600]
        guard let current, !shortlist.contains(current) else { return shortlist }
        return (shortlist + [current]).sorted()
    }

    // MARK: - 5. Focus days

    /// The one screen that turns "three flights a week" from an assumption into
    /// an answer. Everything downstream reads it: the Rhythm row names the days
    /// back, and the chart's target is a count of them.
    private var scheduleStep: some View {
        questionScaffold(
            title: "Which days do you want to focus?",
            subtitle: "Choose the days you want to make part of your routine."
        ) {
            WeekdayPicker(selection: $weeklyDays) { appModel.haptics.tap() }
        } footer: {
            AppPrimaryButton(title: "Continue", systemImage: "arrow.right",
                             isEnabled: !weeklyDays.isEmpty, iconTrailing: true) {
                advance()
            }
            .padding(.bottom, AppSpacing.xl)
        }
    }

    // MARK: - 6. Atmosphere

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
                    .accessibilityLabel(option.localizedName)
                    .accessibilityValue(Text("Selected, playing"))
                    .accessibilityHint(Text("Swipe up or down to hear another soundscape."))
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
                Text(LocalizedStringKey(option.displayName))
                    .font(.system(size: Layout.pad(23, 28), weight: .bold, design: .default))
                    .foregroundStyle(.white)
                Text(LocalizedStringKey(soundBlurb(option)))
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

    // MARK: - 7. Setting up

    /// The list names things the app is genuinely configuring, in the order it
    /// configures them — `onApply` commits the pilot's answers to the canonical
    /// settings partway through, so by the last tick the work described has
    /// actually happened.
    private var setupStep: some View {
        OnboardingSetupStep(
            items: [
                "Your first focus route",
                "Your preferred flight length",
                "Your focus atmosphere",
                "A distraction-free session",
                "Your progress path",
                "Your launch-ready Home",
            ],
            onApply: applySelections,
            onFinished: { move(to: .results) }
        )
    }

    // MARK: - 8. Results

    /// The answers go in as BINDINGS, not values.
    ///
    /// The results screen can correct any of them, and because `resultPlan` is
    /// derived from exactly this state, an edit recomputes the goal, the
    /// assumption line, the graph's label and the plan card together. There is
    /// no second copy of an answer anywhere, so the screen cannot show one thing
    /// and hand `applySelections()` another.
    private var resultsStep: some View {
        // `onContinue` is wrapped rather than passed as `advance` directly: a
        // bare method reference does not carry its default argument, so
        // `advance` has type `(Bool) -> Void` and will not satisfy `() -> Void`.
        OnboardingResultsStep(plan: resultPlan,
                              intent: $intent,
                              friction: $friction,
                              minutes: $minutes,
                              weeklyDays: $weeklyDays,
                              onContinue: { advance() })
    }

    /// Built from the pilot's own answers. `targetDate` is derived here rather
    /// than inside the view so the screen renders a stable value instead of a
    /// new one on every redraw.
    private var resultPlan: OnboardingResultPlan {
        OnboardingResultPlan(
            focusTitle: intent?.title ?? "Focus",
            frictionTitle: friction?.shortTitle ?? "Distractions",
            minutes: minutes ?? 25,
            atmosphere: appModel.selectedJourneyAudio.displayName,
            weeklyDays: weeklyDays,
            targetDate: Calendar.current.date(
                byAdding: .day,
                value: OnboardingResultPlan.weeks * 7,
                to: Date()
            ) ?? Date()
        )
    }

    // MARK: - 9. The offer

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
        // second tap on the results screen's CTA — easy while it is still sliding
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
            // on the results screen with a CTA that gives no feedback and no way
            // forward, unable to finish the first run at all.
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.entitlementGraceSeconds) {
                guard pendingEntitlementResolution, step == .results else { return }
                pendingEntitlementResolution = false
                move(to: .offer)
            }
        }
    }

    private func move(to next: Step) {
        if next != .atmosphere { appModel.stopJourneyAudioPreview() }
        withAnimation(reduceMotion ? nil : AppMotion.soft) { step = next }
    }

    /// Commit the pilot's answers to the canonical settings.
    ///
    /// Called from the setup screen, not only from `finish()`, for two reasons:
    /// it makes that screen truthful — it says the app is setting things up
    /// because at that moment it is — and it means a pilot who closes the app
    /// on the offer keeps everything they chose instead of losing every answer.
    ///
    /// `finish()` calls it a second time, and that call is not merely belt and
    /// braces: the results screen can now correct any of these answers, so the
    /// second call is what writes an edit made AFTER the setup screen ran. Each
    /// call simply overwrites with the current state, which is why running it
    /// twice is safe and why the later one always wins.
    private func applySelections() {
        appModel.applyOnboardingSelections(focusPresetTitle: intent?.title,
                                           preferredMinutes: minutes,
                                           weeklyFocusDays: weeklyDays)
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
        // Safe if the setup screen already ran: both are idempotent, and a
        // branch that reached the offer without passing through setup (a PRO
        // owner resolving mid-flow) still gets its answers written.
        applySelections()
        appModel.completeOnboarding()
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
                        Text(LocalizedStringKey(title))
                            .font(.system(size: Layout.pad(28, 36), weight: .bold, design: .default))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(LocalizedStringKey(subtitle))
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
                Text(LocalizedStringKey(title))
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
        .accessibilityLabel(Text(LocalizedStringKey(title)))
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
                Text(LocalizedStringKey(title))
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
        .accessibilityLabel(Text(LocalizedStringKey(title)))
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

    /// A compact noun for the results screen's "Main distraction" row.
    ///
    /// This is what the friction answer is FOR. It is not persisted — nothing
    /// outside the first run reads it, and storing it again with no reader is
    /// exactly what made the old `focusStruggle` field dead — but it is named
    /// back to the pilot on the screen that leads into the offer, which is the
    /// whole reason the question is asked.
    var shortTitle: String {
        switch self {
        case .phone:           return "My phone"
        case .procrastination: return "Putting it off"
        case .momentum:        return "Losing momentum"
        case .overwhelm:       return "Feeling overwhelmed"
        case .starting:        return "Getting started"
        }
    }

    /// `title` and `shortTitle` above are catalog KEYS — English, fixed, and
    /// the identity this enum compares on. These two are what gets SHOWN, for
    /// the places that need a String rather than a view: the results row and
    /// the goal sentence. Inside a view body, prefer
    /// `Text(LocalizedStringKey(title))`.
    var localizedTitle: String { FocusLocalization.string(title) }
    var localizedShortTitle: String { FocusLocalization.string(shortTitle) }
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

// MARK: - Welcome sign-in drawer

/// The minimal returning-pilot path: a title, Apple, and the policy link.
///
/// It owns no authentication of its own — `FocusAppleSignInButton` is the same
/// component Friends and Settings use, so there is exactly one Sign in with
/// Apple flow in the app and this is a second entrance to it, not a second
/// implementation. Nothing else belongs here: a first run that opens a drawer
/// full of options has stopped being a first run.
struct OnboardingSignInSheet: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var online: FocusOnlineModel
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            OnboardingBackdrop()
            VStack(spacing: AppSpacing.md) {
                Text("Sign In")
                    .font(.system(size: 24, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, AppSpacing.lg)

                FocusAppleSignInButton { error in
                    if let error {
                        errorMessage = error
                    } else {
                        dismiss()
                    }
                }
                .frame(height: 52)

                if let errorMessage {
                    Text(LocalizedStringKey(errorMessage))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.danger)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button("Privacy Policy") { openURL(LegalLinks.privacy) }
                    .buttonStyle(.plain)
                    .font(AppTypography.caption)
                    .foregroundStyle(.white.opacity(0.55))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppSpacing.screen)
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity)
        }
        .preferredColorScheme(.dark)
    }
}
