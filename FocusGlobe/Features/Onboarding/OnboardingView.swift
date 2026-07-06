import SwiftUI

/// First-launch resolving / choose-a-city screen. Shown by `RootView` only while
/// the app has no origin at all (no GPS fix yet, none chosen, never travelled).
///
/// Cinematic & premium: the same satellite 3D planetary Earth as Home sits
/// behind a soft glow, with an elegant orbit loader while we locate the user —
/// it reads as "preparing your world", not a generic spinner. On denied /
/// unavailable it becomes a calm "choose a starting city" state; a manual option
/// also appears after a short timeout so the user is never stuck.
struct OnboardingView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showCityPicker = false
    @State private var allowManualHint = false

    private var isResolving: Bool {
        switch appModel.locationState {
        case .idle, .resolving:                  return true
        case .denied, .unavailable, .resolved:   return false
        }
    }

    var body: some View {
        ZStack {
            // Same satellite 3D planetary globe as Home — "preparing the world".
            JourneyBackdropMap(origin: .default, mode: .origin,
                               showsBalloon: false, showsOrigin: false,
                               style: .satellite, planetary: true)
                .ignoresSafeArea()
            scrim
            glow

            VStack(spacing: AppSpacing.lg) {
                Spacer()
                BalloonView(height: 118, showBurner: true, showGlow: true,
                            glow: AppColors.gold.opacity(0.7))
                if isResolving { resolvingBlock } else { fallbackBlock }
                Spacer()
                if isResolving && allowManualHint { manualHint }
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, AppSpacing.xl)
            .frame(maxWidth: 520)            // responsive cap (iPad / large displays)
            .frame(maxWidth: .infinity)
        }
        .focusScreenChrome()
        .onAppear {
            LaunchLog.mark("Onboarding onAppear + requestLocation")
            appModel.requestLocation()
            // Safety net: if a fix is slow, quietly offer the manual picker so the
            // user is never stuck on the resolving screen.
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { allowManualHint = true }
        }
        .sheet(isPresented: $showCityPicker) { LocationPickerView() }
    }

    private var scrim: some View {
        LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0.20), .black.opacity(0.74)],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    private var glow: some View {
        RadialGradient(colors: [AppColors.brand.opacity(0.18), .clear],
                       center: .center, startRadius: 10, endRadius: 300)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    private var resolvingBlock: some View {
        VStack(spacing: AppSpacing.sm) {
            OrbitLoader()
            Text("Finding your starting point…")
                .font(AppTypography.headline)
                .foregroundStyle(.white)
            Text("Your expeditions begin from where you are.")
                .font(AppTypography.caption)
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
        }
        .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
    }

    private var fallbackBlock: some View {
        VStack(spacing: AppSpacing.md) {
            VStack(spacing: 4) {
                Text("Where shall we begin?")
                    .font(AppTypography.title2)
                    .foregroundStyle(.white)
                Text("Choose a starting city — you'll travel onward from there.")
                    .font(AppTypography.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
            .shadow(color: .black.opacity(0.4), radius: 8, y: 2)

            AppPrimaryButton(title: "Choose a starting city", systemImage: "mappin.and.ellipse") {
                appModel.haptics.tap()
                showCityPicker = true
            }
        }
    }

    private var manualHint: some View {
        Button {
            appModel.haptics.tap()
            showCityPicker = true
        } label: {
            Text("Choose a city manually")
                .font(AppTypography.caption)
                .foregroundStyle(.white.opacity(0.8))
                .underline()
        }
        .buttonStyle(SoftPressStyle())
    }
}

/// A small, elegant orbit loader — a faint ring with a gold satellite dot
/// circling it. Premium and calm; replaces the default system spinner.
private struct OrbitLoader: View {
    @State private var spin = false
    var body: some View {
        ZStack {
            Circle().strokeBorder(.white.opacity(0.18), lineWidth: 2)
            Circle()
                .fill(AppColors.gold)
                .frame(width: 7, height: 7)
                .shadow(color: AppColors.gold.opacity(0.7), radius: 5)
                .offset(y: -19)
                .rotationEffect(.degrees(spin ? 360 : 0))
        }
        .frame(width: 38, height: 38)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) { spin = true }
        }
        .accessibilityLabel("Finding your location")
    }
}
