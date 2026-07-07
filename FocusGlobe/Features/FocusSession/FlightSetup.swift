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

// MARK: - The setup flow (Choose time → Pack focus → Ticket → Rope → fly)

/// The pre-flight ritual, presented full-screen from Home. Four tactile beats —
/// *choose your time, pack your focus, cut the ticket, cut the rope* — that end
/// by calling the *exact same* `router.startJourney(origin:route:intention:)`
/// as before, so nothing downstream changes.
struct FlightSetupView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    private enum Step { case duration, pack, ticket, rope }
    @State private var step: Step = .duration
    @State private var minutes = 25
    @State private var infinite = false
    @State private var focus: FocusPreset?

    private var sky: SkyScene { SkyScene.today() }

    var body: some View {
        ZStack {
            // The living world sits behind every step, so the whole ritual is
            // one continuous place — not a stack of unrelated cards.
            SkySceneView(scene: sky, progress: 0.05)
            LinearGradient(colors: [.black.opacity(0.34), .clear, .black.opacity(0.62)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 0) {
                header
                switch step {
                case .duration:
                    DurationDialView(minutes: $minutes, infinite: $infinite) {
                        appModel.tapFeedback()
                        withAnimation(AppMotion.soft) { step = .pack }
                    }
                case .pack:
                    PackFocusView(minutes: minutes, infinite: infinite, selected: $focus) {
                        appModel.haptics.tap()
                        appModel.uiSound.play(.transition)
                        withAnimation(AppMotion.soft) { step = .ticket }
                    }
                case .ticket:
                    BoardingTicketView(minutes: minutes, infinite: infinite, focus: focus, sky: sky) {
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
                case .pack:     withAnimation(AppMotion.soft) { step = .duration }
                case .ticket:   withAnimation(AppMotion.soft) { step = .pack }
                case .rope:     withAnimation(AppMotion.soft) { step = .ticket }
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
        case .duration: return "Choose your time"
        case .pack:     return "Pack your focus"
        case .ticket:   return "Your boarding ticket"
        case .rope:     return "Cut the rope"
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

// MARK: - Step 1 · Altitude Dial

/// A premium rotary **Altitude Dial**: drag around the gauge to raise or lower
/// your flight time, from 1 minute up through 12 hours and then ∞. A huge centre
/// value, ticking haptics at every stop, quick presets and a live distance
/// preview. No slider anywhere in sight.
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
            dial.frame(height: 300)
            distancePreview
            Spacer(minLength: 0)
            presetRow
            AppPrimaryButton(title: "Continue", systemImage: "arrow.right") {
                appModel.tapFeedback()
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
            let ringSide = side - 28
            let radius = ringSide / 2

            ZStack {
                // Track
                Circle().trim(from: 0, to: 0.75)
                    .stroke(Color.white.opacity(0.10),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(135))
                    .frame(width: ringSide, height: ringSide)
                // Filled progress
                Circle().trim(from: 0, to: 0.75 * fraction)
                    .stroke(AngularGradient(colors: [AppColors.gold, AppColors.brand, AppColors.gold],
                                            center: .center),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(135))
                    .frame(width: ringSide, height: ringSide)
                // Tick marks
                ticks(radius: radius, center: center)
                // The altitude "bug" (knob)
                knob(center: center, radius: radius)
                // Huge centre value
                centerValue
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in updateIndex(location: v.location, center: center) })
        }
    }

    private func ticks(radius: CGFloat, center: CGPoint) -> some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let count = DurationScale.count
            for i in 0..<count {
                let f = Double(i) / Double(count - 1)
                let a = (135.0 + f * 270.0) * .pi / 180.0
                let outer = radius + 3
                let inner = radius - 8
                let p1 = CGPoint(x: c.x + CGFloat(cos(a)) * outer, y: c.y + CGFloat(sin(a)) * outer)
                let p2 = CGPoint(x: c.x + CGFloat(cos(a)) * inner, y: c.y + CGFloat(sin(a)) * inner)
                var path = Path()
                path.move(to: p1)
                path.addLine(to: p2)
                ctx.stroke(path, with: .color(.white.opacity(i <= index ? 0.55 : 0.16)), lineWidth: 2)
            }
        }
    }

    private func knob(center: CGPoint, radius: CGFloat) -> some View {
        let a = (135.0 + fraction * 270.0) * .pi / 180.0
        return Circle()
            .fill(Color(hex: 0xF4EFE4))
            .frame(width: 22, height: 22)
            .overlay(Circle().strokeBorder(AppColors.gold.opacity(0.7), lineWidth: 2))
            .shadow(color: .black.opacity(0.4), radius: 5, y: 2)
            .position(x: center.x + CGFloat(cos(a)) * radius,
                      y: center.y + CGFloat(sin(a)) * radius)
    }

    private var centerValue: some View {
        VStack(spacing: 2) {
            Text(centerBig)
                .font(.system(size: 76, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(centerSub)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(width: 190)
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
             ? "Endless flight · time & distance count up"
             : "Estimated flight · \(Formatters.distance(km: FlightRouteFactory.symbolicKm(minutes: minutes)))")
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.75))
            .contentTransition(.opacity)
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
                        .frame(height: 44)
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
        let newIndex = Int((f * Double(DurationScale.count - 1)).rounded())
        guard newIndex != index else { return }
        index = newIndex
        let v = DurationScale.value(at: newIndex)
        minutes = v.minutes
        infinite = v.infinite
        appModel.haptics.tap()
    }
}

// MARK: - Step 2 · Pack your focus

/// Choose an intention **before** boarding and watch it pack into the balloon's
/// basket. A calm, tap-to-load ritual — the packed focus rides with you.
struct PackFocusView: View {
    let minutes: Int
    let infinite: Bool
    @Binding var selected: FocusPreset?
    let onContinue: () -> Void
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer(minLength: 0)

            // The balloon; the chosen focus nestles into the basket.
            ZStack {
                MiniBalloonView(size: 168, showGlow: true)
                if let f = selected {
                    HStack(spacing: 5) {
                        Image(systemName: f.systemImage)
                            .font(.system(size: 13, weight: .bold))
                        Text(f.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color(hex: 0x2A2119))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(hex: 0xF4EFE4)))
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                    .offset(y: 80)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .frame(height: 210)

            Text(selected == nil ? "Tap a focus to pack it into your basket" : "Packed and ready to board")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: AppSpacing.xs)],
                      spacing: AppSpacing.xs) {
                ForEach(FocusPreset.all) { preset in
                    focusChip(preset)
                }
            }
            .padding(.horizontal, AppSpacing.screen)

            Spacer(minLength: 0)

            AppPrimaryButton(title: selected == nil ? "Pick a focus" : "Continue",
                             systemImage: selected == nil ? "bag" : "arrow.right",
                             isEnabled: selected != nil) { onContinue() }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.bottom, AppSpacing.lg)
                .clusterMaxWidth()
        }
    }

    private func focusChip(_ preset: FocusPreset) -> some View {
        let isSelected = selected?.id == preset.id
        return Button {
            appModel.haptics.tap()
            appModel.uiSound.play(.transition)
            withAnimation(AppMotion.settling) { selected = preset }
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

// MARK: - Step 3 · Boarding ticket

/// A large, real-looking boarding ticket printed on warm paper, floating over
/// the night sky. Drag the stub to **tear** it and board — a firm haptic + a
/// dry snap. Reduce Motion / VoiceOver get a "Board this flight" button.
struct BoardingTicketView: View {
    let minutes: Int
    let infinite: Bool
    let focus: FocusPreset?
    let sky: SkyScene
    let onTear: () -> Void
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    @State private var tearX: CGFloat = 0
    @State private var torn = false

    private let paper = Color(hex: 0xF3E9D6)
    private let ink = Color(hex: 0x2A2119)
    private let inkSoft = Color(hex: 0x746657)

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer(minLength: 0)
            ticket
            VStack(spacing: AppSpacing.sm) {
                Text(torn ? "Boarding…" : "Tear the stub to board")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                if reduceMotion || voiceOver {
                    AppPrimaryButton(title: "Board this flight", systemImage: "ticket") { tearOff() }
                        .padding(.horizontal, AppSpacing.screen)
                        .clusterMaxWidth()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, AppSpacing.lg)
    }

    private var ticket: some View {
        GeometryReader { geo in
            let fullW = min(geo.size.width, 440)
            let stubW: CGFloat = 96
            ZStack(alignment: .leading) {
                // Body stays put.
                ticketCard(fullW: fullW, stubW: stubW)
                    .mask(alignment: .leading) { Rectangle().frame(width: fullW - stubW) }
                // Stub tears away to the right.
                ticketCard(fullW: fullW, stubW: stubW)
                    .mask(alignment: .trailing) { Rectangle().frame(width: stubW) }
                    .offset(x: tearX)
                    .rotationEffect(.degrees(Double(tearX) * 0.02), anchor: .bottomLeading)
                    .opacity(torn ? 0 : 1)
                // Perforation seam.
                perforation(height: geo.size.height)
                    .offset(x: fullW - stubW - 1)
            }
            .frame(width: fullW, height: geo.size.height)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(tearGesture)
        }
        .frame(height: 300)
        .padding(.horizontal, AppSpacing.screen)
        .clusterMaxWidth()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Boarding ticket. Focus flight to \(sky.name), \(bigDuration).")
        .accessibilityAction(named: "Board this flight") { tearOff() }
    }

    private func ticketCard(fullW: CGFloat, stubW: CGFloat) -> some View {
        HStack(spacing: 0) {
            mainContent.frame(width: fullW - stubW)
            stubContent.frame(width: stubW)
        }
        .frame(width: fullW, height: 300)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(paper))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(ink.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 18, y: 12)
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("FOCUSGLOBE")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(ink)
                Spacer()
                MiniBalloonView(size: 30, envelope: AppColors.terracotta, showGlow: false)
            }
            Text("FOCUS FLIGHT")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(3)
                .foregroundStyle(inkSoft)
            Rectangle().fill(ink.opacity(0.14)).frame(height: 1)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DURATION").font(microLabel).tracking(1.4).foregroundStyle(inkSoft)
                    Text(bigDuration)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("SKY").font(microLabel).tracking(1.4).foregroundStyle(inkSoft)
                    Text(sky.name)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            HStack(alignment: .top, spacing: AppSpacing.md) {
                field("DATE", dateText)
                field("FOCUS", focus?.title ?? "Focus")
                field("FLIGHT ID", flightID)
            }

            Spacer(minLength: 0)

            TicketBars(seed: barcodeSeed, color: ink)
                .frame(height: 36)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stubContent: some View {
        VStack(spacing: 8) {
            Text("BOARD")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundStyle(inkSoft)
            Spacer(minLength: 0)
            // A little wax stamp — the sky's initials, echoing the expedition seal.
            ZStack {
                Circle().fill(AppColors.terracotta)
                Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1).padding(3)
                Text(skyInitials)
                    .font(.system(size: 14, weight: .heavy, design: .serif))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            Text("SKY PASS")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(inkSoft)
            Spacer(minLength: 0)
            TicketBars(seed: "stub-\(flightID)", color: ink)
                .frame(height: 22)
                .padding(.horizontal, 4)
        }
        .padding(.vertical, AppSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ink.opacity(0.03))
    }

    private func perforation(height: CGFloat) -> some View {
        VStack(spacing: 5) {
            ForEach(0..<max(1, Int(height / 9)), id: \.self) { _ in
                Circle().fill(ink.opacity(0.30)).frame(width: 2.5, height: 2.5)
            }
        }
        .frame(height: height)
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(microLabel).tracking(1).foregroundStyle(inkSoft)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var microLabel: Font { .system(size: 9, weight: .semibold, design: .monospaced) }

    // MARK: Ticket content

    private var bigDuration: String {
        if infinite { return "∞" }
        if minutes < 60 { return "\(minutes) MIN" }
        return Formatters.durationLabel(minutes: minutes).uppercased()
    }

    private var dateText: String { Date().formatted(date: .abbreviated, time: .omitted) }

    private var skyInitials: String {
        let letters = sky.name.split(separator: " ").compactMap { $0.first }
        let s = String(letters).uppercased()
        return s.isEmpty ? "SK" : String(s.prefix(2))
    }

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

    // MARK: Tear interaction

    private var tearGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { v in
                guard !torn else { return }
                tearX = max(0, v.translation.width)
            }
            .onEnded { v in
                guard !torn else { return }
                if v.translation.width > 96 {
                    tearOff()
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { tearX = 0 }
                }
            }
    }

    private func tearOff() {
        guard !torn else { return }
        appModel.haptics.takeoff()
        appModel.uiSound.play(.ticketTear)
        withAnimation(.easeIn(duration: 0.42)) {
            tearX = 480
            torn = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.12 : 0.46)) { onTear() }
    }
}

/// Deterministic barcode-style bars (pure decoration, accessibility-hidden).
struct TicketBars: View {
    let seed: String
    var color: Color = .white
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
                             with: .color(color.opacity(0.8)))
                }
                x += barW + CGFloat(1 + ((v / 3) % 3))
                i += 1
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Step 4 · Rope Cut (grounded)

/// The balloon is tethered by a slack rope to a stake planted in the ground of
/// this very world. Swipe across the rope to cut it: a firm haptic, a dry snap,
/// the rope falls and the balloon climbs away as the flight begins. Reduce
/// Motion / VoiceOver get a "Take Off" tap fallback.
struct RopeCutView: View {
    let sky: SkyScene
    let onCut: () -> Void
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    @State private var cut = false
    @State private var balloonLift: CGFloat = 0
    @State private var slack: CGFloat = 30
    @State private var sway: CGFloat = 0
    @State private var ropeGone = false
    @State private var fingerStartX: CGFloat?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let balloonSize = min(150, h * 0.22)
            let balloonY = h * 0.32 - balloonLift
            let basket = CGPoint(x: w / 2, y: balloonY + balloonSize * 0.46)
            let groundY = h * 0.80
            let stake = CGPoint(x: w / 2, y: groundY)

            ZStack {
                ground(width: w, height: h, groundY: groundY)

                if !ropeGone {
                    GroundedRopeShape(top: basket, bottom: stake, sag: slack, sway: sway)
                        .stroke(Color(hex: 0xC9A87A),
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .opacity(cut ? 0 : 1)
                }

                stakeView.position(x: stake.x, y: stake.y)

                MiniBalloonView(size: balloonSize, showGlow: true)
                    .rotationEffect(.degrees(Double(sway) * 3))
                    .position(x: w / 2, y: balloonY)

                caption(height: h)
            }
            .contentShape(Rectangle())
            .gesture(cutGesture(width: w, basket: basket, stake: stake))
            .onAppear { startIdle() }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Cut the rope to take off")
            .accessibilityAction { performCut() }
        }
    }

    private func ground(width w: CGFloat, height h: CGFloat, groundY: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: groundY))
            p.addQuadCurve(to: CGPoint(x: w, y: groundY),
                           control: CGPoint(x: w / 2, y: groundY - 16))
            p.addLine(to: CGPoint(x: w, y: h))
            p.addLine(to: CGPoint(x: 0, y: h))
            p.closeSubpath()
        }
        .fill(LinearGradient(colors: [Color(hex: 0x2A211A), Color(hex: 0x120D09)],
                             startPoint: .top, endPoint: .bottom))
        .ignoresSafeArea()
    }

    private var stakeView: some View {
        ZStack {
            Capsule().fill(Color(hex: 0x6B4A2C)).frame(width: 7, height: 34)
            Circle().strokeBorder(Color(hex: 0xC9A87A), lineWidth: 2)
                .frame(width: 12, height: 12).offset(y: -9)
        }
    }

    private func caption(height h: CGFloat) -> some View {
        VStack {
            Spacer()
            if !cut {
                Text("Cut the rope to take off")
                    .font(.system(size: 17, weight: .medium, design: .serif)).italic()
                    .foregroundStyle(.white.opacity(0.85))
                Text("Swipe across the rope")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 2)
                if reduceMotion || voiceOver {
                    AppPrimaryButton(title: "Take Off", systemImage: "scissors") { performCut() }
                        .padding(.horizontal, AppSpacing.screen)
                        .padding(.top, AppSpacing.sm)
                        .clusterMaxWidth()
                }
            } else {
                Text("Focus started")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .transition(.opacity)
            }
            Spacer().frame(height: AppSpacing.xxl)
        }
    }

    /// A swipe crossing the rope's vertical band cuts it; nearing the rope tenses it.
    private func cutGesture(width w: CGFloat, basket: CGPoint, stake: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in
                guard !cut else { return }
                let band = min(basket.y, stake.y)...max(basket.y, stake.y)
                guard band.contains(v.location.y) else { return }
                let dx = v.location.x - w / 2
                withAnimation(.easeOut(duration: 0.1)) {
                    sway = max(-1, min(1, dx / 80))
                    slack = 10   // grabbing the rope pulls it taut
                }
                if fingerStartX == nil { fingerStartX = v.startLocation.x }
                if let sx = fingerStartX,
                   (sx - w / 2) * (v.location.x - w / 2) < 0,
                   abs(v.translation.width) > 40 {
                    performCut()
                }
            }
            .onEnded { _ in
                fingerStartX = nil
                guard !cut else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                    sway = 0
                    slack = 30
                }
            }
    }

    private func performCut() {
        guard !cut else { return }
        appModel.haptics.takeoff()
        appModel.uiSound.play(.ticketTear)   // dry rope snap
        withAnimation(AppMotion.ropeSnap.respecting(reduceMotion)) {
            cut = true
            sway = 0
        }
        withAnimation(.easeIn(duration: 0.5)) { slack = 120 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { ropeGone = true }
        withAnimation(.easeIn(duration: 0.9).delay(0.1)) { balloonLift = 560 }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.2 : 0.85)) { onCut() }
    }

    private func startIdle() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { sway = 0.22 }
    }
}

/// The tether — a slack curve from the basket to a ground stake, leaning with
/// `sway` and sagging by `sag` (both animatable, so it tenses and snaps).
struct GroundedRopeShape: Shape {
    var top: CGPoint
    var bottom: CGPoint
    var sag: CGFloat
    var sway: CGFloat
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(sag, sway) }
        set { sag = newValue.first; sway = newValue.second }
    }
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let mid = CGPoint(x: (top.x + bottom.x) / 2 + sway * 40,
                          y: (top.y + bottom.y) / 2 + sag)
        p.move(to: top)
        p.addQuadCurve(to: bottom, control: mid)
        return p
    }
}
