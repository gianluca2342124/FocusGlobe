import SwiftUI

/// The pre-boarding **focus loadout** ritual — load your focus into the hot-air
/// balloon before take-off.
///
/// A cinematic, highly visual step between Choose Journey and Boarding: the
/// route's Apple-Maps backdrop is darkened, a large charcoal hot-air-balloon
/// silhouette (envelope + basket) sits centre-screen, and the user **drags** a
/// focus token up from the bottom tray into the basket's loading socket. The
/// socket lights up as the token approaches, a burner glows on load, then a
/// Confirm button lifts the balloon and hands the chosen focus to BoardingView.
///
/// Additive: BoardingView is unchanged beyond receiving the pre-selected focus,
/// and this reuses the existing `FocusPreset` model.
struct PreBoardingFocusView: View {
    let route: Route

    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    @State private var selected: FocusPreset?
    @State private var dragging: FocusPreset?
    @State private var dragPoint: CGPoint = .zero
    @State private var dropFrame: CGRect = .zero
    @State private var didInteract = false
    @State private var appeared = false
    @State private var lift = false
    @State private var loadedPop = false

    private var origin: JourneyOrigin { appModel.originForJourney }

    /// Forgiving, distance-based hit test around the basket socket so dropping a
    /// token never needs to be pixel-perfect — a generous magnetic radius.
    private func isNearTarget(_ p: CGPoint) -> Bool {
        guard dropFrame != .zero else { return false }
        let c = CGPoint(x: dropFrame.midX, y: dropFrame.midY)
        let reach = max(dropFrame.width, dropFrame.height) * 0.5 + 150
        return hypot(p.x - c.x, p.y - c.y) <= reach
    }
    private var targetHot: Bool { dragging != nil && isNearTarget(dragPoint) }

    var body: some View {
        GeometryReader { geo in
            // Cap interactive content to a comfortable width and centre it, so the
            // balloon, basket and token grid stay fully on-screen. Wider on iPad/Mac
            // (a larger balloon + roomier token grid); unchanged on iPhone.
            let contentW = min(geo.size.width, Layout.pad(460, 680))
            let w = min(contentW * 0.62, geo.size.height * 0.30, Layout.pad(270, 380))
            ZStack {
                JourneyBackdropMap(origin: origin, destination: route, mode: .route,
                                   progress: 0.4, showsBalloon: false)
                    .ignoresSafeArea()
                cinematicOverlay

                VStack(spacing: AppSpacing.sm) {
                    topBar
                    headline
                    Spacer(minLength: 0)
                    balloon(width: w)
                        .offset(y: lift ? -geo.size.height : 0)
                        .opacity(lift ? 0 : (appeared ? 1 : 0))
                        .scaleEffect(appeared ? 1 : 0.95)
                    Spacer(minLength: 0)
                    confirmArea
                    tokenTray
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.lg)
                .frame(maxWidth: contentW)
                .frame(maxWidth: .infinity)

                // Floating token that follows the finger while dragging.
                if let d = dragging {
                    tokenCard(d, compact: true, active: true)
                        .frame(width: 84)
                        .scaleEffect(1.12)
                        .shadow(color: d.accent.opacity(0.5), radius: 14, y: 6)
                        .position(dragPoint)
                        .allowsHitTesting(false)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .coordinateSpace(name: "ritual")
            .onPreferenceChange(DropFrameKey.self) { dropFrame = $0 }
        }
        .focusScreenChrome()
        .onAppear {
            lift = false; dragging = nil   // fresh state if ever re-shown
            withAnimation(.spring(response: 0.6, dampingFraction: 0.86)) { appeared = true }
        }
    }

    // MARK: - Backdrop & header

    private var cinematicOverlay: some View {
        ZStack {
            Color.black.opacity(0.66)
            RadialGradient(colors: [.clear, .black.opacity(0.5)],
                           center: .center, startRadius: 110, endRadius: 560)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var topBar: some View {
        HStack {
            AppIconButton(systemImage: "chevron.left", size: 44, tint: .white,
                          accessibilityLabel: "Back") { dismiss() }
            Spacer()
        }
    }

    private var headline: some View {
        Text("What are you bringing aboard?")
            .font(.system(size: 23, weight: .semibold, design: .serif))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
            .frame(maxWidth: .infinity)
            .opacity(lift ? 0 : 1)
    }

    // MARK: - Balloon + basket silhouette

    private func balloon(width w: CGFloat) -> some View {
        let envH = w * 1.12
        let basketW = w * 0.54
        let basketH = w * 0.46
        let dropSize = basketW * 0.62
        return VStack(spacing: 0) {
            envelope(width: w, height: envH)
                .offset(y: selected != nil ? -6 : 0)        // subtle lift when loaded
            ropes(width: basketW, height: w * 0.12)
            basket(width: basketW, height: basketH, dropSize: dropSize)
                .overlay(alignment: .top) { burnerGlow.offset(y: -w * 0.14) }
        }
    }

    private func envelope(width w: CGFloat, height h: CGFloat) -> some View {
        ZStack {
            BalloonEnvelopeShape()
                .fill(LinearGradient(colors: [Color(hex: 0xB6543A).opacity(0.92),
                                              Color(hex: 0x7E3A28).opacity(0.92)],
                                     startPoint: .top, endPoint: .bottom))
            BalloonEnvelopeShape()
                .fill(RadialGradient(colors: [.white.opacity(0.16), .clear],
                                     center: UnitPoint(x: 0.36, y: 0.26), startRadius: 4, endRadius: w * 0.6))
            BalloonRibs().stroke(.white.opacity(0.07), lineWidth: 1)
            BalloonEnvelopeShape().stroke(.white.opacity(0.10), lineWidth: 1)
        }
        .frame(width: w, height: h)
        .brightness(selected != nil ? 0.04 : 0)
        .shadow(color: .black.opacity(0.45), radius: 26, y: 14)
    }

    private func ropes(width w: CGFloat, height h: CGFloat) -> some View {
        Path { p in
            let cx = w / 2
            let top = w * 0.16     // narrow near the envelope mouth
            let bot = w * 0.42     // splay out toward the basket's top edges
            for s in [-1.0, -0.4, 0.4, 1.0] {
                p.move(to: CGPoint(x: cx + CGFloat(s) * top, y: 1))
                p.addLine(to: CGPoint(x: cx + CGFloat(s) * bot, y: h - 1))
            }
        }
        .stroke(.white.opacity(0.16), lineWidth: 1.2)
        .frame(width: w, height: h)
    }

    private func basket(width: CGFloat, height: CGFloat, dropSize: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x6B4A2C).opacity(0.94),
                                              Color(hex: 0x452F1D).opacity(0.94)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1))
            // Subtle vertical weave lines.
            HStack(spacing: width / 7) {
                ForEach(0..<6, id: \.self) { _ in
                    Rectangle().fill(.white.opacity(0.05)).frame(width: 1)
                }
            }
            .padding(.vertical, 9)
            dropTarget(size: dropSize)
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.5), radius: 18, y: 10)
    }

    private func dropTarget(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(dropFill)
            if let s = selected {
                Image(systemName: s.systemImage)
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "plus")
                    .font(.system(size: size * 0.3, weight: .semibold))
                    .foregroundStyle(.white.opacity(targetHot ? 0.95 : 0.4))
            }
        }
        .frame(width: size, height: size)
        .overlay(dropBorder)
        .scaleEffect(loadedPop ? 1.08 : (targetHot ? 1.04 : 1))
        .shadow(color: dropGlow, radius: (targetHot || selected != nil) ? 22 : 0)
        .animation(.easeOut(duration: 0.16), value: targetHot)
        .background(GeometryReader { g in
            Color.clear.preference(key: DropFrameKey.self, value: g.frame(in: .named("ritual")))
        })
    }

    private var dropFill: AnyShapeStyle {
        if let s = selected {
            return AnyShapeStyle(LinearGradient(colors: [s.accent, s.accent.opacity(0.8)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        return AnyShapeStyle(Color.white.opacity(targetHot ? 0.14 : 0.05))
    }

    @ViewBuilder private var dropBorder: some View {
        if selected == nil {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(targetHot ? AppColors.gold.opacity(0.9) : .white.opacity(0.3),
                              style: StrokeStyle(lineWidth: targetHot ? 2 : 1.5, dash: [6, 5]))
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.5), lineWidth: 1.5)
        }
    }

    private var dropGlow: Color {
        if let s = selected { return s.accent.opacity(0.7) }
        return targetHot ? AppColors.gold.opacity(0.6) : .clear
    }

    private var burnerGlow: some View {
        Circle()
            .fill(RadialGradient(colors: [AppColors.gold.opacity(0.85),
                                          Color(hex: 0xFF8A2A).opacity(0.4), .clear],
                                 center: .center, startRadius: 1, endRadius: 34))
            .frame(width: 72, height: 72)
            .blur(radius: 6)
            .opacity(selected != nil ? 1 : (targetHot ? 0.7 : 0))
            .scaleEffect(loadedPop ? 1.18 : 1)
            .animation(.easeOut(duration: 0.2), value: targetHot)
            .allowsHitTesting(false)
    }

    // MARK: - Confirm

    @ViewBuilder private var confirmArea: some View {
        ZStack {
            if selected != nil && !lift {
                ExpeditionButton(title: "Board the balloon", systemImage: "location.north.line.fill") { confirm() }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(height: 54)
    }

    // MARK: - Token tray

    private var tokenTray: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            ForEach(FocusPreset.all) { preset in trayChip(preset) }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .fill(Color.black.opacity(0.32)))
                .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1))
        )
        .overlay(alignment: .top) {
            if !didInteract && selected == nil { DragHandHint().offset(y: -34) }
        }
        .opacity(lift ? 0 : 1)
    }

    private func trayChip(_ preset: FocusPreset) -> some View {
        let isDragging = dragging?.id == preset.id
        let isLoaded = selected?.id == preset.id
        return tokenCard(preset, compact: false)
            .opacity(isDragging ? 0.35 : (isLoaded ? 0.4 : 1))
            .gesture(
                DragGesture(coordinateSpace: .named("ritual"))
                    .onChanged { v in
                        didInteract = true
                        if dragging?.id != preset.id {
                            dragging = preset
                            appModel.haptics.bubble()   // soft pop on grab (fires once)
                        }
                        dragPoint = v.location
                    }
                    .onEnded { v in
                        // Accept if released near the socket OR simply dragged
                        // meaningfully upward toward the balloon — generous, so a
                        // drop succeeds every time.
                        let accepted = isNearTarget(v.location) || v.translation.height < -90
                        if accepted {
                            assign(preset)                 // clears `dragging` with a snap
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) { dragging = nil }
                        }
                    }
            )
    }

    /// A premium, **fully colour-filled** focus token. `active` lifts it (brighter
    /// border + stronger glow) for the dragged/elevated copy.
    private func tokenCard(_ preset: FocusPreset, compact: Bool, active: Bool = false) -> some View {
        VStack(spacing: 5) {
            Image(systemName: preset.systemImage)
                .font(.system(size: Layout.pad(19, 24), weight: .bold))
                .foregroundStyle(.white)
            Text(preset.title)
                .font(.system(size: Layout.pad(12, 15), weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)   // legibility on bright accents
        .frame(maxWidth: compact ? nil : .infinity)
        .frame(height: Layout.pad(62, 78))
        .padding(.horizontal, compact ? 18 : 4)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [preset.accent, preset.accent.opacity(0.78)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                RoundedRectangle(cornerRadius: 18, style: .continuous)   // soft top sheen
                    .fill(LinearGradient(colors: [.white.opacity(0.22), .clear],
                                         startPoint: .top, endPoint: .center))
                    .blendMode(.plusLighter)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(active ? 0.85 : 0.22), lineWidth: active ? 2 : 1)
        )
        .shadow(color: preset.accent.opacity(active ? 0.65 : 0.4), radius: active ? 16 : 8, y: active ? 9 : 5)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Actions

    private func assign(_ preset: FocusPreset) {
        appModel.haptics.takeoff()
        appModel.uiSound.play(.focusDrop)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            selected = preset
            dragging = nil
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { loadedPop = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.easeOut(duration: 0.2)) { loadedPop = false }
        }
    }

    private func confirm() {
        guard let preset = selected else { return }
        appModel.haptics.takeoff()
        appModel.uiSound.play(.confirm)
        withAnimation(.easeIn(duration: 0.5)) { lift = true }   // balloon lifts / take-off
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            router.proceedToBoarding(route, focus: preset)
        }
    }
}

// MARK: - Drop-target frame preference

private struct DropFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

// MARK: - Shapes

/// A rounded hot-air-balloon envelope (teardrop tapering to a small mouth).
private struct BalloonEnvelopeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let cx = rect.midX
        let mouth = w * 0.15
        p.move(to: CGPoint(x: cx - mouth, y: rect.maxY))
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.42),
                   control1: CGPoint(x: cx - mouth - w * 0.05, y: rect.maxY - h * 0.04),
                   control2: CGPoint(x: rect.minX, y: rect.minY + h * 0.78))
        p.addCurve(to: CGPoint(x: cx, y: rect.minY),
                   control1: CGPoint(x: rect.minX, y: rect.minY + h * 0.12),
                   control2: CGPoint(x: cx - w * 0.34, y: rect.minY))
        p.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.42),
                   control1: CGPoint(x: cx + w * 0.34, y: rect.minY),
                   control2: CGPoint(x: rect.maxX, y: rect.minY + h * 0.12))
        p.addCurve(to: CGPoint(x: cx + mouth, y: rect.maxY),
                   control1: CGPoint(x: rect.maxX, y: rect.minY + h * 0.78),
                   control2: CGPoint(x: cx + mouth + w * 0.05, y: rect.maxY - h * 0.04))
        p.closeSubpath()
        return p
    }
}

/// A few curved vertical ribs (gores) so the envelope reads as a balloon.
private struct BalloonRibs: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height, cx = rect.midX
        let top = rect.minY + h * 0.05, bottom = rect.maxY - h * 0.04
        for frac in [-0.6, -0.3, 0.0, 0.3, 0.6] {
            let topX = cx + CGFloat(frac) * w * 0.14
            let midX = cx + CGFloat(frac) * w * 0.5
            p.move(to: CGPoint(x: topX, y: top))
            p.addQuadCurve(to: CGPoint(x: cx + CGFloat(frac) * w * 0.15, y: bottom),
                           control: CGPoint(x: midX, y: rect.minY + h * 0.5))
        }
        return p
    }
}

// MARK: - Hand hint

/// A soft, looping finger that drags upward from the tray toward the basket —
/// shown only before the user interacts.
private struct DragHandHint: View {
    @State private var up = false
    var body: some View {
        Image(systemName: "hand.point.up.left.fill")
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(.white.opacity(0.7))
            .shadow(color: .black.opacity(0.4), radius: 5, y: 1)
            .offset(y: up ? -64 : 4)
            .opacity(up ? 0.15 : 0.85)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) { up = true }
            }
            .allowsHitTesting(false)
    }
}
