import StoreKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// First-run onboarding — a calm, premium, conversion-aware welcome that runs
/// **once** (gated by `appModel.needsOnboarding`; pre-existing pilots are
/// auto-skipped in `AppModel.init`). Eleven gentle steps over one continuous
/// night-sky scene: promise → goal → name → age → struggle → focus style →
/// soundscape → a small favour (review) → Focus Shield → notifications →
/// premium intro. The review ask now follows the first meaningful product taste
/// instead of arriving at the very end. Everything lands in the local
/// `UserProfile`; no backend, no
/// sign-in — "Skip for now" simply opens the app.
struct OnboardingView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview

    /// The one shared `SubscriptionManager`, reached exactly as `PaywallView`
    /// reaches it — through the injected `AppModel`, which owns it as a stored
    /// `let`. It is deliberately NOT a separate `@EnvironmentObject`: there is
    /// only ever one instance, nothing in the app injects it independently, and
    /// a second reference would be a second source of offerings and eligibility.
    /// `AppModel` republishes its changes, so reading it here still re-evaluates
    /// the CTA when offerings finish loading.
    private var subs: SubscriptionManager { appModel.subscriptions }

    private static let stepCount = 11

    @State private var step = 0
    @State private var name = ""
    @State private var yearGoal = ""
    @State private var ageRange: String?
    @State private var struggle: String?
    @State private var focusStyle: String?
    @State private var shieldOptIn = false
    @State private var introFloat: CGFloat = 0
    /// The soundscape carousel's current index.
    @State private var soundIndex = 0
    /// Whether a soundscape preview is currently playing on the music step.
    @State private var isPreviewingSound = false
    /// Guards the review request so a double-tap can't fire it twice or race the
    /// transition to the premium page.
    @State private var reviewRequested = false
    /// Guards the permission request so a double-tap can't call
    /// `requestAuthorization` twice or advance the step twice.
    @State private var notificationRequestInFlight = false
    @State private var premiumPreviewIndex = 0
    /// The final Continue was tapped while RevenueCat was unresolved. We hold
    /// that intent without showing the PRO page, then either finish for an owner
    /// or advance for a confirmed Free pilot.
    @State private var pendingPremiumResolution = false
    @FocusState private var textFocused: Bool

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: 0) {
                header
                ZStack {
                    stepBody
                }
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: appModel.entitlement) { _, access in
            guard step == Self.stepCount - 1 || pendingPremiumResolution else { return }
            if access == .premium {
                pendingPremiumResolution = false
                complete(thenPaywall: false)
            } else if access == .free, pendingPremiumResolution {
                pendingPremiumResolution = false
                withAnimation(AppMotion.soft) { step = Self.stepCount - 1 }
            }
        }
    }

    // MARK: Scene

    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0B1024), Color(hex: 0x1C2444), Color(hex: 0x2E2350)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [AppColors.gold.opacity(0.14), .clear],
                           center: UnitPoint(x: 0.5, y: 0.85), startRadius: 8, endRadius: 420)
            StarSprinkle()
        }
        .ignoresSafeArea()
        .onTapGesture { textFocused = false }
    }

    // MARK: Header — back + progress

    // Progress only — no back arrow (a clean, forward-moving onboarding).
    private var header: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                Capsule().fill(AppColors.brand)
                    .frame(width: geo.size.width * CGFloat(step + 1) / CGFloat(Self.stepCount))
            }
        }
        .frame(height: 4)
        .animation(.easeOut(duration: 0.3), value: step)
        .padding(.horizontal, AppSpacing.screen)
        .padding(.top, AppSpacing.md)
    }

    @ViewBuilder private var stepBody: some View {
        Group {
            switch step {
            case 0:  welcomeStep
            case 1:  goalStep
            case 2:  nameStep
            case 3:  ageStep
            case 4:  struggleStep
            case 5:  styleStep
            case 6:  soundscapeStep
            case 7:  favourStep
            case 8:  shieldStep
            case 9:  notificationsStep
            default: premiumStep
            }
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .offset(y: 24)),
            removal: .opacity.combined(with: .offset(y: -16))))
        .id(step)
        .padding(.horizontal, AppSpacing.screen)
    }

    private func advance() {
        textFocused = false
        appModel.tapFeedback()
        if step == Self.stepCount - 2 {
            switch appModel.entitlement {
            case .premium:
                complete(thenPaywall: false)
            case .free:
                withAnimation(AppMotion.soft) { step = Self.stepCount - 1 }
            case .loading:
                pendingPremiumResolution = true
                appModel.refreshSubscriptionStatus()
            }
            return
        }
        withAnimation(AppMotion.soft) { step = min(Self.stepCount - 1, step + 1) }
    }

    /// Finish onboarding (persist the profile). `needsOnboarding` flips and
    /// RootView cross-fades onto Home.
    private func complete(thenPaywall: Bool) {
        // Onboarding must always hand off to Home, whatever the user did on the
        // premium page (continue free / open + close the paywall / purchase /
        // restore). Set the root tab explicitly and clear any transient route
        // BEFORE flipping `needsOnboarding`, so AppShell can never restore a
        // stale tab (e.g. Settings) behind the cross-fade.
        router.path.removeAll()
        router.selectedTab = .home
        appModel.completeOnboarding(name: name, yearGoal: yearGoal, ageRange: ageRange,
                                    struggle: struggle, focusStyle: focusStyle,
                                    shieldOptIn: shieldOptIn)
        appModel.markPremiumIntroSeen()   // onboarding already made the premium offer
        if thenPaywall {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // The STANDARD paywall — the same `.general` context the Home
                // PRO button opens, with Annual and Monthly, the plan selector,
                // the trial timeline, the pricing disclosure and the showcase
                // carousel. It used to open `.onboarding`, which is annual-only
                // with no selector: someone who wanted the monthly plan had to
                // finish onboarding, close a paywall and find another entry
                // point. There is one paywall view; only the context differs.
                router.presentPaywall(context: .general)
            }
        }
    }

    // MARK: Step 1 — Welcome / promise

    private var welcomeStep: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            // The hero balloon drifts gently — a magical, alive first impression.
            ZStack {
                // Light, not a lit shape. The gradient must reach fully clear
                // BEFORE it meets its own frame, otherwise the frame crops a
                // still-visible ring and the balloon appears to sit on a disc.
                // (The previous ellipse was 220×270 with endRadius 128 — 128 is
                // larger than the 105 pt half-width, so the shape sliced the
                // glow at ~8% alpha and a 17 pt blur only softened that arc.)
                // Here the shortest centre-to-edge distance is 150 pt against a
                // 128 pt falloff, so every edge is genuinely transparent.
                RadialGradient(
                    colors: [
                        AppColors.gold.opacity(0.27),
                        Color(hex: 0x8F7BE8).opacity(0.08),
                        .clear,
                    ],
                    center: .center,
                    startRadius: 2,
                    endRadius: 128
                )
                .frame(width: 300, height: 300)
                .scaleEffect(x: 1, y: 1.14)      // the soft vertical bloom, kept
                .blur(radius: 18)
                .allowsHitTesting(false)
                introHero
            }
            .offset(y: introFloat)
            VStack(spacing: AppSpacing.sm) {
                Text("Your phone becomes\na focus flight.")
                    .font(.system(size: Layout.pad(34, 44), weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                Text("Choose a time, lift off, and let FocusGlobe keep you away from distractions.")
                    .font(AppTypography.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, AppSpacing.md)
            }
            Spacer()
            AppPrimaryButton(title: "Begin", systemImage: "arrow.right", iconTrailing: true) { advance() }
                .padding(.bottom, AppSpacing.xl)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { introFloat = -14 }
        }
    }

    /// The intro hero — bundled `OnboardingHero_Balloon` if present, else the
    /// procedural balloon.
    @ViewBuilder private var introHero: some View {
        #if canImport(UIKit)
        if let ui = UIImage(named: "OnboardingHero_Balloon") {
            Image(uiImage: ui).resizable().scaledToFit().frame(height: 170)
        } else {
            BalloonView(height: 156, showBurner: true, showGlow: true, glow: AppColors.gold.opacity(0.7))
        }
        #else
        BalloonView(height: 156, showBurner: true, showGlow: true, glow: AppColors.gold.opacity(0.7))
        #endif
    }

    // MARK: Step 2 — Goal

    private var goalStep: some View {
        questionScaffold(
            title: "What do you want to achieve this year?",
            subtitle: "FocusGlobe keeps your journey pointed somewhere that matters.") {
            TextField("e.g. Study for my exams", text: $yearGoal, axis: .vertical)
                .lineLimit(3...5)
                .focused($textFocused)
                .font(AppTypography.body)
                .foregroundStyle(Color(hex: 0x26221D))
                .tint(AppColors.selectionGold)
                .padding(AppSpacing.md)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: 0xF4EFE4)))
        } footer: {
            continueRow(skippable: true)
        }
    }

    // MARK: Step 3 — Name

    private var nameStep: some View {
        questionScaffold(
            title: "What's your name?",
            subtitle: "This is how FocusGlobe will personalize your journey.") {
            TextField("e.g. Alex", text: $name)
                .focused($textFocused)
                .textInputAutocapitalization(.words)
                .font(.system(size: 22, weight: .semibold, design: .default))
                .foregroundStyle(Color(hex: 0x26221D))
                .tint(AppColors.selectionGold)
                .multilineTextAlignment(.center)
                .padding(AppSpacing.md)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: 0xF4EFE4)))
        } footer: {
            continueRow(skippable: true)
        }
    }

    // MARK: Step 4 — Age range (optional)

    private var ageStep: some View {
        questionScaffold(
            title: "How old are you?",
            subtitle: "Optional — it helps us shape FocusGlobe.") {
            optionList(["13 or under", "14–17", "18–24", "25–34", "35+"],
                       selected: ageRange) { choice in
                ageRange = choice
                advance()
            }
        } footer: {
            skipButton
        }
    }

    // MARK: Step 5 — Focus struggle

    private var struggleStep: some View {
        questionScaffold(
            title: "When you try to focus, what usually happens?",
            subtitle: "So your flights can protect the right things.") {
            optionList(["I pick up my phone", "I lose motivation", "I get overwhelmed",
                        "I procrastinate", "I study well alone", "Other"],
                       selected: struggle) { choice in
                struggle = choice
                advance()
            }
        } footer: {
            skipButton
        }
    }

    // MARK: Step 6 — Focus style

    private var styleStep: some View {
        questionScaffold(
            title: "What are you focusing on most?",
            subtitle: "Your focus tokens will be waiting in the basket.") {
            optionGrid(FocusPreset.all.map { $0.title }, selected: focusStyle) { choice in
                focusStyle = choice
                advance()
            }
        } footer: {
            skipButton
        }
    }

    // MARK: Step 7 — Soundscape

    private var soundscapeStep: some View {
        questionScaffold(
            title: "Pick your focus atmosphere",
            subtitle: "Every soundscape is free. Swipe between them and choose your favourite.") {
            soundCarousel
        } footer: {
            continueRow(skippable: false)
        }
    }

    private var soundOptions: [JourneyAudioOption] { JourneyAudioOption.all }

    /// A radio/Spotify-style carousel: a large central cover with left/right
    /// arrows, dots, the title and a short line. Selecting persists the choice.
    private var soundCarousel: some View {
        let opts = soundOptions
        let option = opts[max(0, min(opts.count - 1, soundIndex))]
        return VStack(spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                carouselArrow(system: "chevron.left", enabled: soundIndex > 0) {
                    withAnimation(.easeInOut(duration: 0.3)) { soundIndex = max(0, soundIndex - 1) }
                }
                SoundCoverCard(option: option)
                    .frame(maxWidth: .infinity)
                    // One element that names the soundscape AND its state, so
                    // VoiceOver never reads decorative artwork and never implies
                    // a play control that no longer exists. Adjustable, because
                    // swiping between options is the whole interaction.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(option.displayName)
                    .accessibilityValue(isPreviewingSound
                                        ? "Selected, playing"
                                        : "Selected")
                    .accessibilityHint("Swipe up or down to hear another soundscape.")
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment where soundIndex < opts.count - 1:
                            withAnimation(.easeInOut(duration: 0.3)) { soundIndex += 1 }
                        case .decrement where soundIndex > 0:
                            withAnimation(.easeInOut(duration: 0.3)) { soundIndex -= 1 }
                        default: break
                        }
                    }
                    .gesture(DragGesture(minimumDistance: 24).onEnded { v in
                        if v.translation.width < -30, soundIndex < opts.count - 1 {
                            withAnimation(.easeInOut(duration: 0.3)) { soundIndex += 1 }
                        } else if v.translation.width > 30, soundIndex > 0 {
                            withAnimation(.easeInOut(duration: 0.3)) { soundIndex -= 1 }
                        }
                    })
                carouselArrow(system: "chevron.right", enabled: soundIndex < opts.count - 1) {
                    withAnimation(.easeInOut(duration: 0.3)) { soundIndex = min(opts.count - 1, soundIndex + 1) }
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
            // No Play button: the selected soundscape auto-plays on this step.
            // A minimal equalizer indicator confirms audio is playing.
            nowPlayingIndicator
            HStack(spacing: 6) {
                ForEach(opts.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == soundIndex ? AppColors.selectionGold : .white.opacity(0.28))
                        .frame(width: i == soundIndex ? 18 : 6, height: 6)
                }
            }
        }
        .onAppear {
            let idx = soundOptions.firstIndex { $0.id == appModel.selectedJourneyAudio.id } ?? 0
            soundIndex = idx
            // Auto-play the selected soundscape the moment the step appears.
            let opt = soundOptions[max(0, min(soundOptions.count - 1, idx))]
            appModel.previewJourneyAudio(opt)
            isPreviewingSound = true
        }
        .onChange(of: soundIndex) { _, i in
            let opt = soundOptions[max(0, min(soundOptions.count - 1, i))]
            appModel.selectJourneyAudio(opt)
            appModel.haptics.tap()
            // Swiping to a new soundscape switches the preview instantly (one at
            // a time) — always playing, never a silent step.
            appModel.previewJourneyAudio(opt)
            isPreviewingSound = true
        }
        // Stop the preview whenever the step leaves the screen (advance / back)
        // or onboarding completes, so audio never bleeds into the first flight.
        .onDisappear {
            appModel.stopJourneyAudioPreview()
            isPreviewingSound = false
        }
    }

    /// A minimal "now playing" indicator (animated equalizer) — the music step
    /// auto-plays the selected soundscape, so there is no Play/Pause button.
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
        .accessibilityLabel("Now playing a preview")
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

    // MARK: Step 8 — Focus Shield

    private var shieldStep: some View {
        questionScaffold(
            title: "Protect your flight",
            subtitle: "Focus Shield keeps distracting apps grounded while you fly. A protected flight makes distractions feel further away, so it's easier to stay with your plan.") {
            shieldPreviewCard
        } footer: {
            VStack(spacing: AppSpacing.sm) {
                AppPrimaryButton(title: "Enable Focus Shield", systemImage: "shield.fill") {
                    shieldOptIn = true
                    advance()
                }
                Button("Set up later") { shieldOptIn = false; advance() }
                    .font(AppTypography.callout)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(.bottom, AppSpacing.xl)
        }
    }

    /// The pre-permission explainer: the shield artwork floating free above the
    /// three promises. Deliberately NOT a bordered card — a single hero image
    /// boxed inside a gold-outlined rectangle reads as a widget preview or an
    /// ad, and the frame competes with the artwork it is supposed to present.
    private var shieldPreviewCard: some View {
        VStack(spacing: AppSpacing.md) {
            shieldHero
            VStack(spacing: AppSpacing.sm) {
                bulletPoint(icon: "airplane", text: "Your flight becomes a protected space")
                bulletPoint(icon: "app.badge", text: "Distracting apps stay on the ground")
                bulletPoint(icon: "checkmark.seal", text: "You choose exactly what is blocked")
            }
        }
        .padding(.vertical, AppSpacing.md)
        .frame(maxWidth: .infinity)
    }

    /// The shield hero — the real `focusshield` art (transparent PNG, soft
    /// natural glow), falling back to older bundled names, else the glyph.
    @ViewBuilder private var shieldHero: some View {
        #if canImport(UIKit)
        if let ui = UIImage(named: "focusshield")
            ?? UIImage(named: "protectyourflight")
            ?? UIImage(named: "OnboardingHero_FocusShield") {
            // Floats free. The art already carries its own natural glow, so this
            // adds only a grounding drop shadow — a 24 pt gold bloom on top of a
            // glowing PNG is what made the shield look like a sticker.
            Image(uiImage: ui).resizable().scaledToFit()
                .frame(maxHeight: 158)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .shadow(color: .black.opacity(0.28), radius: 14, y: 8)
        } else {
            shieldGlyph
        }
        #else
        shieldGlyph
        #endif
    }

    private var shieldGlyph: some View {
        Image(systemName: "shield.lefthalf.filled")
            .font(.system(size: 58, weight: .semibold))
            .foregroundStyle(LinearGradient(colors: [Color(hex: 0xF4EFE4), AppColors.gold],
                                            startPoint: .top, endPoint: .bottom))
            .shadow(color: AppColors.gold.opacity(0.4), radius: 14)
    }

    private func bulletPoint(icon: String, text: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.gold)
                .frame(width: 26)
            Text(text)
                .font(AppTypography.callout)
                .foregroundStyle(.white.opacity(0.85))
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.07)))
    }

    // MARK: Step 9 — Notifications

    private var notificationsStep: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer(minLength: 0)
            VStack(spacing: 8) {
                Text("Stay on track")
                    .font(.system(size: Layout.pad(28, 36), weight: .bold, design: .default))
                    .foregroundStyle(.white)
                Text("A gentle nudge for your streak, planned flights and landings — never noise.")
                    .font(AppTypography.callout)
                    .foregroundStyle(.white.opacity(0.66))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppSpacing.md)
            simulatedNotifCard
            Spacer(minLength: 0)
        }
        .padding(.top, AppSpacing.xl)
        // Deliberately no bottom Skip button on this step — the card's own
        // buttons drive it: "Don't Allow" continues; "Allow" triggers the real
        // iOS notification prompt (a custom SwiftUI card, never a real alert).
    }

    /// A custom, Apple-styled notification-permission preview. Visual only — the
    /// real system prompt is only requested when the user taps Allow.
    private var simulatedNotifCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: AppSpacing.sm) {
                appIconMark
                Text("\u{201C}FocusGlobe\u{201D} Would Like to\nSend You Notifications")
                    .font(.system(size: 16, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(hex: 0x14120E))
                Text("Notifications may include gentle reminders, streak nudges and landing notes.")
                    .font(.system(size: 12.5))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(hex: 0x14120E).opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppSpacing.md)
            Rectangle().fill(Color.black.opacity(0.12)).frame(height: 1)
            HStack(spacing: 0) {
                Button {
                    appModel.tapFeedback()
                    advance()
                } label: {
                    Text("Don't Allow")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color(hex: 0x0A84FF))
                        .frame(maxWidth: .infinity).frame(height: 46)
                }
                Rectangle().fill(Color.black.opacity(0.12)).frame(width: 1, height: 46)
                Button {
                    appModel.tapFeedback()
                    guard !notificationRequestInFlight else { return }
                    notificationRequestInFlight = true
                    Task { @MainActor in
                        // Straight to the system prompt. There is nothing of ours
                        // left to render first, so no artificial delay.
                        await appModel.requestOnboardingNotificationPermission()
                        notificationRequestInFlight = false
                        advance()
                    }
                } label: {
                    Text("Allow")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x0A84FF))
                        .frame(maxWidth: .infinity).frame(height: 46)
                }
            }
        }
        .frame(maxWidth: 300)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(hex: 0xEDECEF)))
        .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
        .frame(maxWidth: .infinity)
    }

    // The 👆 "Tap Allow" cue that used to live here has been removed. iOS
    // presents its permission alert in a system-owned `UIWindow` above the app's
    // own window, so an overlay drawn inside our hierarchy can never sit on top
    // of it — no `zIndex` applies across windows. It could only ever appear
    // BEHIND the alert, or flash as a stray hand on the onboarding page as the
    // alert dismissed. The Apple-styled preview card above already shows the
    // pilot exactly which button is coming.

    /// The REAL FocusGlobe app icon (the `AppLogo` asset) inside the Apple-style
    /// permission card, so the branding is correct — never a procedural mock.
    /// Falls back to the balloon mark only if the asset is somehow missing.
    private var appIconMark: some View {
        Group {
            #if canImport(UIKit)
            if let ui = UIImage(named: "AppLogo") {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                appIconFallback
            }
            #else
            appIconFallback
            #endif
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
            .strokeBorder(.black.opacity(0.12), lineWidth: 1))
    }

    private var appIconFallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x2E2350), Color(hex: 0x0B1024)],
                                     startPoint: .top, endPoint: .bottom))
            MiniBalloonView(size: 34, showGlow: false)
        }
    }

    // MARK: Step 10 — A little favour ❤️

    private var favourStep: some View {
        questionScaffold(
            title: "A little favour… ❤️",
            subtitle: "FocusGlobe was built on a simple belief: focus should feel calm, beautiful, and worth returning to. Phones usually pull us away — FocusGlobe tries to turn yours into a tiny journey instead. If it helps you, a review genuinely helps a tiny team keep building.") {
            VStack(spacing: AppSpacing.md) {
                // Reviews first (social proof), then the large emotional hero
                // below them, then the review/continue actions in the footer.
                reviewCarousel
                favourHero
                Text("— the FocusGlobe team")
                    .font(AppTypography.caption)
                    .italic()
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        } footer: {
            VStack(spacing: AppSpacing.sm) {
                if reviewRequested {
                    // The Apple prompt was requested over THIS screen (an
                    // intentional tap). We do NOT auto-advance: Continue moves on
                    // only after the user is done, so the system sheet can never
                    // appear stacked over the next ("Focus, elevated") screen.
                    AppPrimaryButton(title: "Continue", systemImage: "arrow.right", iconTrailing: true) {
                        appModel.tapFeedback(); advance()
                    }
                } else {
                    AppPrimaryButton(title: "Leave a review", systemImage: "heart.fill") {
                        reviewRequested = true
                        appModel.tapFeedback()
                        // Requested here, over the favour screen — Apple decides if
                        // it shows; either way the user then taps Continue.
                        requestReview()
                    }
                    Button("Maybe later") { advance() }
                        .font(AppTypography.callout)
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .padding(.bottom, AppSpacing.xl)
        }
    }

    /// The bundled `alittlefavour` art if present — a warm emotional hero. Falls
    /// back to a soft heart so the page never looks empty before the art lands.
    @ViewBuilder private var favourHero: some View {
        #if canImport(UIKit)
        if let ui = UIImage(named: "alittlefavour") {
            // A large, editorial emotional hero — bigger, with soft rounded edges
            // + a shadow so it reads as immersive, never a tiny boxed thumbnail.
            // (The step scrolls, so the extra height is fine on any screen.)
            Image(uiImage: ui).resizable().scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: Layout.pad(360, 440))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.4), radius: 22, y: 10)
        } else {
            Image(systemName: "heart.fill")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xF2643C), Color(hex: 0xFFB65C)],
                                                startPoint: .top, endPoint: .bottom))
                .frame(maxHeight: 120)
        }
        #else
        EmptyView()
        #endif
    }

    // Static, illustrative review cards (App Store-style copy — not live data).
    private var reviewCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                OnboardingReviewCard(name: "Maya", quote: "The first focus timer I actually want to open.")
                OnboardingReviewCard(name: "Daniel", quote: "It makes studying feel calm instead of stressful.")
                OnboardingReviewCard(name: "Priya", quote: "The balloon idea is weirdly motivating.")
                OnboardingReviewCard(name: "Leo", quote: "Beautiful, and it genuinely keeps me off my phone.")
            }
            .padding(.horizontal, 2).padding(.vertical, 4)
        }
    }

    // MARK: Step 11 — Premium intro (soft, never blocking)

    private var premiumStep: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    premiumHero
                    VStack(spacing: 6) {
                        Text("Focus, elevated.")
                            .font(.system(size: Layout.pad(30, 40), weight: .bold, design: .default))
                            .foregroundStyle(.white)
                        // NOT "Everything in FocusGlobe, unlocked." — PRO opens
                        // the four exclusive Skies, not the progression ones
                        // (Fiji, Northern Aurora, Deep Space are still earned by
                        // flying). Promising "everything" here is a claim the
                        // app then refuses to honour on the Sky selector.
                        Text("The exclusive Skies, skins and features.")
                            .font(AppTypography.callout)
                            .foregroundStyle(.white.opacity(0.66))
                    }
                    premiumBenefits
                }
                .padding(.top, AppSpacing.lg)
                .padding(.horizontal, 2)
            }
            VStack(spacing: AppSpacing.sm) {
                AppPrimaryButton(title: premiumCTATitle, systemImage: "sparkles") {
                    appModel.tapFeedback()
                    complete(thenPaywall: true)
                }
                // Secondary, but readable: this must never feel like a trap.
                Button("Skip for now") {
                    appModel.tapFeedback()
                    complete(thenPaywall: false)
                }
                .font(AppTypography.headline)
                .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.bottom, AppSpacing.xl)
        }
        // Ask for offerings when the step appears so the CTA has a real product
        // and a real eligibility answer to work from. Until it does, the CTA
        // says "See PRO Plans", which is true in every case.
        .onAppear { subs.loadOfferings() }
    }

    /// "Try for $0.00" is a price claim, so it is only made when the Store has
    /// actually confirmed one: a loaded annual product, carrying a real
    /// free-trial introductory offer, that THIS Apple ID is eligible for, and a
    /// zero formatted by that product's own formatter — so the currency and
    /// placement are right on every storefront rather than a hardcoded "$".
    ///
    /// Anything short of all four — offerings still loading, no trial
    /// configured, already used the trial, an unknown eligibility result — falls
    /// back to a claim that is always true.
    private var premiumCTATitle: String {
        guard let annual = subs.plan(.annual),
              annual.offersFreeTrial,
              let zero = annual.localizedZeroPrice
        else { return "See PRO Plans" }
        return "Try for \(zero)"
    }

    /// A continuously moving window into real PRO worlds. The scene art is a
    /// still foundation and only the conveyor moves, keeping this first-run
    /// surface rich without running several living-Sky timelines at once.
    private var premiumHero: some View {
        FocusContinuousCarousel(
            items: premiumPreviewItems,
            selectedIndex: $premiumPreviewIndex,
            spacing: 4,
            maximumCardWidth: 210,
            cardWidthFraction: 0.54,
            minimumCardWidth: 140,
            // Deliberately below the shared 42: this is a first-run surface and
            // the only carousel that mixes landscape Skies with balloons, so it
            // stays a touch calmer. Still +25% on its previous 28.
            speed: 35
        ) { preview, prominence in
            premiumPreviewCard(preview, prominence: prominence)
        }
        .frame(height: Layout.pad(170, 190))
    }

    /// A Sky reads as a place (full landscape card); a balloon skin reads as an
    /// object (isolated artwork, no scenery, no card) — never a balloon stuffed
    /// inside a Sky.
    @ViewBuilder
    private func premiumPreviewCard(_ preview: OnboardingPremiumPreview,
                                    prominence: Double) -> some View {
        switch preview {
        case .sky(let sky):
            ZStack {
                SkyStillPreview(sky: sky)
                LinearGradient(colors: [.clear, .black.opacity(0.42)],
                               startPoint: .center, endPoint: .bottom)
                previewCaption(sky.name)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.10 + prominence * 0.10), lineWidth: 1)
            )

        case .skin(let skin):
            // Isolated balloon: transparent artwork floating on the page, lifted
            // gently as it reaches centre. No landscape, no rectangle, no border.
            ZStack {
                BalloonView(height: 104 + 16 * prominence,
                            showBurner: true,
                            showGlow: prominence > 0.5,
                            skin: skin)
                    .offset(y: -6 - 4 * prominence)
                    .shadow(color: .black.opacity(0.28), radius: 14, y: 9)
                previewCaption(skin.name)
            }
        }
    }

    private func previewCaption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1).minimumScaleFactor(0.8)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(.black.opacity(0.34)))
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 9)
    }

    /// The showcase reel: the four PRO-exclusive Skies interleaved with real PRO
    /// balloon skins, so it alternates Sky · Balloon · Sky · Balloon. Both lists
    /// come from the canonical models — never a hand-maintained duplicate.
    private var premiumPreviewItems: [OnboardingPremiumPreview] {
        let skies = FocusSky.proExclusive
        let skins = BalloonSkin.all.filter(\.isPremium)
        guard !skies.isEmpty || !skins.isEmpty else { return [] }
        var reel: [OnboardingPremiumPreview] = []
        for index in 0..<max(skies.count, skins.count) {
            if index < skies.count { reel.append(.sky(skies[index])) }
            if index < skins.count { reel.append(.skin(skins[index])) }
        }
        return reel
    }

    private var premiumBenefits: some View {
        VStack(spacing: AppSpacing.xs) {
            // Fixed order and consistent Title Case; sentiment is kept out of the
            // product-benefit table.
            premiumBenefit("moon.stars.fill", "Exclusive Skies")
            premiumBenefit("circle.circle.fill", "Exclusive Skins & Items")
            premiumBenefit("square.grid.2x2.fill", "Exclusive Widgets")
            premiumBenefit("person.2.fill", "Online Mode")
            premiumBenefit("infinity", "Unlimited Time ∞")
            premiumBenefit("bolt.fill", "2x Coins on Every Flight")
            premiumBenefit("hand.thumbsup.fill", "No Ads, Ever")
        }
    }

    private func premiumBenefit(_ icon: String, _ text: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.gold)
                .frame(width: 24)
            Text(text)
                .font(AppTypography.callout)
                .foregroundStyle(.white.opacity(0.9))
            Spacer(minLength: 0)
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColors.gold)
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(height: 40)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.06)))
    }

    // MARK: Shared scaffolding

    private func questionScaffold<Content: View, Footer: View>(
        title: String, subtitle: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer) -> some View {
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
                    content()
                }
                .padding(.top, AppSpacing.xl)
            }
            footer()
        }
    }

    private func continueRow(skippable: Bool) -> some View {
        VStack(spacing: AppSpacing.sm) {
            AppPrimaryButton(title: "Continue", systemImage: "arrow.right", iconTrailing: true) { advance() }
            if skippable {
                Button("Skip") { advance() }
                    .font(AppTypography.callout)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(.bottom, AppSpacing.xl)
    }

    private var skipButton: some View {
        Button("Skip") { advance() }
            .font(AppTypography.callout)
            .foregroundStyle(.white.opacity(0.55))
            .padding(.bottom, AppSpacing.xl)
    }

    private func optionList(_ options: [String], selected: String?,
                            choose: @escaping (String) -> Void) -> some View {
        VStack(spacing: AppSpacing.xs) {
            ForEach(options, id: \.self) { option in
                optionButton(option, isSelected: selected == option) { choose(option) }
            }
        }
    }

    private func optionGrid(_ options: [String], selected: String?,
                            choose: @escaping (String) -> Void) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: AppSpacing.xs),
                            GridItem(.flexible(), spacing: AppSpacing.xs)],
                  spacing: AppSpacing.xs) {
            ForEach(options, id: \.self) { option in
                optionButton(option, isSelected: selected == option) { choose(option) }
            }
        }
    }

    private func optionButton(_ title: String, isSelected: Bool,
                              action: @escaping () -> Void) -> some View {
        Button {
            appModel.tapFeedback()
            action()
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .default))
                .foregroundStyle(isSelected ? Color(hex: 0x14120E) : .white)
                .lineLimit(1).minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color(hex: 0xF4EFE4) : Color.white.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(isSelected ? 0 : 0.12), lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle(scale: 0.98))
    }
}

/// One entry in the onboarding PRO showcase. Skies and balloon skins are two
/// DIFFERENT kinds of thing and are presented differently: a Sky gets a full
/// landscape card, a balloon skin floats free as isolated artwork with no forced
/// scenery behind it. They alternate so the reel reads as "worlds *and* balloons".
private enum OnboardingPremiumPreview: Identifiable {
    case sky(FocusSky)
    case skin(BalloonSkin)

    var id: String {
        switch self {
        case .sky(let s):  return "sky.\(s.id)"
        case .skin(let k): return "skin.\(k.id)"
        }
    }

    var title: String {
        switch self {
        case .sky(let s):  return s.name
        case .skin(let k): return k.name
        }
    }
}

/// A large soundscape "cover" for the onboarding carousel — the bundled
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

/// A static, illustrative 5-star review card for the onboarding "favour" step —
/// App Store-style copy, never presented as live data.
private struct OnboardingReviewCard: View {
    let name: String
    let quote: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.gold)
                        .shadow(color: AppColors.gold.opacity(0.5), radius: 3)
                }
            }
            Text(quote)
                .font(.system(size: 13.5, weight: .medium, design: .default))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Text("— \(name)")
                .font(AppTypography.caption)
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(AppSpacing.md)
        .frame(width: 240, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1))
        )
    }
}

/// A quiet, deterministic star sprinkle for the onboarding night sky.
private struct StarSprinkle: View {
    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: 0x0B0A)
            for _ in 0..<70 {
                let x = CGFloat(rng.unit()) * size.width
                let y = CGFloat(rng.unit()) * size.height * 0.7
                let r = CGFloat(0.5 + rng.unit() * 1.4)
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(0.14 + rng.unit() * 0.4)))
            }
        }
        .allowsHitTesting(false)
    }
}
