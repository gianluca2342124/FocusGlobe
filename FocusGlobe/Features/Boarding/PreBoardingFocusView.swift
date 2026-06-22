import SwiftUI

/// The pre-boarding **focus loadout** ritual — a cinematic, highly visual step
/// shown between Choose Journey and Boarding.
///
/// The journey map stays behind a heavy dark overlay (subdued, cinematic). A
/// large, minimal charcoal balloon-pod sits centre-screen with a single focus
/// compartment. The user taps the compartment, picks a focus token from a
/// floating panel, and the slot fills. A confirm button then triggers a polished
/// upward "take-off" transition into the existing `BoardingView`, carrying the
/// chosen focus.
///
/// This is an *additive* step: it never replaces or redesigns BoardingView, and
/// it reuses the existing `FocusPreset` model.
struct PreBoardingFocusView: View {
    let route: Route

    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    @State private var selected: FocusPreset?
    @State private var showPanel = false
    @State private var appeared = false
    @State private var lift = false        // upward take-off transition
    @State private var slotPop = false     // spring when a token lands

    private var origin: JourneyOrigin { appModel.originForJourney }

    var body: some View {
        GeometryReader { geo in
            let podW = min(geo.size.width * 0.72, 300)
            let podH = min(geo.size.height * 0.52, 470)
            ZStack {
                // Subdued cinematic backdrop: the journey map behind a dark scrim.
                JourneyBackdropMap(origin: origin, destination: route, mode: .route,
                                   progress: 0.4, showsBalloon: false)
                    .ignoresSafeArea()
                cinematicOverlay

                VStack(spacing: AppSpacing.lg) {
                    topBar
                    titleBlock
                        .opacity(showPanel ? 0.25 : 1)
                    Spacer(minLength: 0)
                    pod(width: podW, height: podH)
                        .offset(y: lift ? -geo.size.height : 0)
                        .scaleEffect(appeared ? 1 : 0.94)
                        .opacity(lift ? 0 : (appeared ? 1 : 0))
                    Spacer(minLength: 0)
                    confirmArea
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.vertical, AppSpacing.lg)

                if showPanel { tokenPanel }
            }
        }
        .focusScreenChrome()
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.86)) { appeared = true }
        }
    }

    // MARK: - Backdrop

    private var cinematicOverlay: some View {
        ZStack {
            Color.black.opacity(0.64)
            RadialGradient(colors: [.clear, .black.opacity(0.45)],
                           center: .center, startRadius: 120, endRadius: 540)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Header

    private var topBar: some View {
        HStack {
            AppIconButton(systemImage: "chevron.left", size: 44, tint: .white,
                          accessibilityLabel: "Back") { dismiss() }
            Spacer()
        }
    }

    private var titleBlock: some View {
        Text("What do you want to focus?")
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Central loading pod

    private func pod(width: CGFloat, height: CGFloat) -> some View {
        let topR = width * 0.5
        let botR = width * 0.16
        return VStack(spacing: AppSpacing.sm) {
            // Globe/envelope accent — FocusGlobe identity, minimal.
            ZStack {
                Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1.5)
                Circle().strokeBorder(.white.opacity(0.06), lineWidth: 1).padding(7)
                Image(systemName: "globe.europe.africa.fill")
                    .font(.system(size: width * 0.11, weight: .light))
                    .foregroundStyle(.white.opacity(0.18))
            }
            .frame(width: width * 0.36, height: width * 0.36)
            .padding(.top, AppSpacing.md)

            focusSlot(size: width * 0.46)

            // Decorative compartments — composition only.
            VStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(.white.opacity(0.07), lineWidth: 1))
                        .frame(height: 14)
                }
            }
            .padding(.horizontal, width * 0.18)
            .padding(.bottom, AppSpacing.md)
            Spacer(minLength: 0)
        }
        .frame(width: width, height: height)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: topR, bottomLeadingRadius: botR,
                                   bottomTrailingRadius: botR, topTrailingRadius: topR, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x232B39).opacity(0.62),
                                              Color(hex: 0x121620).opacity(0.66)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: topR, bottomLeadingRadius: botR,
                                           bottomTrailingRadius: botR, topTrailingRadius: topR, style: .continuous)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.55), radius: 30, y: 18)
        )
    }

    private func focusSlot(size: CGFloat) -> some View {
        Button { openPanel() } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(slotFill)
                slotContent(size: size)
            }
            .frame(width: size, height: size)
            .overlay(slotBorder)
            .shadow(color: (selected?.accent ?? .clear).opacity(0.5), radius: 18)
            .scaleEffect(slotPop ? 1.06 : 1)
            .overlay { if selected == nil && !showPanel { FocusHandHint() } }
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel(selected == nil ? "Choose a focus" : "Focus: \(selected!.title)")
    }

    private var slotFill: AnyShapeStyle {
        if let s = selected {
            return AnyShapeStyle(LinearGradient(colors: [s.accent, s.accent.opacity(0.8)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        return AnyShapeStyle(Color.white.opacity(0.05))
    }

    @ViewBuilder private var slotBorder: some View {
        if selected == nil {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.28), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        } else {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.5), lineWidth: 1.5)
        }
    }

    @ViewBuilder private func slotContent(size: CGFloat) -> some View {
        if let s = selected {
            VStack(spacing: 6) {
                Image(systemName: s.systemImage)
                    .font(.system(size: size * 0.26, weight: .bold))
                    .foregroundStyle(.white)
                Text(s.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        } else {
            Image(systemName: "plus")
                .font(.system(size: size * 0.24, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    // MARK: - Confirm

    @ViewBuilder private var confirmArea: some View {
        ZStack {
            if selected != nil && !lift {
                AppPrimaryButton(title: "Confirm focus", systemImage: "checkmark") { confirm() }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(height: 56)   // reserve space so the pod doesn't jump
    }

    // MARK: - Token panel

    private var tokenPanel: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { closePanel() }
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Capsule().fill(.white.opacity(0.25)).frame(width: 38, height: 5)
                    .frame(maxWidth: .infinity)
                Text("What do you want to focus?")
                    .font(AppTypography.headline)
                    .foregroundStyle(.white)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: AppSpacing.sm)],
                          spacing: AppSpacing.sm) {
                    ForEach(FocusPreset.all) { preset in tokenChip(preset) }
                }
            }
            .padding(AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                UnevenRoundedRectangle(topLeadingRadius: AppSpacing.sheetRadius,
                                       bottomLeadingRadius: 0, bottomTrailingRadius: 0,
                                       topTrailingRadius: AppSpacing.sheetRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(UnevenRoundedRectangle(topLeadingRadius: AppSpacing.sheetRadius,
                                                    bottomLeadingRadius: 0, bottomTrailingRadius: 0,
                                                    topTrailingRadius: AppSpacing.sheetRadius, style: .continuous)
                        .fill(Color.black.opacity(0.4)))
                    .ignoresSafeArea(edges: .bottom)
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .transition(.opacity)
    }

    private func tokenChip(_ preset: FocusPreset) -> some View {
        let isSel = selected?.id == preset.id
        return Button { assign(preset) } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(preset.accent).frame(width: 30, height: 30)
                    Image(systemName: preset.systemImage)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text(preset.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Capsule().fill(.ultraThinMaterial)
                    .overlay(Capsule().fill(preset.accent.opacity(isSel ? 0.45 : 0.18)))
                    .overlay(Capsule().strokeBorder(preset.accent.opacity(isSel ? 0.9 : 0.5),
                                                    lineWidth: isSel ? 2 : 1))
            )
        }
        .buttonStyle(SoftPressStyle())
    }

    // MARK: - Actions

    private func openPanel() {
        appModel.haptics.tap()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { showPanel = true }
    }

    private func closePanel() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { showPanel = false }
    }

    private func assign(_ preset: FocusPreset) {
        appModel.haptics.tap()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            selected = preset
            showPanel = false
        }
        // A small "drop into the slot" pop.
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { slotPop = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            withAnimation(.easeOut(duration: 0.2)) { slotPop = false }
        }
    }

    private func confirm() {
        guard let preset = selected else { return }
        appModel.haptics.takeoff()
        withAnimation(.easeIn(duration: 0.5)) { lift = true }   // pod lifts up / take-off
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            router.openBoarding(route, focus: preset)
        }
    }
}

// MARK: - Hand hint

/// A soft, looping finger-tap hint over the focus slot. Disappears once the user
/// interacts (the parent only shows it while no focus is selected).
private struct FocusHandHint: View {
    @State private var animate = false
    var body: some View {
        Image(systemName: "hand.tap.fill")
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(.white.opacity(0.7))
            .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
            .scaleEffect(animate ? 0.84 : 1.0)
            .offset(y: animate ? 7 : -2)
            .opacity(animate ? 0.55 : 0.9)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { animate = true }
            }
            .allowsHitTesting(false)
    }
}
