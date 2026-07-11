import StoreKit
import SwiftUI

/// First-run onboarding — a calm, premium, conversion-aware welcome that runs
/// **once** (gated by `appModel.needsOnboarding`; pre-existing pilots are
/// auto-skipped in `AppModel.init`). Eleven gentle steps over one continuous
/// night-sky scene: promise → goal → name → age → struggle → focus style →
/// soundscape → Focus Shield → notifications → a small favour (review) →
/// premium intro. Everything lands in the local `UserProfile`; no backend, no
/// sign-in — "Continue free" simply opens the app.
struct OnboardingView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview

    private static let stepCount = 11

    @State private var step = 0
    @State private var name = ""
    @State private var yearGoal = ""
    @State private var ageRange: String?
    @State private var struggle: String?
    @State private var focusStyle: String?
    @State private var shieldOptIn = false
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

    private var header: some View {
        HStack(spacing: AppSpacing.sm) {
            if step > 0 {
                AppIconButton(systemImage: "chevron.left", size: 38, tint: .white,
                              accessibilityLabel: "Back") {
                    appModel.tapFeedback()
                    withAnimation(AppMotion.soft) { step = max(0, step - 1) }
                }
            } else {
                Color.clear.frame(width: 38, height: 38)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule().fill(AppColors.gold)
                        .frame(width: geo.size.width * CGFloat(step + 1) / CGFloat(Self.stepCount))
                }
            }
            .frame(height: 4)
            .animation(.easeOut(duration: 0.3), value: step)
            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.top, AppSpacing.sm)
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
            case 7:  shieldStep
            case 8:  notificationsStep
            case 9:  favourStep
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
        withAnimation(AppMotion.soft) { step = min(Self.stepCount - 1, step + 1) }
    }

    /// Finish onboarding (persist the profile). `needsOnboarding` flips and
    /// RootView cross-fades onto Home.
    private func complete(thenPaywall: Bool) {
        appModel.completeOnboarding(name: name, yearGoal: yearGoal, ageRange: ageRange,
                                    struggle: struggle, focusStyle: focusStyle,
                                    shieldOptIn: shieldOptIn)
        appModel.markPremiumIntroSeen()   // onboarding already made the premium offer
        if thenPaywall {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                router.presentPaywall()
            }
        }
    }

    // MARK: Step 1 — Welcome / promise

    private var welcomeStep: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            BalloonView(height: 150, showBurner: true, showGlow: true,
                        glow: AppColors.gold.opacity(0.7))
            VStack(spacing: AppSpacing.sm) {
                Text("Your phone becomes\na focus flight.")
                    .font(.system(size: Layout.pad(33, 42), weight: .semibold, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                Text("Choose a time, lift off, and let FocusGlobe keep you away from distractions.")
                    .font(AppTypography.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, AppSpacing.md)
            }
            Spacer()
            AppPrimaryButton(title: "Begin", systemImage: "arrow.right") { advance() }
                .padding(.bottom, AppSpacing.xl)
        }
    }

    // MARK: Step 2 — Goal

    private var goalStep: some View {
        questionScaffold(
            title: "What do you want to achieve this year?",
            subtitle: "FocusGlobe keeps your journey pointed somewhere that matters.") {
            TextField("Pass my exams, build my app, read more, stay consistent…",
                      text: $yearGoal, axis: .vertical)
                .lineLimit(3...5)
                .focused($textFocused)
                .font(AppTypography.body)
                .foregroundStyle(Color(hex: 0x26221D))
                .tint(AppColors.gold)
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
            TextField("Your name", text: $name)
                .focused($textFocused)
                .textInputAutocapitalization(.words)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: 0x26221D))
                .tint(AppColors.gold)
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
            subtitle: "Wind is free — every soundscape opens with Premium.") {
            VStack(spacing: AppSpacing.xs) {
                ForEach(JourneyAudioOption.all.prefix(5)) { option in
                    soundRow(option)
                }
            }
        } footer: {
            continueRow(skippable: false)
        }
    }

    private func soundRow(_ option: JourneyAudioOption) -> some View {
        let unlocked = appModel.isAudioUnlocked(option)
        let selected = appModel.selectedJourneyAudio.id == option.id
        return Button {
            guard unlocked else { appModel.haptics.tap(); return }
            appModel.selectJourneyAudio(option)
            appModel.tapFeedback()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: option.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(selected ? Color(hex: 0x14120E) : .white)
                    .frame(width: 24)
                Text(option.displayName)
                    .font(AppTypography.callout)
                    .foregroundStyle(selected ? Color(hex: 0x14120E) : .white)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(hex: 0x14120E))
                } else if !unlocked {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColors.gold)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(height: 52)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(selected ? Color(hex: 0xF4EFE4) : Color.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(selected ? 0 : 0.12), lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle(scale: 0.98))
    }

    // MARK: Step 8 — Focus Shield

    private var shieldStep: some View {
        questionScaffold(
            title: "Protect your flight",
            subtitle: "Focus Shield keeps distracting apps grounded while you fly, so a focus session stays a focus session.") {
            VStack(spacing: AppSpacing.sm) {
                bulletPoint(icon: "airplane", text: "Your flight becomes a protected space")
                bulletPoint(icon: "app.badge", text: "Distracting apps wait on the ground")
                bulletPoint(icon: "checkmark.seal", text: "You choose exactly what is blocked")
            }
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
        questionScaffold(
            title: "Let FocusGlobe remind you gently",
            subtitle: "A quiet nudge for your streak, planned flights and landings — never noise.") {
            VStack(spacing: AppSpacing.sm) {
                bulletPoint(icon: "flame", text: "Keep your streak alive")
                bulletPoint(icon: "clock", text: "Reminders for flights you plan")
                bulletPoint(icon: "airplane.arrival", text: "A soft note when you land")
            }
        } footer: {
            VStack(spacing: AppSpacing.sm) {
                AppPrimaryButton(title: "Enable reminders", systemImage: "bell.fill") {
                    appModel.setNotificationsEnabled(true)
                    advance()
                }
                Button("Not now") { advance() }
                    .font(AppTypography.callout)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(.bottom, AppSpacing.xl)
        }
    }

    // MARK: Step 10 — A little favour ❤️

    private var favourStep: some View {
        questionScaffold(
            title: "A little favour… ❤️",
            subtitle: "FocusGlobe is built with a simple idea: focus should feel calm, beautiful, and worth returning to. If this app helps you, a review means a lot and helps us keep building.") {
            VStack(spacing: AppSpacing.sm) {
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(AppColors.gold)
                    }
                }
                Text("— the FocusGlobe team")
                    .font(AppTypography.serifCaption)
                    .italic()
                    .foregroundStyle(.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
        } footer: {
            VStack(spacing: AppSpacing.sm) {
                AppPrimaryButton(title: "Leave a review", systemImage: "heart.fill") {
                    requestReview()
                    advance()
                }
                Button("Maybe later") { advance() }
                    .font(AppTypography.callout)
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(.bottom, AppSpacing.xl)
        }
    }

    // MARK: Step 11 — Premium intro (soft, never blocking)

    private var premiumStep: some View {
        questionScaffold(
            title: "Unlock every Sky",
            subtitle: "Premium gives you all Skies, premium sounds, skins, advanced Focus Shield, and deeper stats.") {
            VStack(spacing: AppSpacing.xs) {
                ForEach(Array(FocusSky.all.prefix(4))) { sky in
                    HStack(spacing: AppSpacing.sm) {
                        Circle()
                            .fill(LinearGradient(colors: sky.paletteColors,
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: 26, height: 26)
                            .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                        Text(sky.name)
                            .font(AppTypography.callout)
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Image(systemName: sky.isDefaultFree ? "checkmark.circle.fill" : "crown.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(sky.isDefaultFree ? AppColors.success : AppColors.gold)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(0.07)))
                }
                Text("+ \(FocusSky.all.count - 4) more Skies")
                    .font(AppTypography.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        } footer: {
            VStack(spacing: AppSpacing.sm) {
                AppPrimaryButton(title: "Try Premium", systemImage: "crown.fill") {
                    appModel.tapFeedback()
                    complete(thenPaywall: true)
                }
                Button("Continue free") {
                    appModel.tapFeedback()
                    complete(thenPaywall: false)
                }
                .font(AppTypography.headline)
                .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.bottom, AppSpacing.xl)
        }
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
                            .font(.system(size: Layout.pad(28, 36), weight: .semibold, design: .serif))
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
            AppPrimaryButton(title: "Continue", systemImage: "arrow.right") { advance() }
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
                .font(.system(size: 16, weight: .semibold, design: .rounded))
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
