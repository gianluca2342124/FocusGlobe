import SwiftUI

/// First-launch resolving / choose-a-city screen. Shown by `RootView` only while
/// the app has no origin at all (no GPS fix yet, none chosen, never travelled).
///
/// • Resolving → a calm premium "finding you" state.
/// • Denied / unavailable → a clean fallback where the user picks a starting
///   city. Once GPS resolves, a city is chosen, or the user has travelled,
///   `RootView` swaps to Home automatically.
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
            JourneyBackdropMap(origin: .default, mode: .origin,
                               showsBalloon: false, showsOrigin: false)
                .ignoresSafeArea()
            scrim
            VStack(spacing: AppSpacing.lg) {
                Spacer()
                BalloonView(height: 150, showBurner: true, showGlow: true,
                            glow: AppColors.gold.opacity(0.7))
                AppLogo(size: 34)
                if isResolving { resolvingBlock } else { fallbackBlock }
                Spacer()
                if isResolving && allowManualHint { manualHint }
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, AppSpacing.xl)
        }
        .focusScreenChrome()
        .onAppear {
            appModel.requestLocation()
            // Safety net: if a fix is slow, quietly offer the manual picker so the
            // user is never stuck on the resolving screen.
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { allowManualHint = true }
        }
        .sheet(isPresented: $showCityPicker) { LocationPickerView() }
    }

    private var scrim: some View {
        LinearGradient(colors: [.black.opacity(0.5), .black.opacity(0.18), .black.opacity(0.7)],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    private var resolvingBlock: some View {
        VStack(spacing: AppSpacing.sm) {
            ProgressView().tint(.white)
            Text("Finding where you are…")
                .font(AppTypography.headline)
                .foregroundStyle(.white)
            Text("Your journeys begin from your real location.")
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
