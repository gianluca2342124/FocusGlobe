import Foundation
import SwiftUI
import UIKit

// MARK: - Flight route factory

/// Builds the synthetic `Route` behind a focus flight, so the entire existing
/// session engine (timer, resume persistence, streak, missions, Passport,
/// completion rewards, RevenueCat/ads gating) keeps working unchanged — the
/// route is simply born from a chosen duration + today's sky instead of a map.
/// Distance is **symbolic** (poetic progress, not cartography), scaling
/// superlinearly with duration: 5 min ≈ 12 km, 25 ≈ 72 km, 60 ≈ 210 km.
enum FlightRouteFactory {

    /// Marker prefix that identifies open-ended (Infinity) flights.
    static let infinityIDPrefix = "flight-infinity"
    /// Infinity flights run on a 12-hour engine cap; the user lands manually.
    static let infinityMinutes = 720

    static func symbolicKm(minutes: Int) -> Double {
        let m = Double(minutes)
        return (m * 2.4 + m * m / 45).rounded()
    }

    /// Poetic in-flight speed for Infinity mode's "Distance Traveled".
    static func traveledKm(elapsedSeconds: Int) -> Double {
        Double(elapsedSeconds) / 60.0 * 3.5
    }

    static func route(minutes rawMinutes: Int, infinite: Bool,
                      origin: JourneyOrigin, sky: SkyScene) -> Route {
        let minutes = infinite ? infinityMinutes : max(1, min(rawMinutes, infinityMinutes))
        let km = infinite ? symbolicKm(minutes: 60) * 4 : symbolicKm(minutes: minutes)
        // A gentle north-east drift sized to the symbolic distance, so any
        // coordinate-based internals (interpolation, resume snapshots) stay valid.
        let deg = min(60, km / 111.0)
        let category: RouteCategory = minutes <= 30 ? .short : (minutes <= 90 ? .deep : (minutes <= 240 ? .long : .ultra))
        let id = infinite ? "\(infinityIDPrefix)-\(sky.id)" : "flight-\(minutes)m-\(sky.id)"
        return Route(
            id: id,
            name: sky.name,
            shortName: sky.name,
            originName: origin.city,
            destinationName: sky.name,
            originLatitude: origin.coordinate.latitude,
            originLongitude: origin.coordinate.longitude,
            destinationLatitude: min(84, origin.coordinate.latitude + deg * 0.55),
            destinationLongitude: origin.coordinate.longitude + deg,
            durationMinutes: minutes,
            approximateDistanceKm: km,
            category: category,
            mood: sky.mood,
            rewardName: sky.name,
            isPremium: false,
            colorTheme: sky.theme,
            ambientSoundName: "")
    }

    static func isInfinity(_ route: Route) -> Bool { route.id.hasPrefix(infinityIDPrefix) }
}

/// The set of "nice" durations the Altitude Dial snaps through, low → high,
/// with an extra terminal stop meaning **∞ (endless)**. Presets and the dial
/// both address these by index so the two controls always agree.
enum DurationScale {
    static let stops: [Int] = [1, 2, 3, 4, 5, 10, 15, 20, 25, 30, 40, 45, 50, 60,
                               75, 90, 120, 150, 180, 240, 300, 360, 480, 600, 720]
    /// Total selectable positions, including the trailing ∞.
    static var count: Int { stops.count + 1 }
    static var infinityIndex: Int { stops.count }

    static func index(forMinutes m: Int, infinite: Bool) -> Int {
        if infinite { return infinityIndex }
        var best = 0
        var bestDiff = Int.max
        for (i, s) in stops.enumerated() {
            let d = abs(s - m)
            if d < bestDiff { bestDiff = d; best = i }
        }
        return best
    }

    static func value(at index: Int) -> (minutes: Int, infinite: Bool) {
        if index >= infinityIndex { return (FlightRouteFactory.infinityMinutes, true) }
        return (stops[max(0, min(stops.count - 1, index))], false)
    }
}

// MARK: - The setup ritual (Choose time → Pack your focus → Check in → fly)

/// The pre-flight ritual, presented full-screen from Home. Three tactile beats
/// over one continuous still world — *choose your time, pack your focus, check
/// in* — and the validated boarding pass launches the flight directly. It ends
/// by calling the *exact same* `router.startJourney(origin:route:intention:)`
/// as always, so nothing downstream changes.
struct FlightSetupView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Step { case duration, pack, ticket }
    @State private var step: Step = .duration
    @State private var minutes = 25
    @State private var infinite = false
    @State private var focus: FocusPreset?

    private var sky: SkyScene { SkyScene.today() }

    var body: some View {
        ZStack {
            // The world sits still behind every step — one continuous place.
            // It only begins to move when the flight itself begins.
            SkySceneView(scene: sky, altitude: 0.03,
                         motion: reduceMotion ? .still : .ambient)
            LinearGradient(colors: [.black.opacity(0.34), .clear, .black.opacity(0.60)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 0) {
                header
                ZStack {
                    switch step {
                    case .duration:
                        DurationDialView(minutes: $minutes, infinite: $infinite) {
                            appModel.tapFeedback()
                            appModel.uiSound.play(.transition)
                            withAnimation(AppMotion.soft) { step = .pack }
                        }
                        .transition(stepTransition)
                    case .pack:
                        PackFocusView(selected: $focus) {
                            appModel.haptics.tap()
                            appModel.uiSound.play(.transition)
                            withAnimation(AppMotion.soft) { step = .ticket }
                        }
                        .transition(stepTransition)
                    case .ticket:
                        CheckInTicketView(minutes: minutes, infinite: infinite,
                                          focus: focus, sky: sky) {
                            takeOff()
                        }
                        .transition(stepTransition)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)   // the ritual is always a night-cinema moment
    }

    /// A soft, deep step change: the outgoing step sinks away as the incoming
    /// one rises into place — no hard swaps.
    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 26)).combined(with: .scale(scale: 0.99)),
            removal: .opacity.combined(with: .offset(y: -18)))
    }

    private var header: some View {
        HStack {
            AppIconButton(systemImage: step == .duration ? "xmark" : "chevron.left",
                          size: 40, tint: .white, accessibilityLabel: "Back") {
                appModel.tapFeedback()
                switch step {
                case .duration: dismiss()
                case .pack:     withAnimation(AppMotion.soft) { step = .duration }
                case .ticket:   withAnimation(AppMotion.soft) { step = .pack }
                }
            }
            Spacer()
            Text(stepTitle)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
                .id(stepTitle)
                .transition(.opacity)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.top, AppSpacing.sm)
    }

    private var stepTitle: String {
        switch step {
        case .duration: return "Choose your time"
        case .pack:     return "Pack your focus"
        case .ticket:   return "Check in"
        }
    }

    private func takeOff() {
        let route = FlightRouteFactory.route(minutes: minutes, infinite: infinite,
                                             origin: appModel.originForJourney, sky: sky)
        let intention = focus?.title
        dismiss()
        // Let the cover dismiss over the same still sky, then present the
        // full-screen flight (same pattern as the resume flow). The flight
        // opens on the same world, so the hand-off reads as one scene.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            router.startJourney(origin: appModel.originForJourney, route: route, intention: intention)
        }
    }
}

// MARK: - Step 1 · Altitude Dial

/// A refined rotary **Altitude Dial**: drag around the gauge to raise or lower
/// your flight time, from 1 minute up through 12 hours and then ∞. A huge
/// centre value, ticking haptics at every stop, quick presets and a quiet
/// symbolic distance preview.
struct DurationDialView: View {
    @Binding var minutes: Int
    @Binding var infinite: Bool
    let onContinue: () -> Void
    @EnvironmentObject private var appModel: AppModel

    @State private var index = 0
    @State private var didInit = false

    private let presets: [(label: String, minutes: Int, infinite: Bool)] = [
        ("5", 5, false), ("15", 15, false), ("25", 25, false), ("45", 45, false),
        ("60", 60, false), ("2h", 120, false), ("4h", 240, false), ("∞", 720, true)
    ]

    private var fraction: Double { Double(index) / Double(DurationScale.count - 1) }
    private var isInfinityIndex: Bool { index >= DurationScale.infinityIndex }

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer(minLength: 0)
            dial.frame(height: 310)
            distancePreview
            Spacer(minLength: 0)
            presetRow
            AppPrimaryButton(title: "Continue", systemImage: "arrow.right") {
                onContinue()
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, AppSpacing.lg)
            .clusterMaxWidth()
        }
        .onAppear {
            guard !didInit else { return }
            index = DurationScale.index(forMinutes: minutes, infinite: infinite)
            didInit = true
        }
    }

    // The gauge itself.
    private var dial: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let ringSide = side - 30
            let radius = ringSide / 2

            ZStack {
                // A soft pool of depth behind the gauge so it floats over the
                // world without a heavy panel.
                RadialGradient(colors: [.black.opacity(0.30), .clear],
                               center: .center, startRadius: 10, endRadius: side * 0.62)
                    .allowsHitTesting(false)

                // Track
                Circle().trim(from: 0, to: 0.75)
                    .stroke(Color.white.opacity(0.08),
                            style: StrokeStyle(lineWidth: 11, lineCap: .round))
                    .rotationEffect(.degrees(135))
                    .frame(width: ringSide, height: ringSide)
                // Filled arc — cream into gold, quietly luminous.
                Circle().trim(from: 0, to: 0.75 * fraction)
                    .stroke(AngularGradient(
                                gradient: Gradient(colors: [Color(hex: 0xF4EFE4),
                                                            AppColors.gold,
                                                            Color(hex: 0xE8C288)]),
                                center: .center,
                                startAngle: .degrees(135), endAngle: .degrees(405)),
                            style: StrokeStyle(lineWidth: 11, lineCap: .round))
                    .rotationEffect(.degrees(135))
                    .frame(width: ringSide, height: ringSide)
                    .shadow(color: AppColors.gold.opacity(0.35), radius: 10)
                ticks(radius: radius)
                knob(center: center, radius: radius)
                centerValue
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in updateIndex(location: v.location, center: center) })
        }
        .accessibilityElement()
        .accessibilityLabel("Flight time")
        .accessibilityValue(isInfinityIndex ? "Endless" : Formatters.durationLabel(minutes: minutes))
        .accessibilityAdjustableAction { direction in
            let next = direction == .increment ? index + 1 : index - 1
            setIndex(max(0, min(DurationScale.count - 1, next)))
        }
    }

    private func ticks(radius: CGFloat) -> some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let count = DurationScale.count
            for i in 0..<count {
                let f = Double(i) / Double(count - 1)
                let a = (135.0 + f * 270.0) * .pi / 180.0
                let outer = radius - 12
                let inner = outer - 6
                let p1 = CGPoint(x: c.x + CGFloat(cos(a)) * outer, y: c.y + CGFloat(sin(a)) * outer)
                let p2 = CGPoint(x: c.x + CGFloat(cos(a)) * inner, y: c.y + CGFloat(sin(a)) * inner)
                var path = Path()
                path.move(to: p1)
                path.addLine(to: p2)
                ctx.stroke(path, with: .color(.white.opacity(i <= index ? 0.45 : 0.12)),
                           lineWidth: 1.6)
            }
        }
    }

    private func knob(center: CGPoint, radius: CGFloat) -> some View {
        let a = (135.0 + fraction * 270.0) * .pi / 180.0
        return Circle()
            .fill(Color(hex: 0xF4EFE4))
            .frame(width: 24, height: 24)
            .overlay(Circle().strokeBorder(AppColors.gold.opacity(0.8), lineWidth: 2))
            .shadow(color: AppColors.gold.opacity(0.55), radius: 9)
            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
            .position(x: center.x + CGFloat(cos(a)) * radius,
                      y: center.y + CGFloat(sin(a)) * radius)
    }

    private var centerValue: some View {
        VStack(spacing: 3) {
            Text(centerBig)
                .font(.system(size: 78, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: centerBig)
                .minimumScaleFactor(0.45)
                .lineLimit(1)
                .shadow(color: AppColors.gold.opacity(0.25), radius: 18)
            Text(centerSub)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .tracking(3.4)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(width: 195)
    }

    private var centerBig: String {
        if isInfinityIndex { return "∞" }
        if minutes < 60 { return "\(minutes)" }
        return Formatters.durationLabel(minutes: minutes)
    }

    private var centerSub: String {
        if isInfinityIndex { return "ENDLESS" }
        if minutes < 60 { return minutes == 1 ? "MINUTE" : "MINUTES" }
        return "FLIGHT TIME"
    }

    private var distancePreview: some View {
        Text(infinite
             ? "Endless flight"
             : "Estimated flight · \(Formatters.distance(km: FlightRouteFactory.symbolicKm(minutes: minutes)))")
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.72))
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: infinite)
    }

    private var presetRow: some View {
        HStack(spacing: 6) {
            ForEach(presets, id: \.label) { p in
                let selected = (p.infinite && infinite) || (!p.infinite && !infinite && minutes == p.minutes)
                Button {
                    appModel.haptics.tap()
                    infinite = p.infinite
                    minutes = p.minutes
                    index = DurationScale.index(forMinutes: p.minutes, infinite: p.infinite)
                } label: {
                    Text(p.label)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(selected ? Color(hex: 0x14120E) : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selected ? Color(hex: 0xF4EFE4) : Color.white.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.white.opacity(selected ? 0 : 0.12), lineWidth: 1))
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityLabel(p.infinite ? "Infinity" : "\(p.minutes) minutes")
            }
        }
        .padding(.horizontal, AppSpacing.screen)
        .clusterMaxWidth()
    }

    /// Map a touch on the gauge to the nearest stop, ticking haptically on change.
    private func updateIndex(location: CGPoint, center: CGPoint) {
        let dx = Double(location.x - center.x)
        let dy = Double(location.y - center.y)
        guard dx * dx + dy * dy > 120 else { return }   // ignore the dead centre
        var deg = atan2(dy, dx) * 180 / .pi
        if deg < 0 { deg += 360 }
        var rel = deg - 135
        if rel < 0 { rel += 360 }
        let f: Double
        if rel <= 270 { f = rel / 270 }
        else if rel <= 315 { f = 1 }         // just past the top → clamp to ∞
        else { f = 0 }                        // in the bottom gap near the start
        setIndex(Int((f * Double(DurationScale.count - 1)).rounded()))
    }

    private func setIndex(_ newIndex: Int) {
        guard newIndex != index else { return }
        index = newIndex
        let v = DurationScale.value(at: newIndex)
        minutes = v.minutes
        infinite = v.infinite
        appModel.haptics.tap()
    }
}

// MARK: - Step 2 · Pack your focus (the drag ritual)

/// The focus ritual: a dark hot-air-balloon silhouette waits centre-screen and
/// the user **drags** a glowing focus token up into its basket socket. The
/// socket warms as the token nears; on the drop the burner lights, the envelope
/// ignites from within and the balloon is packed. Tap-to-pack works too, and
/// an eighth **Custom** token names any focus.
struct PackFocusView: View {
    @Binding var selected: FocusPreset?
    let onContinue: () -> Void
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.scenePhase) private var scenePhase

    @State private var dragging: FocusPreset?
    @State private var dragPoint: CGPoint = .zero
    @State private var dropFrame: CGRect = .zero
    @State private var didInteract = false
    @State private var loadedPop = false
    @State private var showCustomAlert = false
    @State private var customText = ""

    /// The custom token that replaces the old "Fly" preset in this ritual.
    private static let customTile = FocusPreset(
        title: "Custom", systemImage: "square.and.pencil", accent: Color(hex: 0xC9A86A))

    private var tokens: [FocusPreset] {
        FocusPreset.all.filter { $0.title != "Fly" } + [Self.customTile]
    }

    /// Forgiving, magnetic hit test around the basket socket — a drop never
    /// needs to be pixel-perfect.
    private func isNearTarget(_ p: CGPoint) -> Bool {
        guard dropFrame != .zero else { return false }
        let c = CGPoint(x: dropFrame.midX, y: dropFrame.midY)
        let reach = max(dropFrame.width, dropFrame.height) * 0.5 + 150
        return hypot(p.x - c.x, p.y - c.y) <= reach
    }
    private var targetHot: Bool { dragging != nil && isNearTarget(dragPoint) }

    var body: some View {
        GeometryReader { geo in
            let contentW = min(geo.size.width, Layout.pad(460, 680))
            let w = min(contentW * 0.56, geo.size.height * 0.27, Layout.pad(250, 350))
            ZStack {
                VStack(spacing: AppSpacing.sm) {
                    Spacer(minLength: 0)
                    balloon(width: w)
                    Text(caption)
                        .font(.system(size: 15, weight: .medium, design: .serif)).italic()
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.top, AppSpacing.xs)
                        .animation(.easeInOut(duration: 0.25), value: selected != nil)
                    Spacer(minLength: 0)
                    tokenTray
                    AppPrimaryButton(title: selected == nil ? "Pack a focus" : "Continue",
                                     systemImage: selected == nil ? "bag" : "arrow.right",
                                     isEnabled: selected != nil) { onContinue() }
                        .padding(.top, 2)
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.bottom, AppSpacing.lg)
                .frame(maxWidth: contentW)
                .frame(maxWidth: .infinity)

                // The token that rides the finger while dragging.
                if let d = dragging {
                    tokenCard(d, compact: true, active: true)
                        .frame(width: 86)
                        .scaleEffect(1.12)
                        .shadow(color: d.accent.opacity(0.5), radius: 14, y: 6)
                        .position(dragPoint)
                        .allowsHitTesting(false)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .coordinateSpace(name: "pack")
            .onPreferenceChange(PackDropFrameKey.self) { dropFrame = $0 }
        }
        .onAppear { dragging = nil }
        // A system-cancelled drag (backgrounding, interruption) never calls
        // onEnded — don't leave a token frozen mid-air.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                withAnimation(.easeOut(duration: 0.2)) { dragging = nil }
            }
        }
        .alert("Name your focus", isPresented: $showCustomAlert) {
            TextField("What are you working on?", text: $customText)
            Button("Pack") {
                let trimmed = customText.trimmingCharacters(in: .whitespacesAndNewlines)
                assign(FocusPreset(title: trimmed.isEmpty ? "Focus" : String(trimmed.prefix(24)),
                                   systemImage: "sparkles",
                                   accent: Color(hex: 0xC9A86A)))
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var caption: String {
        if let s = selected { return "\(s.title) is packed — ready to check in" }
        return "Drag a focus into the balloon"
    }

    // MARK: The dark silhouette that ignites

    private func balloon(width w: CGFloat) -> some View {
        let envH = w * 1.12
        let basketW = w * 0.54
        let basketH = w * 0.42
        let dropSize = basketW * 0.60
        return VStack(spacing: 0) {
            envelope(width: w, height: envH)
                .offset(y: selected != nil ? -5 : 0)
            ropes(width: basketW, height: w * 0.12)
            basket(width: basketW, height: basketH, dropSize: dropSize)
                .overlay(alignment: .top) { burnerGlow.offset(y: -w * 0.13) }
        }
    }

    private func envelope(width w: CGFloat, height h: CGFloat) -> some View {
        let lit = selected != nil
        return ZStack {
            RitualEnvelopeShape()
                .fill(LinearGradient(colors: [Color(hex: 0x2B2440), Color(hex: 0x151021)],
                                     startPoint: .top, endPoint: .bottom))
            // The inner light: cold and faint while empty, warm once packed.
            RitualEnvelopeShape()
                .fill(RadialGradient(
                    colors: [lit ? AppColors.gold.opacity(0.34) : Color.white.opacity(0.05),
                             .clear],
                    center: UnitPoint(x: 0.5, y: lit ? 0.78 : 0.30),
                    startRadius: 4, endRadius: w * 0.75))
            RitualRibsShape().stroke(.white.opacity(lit ? 0.12 : 0.06), lineWidth: 1)
            RitualEnvelopeShape().stroke(.white.opacity(lit ? 0.20 : 0.10), lineWidth: 1)
        }
        .frame(width: w, height: h)
        .shadow(color: lit ? AppColors.gold.opacity(0.25) : .black.opacity(0.45),
                radius: lit ? 30 : 24, y: lit ? 6 : 14)
        .animation(.easeInOut(duration: 0.5), value: lit)
    }

    private func ropes(width w: CGFloat, height h: CGFloat) -> some View {
        Path { p in
            let cx = w / 2
            let top = w * 0.16
            let bot = w * 0.42
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
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x33281C), Color(hex: 0x1C140D)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1))
            HStack(spacing: width / 7) {
                ForEach(0..<6, id: \.self) { _ in
                    Rectangle().fill(.white.opacity(0.05)).frame(width: 1)
                }
            }
            .padding(.vertical, 8)
            dropTarget(size: dropSize)
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.5), radius: 16, y: 9)
    }

    private func dropTarget(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous).fill(dropFill)
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
        .scaleEffect(loadedPop ? 1.10 : (targetHot ? 1.05 : 1))
        .shadow(color: dropGlow, radius: (targetHot || selected != nil) ? 20 : 0)
        .animation(.easeOut(duration: 0.16), value: targetHot)
        .background(GeometryReader { g in
            Color.clear.preference(key: PackDropFrameKey.self, value: g.frame(in: .named("pack")))
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
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(targetHot ? AppColors.gold.opacity(0.9) : .white.opacity(0.3),
                              style: StrokeStyle(lineWidth: targetHot ? 2 : 1.5, dash: [6, 5]))
        } else {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
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

    // MARK: Token tray

    private var tokenTray: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            ForEach(tokens) { preset in trayChip(preset) }
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .fill(Color.black.opacity(0.32)))
                .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1))
        )
        .overlay(alignment: .top) {
            if !didInteract && selected == nil { PackDragHint().offset(y: -34) }
        }
    }

    private func trayChip(_ preset: FocusPreset) -> some View {
        let isDragging = dragging?.id == preset.id
        let isLoaded = selected?.id == preset.id
            || (preset.id == Self.customTile.id && selected.map { p in tokens.allSatisfy { $0.id != p.id } } == true)
        return tokenCard(preset, compact: false)
            .opacity(isDragging ? 0.35 : (isLoaded ? 0.45 : 1))
            .onTapGesture { handleDrop(preset) }
            .gesture(
                DragGesture(coordinateSpace: .named("pack"))
                    .onChanged { v in
                        didInteract = true
                        if dragging?.id != preset.id {
                            dragging = preset
                            appModel.haptics.bubble()   // soft pop on grab
                        }
                        dragPoint = v.location
                    }
                    .onEnded { v in
                        // Accept near the socket OR on a meaningful upward
                        // throw — generous, so a drop succeeds every time.
                        let accepted = isNearTarget(v.location) || v.translation.height < -90
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) { dragging = nil }
                        if accepted { handleDrop(preset) }
                    }
            )
            .accessibilityLabel("Focus on \(preset.title)")
            .accessibilityAddTraits(.isButton)
    }

    private func handleDrop(_ preset: FocusPreset) {
        didInteract = true
        if preset.id == Self.customTile.id {
            customText = ""
            showCustomAlert = true
        } else {
            assign(preset)
        }
    }

    /// A premium, colour-filled focus token (`active` = the dragged copy).
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
        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
        .frame(maxWidth: compact ? nil : .infinity)
        .frame(height: Layout.pad(60, 76))
        .padding(.horizontal, compact ? 18 : 4)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(LinearGradient(colors: [preset.accent, preset.accent.opacity(0.78)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.22), .clear],
                                         startPoint: .top, endPoint: .center))
                    .blendMode(.plusLighter)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(.white.opacity(active ? 0.85 : 0.22), lineWidth: active ? 2 : 1)
        )
        .shadow(color: preset.accent.opacity(active ? 0.65 : 0.35), radius: active ? 16 : 7, y: active ? 9 : 4)
        .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

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
}

private struct PackDropFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

/// A rounded hot-air-balloon envelope (teardrop tapering to a small mouth).
private struct RitualEnvelopeShape: Shape {
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
private struct RitualRibsShape: Shape {
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

/// A soft looping finger that drags upward from the tray toward the basket —
/// shown only before the first interaction.
private struct PackDragHint: View {
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

// MARK: - Step 3 · Check in (the boarding pass)

/// A large boarding pass on warm paper, floating over the night world. The
/// user slides a finger across the **barcode** to check in: a gold scan line
/// follows the finger, the bars light behind it, and at the end the pass is
/// stamped CHECKED IN — a firm haptic, a dry click, then the ticket lifts away
/// and the flight begins. No tear-strips, no gimmicks.
struct CheckInTicketView: View {
    let minutes: Int
    let infinite: Bool
    let focus: FocusPreset?
    let sky: SkyScene
    let onValidated: () -> Void
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    @State private var scan: CGFloat = 0          // 0…1 across the barcode
    @State private var checked = false
    @State private var stampIn = false
    @State private var flyAway = false
    @State private var started = false
    @State private var lastTick: CGFloat = 0
    /// The scheduled check-in beats, cancellable so backing out of this step
    /// mid-validation can never launch a flight behind the user's back.
    @State private var pendingBeats: [DispatchWorkItem] = []

    private let paper = Color(hex: 0xF5EBD8)
    private let ink = Color(hex: 0x2A2119)
    private let inkSoft = Color(hex: 0x77685A)

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer(minLength: 0)
            ZStack {
                ticket
                    .opacity(flyAway ? 0 : 1)
                    .offset(y: flyAway ? -70 : 0)
                    .scaleEffect(flyAway ? 1.04 : 1)
                if started {
                    Text("Focus started")
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 10, y: 2)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            hint
            Spacer(minLength: 0)
        }
        .padding(.bottom, AppSpacing.lg)
        .onDisappear {
            pendingBeats.forEach { $0.cancel() }
            pendingBeats.removeAll()
        }
    }

    @ViewBuilder private var hint: some View {
        if !checked {
            VStack(spacing: AppSpacing.sm) {
                Label("Slide across the barcode to check in", systemImage: "hand.draw")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                if reduceMotion || voiceOver {
                    AppPrimaryButton(title: "Check in", systemImage: "checkmark.seal") { validate() }
                        .padding(.horizontal, AppSpacing.screen)
                        .clusterMaxWidth()
                }
            }
            .transition(.opacity)
        } else {
            Text("Ready to fly")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.gold)
                .transition(.opacity)
        }
    }

    // MARK: The pass

    private var ticket: some View {
        VStack(alignment: .leading, spacing: 0) {
            ticketHeader
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.lg)
            ticketBody
                .padding(.horizontal, AppSpacing.lg)
            Spacer(minLength: AppSpacing.sm)
            perforation
            barcodeZone
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.md)
        }
        .frame(maxWidth: 480)
        .frame(height: 430)
        .background(
            TicketShape(cornerRadius: 24, notchRadius: 10, notchFromBottom: 118)
                .fill(paper, style: FillStyle(eoFill: true))
                .overlay(
                    PaperGrain(intensity: 0.8)
                        .environment(\.colorScheme, .light)   // dark grain on cream
                        .clipShape(TicketShape(cornerRadius: 24, notchRadius: 10, notchFromBottom: 118))
                )
                .shadow(color: .black.opacity(0.45), radius: 26, y: 16)
        )
        .overlay(stamp)
        .padding(.horizontal, AppSpacing.screen)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Boarding pass. Focus flight to \(sky.name), \(durationBig). \(checked ? "Checked in." : "Not checked in.")")
    }

    private var ticketHeader: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center) {
                Text("FOCUSGLOBE")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(ink)
                Spacer()
                MiniBalloonView(size: 34, envelope: AppColors.terracotta, showGlow: false)
            }
            Text("BOARDING PASS")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(3.4)
                .foregroundStyle(inkSoft)
            Rectangle().fill(ink.opacity(0.14)).frame(height: 1)
                .padding(.top, 3)
        }
    }

    private var ticketBody: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    fieldLabel("DURATION")
                    Text(durationBig)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(ink)
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    fieldLabel("SKY")
                    Text(sky.name)
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(.top, AppSpacing.sm)

            HStack(alignment: .top, spacing: AppSpacing.md) {
                field("DATE", dateText)
                field("FOCUS", focus?.title ?? "Focus")
                field("FLIGHT ID", flightID)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(checked ? Color(hex: 0x3F9C7C) : inkSoft.opacity(0.5))
                    .frame(width: 7, height: 7)
                Text(checked ? "READY TO FLY" : "AWAITING CHECK-IN")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(checked ? Color(hex: 0x3F9C7C) : inkSoft)
            }
        }
    }

    private var perforation: some View {
        HStack(spacing: 6) {
            ForEach(0..<26, id: \.self) { _ in
                Rectangle().fill(ink.opacity(0.22)).frame(height: 1.4)
            }
        }
        .frame(height: 1.4)
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: Barcode + scan interaction

    private var barcodeZone: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                TicketBars(seed: barcodeSeed, color: ink, highlight: scan,
                           accent: AppColors.terracotta)
                    .frame(height: 62)
                // The scan line riding the finger.
                if scan > 0.005 && !checked {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(AppColors.gold)
                        .frame(width: 3, height: 74)
                        .shadow(color: AppColors.gold.opacity(0.8), radius: 7)
                        .position(x: scan * w, y: 31)
                }
            }
            .frame(width: w, height: 62)
            .contentShape(Rectangle().inset(by: -14))
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { v in
                        guard !checked else { return }
                        let f = min(1, max(0, v.location.x / max(1, w)))
                        scan = max(scan, f)   // the scan only advances
                        tickIfNeeded(f)
                        if scan >= 0.985 { validate() }
                    }
                    .onEnded { _ in
                        guard !checked else { return }
                        if scan >= 0.88 {
                            validate()
                        } else {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { scan = 0 }
                            lastTick = 0
                        }
                    }
            )
        }
        .frame(height: 62)
        .accessibilityElement()
        .accessibilityLabel("Barcode. Slide across to check in.")
        .accessibilityAction { validate() }
    }

    /// Light haptic clicks as the scan line sweeps the bars.
    private func tickIfNeeded(_ f: CGFloat) {
        for threshold in stride(from: CGFloat(0.2), through: 0.8, by: 0.2)
        where lastTick < threshold && f >= threshold {
            appModel.haptics.tap()
            lastTick = threshold
        }
    }

    @ViewBuilder private var stamp: some View {
        if stampIn {
            InkStamp(text: "Checked in", color: AppColors.terracotta, rotation: -8)
                .scaleEffect(1.35)
                .offset(x: 70, y: 26)
                .transition(.scale(scale: 1.9).combined(with: .opacity))
        }
    }

    // MARK: Validation → flight

    private func validate() {
        guard !checked else { return }
        checked = true
        scan = 1
        appModel.haptics.takeoff()
        appModel.uiSound.play(.ticketTear)          // the dry scan click
        withAnimation(AppMotion.sealImpact.respecting(reduceMotion)) { stampIn = true }
        let beat = reduceMotion ? 0.25 : 0.75
        let lift = DispatchWorkItem {
            appModel.uiSound.play(.confirm)
            withAnimation(.easeIn(duration: reduceMotion ? 0.1 : 0.45)) {
                flyAway = true
                started = true
            }
        }
        let launch = DispatchWorkItem { onValidated() }
        pendingBeats = [lift, launch]
        DispatchQueue.main.asyncAfter(deadline: .now() + beat, execute: lift)
        DispatchQueue.main.asyncAfter(deadline: .now() + beat + (reduceMotion ? 0.25 : 0.75),
                                      execute: launch)
    }

    // MARK: Pass content

    private var durationBig: String {
        if infinite { return "∞" }
        if minutes < 60 { return "\(minutes) MIN" }
        return Formatters.durationLabel(minutes: minutes).uppercased()
    }

    private var dateText: String { Date().formatted(date: .abbreviated, time: .omitted) }

    private var flightID: String {
        var h = 7
        for u in ("\(minutes)" + (focus?.title ?? "") + sky.id).unicodeScalars {
            h = (h &* 31 &+ Int(u.value)) & 0x7fffffff
        }
        let n = h % 900 + 100
        let base = infinite ? "INF" : String(format: "%03d", min(minutes, 999))
        return "FG\(base)·\(n)"
    }

    private var barcodeSeed: String { "\(minutes)-\(focus?.title ?? "focus")-\(sky.id)" }

    private func fieldLabel(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .tracking(1.4)
            .foregroundStyle(inkSoft)
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            fieldLabel(label)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The boarding-pass silhouette: a rounded card with two side notches punched
/// at the perforation line, like a real pass. Fill with `FillStyle(eoFill:)`.
struct TicketShape: Shape {
    var cornerRadius: CGFloat = 24
    var notchRadius: CGFloat = 10
    /// Distance of the notch centres from the bottom edge.
    var notchFromBottom: CGFloat = 118

    func path(in rect: CGRect) -> Path {
        var p = Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)
        let y = rect.maxY - notchFromBottom
        p.addEllipse(in: CGRect(x: rect.minX - notchRadius, y: y - notchRadius,
                                width: notchRadius * 2, height: notchRadius * 2))
        p.addEllipse(in: CGRect(x: rect.maxX - notchRadius, y: y - notchRadius,
                                width: notchRadius * 2, height: notchRadius * 2))
        return p
    }
}

/// Deterministic barcode bars (decoration, accessibility-hidden). Bars behind
/// the scan `highlight` fraction render in the warm accent — the pass visibly
/// reacts as the finger sweeps it.
struct TicketBars: View {
    let seed: String
    var color: Color = .white
    var highlight: CGFloat = 0
    var accent: Color = AppColors.terracotta

    var body: some View {
        Canvas { ctx, size in
            let scalars = Array(seed.unicodeScalars.map { Int($0.value) })
            guard !scalars.isEmpty else { return }
            let cut = highlight * size.width
            var x: CGFloat = 0
            var i = 0
            while x < size.width {
                let v = abs(scalars[i % scalars.count] &+ i &* 7)
                let barW = CGFloat(1 + (v % 3))
                if v % 4 != 0 {
                    let scanned = x <= cut
                    ctx.fill(Path(CGRect(x: x, y: 0, width: barW, height: size.height)),
                             with: .color(scanned ? accent.opacity(0.95) : color.opacity(0.82)))
                }
                x += barW + CGFloat(1 + ((v / 3) % 3))
                i += 1
            }
        }
        .accessibilityHidden(true)
    }
}
