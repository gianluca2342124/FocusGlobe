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

// MARK: - The setup flow (Duration → Check-In → Rope Cut → fly)

/// The pre-flight ritual, presented full-screen from Home. Three quick steps —
/// never annoying on daily use — that end by calling the *exact same*
/// `router.startJourney(origin:route:intention:)` as before.
struct FlightSetupView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    private enum Step { case duration, checkIn, rope }
    @State private var step: Step = .duration
    @State private var minutes = 25
    @State private var infinite = false
    @State private var focus: FocusPreset?

    private var sky: SkyScene { SkyScene.today() }

    var body: some View {
        ZStack {
            SkySceneView(scene: sky, progress: 0.04)
            LinearGradient(colors: [.black.opacity(0.35), .clear, .black.opacity(0.6)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 0) {
                header
                switch step {
                case .duration:
                    DurationPickerView(minutes: $minutes, infinite: $infinite) {
                        appModel.tapFeedback()
                        withAnimation(AppMotion.soft) { step = .checkIn }
                    }
                case .checkIn:
                    FocusCheckInView(minutes: minutes, infinite: infinite, selected: $focus) {
                        appModel.haptics.tap()
                        appModel.uiSound.play(.transition)
                        withAnimation(AppMotion.soft) { step = .rope }
                    }
                case .rope:
                    RopeCutView(sky: sky) { takeOff() }
                }
            }
        }
        .preferredColorScheme(.dark)   // the ritual is always a night-cinema moment
        .interactiveDismissDisabled(step == .rope)
    }

    private var header: some View {
        HStack {
            AppIconButton(systemImage: step == .duration ? "xmark" : "chevron.left",
                          size: 40, tint: .white, accessibilityLabel: "Back") {
                appModel.tapFeedback()
                switch step {
                case .duration: dismiss()
                case .checkIn:  withAnimation(AppMotion.soft) { step = .duration }
                case .rope:     withAnimation(AppMotion.soft) { step = .checkIn }
                }
            }
            Spacer()
            Text(stepTitle)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, AppSpacing.screen)
        .padding(.top, AppSpacing.sm)
    }

    private var stepTitle: String {
        switch step {
        case .duration: return "How long will you fly?"
        case .checkIn:  return "Focus Check-In"
        case .rope:     return "Take Off"
        }
    }

    private func takeOff() {
        let route = FlightRouteFactory.route(minutes: minutes, infinite: infinite,
                                             origin: appModel.originForJourney, sky: sky)
        let intention = focus?.title
        dismiss()
        // Let the cover dismiss, then present the full-screen flight (same
        // pattern as the resume flow).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            router.startJourney(origin: appModel.originForJourney, route: route, intention: intention)
        }
    }
}

// MARK: - Step 1 · Duration

struct DurationPickerView: View {
    @Binding var minutes: Int
    @Binding var infinite: Bool
    let onContinue: () -> Void
    @EnvironmentObject private var appModel: AppModel

    private let presets = [5, 15, 25, 45, 60]

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            BalloonView(height: 110, showBurner: true, showGlow: true)
            Spacer()

            VStack(spacing: AppSpacing.sm) {
                // Presets + ∞
                HStack(spacing: AppSpacing.xs) {
                    ForEach(presets, id: \.self) { m in
                        durationChip("\(m)", subtitle: "min", selected: !infinite && minutes == m) {
                            appModel.haptics.tap()
                            infinite = false
                            minutes = m
                        }
                    }
                    durationChip("∞", subtitle: "", selected: infinite) {
                        appModel.haptics.tap()
                        infinite = true
                    }
                }

                // Custom duration — 1 minute up.
                if !infinite {
                    HStack(spacing: AppSpacing.sm) {
                        Text("Custom")
                            .font(AppTypography.caption).foregroundStyle(.white.opacity(0.7))
                        Slider(value: Binding(
                            get: { Double(minutes) },
                            set: { minutes = max(1, Int($0.rounded())) }
                        ), in: 1...180, step: 1)
                        .tint(.white)
                        Text(Formatters.durationLabel(minutes: minutes))
                            .font(AppTypography.timerPill).foregroundStyle(.white)
                            .frame(width: 76, alignment: .trailing)
                    }
                    .padding(.horizontal, 4)
                } else {
                    Text("Fly until you choose to land — time and distance count up.")
                        .font(AppTypography.caption).foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

                #if FOCUS_SHIELD_ENABLED
                // "Leave them on the ground": pick apps to block for this flight.
                // The shield applies on session start and lifts on landing/cancel
                // (already wired in FocusSessionViewModel); fully optional.
                FocusShieldBoardingRow(service: appModel.focusShield,
                                       ink: .white, inkSoft: .white.opacity(0.6))
                #endif

                AppPrimaryButton(title: "Continue", systemImage: "arrow.right") { onContinue() }
                    .padding(.top, 2)
            }
            .padding(AppSpacing.md)
            .glassBackground(cornerRadius: 24, tintOpacity: 0.2, shadowRadius: 16, shadowY: 8)
            .padding(.horizontal, AppSpacing.screen)
            .padding(.bottom, AppSpacing.xl)
            .clusterMaxWidth()
        }
    }

    private func durationChip(_ value: String, subtitle: String, selected: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(value).font(.system(size: 19, weight: .bold, design: .rounded))
                if !subtitle.isEmpty {
                    Text(subtitle).font(.system(size: 10, weight: .medium, design: .rounded)).opacity(0.7)
                }
            }
            .foregroundStyle(selected ? Color(hex: 0x14120E) : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? Color(hex: 0xF4EFE4) : Color.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(selected ? 0 : 0.14), lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel(value == "∞" ? "Infinity" : "\(value) minutes")
    }
}

// MARK: - Step 2 · Focus Check-In (ticket + pack the basket)

struct FocusCheckInView: View {
    let minutes: Int
    let infinite: Bool
    @Binding var selected: FocusPreset?
    let onContinue: () -> Void
    @EnvironmentObject private var appModel: AppModel
    @State private var packed = false

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer(minLength: AppSpacing.sm)

            ticket

            Text("What are you focusing on?")
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(.white)

            // Focus grid — tapping packs the focus into the basket (a reliable
            // tap-to-load ritual; the tag animates onto the ticket).
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: AppSpacing.xs)],
                      spacing: AppSpacing.xs) {
                ForEach(FocusPreset.all) { preset in
                    focusChip(preset)
                }
            }
            .padding(.horizontal, AppSpacing.screen)

            Spacer()

            AppPrimaryButton(title: packed ? "Continue" : "Pick a focus",
                             systemImage: packed ? "arrow.right" : "bag",
                             isEnabled: packed) { onContinue() }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.bottom, AppSpacing.xl)
                .clusterMaxWidth()
        }
    }

    private var ticket: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text("FOCUS CHECK-IN")
                    .font(.system(size: 11, weight: .heavy, design: .rounded)).tracking(2)
                    .foregroundStyle(AppColors.gold)
                Spacer()
                Text("Today's flight")
                    .font(AppTypography.caption).foregroundStyle(.white.opacity(0.6))
            }
            HStack(spacing: AppSpacing.md) {
                ticketField("Duration", infinite ? "∞" : Formatters.durationLabel(minutes: minutes))
                ticketField("Focus", selected?.title ?? "—")
            }
            // Barcode-like element — deterministic bars from the flight setup.
            TicketBars(seed: "\(minutes)-\(selected?.title ?? "x")")
                .frame(height: 30)
                .padding(.top, 2)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .padding(.horizontal, AppSpacing.screen)
        .clusterMaxWidth()
    }

    private func ticketField(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .rounded)).tracking(0.6)
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func focusChip(_ preset: FocusPreset) -> some View {
        let isSelected = selected?.id == preset.id
        return Button {
            appModel.haptics.tap()
            appModel.uiSound.play(.transition)
            withAnimation(AppMotion.settling) {
                selected = preset
                packed = true
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: preset.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? Color(hex: 0x14120E) : preset.accent)
                Text(preset.title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? Color(hex: 0x14120E) : .white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 74)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color(hex: 0xF4EFE4) : Color.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(isSelected ? 0 : 0.12), lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle(scale: 0.96))
        .accessibilityLabel("Focus on \(preset.title)")
    }
}

/// Deterministic barcode-style bars (pure decoration, accessibility-hidden).
struct TicketBars: View {
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
                if v % 4 != 0 {
                    ctx.fill(Path(CGRect(x: x, y: 0, width: barW, height: size.height)),
                             with: .color(.white.opacity(0.75)))
                }
                x += barW + CGFloat(1 + ((v / 3) % 3))
                i += 1
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Step 3 · Rope Cut

/// The balloon is tethered by a living rope; swipe across it to cut. On cut:
/// snap sound, heavy haptic, rope splits, the balloon jolts upward and the
/// flight begins. Reduce Motion / VoiceOver get a "Take Off" tap fallback.
struct RopeCutView: View {
    let sky: SkyScene
    let onCut: () -> Void
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    @State private var cut = false
    @State private var balloonLift: CGFloat = 0
    @State private var ropeSway: CGFloat = 0
    @State private var fingerX: CGFloat?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                // Balloon, hovering gently while tethered.
                BalloonView(height: 150, showBurner: true, showGlow: true)
                    .position(x: w / 2, y: h * 0.34 - balloonLift)

                // The rope: a soft curve from the basket to a ground anchor.
                if !cut {
                    RopeShape(sway: ropeSway)
                        .stroke(Color(hex: 0xC9B08A), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 8, height: h * 0.3)
                        .position(x: w / 2 + ropeSway * 6, y: h * 0.34 + 75 + h * 0.15)
                    // Ground anchor stake.
                    Capsule().fill(Color(hex: 0x8A7050))
                        .frame(width: 22, height: 8)
                        .position(x: w / 2, y: h * 0.34 + 75 + h * 0.3)
                }

                VStack {
                    Spacer()
                    if !cut {
                        Text("Cut the rope to begin")
                            .font(.system(size: 17, weight: .medium, design: .serif)).italic()
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.bottom, 6)
                        if reduceMotion || voiceOver {
                            AppPrimaryButton(title: "Take Off", systemImage: "scissors") { performCut() }
                                .padding(.horizontal, AppSpacing.screen)
                                .clusterMaxWidth()
                        }
                    } else {
                        Text("Focus started")
                            .font(.system(size: 19, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                            .transition(.opacity)
                    }
                    Spacer().frame(height: AppSpacing.xxl)
                }
            }
            .contentShape(Rectangle())
            .gesture(cutGesture(width: w, height: h))
            .onAppear { startSway() }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Cut the rope to begin")
            .accessibilityAction { performCut() }
        }
    }

    /// A horizontal swipe crossing the rope's vertical band cuts it.
    private func cutGesture(width: CGFloat, height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { v in
                guard !cut else { return }
                // Rope tenses toward the finger as it nears.
                let ropeBandY = (height * 0.49)...(height * 0.72)
                if ropeBandY.contains(v.location.y) {
                    let dx = v.location.x - width / 2
                    withAnimation(.easeOut(duration: 0.1)) { ropeSway = max(-1, min(1, dx / 60)) }
                    if fingerX == nil { fingerX = v.startLocation.x }
                    // Crossed the rope's centre line with a real horizontal swipe → cut.
                    if let startX = fingerX,
                       (startX - width / 2) * (v.location.x - width / 2) < 0,
                       abs(v.translation.width) > 34 {
                        performCut()
                    }
                }
            }
            .onEnded { _ in
                fingerX = nil
                guard !cut else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) { ropeSway = 0 }
            }
    }

    private func performCut() {
        guard !cut else { return }
        appModel.haptics.takeoff()
        appModel.uiSound.play(.ticketTear)   // soft snap
        withAnimation(AppMotion.ropeSnap.respecting(reduceMotion)) {
            cut = true
            balloonLift = 60
        }
        withAnimation(.easeIn(duration: 0.8).delay(0.15)) { balloonLift = 400 }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.2 : 0.8)) { onCut() }
    }

    private func startSway() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { ropeSway = 0.35 }
    }
}

/// The tether rope — a gentle S-curve that leans with `sway`.
struct RopeShape: Shape {
    var sway: CGFloat
    var animatableData: CGFloat {
        get { sway }
        set { sway = newValue }
    }
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                   control1: CGPoint(x: rect.midX + sway * 26, y: rect.height * 0.35),
                   control2: CGPoint(x: rect.midX - sway * 18, y: rect.height * 0.7))
        return p
    }
}
