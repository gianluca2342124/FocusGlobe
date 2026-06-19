import SwiftUI

/// The premium check-in ritual. A real Google map (current location →
/// destination) sits behind a boarding pass that "prints" into place; the user
/// then drags to tear the stub, which takes off. FocusFlight-grade, calm, and
/// dark-first.
struct BoardingView: View {
    let route: Route

    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @State private var intention: String = ""
    @FocusState private var intentionFocused: Bool

    // Print + tear choreography.
    @State private var reveal: CGFloat = 0
    @State private var barcodeIn = false
    @State private var torn = false

    private var origin: JourneyOrigin { appModel.originForJourney }
    private var distanceKm: Double {
        GeoMath.distanceKm(from: origin.coordinate, to: route.destination)
    }

    var body: some View {
        ZStack {
            JourneyBackdropMap(origin: origin, destination: route, mode: .route,
                               progress: 0.32, showsBalloon: false)
                .ignoresSafeArea()

            scrims

            VStack(spacing: AppSpacing.md) {
                topBar
                Spacer(minLength: AppSpacing.sm)

                BoardingPassCard(origin: origin, route: route, distanceKm: distanceKm,
                                 reveal: reveal, barcodeIn: barcodeIn, torn: torn)
                    .frame(maxWidth: 420)

                intentionField
                    .opacity(barcodeIn ? 1 : 0)

                Spacer(minLength: AppSpacing.sm)

                TearToTakeOff(accent: route.colorTheme.accent) { takeOff() }
                    .opacity(barcodeIn && !torn ? 1 : 0)
                    .padding(.bottom, AppSpacing.xs)
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.lg)
        }
        .focusScreenChrome()
        .onAppear {
            appModel.analytics.log(.journeyPassViewed, ["route": route.id])
            runPrintSequence()
        }
        .contentShape(Rectangle())
        .onTapGesture { intentionFocused = false }
    }

    private var scrims: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 150)
            Spacer()
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                .frame(height: 320)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var topBar: some View {
        HStack {
            AppIconButton(systemImage: "chevron.left", size: 44, tint: .white,
                          accessibilityLabel: "Back") { dismiss() }
            Spacer()
            Text("Check in")
                .font(AppTypography.headline)
                .foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
    }

    private var intentionField: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "target")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(route.colorTheme.accent)
            TextField("What are you focusing on?", text: $intention)
                .font(AppTypography.body)
                .foregroundStyle(.white)
                .focused($intentionFocused)
                .submitLabel(.done)
                .onSubmit { intentionFocused = false }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.md - 3)
        .glassBackground(cornerRadius: 16, tintOpacity: 0.22, shadowRadius: 8, shadowY: 4)
    }

    // MARK: - Choreography

    private func runPrintSequence() {
        guard reveal == 0 else { return }
        withAnimation(.easeOut(duration: 1.15)) { reveal = 1 }
        // Subtle "printing" haptic ticks.
        for t in [0.12, 0.45, 0.82] {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { appModel.haptics.tap() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { barcodeIn = true }
            appModel.haptics.resume()
        }
    }

    private func takeOff() {
        appModel.haptics.takeoff()
        intentionFocused = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) { torn = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            router.startJourney(origin: origin, route: route, intention: intention)
        }
    }
}

// MARK: - Boarding pass

private struct BoardingPassCard: View {
    let origin: JourneyOrigin
    let route: Route
    let distanceKm: Double
    let reveal: CGFloat
    let barcodeIn: Bool
    let torn: Bool

    private let stubHeight: CGFloat = 168

    var body: some View {
        VStack(spacing: 0) {
            stub
                .offset(y: torn ? -10 : 0)
                .opacity(torn ? 0.0 : 1)
            // The lower strip (with the barcode) tears away at the perforation.
            details
                .offset(y: torn ? 80 : 0)
                .rotationEffect(.degrees(torn ? 1.5 : 0), anchor: .top)
                .opacity(torn ? 0 : 1)
        }
        .background {
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                        .fill(Color(hex: 0x0E1424).opacity(0.55))
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous))
        .overlay(alignment: .top) {
            DashLine()
                .stroke(.white.opacity(0.45), style: StrokeStyle(lineWidth: 1.2, dash: [4, 5]))
                .frame(height: 1)
                .padding(.horizontal, AppSpacing.md)
                .offset(y: stubHeight)
        }
        .overlay(alignment: .topLeading) { notch.offset(x: -9, y: stubHeight - 9) }
        .overlay(alignment: .topTrailing) { notch.offset(x: 9, y: stubHeight - 9) }
        .compositingGroup()
        .shadow(color: .black.opacity(0.4), radius: 22, x: 0, y: 14)
        // "Printing": reveal top-down out of the slot.
        .mask(alignment: .top) {
            GeometryReader { g in
                Rectangle()
                    .frame(height: max(0, g.size.height * reveal))
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private var notch: some View {
        Circle()
            .fill(Color.black)
            .frame(width: 18, height: 18)
            .blendMode(.destinationOut)
    }

    private var stub: some View {
        ZStack {
            route.mood.gradient
            DottedTexture().opacity(0.18)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Text("FocusGlobe · Boarding Pass")
                        .font(AppTypography.micro)
                        .tracking(0.6)
                        .foregroundStyle(route.mood.preferredForeground.opacity(0.85))
                    Spacer()
                    AppTagChip(title: route.category.displayName,
                               systemImage: route.category.systemImage,
                               foreground: route.mood.preferredForeground)
                }

                Spacer()

                HStack(alignment: .center) {
                    endpoint(code: origin.code, name: origin.city)
                    Spacer()
                    VStack(spacing: 2) {
                        BalloonView(height: 44, showBurner: false, showGlow: false)
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(route.mood.preferredForeground.opacity(0.7))
                    }
                    Spacer()
                    endpoint(code: route.destinationCode, name: route.destinationName, alignment: .trailing)
                }
            }
            .padding(AppSpacing.md)
        }
        .frame(height: stubHeight)
    }

    private var details: some View {
        let columns = [GridItem(.flexible(), spacing: AppSpacing.sm),
                       GridItem(.flexible(), spacing: AppSpacing.sm),
                       GridItem(.flexible(), spacing: AppSpacing.sm)]
        return VStack(spacing: AppSpacing.md) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: AppSpacing.md) {
                PassDetail(label: "Duration", value: route.durationLabel, systemImage: "clock")
                PassDetail(label: "Distance", value: Formatters.distance(km: distanceKm), systemImage: "ruler")
                PassDetail(label: "Date", value: Self.dateText, systemImage: "calendar")
                PassDetail(label: "Boarding", value: "Now", systemImage: "clock.badge.checkmark")
                PassDetail(label: "Seat", value: "1A · Focus", systemImage: "chair.lounge")
                PassDetail(label: "Vehicle", value: "Sky Balloon", systemImage: "balloon")
            }

            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "gift").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(route.colorTheme.accent)
                Text("REWARD").font(.system(size: 9, weight: .semibold, design: .rounded))
                    .tracking(0.5).foregroundStyle(.white.opacity(0.55))
                Text(route.rewardName).font(AppTypography.caption).foregroundStyle(.white)
                Spacer()
            }

            BarcodeStrip(seed: origin.code + route.id + route.destinationCode)
                .frame(height: 42)
                .opacity(barcodeIn ? 1 : 0)
                .scaleEffect(x: barcodeIn ? 1 : 0.96, anchor: .leading)
        }
        .padding(AppSpacing.md)
    }

    private func endpoint(code: String, name: String, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(code)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(route.mood.preferredForeground)
            Text(name)
                .font(AppTypography.caption)
                .foregroundStyle(route.mood.preferredForeground.opacity(0.85))
                .lineLimit(1)
        }
    }

    private static let dateText: String = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f.string(from: Date()).uppercased()
    }()
}

// MARK: - Tear to take off

/// A premium "slide to tear & take off" control. Dragging the knob across the
/// perforation tears the stub; releasing past the threshold takes off.
private struct TearToTakeOff: View {
    let accent: Color
    let onComplete: () -> Void

    @State private var drag: CGFloat = 0
    @State private var committed = false
    private let knob: CGFloat = 56

    var body: some View {
        GeometryReader { geo in
            let track = geo.size.width
            let maxX = max(1, track - knob)
            let progress = min(1, drag / maxX)

            ZStack(alignment: .leading) {
                // Track with a dashed "perforation".
                Capsule().fill(.ultraThinMaterial)
                Capsule().fill(Color.black.opacity(0.28))
                Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1)
                HStack(spacing: 6) {
                    ForEach(0..<26, id: \.self) { _ in
                        Capsule().fill(.white.opacity(0.18)).frame(width: 4, height: 2)
                    }
                }
                .padding(.horizontal, knob)
                .opacity(1 - progress)

                // Filled trail as you drag.
                Capsule()
                    .fill(accent.opacity(0.30))
                    .frame(width: drag + knob)

                Text(progress > 0.55 ? "Release to take off" : "Slide to tear & take off")
                    .font(AppTypography.callout)
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .opacity(1 - progress * 0.9)

                // Knob.
                ZStack {
                    Circle().fill(.white)
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Color(hex: 0x14181F))
                        .rotationEffect(.degrees(progress * 12))
                }
                .frame(width: knob, height: knob)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                .offset(x: drag)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            guard !committed else { return }
                            drag = min(maxX, max(0, v.translation.width))
                        }
                        .onEnded { _ in
                            guard !committed else { return }
                            if progress >= 0.85 {
                                committed = true
                                withAnimation(.easeOut(duration: 0.18)) { drag = maxX }
                                onComplete()
                            } else {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { drag = 0 }
                            }
                        }
                )
            }
        }
        .frame(height: knob)
        .accessibilityElement()
        .accessibilityLabel("Slide to take off")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onComplete() }
    }
}

// MARK: - Pass pieces

private struct PassDetail: View {
    let label: String
    let value: String
    let systemImage: String
    var accent: Color = AppColors.brand

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.55))
                Text(value)
                    .font(AppTypography.caption)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

private struct DashLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

/// A subtle dotted texture (premium boarding-pass background pattern).
private struct DottedTexture: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 14
            var y: CGFloat = 6
            while y < size.height {
                var x: CGFloat = 6
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)),
                             with: .color(.white.opacity(0.5)))
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
    }
}

/// A deterministic boarding-pass barcode (decorative). Same seed → same bars.
private struct BarcodeStrip: View {
    let seed: String

    var body: some View {
        Canvas { ctx, size in
            let scalars = Array(seed.unicodeScalars.map { Int($0.value) })
            guard !scalars.isEmpty else { return }
            var x: CGFloat = 0
            var i = 0
            while x < size.width {
                let v = abs(scalars[i % scalars.count] &+ i &* 7)
                let barW = CGFloat(1 + (v % 3))
                let gapW = CGFloat(1 + ((v / 3) % 3))
                if v % 5 != 0 {
                    ctx.fill(Path(CGRect(x: x, y: 0, width: barW, height: size.height)),
                             with: .color(.white.opacity(0.85)))
                }
                x += barW + gapW
                i += 1
            }
        }
        .accessibilityHidden(true)
    }
}
