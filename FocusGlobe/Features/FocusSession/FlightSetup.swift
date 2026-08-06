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

    /// Build the synthetic route for a chosen **Sky** — the Sky's id rides in the
    /// route id (resume-safe) and its name becomes the destination, so the
    /// ticket, landing and Passport all record the Sky without model changes.
    static func route(minutes rawMinutes: Int, infinite: Bool,
                      origin: JourneyOrigin, focusSky: FocusSky) -> Route {
        let minutes = infinite ? infinityMinutes : max(1, min(rawMinutes, infinityMinutes))
        let km = infinite ? symbolicKm(minutes: 60) * 4 : symbolicKm(minutes: minutes)
        let deg = min(60, km / 111.0)
        let category: RouteCategory = minutes <= 30 ? .short : (minutes <= 90 ? .deep : (minutes <= 240 ? .long : .ultra))
        let id = infinite ? "\(infinityIDPrefix)-\(focusSky.id)" : "flight-\(minutes)m-\(focusSky.id)"
        let scene = focusSky.scene
        return Route(
            id: id,
            name: focusSky.name,
            shortName: focusSky.name,
            originName: origin.city,
            destinationName: focusSky.name,
            originLatitude: origin.coordinate.latitude,
            originLongitude: origin.coordinate.longitude,
            destinationLatitude: min(84, origin.coordinate.latitude + deg * 0.55),
            destinationLongitude: origin.coordinate.longitude + deg,
            durationMinutes: minutes,
            approximateDistanceKm: km,
            category: category,
            mood: scene.mood,
            rewardName: focusSky.name,
            isPremium: false,
            colorTheme: scene.theme,
            ambientSoundName: "")
    }
}

/// The set of "nice" durations the Altitude Dial snaps through, low → high,
/// with an extra terminal stop meaning **∞ (endless)**. Presets and the dial
/// both address these by index so the two controls always agree.
enum DurationScale {
    /// Clean 5-minute steps up to 3 hours, then broader cinematic stops
    /// (3h30 · 4h · 5h · 6h · 8h · 10h · 12h) and a trailing ∞. Presets and the
    /// dial both address these by index so the two controls always agree.
    static let stops: [Int] =
        Array(stride(from: 5, through: 180, by: 5)) + [210, 240, 300, 360, 480, 600, 720]
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
/// The setup ritual's own modal destinations — presented from INSIDE the
/// full-screen cover (never via the app-wide router), so a paywall or sign-in
/// can't collapse the cover or leave the router's `activeModal` stuck.
enum SetupModal: Identifiable {
    case infinitePaywall
    case onlinePaywall
    case onlineSignIn
    var id: String {
        switch self {
        case .infinitePaywall: return "infinite"
        case .onlinePaywall:   return "online"
        case .onlineSignIn:    return "signin"
        }
    }
}

struct FlightSetupView: View {
    /// The Sky chosen on Home — carried through the whole ritual: the backdrop
    /// matches its mood, the ticket names it, and the flight is biased to it.
    var focusSky: FocusSky = .defaultFree
    /// Hands the validated flight back to the presenter (Home) so it can swap the
    /// setup cover directly into the flight cover — with the Home chrome held
    /// hidden across the swap, the base screen never flashes between them.
    var onTakeOff: (Route, String?) -> Void

    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var online: FocusOnlineModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Step { case mode, duration, pack, ticket }
    @State private var step: Step = .mode
    @State private var minutes = 25
    /// Whether the dial and the focus token have already been seeded from the
    /// pilot's onboarding answers. Once only — re-seeding on a later `onAppear`
    /// would throw away a change they just made inside this ritual.
    @State private var didSeedFromPreferences = false
    @State private var infinite = false
    @State private var focus: FocusPreset?
    /// The ritual's OWN modal coordinator. The setup ritual is a full-screen
    /// cover, so any paywall / sign-in it needs MUST present from inside the
    /// cover — never through the app-wide `router` coordinator (a RootView sheet
    /// cannot present while this cover is up: it tears the cover down, dropping
    /// the user back onto Home's sky pager, and leaves a stuck `activeModal` that
    /// re-fires on the next tap). One at a time; dismiss returns here cleanly.
    @State private var setupModal: SetupModal?
    /// The pre-flight "Flight Mode" intent — whether the user wants distracting
    /// apps grounded for this journey. (Real enforcement rides the parked Focus
    /// Shield infrastructure; this is the premium pre-flight control for it.)
    @State private var blockApps = true

    var body: some View {
        ZStack {
            // The world sits still behind every step — the REAL destination Sky
            // (the same living renderer as the flight, held static), so the
            // pre-flight ritual, the take-off curtain and the flight are one
            // continuous place with no visual identity change.
            SkyFlightSceneView(
                sky: focusSky,
                elapsed: { 8 },
                animated: false,
                presentationMode: .ritual,
                renderQuality: .still
            )
                .ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.34), .clear, .black.opacity(0.60)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 0) {
                header
                ZStack {
                    switch step {
                    case .mode:
                        // The whole composition is vertically centred in the
                        // usable area (clamped width on iPad/Mac); it scrolls
                        // only if it can't fit on a very short screen.
                        GeometryReader { proxy in
                            ScrollView(showsIndicators: false) {
                                FlightModeSelectorView(
                                    onNeedOnlinePaywall: { present(.onlinePaywall) },
                                    onNeedSignIn: { present(.onlineSignIn) }
                                ) { _ in
                                    appModel.uiSound.play(.transition)
                                    withAnimation(AppMotion.soft) { step = .duration }
                                }
                                .padding(.horizontal, AppSpacing.screen)
                                .frame(maxWidth: 520)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: proxy.size.height, alignment: .center)
                            }
                        }
                        .transition(stepTransition)
                    case .duration:
                        DurationDialView(minutes: $minutes, infinite: $infinite,
                                         onNeedInfinitePaywall: { present(.infinitePaywall) }) {
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
                                          focus: focus, skyName: focusSky.name,
                                          skyAccent: focusSky.glowColor,
                                          blockApps: $blockApps) {
                            takeOff()
                        }
                        .transition(stepTransition)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)   // the ritual is always a night-cinema moment
        // Open on what the pilot told onboarding, not on a hardcoded default.
        // This is the reader that turns the first-flight question into a real
        // setting; without it that screen would be a survey.
        .onAppear {
            guard !didSeedFromPreferences else { return }
            didSeedFromPreferences = true
            if let preferred = appModel.settings.preferredFlightMinutes {
                minutes = preferred
            }
            // The focus token they named, pre-selected — still fully changeable
            // here, and left alone entirely if they never answered.
            if focus == nil, let title = appModel.profile.focusStyle {
                focus = FocusPreset.all.first { $0.title == title }
            }
        }
        // The ritual's OWN presenter remains inside its full-screen boundary.
        // Paywalls are full-screen; sign-in remains a sheet. Both filtered
        // bindings still use one local modal state.
        .fullScreenCover(item: setupPaywallBinding) { modal in
            switch modal {
            case .infinitePaywall:
                PaywallView(context: .infinite)
                    .environmentObject(appModel).environmentObject(router).focusResponsiveLayout()
            case .onlinePaywall:
                PaywallView(context: .online)
                    .environmentObject(appModel).environmentObject(router).focusResponsiveLayout()
            case .onlineSignIn:
                EmptyView()
            }
        }
        .sheet(item: setupSignInBinding) { _ in
            OnlineSignInView { }
                .environmentObject(online).environmentObject(appModel)
        }
    }

    /// Present a ritual-scoped modal (idempotent — ignores a second request while
    /// one is already up, so a rapid double-tap can't stack sheets).
    private func present(_ modal: SetupModal) {
        guard setupModal == nil else { return }
        setupModal = modal
    }

    private var setupPaywallBinding: Binding<SetupModal?> {
        Binding(
            get: {
                switch setupModal {
                case .infinitePaywall, .onlinePaywall: return setupModal
                case .onlineSignIn, .none: return nil
                }
            },
            set: { newValue in
                if let newValue { setupModal = newValue }
                else if setupModal != .onlineSignIn { setupModal = nil }
            }
        )
    }

    private var setupSignInBinding: Binding<SetupModal?> {
        Binding(
            get: { setupModal == .onlineSignIn ? setupModal : nil },
            set: { newValue in
                if let newValue { setupModal = newValue }
                else if setupModal == .onlineSignIn { setupModal = nil }
            }
        )
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
            AppIconButton(systemImage: step == .mode ? "xmark" : "chevron.left",
                          size: 40, tint: .white, accessibilityLabel: "Back") {
                appModel.tapFeedback()
                switch step {
                case .mode:     dismiss()
                case .duration: withAnimation(AppMotion.soft) { step = .mode }
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
        case .mode:     return ""   // the selector owns its own centred title
        case .duration: return "Choose your time"
        case .pack:     return "Pack your focus"
        case .ticket:   return "Check in"
        }
    }

    private func takeOff() {
        let route = FlightRouteFactory.route(minutes: minutes, infinite: infinite,
                                             origin: appModel.originForJourney,
                                             focusSky: focusSky)
        // Hand off to Home, which hides its chrome, dismisses this cover, and — in
        // the cover's own `onDismiss` — presents the flight. No timed gap, so the
        // Home screen never flashes between the ticket and the flight.
        onTakeOff(route, focus?.title)
    }
}

// MARK: - Step 1 · Altitude Dial

/// A refined rotary **Altitude Dial**: drag around the gauge to raise or lower
/// your flight time, from 5 minutes up through 12 hours and then ∞. A huge
/// centre value, ticking haptics at every stop, quick presets and a quiet
/// symbolic distance preview.
struct DurationDialView: View {
    @Binding var minutes: Int
    @Binding var infinite: Bool
    /// Free pilot reached ∞ (preset OR dial) → open the ritual's Infinite paywall.
    /// Presented by the ritual itself, never via the app-wide router coordinator.
    var onNeedInfinitePaywall: () -> Void = {}
    let onContinue: () -> Void
    @EnvironmentObject private var appModel: AppModel

    @State private var index = 0
    @State private var didInit = false
    @State private var premiumBoundaryAttemptActive = false
    @Environment(\.horizontalSizeClass) private var hSize

    /// Presets. On a compact iPhone width we drop 5 & 15 to keep the row roomy;
    /// iPad/Mac (regular) keep them. "60" reads as "1h".
    private var presets: [(label: String, minutes: Int, infinite: Bool)] {
        let full: [(String, Int, Bool)] = [
            ("5", 5, false), ("15", 15, false), ("25", 25, false), ("45", 45, false),
            ("1h", 60, false), ("2h", 120, false), ("4h", 240, false), ("∞", 720, true)
        ]
        let compact = full.filter { $0.1 != 5 && $0.1 != 15 }
        return (hSize == .regular ? full : compact)
            .map { (label: $0.0, minutes: $0.1, infinite: $0.2) }
    }

    private var fraction: Double { Double(index) / Double(DurationScale.count - 1) }
    private var isInfinityIndex: Bool { index >= DurationScale.infinityIndex }

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer(minLength: 0)
            dial.frame(height: hSize == .regular ? 440 : 310)   // the dial is the hero, larger on iPad/Mac
            distancePreview
            Spacer(minLength: 0)
            presetRow
            AppPrimaryButton(title: "Continue", systemImage: "arrow.right", iconTrailing: true) {
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
            // A fixed rhythm of ticks (decoupled from the 5-minute stop count, so
            // the ring never looks like a solid band) with a longer major every 5.
            let count = 31
            for i in 0..<count {
                let f = Double(i) / Double(count - 1)
                let a = (135.0 + f * 270.0) * .pi / 180.0
                let major = i % 5 == 0
                let outer = radius - 12
                let inner = outer - (major ? 10 : 6)
                let p1 = CGPoint(x: c.x + CGFloat(cos(a)) * outer, y: c.y + CGFloat(sin(a)) * outer)
                let p2 = CGPoint(x: c.x + CGFloat(cos(a)) * inner, y: c.y + CGFloat(sin(a)) * inner)
                var path = Path()
                path.move(to: p1)
                path.addLine(to: p2)
                ctx.stroke(path, with: .color(.white.opacity(f <= fraction + 0.001 ? 0.45 : 0.12)),
                           lineWidth: major ? 2.0 : 1.4)
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
                .font(.system(size: hSize == .regular ? 108 : 78, weight: .bold, design: .default))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: centerBig)
                .minimumScaleFactor(0.45)
                .lineLimit(1)
                .shadow(color: AppColors.gold.opacity(0.25), radius: 18)
            Text(centerSub)
                .font(.system(size: hSize == .regular ? 13 : 12, weight: .semibold, design: .monospaced))
                .tracking(3.4)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(width: hSize == .regular ? 270 : 195)
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
            .font(.system(size: 14, weight: .medium, design: .default))
            .foregroundStyle(.white.opacity(0.72))
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: infinite)
    }

    private var presetRow: some View {
        HStack(spacing: 6) {
            ForEach(presets, id: \.label) { p in
                let selected = (p.infinite && infinite) || (!p.infinite && !infinite && minutes == p.minutes)
                // The ∞ preset is a FocusGlobe PRO feature — mark it with a gold
                // ring + crown while the pilot isn't premium, so it clearly reads
                // as a locked premium option (never a plain free choice).
                let proLocked = p.infinite && appModel.entitlement != .premium
                Button {
                    // Infinite is PRO-only. A free tap opens the Infinite paywall
                    // and leaves the current finite choice untouched (no silent
                    // finite swap); loading never flashes a paywall.
                    if p.infinite {
                        switch appModel.entitlement {
                        case .premium: break
                        case .free:
                            appModel.tapFeedback(); onNeedInfinitePaywall(); return
                        case .loading:
                            appModel.tapFeedback(); appModel.refreshSubscriptionStatus(); return
                        }
                    }
                    appModel.haptics.tap()
                    infinite = p.infinite
                    minutes = p.minutes
                    index = DurationScale.index(forMinutes: p.minutes, infinite: p.infinite)
                } label: {
                    Text(p.label)
                        .font(.system(size: proLocked ? 18 : 15, weight: .bold, design: .default))
                        .foregroundStyle(selected ? AnyShapeStyle(Color(hex: 0x14120E))
                                         : (proLocked ? AnyShapeStyle(ProBrand.softGradient)
                                                      : AnyShapeStyle(Color.white)))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selected ? Color(hex: 0xF4EFE4)
                                  : (proLocked ? ProBrand.c5.opacity(0.12) : Color.white.opacity(0.08))))
                        // Locked ∞ wears a restrained multicolor outline (never gold).
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(proLocked ? AnyShapeStyle(ProBrand.borderGradient)
                                          : AnyShapeStyle(Color.white.opacity(selected ? 0 : 0.12)),
                                          lineWidth: proLocked ? 1.5 : 1))
                        .overlay(alignment: .topTrailing) {
                            if proLocked {
                                FocusGlobePROBadge(visibleHeight: 10).padding(2)
                            }
                        }
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityLabel(p.infinite ? (proLocked ? "Infinity, FocusGlobe PRO" : "Infinity")
                                                : "\(p.minutes) minutes")
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
        if rel <= 270 {
            f = rel / 270
        } else if rel <= 286 {
            // Only a deliberate overshoot on the high-duration side reaches
            // the premium terminal stop. The rest of the inactive lower arc
            // belongs to the five-minute end and can never open a paywall.
            f = 1
        } else {
            f = 0
        }
        setIndex(Int((f * Double(DurationScale.count - 1)).rounded()))
    }

    private func setIndex(_ newIndex: Int) {
        let clampedIndex = max(0, min(DurationScale.count - 1, newIndex))
        let requestedValue = DurationScale.value(at: clampedIndex)

        // Infinite is visible on the dial but PRO-locked. Reaching it as a free
        // pilot opens the Infinite paywall and leaves the current selection
        // untouched — the knob never lands on a fake finite value, and never on
        // ∞ without entitlement. A continuous drag can request this boundary
        // many times; one gesture produces at most one purchase prompt.
        if requestedValue.infinite {
            switch appModel.entitlement {
            case .premium: break
            case .free:
                guard !premiumBoundaryAttemptActive else { return }
                premiumBoundaryAttemptActive = true
                appModel.tapFeedback()
                onNeedInfinitePaywall()
                return
            case .loading:
                guard !premiumBoundaryAttemptActive else { return }
                premiumBoundaryAttemptActive = true
                appModel.refreshSubscriptionStatus()
                return
            }
        } else {
            premiumBoundaryAttemptActive = false
        }

        guard clampedIndex != index else { return }
        index = clampedIndex
        minutes = requestedValue.minutes
        infinite = requestedValue.infinite
        appModel.haptics.tap()
    }
}

// MARK: - Step 2 · Pack your focus (the drag ritual)

/// The focus ritual: a dark hot-air-balloon silhouette waits centre-screen and
/// the user **drags** (or taps) a glowing focus token up into its basket socket.
/// The socket warms as the token nears; on the drop the burner lights, the
/// envelope ignites from within, gold sparks lift — and the step advances to
/// the boarding pass on its own. No confirm button: pack and go.
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
    @State private var packing = false
    /// The auto-advance beat, cancellable so backing out can't launch onward.
    @State private var advance: DispatchWorkItem?

    /// The eight focus intentions (Fly included; no Custom in this pass).
    private var tokens: [FocusPreset] { FocusPreset.all }

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
                    // The interaction is self-evident (the finger hint + the socket),
                    // so no instruction line before packing. Only a soft confirmation
                    // appears once a focus is loaded.
                    if let s = selected {
                        Text("\(s.title) packed — taking off")
                            .font(.system(size: 15, weight: .medium, design: .serif)).italic()
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.top, AppSpacing.xs)
                            .transition(.opacity)
                    }
                    Spacer(minLength: 0)
                    tokenTray
                        .opacity(packing ? 0.4 : 1)
                        .allowsHitTesting(!packing)
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
        .onDisappear { advance?.cancel() }
        // A system-cancelled drag (backgrounding, interruption) never calls
        // onEnded — don't leave a token frozen mid-air.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                withAnimation(.easeOut(duration: 0.2)) { dragging = nil }
            }
        }
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
                .overlay { PackSparkBurst(active: loadedPop) }
        }
    }

    private func envelope(width w: CGFloat, height h: CGFloat) -> some View {
        let lit = selected != nil
        return ZStack {
            // One coherent dark silhouette before activation — deep navy into
            // near-black, no purple, no warmth. It only glows once packed.
            RitualEnvelopeShape()
                .fill(LinearGradient(colors: [Color(hex: 0x161B2B), Color(hex: 0x090C15)],
                                     startPoint: .top, endPoint: .bottom))
            // The inner light stays off until a focus is packed; then it warms.
            RitualEnvelopeShape()
                .fill(RadialGradient(
                    colors: [lit ? AppColors.gold.opacity(0.36) : Color.clear,
                             .clear],
                    center: UnitPoint(x: 0.5, y: 0.78),
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
                .fill(LinearGradient(colors: [Color(hex: 0x161B2B), Color(hex: 0x090C15)],
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
            // A quiet dashed cream outline is the only marking before activation.
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(targetHot ? AppColors.gold.opacity(0.9) : Color(hex: 0xE8DEC9).opacity(0.42),
                              style: StrokeStyle(lineWidth: targetHot ? 2 : 1.5, dash: [6, 5]))
        } else {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(.white.opacity(0.5), lineWidth: 1.5)
        }
    }

    private var dropGlow: Color {
        // No warm glow before a focus is packed — only a cool cream hint on hover.
        if let s = selected { return s.accent.opacity(0.7) }
        return targetHot ? Color(hex: 0xE8DEC9).opacity(0.35) : .clear
    }

    private var burnerGlow: some View {
        // The burner is fully dark until a focus is packed; then it ignites.
        Circle()
            .fill(RadialGradient(colors: [AppColors.gold.opacity(0.85),
                                          Color(hex: 0xFF8A2A).opacity(0.4), .clear],
                                 center: .center, startRadius: 1, endRadius: 34))
            .frame(width: 72, height: 72)
            .blur(radius: 6)
            .opacity(selected != nil ? 1 : 0)
            .scaleEffect(loadedPop ? 1.18 : 1)
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
        assign(preset)
    }

    /// A premium, colour-filled focus token (`active` = the dragged copy).
    private func tokenCard(_ preset: FocusPreset, compact: Bool, active: Bool = false) -> some View {
        VStack(spacing: 5) {
            Image(systemName: preset.systemImage)
                .font(.system(size: Layout.pad(19, 24), weight: .bold))
                .foregroundStyle(.white)
            Text(preset.title)
                .font(.system(size: Layout.pad(12, 15), weight: .bold, design: .default))
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
        guard !packing else { return }
        appModel.haptics.takeoff()
        appModel.uiSound.play(.focusDrop)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            selected = preset
            dragging = nil
            packing = true
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { loadedPop = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.easeOut(duration: 0.2)) { loadedPop = false }
        }
        // The balloon ignites, then the ritual carries itself into the ticket —
        // no Continue tap. Cancellable so a Back before the beat aborts cleanly.
        let work = DispatchWorkItem { onContinue() }
        advance = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: work)
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

/// A short burst of small gold sparks lifting from the basket the moment a
/// focus is packed — the ignition. Deterministic, cheap, and self-resetting.
private struct PackSparkBurst: View {
    let active: Bool
    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { i in
                let ang = Double(i) / 10 * 2 * .pi
                Circle()
                    .fill(AppColors.gold)
                    .frame(width: 4, height: 4)
                    .offset(x: active ? CGFloat(cos(ang)) * 34 : 0,
                            y: active ? CGFloat(sin(ang)) * 34 - 10 : 0)
                    .opacity(active ? 0 : 0.9)
                    .scaleEffect(active ? 0.3 : 1)
                    .animation(.easeOut(duration: 0.55).delay(Double(i) * 0.012), value: active)
            }
        }
        .allowsHitTesting(false)
    }
}

/// A soft looping finger that sweeps to the right across the barcode strip —
/// shown only before the first tear, so the gesture is discoverable.
private struct TearFingerHint: View {
    @State private var go = false
    var body: some View {
        Image(systemName: "hand.point.up.left.fill")
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(Color(hex: 0x2A2119).opacity(0.5))
            .scaleEffect(x: -1, y: 1)   // face right
            .offset(x: go ? 60 : -30)
            .opacity(go ? 0.1 : 0.7)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) { go = true }
            }
            .allowsHitTesting(false)
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

// MARK: - Flight Mode (compact sheet, opened from the boarding pass)

/// The compact **Flight Mode** editor — a half-sheet opened from the row under
/// the boarding pass (Flight Mode is no longer a full ritual step). Ground
/// distracting apps and pick the soundscape, then Done. (Solo vs Online is
/// the ritual's FIRST step now — never switched from here.)
/// Enforcement rides the (currently parked) Focus Shield infrastructure; this
/// surfaces the intent, honestly.
struct FlightModeSheet: View {
    @Binding var blockApps: Bool
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showShieldPicker = false

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    header
                    blockRow
                    if blockApps { scopeRow }
                    soundscapeRow
                    Text("Protected flights ground your chosen apps for the whole journey, so the sky stays yours.")
                        .font(.system(size: 12.5, weight: .regular, design: .default))
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                    AppPrimaryButton(title: "Done", systemImage: "checkmark") {
                        appModel.tapFeedback(); dismiss()
                    }
                    .padding(.top, AppSpacing.xs)
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle().fill(AppColors.gold.opacity(0.16)).frame(width: 46, height: 46)
                Image(systemName: "airplane")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColors.gold)
                    .rotationEffect(.degrees(-45))
            }
            Text("Flight Mode")
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
            Spacer()
        }
    }

    private var blockRow: some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) { blockApps.toggle() }
            appModel.haptics.tap()
        } label: {
            rowShell {
                Image(systemName: blockApps ? "moon.zzz.fill" : "bell.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(blockApps ? AppColors.gold : .white.opacity(0.6))
                    .frame(width: 26)
                rowText("Block distracting apps",
                        blockApps ? "Distractions grounded for the flight" : "Notifications and apps stay on")
                Spacer()
                fauxSwitch
            }
        }
        .buttonStyle(SoftPressStyle(scale: 0.99))
    }

    // The apps in scope — opens Apple's real FamilyActivityPicker (via the
    // shared FocusShield configurator). No "coming soon".
    private var scopeRow: some View {
        Button {
            appModel.tapFeedback()
            showShieldPicker = true
        } label: {
            rowShell {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6)).frame(width: 26)
                rowText("What's grounded", groundedSummary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .buttonStyle(SoftPressStyle(scale: 0.99))
        #if FOCUS_SHIELD_ENABLED
        .sheet(isPresented: $showShieldPicker) {
            FocusShieldPickerView(service: appModel.focusShield, context: .settings)
                .environmentObject(appModel)
        }
        #endif
    }

    /// A real summary of the current blocked selection (never "coming soon").
    private var groundedSummary: String {
        guard appModel.focusShield.isSupported else { return "Available on iPhone and iPad" }
        let n = appModel.focusShield.selectionCount
        return n == 0 ? "Tap to choose apps" : "\(n) selected · tap to change"
    }

    private var soundscapeRow: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("SOUNDSCAPE")
                .font(.system(size: 11, weight: .heavy, design: .default))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.5))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(JourneyAudioOption.all) { option in
                        soundChip(option)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func soundChip(_ option: JourneyAudioOption) -> some View {
        let selected = appModel.selectedJourneyAudio.id == option.id
        return Button {
            appModel.selectJourneyAudio(option)
            appModel.haptics.tap()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: option.systemImage).font(.system(size: 13, weight: .bold))
                Text(option.displayName).font(.system(size: 13.5, weight: .bold, design: .default))
            }
            .foregroundStyle(selected ? Color(hex: 0x14120E) : .white)
            .padding(.horizontal, AppSpacing.sm)
            .frame(height: 40)
            .background(Capsule().fill(selected ? AnyShapeStyle(option.accent) : AnyShapeStyle(Color.white.opacity(0.08))))
            .overlay(Capsule().strokeBorder(.white.opacity(selected ? 0 : 0.12), lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle())
    }

    // MARK: Row helpers

    private func rowShell<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: AppSpacing.sm) { content() }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm + 2)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1))
            )
    }

    private func rowText(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .default))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 12.5, weight: .regular, design: .default))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    private var fauxSwitch: some View {
        Capsule()
            .fill(blockApps ? AppColors.gold : Color.white.opacity(0.16))
            .frame(width: 50, height: 30)
            .overlay(alignment: .leading) {
                Circle().fill(.white).frame(width: 24, height: 24)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .offset(x: blockApps ? 23 : 3)
            }
    }
}

// MARK: - Step 4 · Check in (the boarding pass)

/// A large boarding pass on warm paper, floating over the night world. The
/// bottom **barcode strip physically tears off**: swipe across it and it peels
/// from the perforation in 3D, following your finger, and past a threshold it
/// detaches with a paper snap + a "Ready" stamp — then the pass lifts away and
/// the flight begins. Restored from the build-11 boarding tear.
struct CheckInTicketView: View {
    let minutes: Int
    let infinite: Bool
    let focus: FocusPreset?
    let skyName: String
    /// The selected Sky's accent — tints the FOCUS label, the ticket balloon and
    /// the "Ready" stamp, so the pass belongs to this Sky.
    var skyAccent: Color = AppColors.terracotta
    /// The Flight-Mode "ground distracting apps" intent, edited via the compact
    /// row beneath the ticket (no longer a full ritual step).
    @Binding var blockApps: Bool
    let onValidated: () -> Void
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    /// Horizontal tear travel of the barcode strip (finger translation).
    @State private var tearX: CGFloat = 0
    @State private var checked = false            // strip torn off / validated
    @State private var stampIn = false
    @State private var flyAway = false
    @State private var started = false
    @State private var showFlightMode = false
    /// The scheduled check-in beats, cancellable so backing out of this step
    /// mid-validation can never launch a flight behind the user's back.
    @State private var pendingBeats: [DispatchWorkItem] = []

    private let threshold: CGFloat = 120
    private let paper = Color(hex: 0xF5EBD8)
    private let ink = Color(hex: 0x2A2119)
    private let inkSoft = Color(hex: 0x77685A)

    /// Effective tear distance: follows the finger, then snaps far once torn so
    /// the strip peels fully away.
    private var effTear: CGFloat { checked ? 640 : tearX }
    /// 0…1 peel progress — grows the lift shadow so the strip reads as attached
    /// at rest and lifting as it tears.
    private var tearLift: CGFloat { min(1, effTear / threshold) }

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
            if !checked && !started {
                flightModeRow
                    .padding(.horizontal, AppSpacing.screen)
                    .clusterMaxWidth()
                    .transition(.opacity)
            }
            hint
            Spacer(minLength: 0)
        }
        .padding(.bottom, AppSpacing.lg)
        .onDisappear {
            pendingBeats.forEach { $0.cancel() }
            pendingBeats.removeAll()
        }
        .sheet(isPresented: $showFlightMode) {
            FlightModeSheet(blockApps: $blockApps)
                .environmentObject(appModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    /// The compact Flight-Mode summary under the ticket: a one-line status
    /// (Protected/Online · soundscape) with an Edit affordance opening the sheet.
    /// Flight Mode is no longer a full ritual step — it lives here, out of the way.
    private var flightModeRow: some View {
        Button {
            appModel.tapFeedback()
            showFlightMode = true
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "airplane")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.gold)
                    .rotationEffect(.degrees(-45))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Flight Mode")
                        .font(.system(size: 13, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                    Text(flightModeSummary)
                        .font(.system(size: 11.5, weight: .medium, design: .default))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                }
                Spacer()
                Text("Edit")
                    .font(.system(size: 13, weight: .bold, design: .default))
                    .foregroundStyle(AppColors.gold)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.1)))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.black.opacity(0.28)))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1))
            )
        }
        .buttonStyle(SoftPressStyle(scale: 0.99))
    }

    private var flightModeSummary: String {
        let protection = blockApps ? "Protected" : "Open"
        let crew: String
        switch OnlineCache.lastFlightMode {
        case .solo:        crew = "Solo"
        case .publicSky:   crew = "Online"
        case .privateRoom: crew = "Crew flight"
        }
        return "\(protection) · \(crew) · \(appModel.selectedJourneyAudio.displayName)"
    }

    @ViewBuilder private var hint: some View {
        if !checked {
            VStack(spacing: AppSpacing.sm) {
                Label("Tear the barcode across to board", systemImage: "hand.draw")
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundStyle(.white.opacity(0.72))
                if reduceMotion || voiceOver {
                    AppPrimaryButton(title: "Check in", systemImage: "checkmark.seal") { commitTear() }
                        .padding(.horizontal, AppSpacing.screen)
                        .clusterMaxWidth()
                }
            }
            .transition(.opacity)
        } else {
            Text("Ready to fly")
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundStyle(AppColors.gold)
                .transition(.opacity)
        }
    }

    // MARK: The pass — a body card + a detachable barcode strip

    private var ticket: some View {
        VStack(spacing: 0) {   // spacing 0 → the strip touches the body's bottom edge
            bodyCard
                .overlay(alignment: .bottom) {
                    perforation.opacity(checked ? 0 : 1).offset(y: 6)
                }
            // The barcode strip tears off as paper: it peels from the top-left of
            // the perforation, bending out in 3D and following the finger sideways
            // — never a fade, never a rigid block flying off flat.
            barcodeStrip
                .padding(.top, -4)   // tighten the gap between body and barcode
                .rotation3DEffect(.degrees(Double(min(30, effTear * 0.12))),
                                  axis: (x: 0.18, y: 1, z: 0), anchor: .topLeading, perspective: 0.8)
                .rotationEffect(.degrees(Double(min(10, effTear * 0.05))), anchor: .topLeading)
                .offset(x: effTear * 0.8, y: effTear * 0.12)
                .opacity(checked ? 0 : 1)
                // The gesture hint rides the perforation (top of the strip), not
                // the barcode itself — it shows where to tear.
                .overlay(alignment: .top) {
                    if !checked && tearX == 0 { TearFingerHint().offset(y: -13) }
                }
                .gesture(tearGesture)
        }
        .frame(maxWidth: 460)
        .overlay(stamp)
        .padding(.horizontal, AppSpacing.screen)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Boarding pass. Focus flight to \(skyName), \(durationBig). \(checked ? "Checked in." : "Not checked in.")")
        .accessibilityAction(named: "Check in") { commitTear() }
    }

    private var bodyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ticketHeader
                .padding(.horizontal, AppSpacing.lg).padding(.top, AppSpacing.lg)
            ticketBody
                .padding(.horizontal, AppSpacing.lg).padding(.top, AppSpacing.sm)
            Spacer(minLength: AppSpacing.sm)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .background(paperFill(topRounded: true))
        .overlay(alignment: .bottomLeading) { notch.offset(x: -9, y: 9) }
        .overlay(alignment: .bottomTrailing) { notch.offset(x: 9, y: 9) }
        .compositingGroup()
        .shadow(color: .black.opacity(0.45), radius: 20, y: 12)
    }

    private var barcodeStrip: some View {
        TicketBars(seed: barcodeSeed, color: ink)
            .frame(height: 84)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .frame(maxWidth: .infinity)
        .background(paperFill(topRounded: false))
        .overlay(alignment: .topLeading) { notch.offset(x: -9, y: -9) }
        .overlay(alignment: .topTrailing) { notch.offset(x: 9, y: -9) }
        .compositingGroup()
        // No resting shadow → the stub reads as attached. The lift shadow grows
        // only as the strip peels away.
        .shadow(color: .black.opacity(0.5 * Double(tearLift)),
                radius: 8 + 10 * tearLift, y: 4 + 8 * tearLift)
    }

    /// Cream paper with a soft grain, clipped so the body rounds at the top and
    /// the strip rounds at the bottom — together they read as one ticket.
    private func paperFill(topRounded: Bool) -> some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: topRounded ? 22 : 0,
            bottomLeadingRadius: topRounded ? 0 : 22,
            bottomTrailingRadius: topRounded ? 0 : 22,
            topTrailingRadius: topRounded ? 22 : 0, style: .continuous)
        return shape.fill(paper)
            .overlay(
                PaperGrain(intensity: 0.8)
                    .environment(\.colorScheme, .light)
                    .clipShape(shape))
    }

    /// A punched notch at the perforation corners — a hole showing the night sky
    /// behind the pass, like a real ticket.
    private var notch: some View {
        Circle().fill(Color.black).frame(width: 18, height: 18).blendMode(.destinationOut)
    }

    private var ticketHeader: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center) {
                Text("FOCUSGLOBE")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(ink)
                Spacer()
                MiniBalloonView(size: 34, envelope: skyAccent, showGlow: false)
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
            // The headline trio — DURATION, FOCUS, SKY — reads at a glance.
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    fieldLabel("DURATION")
                    Text(durationBig)
                        .font(.system(size: 50, weight: .heavy, design: .default))
                        .foregroundStyle(ink)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    fieldLabel("SKY")
                    Text(skyName)
                        .font(.system(size: 25, weight: .semibold, design: .serif))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .padding(.top, AppSpacing.xs)

            VStack(alignment: .leading, spacing: 1) {
                fieldLabel("FOCUS")
                Text((focus?.title ?? "Focus").uppercased())
                    .font(.system(size: 30, weight: .bold, design: .default))
                    .foregroundStyle(skyAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            HStack(alignment: .top, spacing: AppSpacing.lg) {
                field("DATE", dateText)
                field("FLIGHT ID", flightID)
                statusChip
            }
        }
    }

    private var statusChip: some View {
        VStack(alignment: .leading, spacing: 2) {
            fieldLabel("STATUS")
            HStack(spacing: 5) {
                Circle()
                    .fill(checked ? Color(hex: 0x3F9C7C) : inkSoft.opacity(0.5))
                    .frame(width: 7, height: 7)
                Text(checked ? "READY" : "CHECK IN")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(checked ? Color(hex: 0x3F9C7C) : inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The dashed cut line on the seam between the body and the strip — clearly
    /// visible so the "tear here" affordance reads instantly, with a small
    /// scissors mark at the leading edge.
    private var perforation: some View {
        HStack(spacing: 5) {
            Image(systemName: "scissors")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(inkSoft.opacity(0.7))
            HStack(spacing: 5) {
                ForEach(0..<26, id: \.self) { _ in
                    Capsule().fill(ink.opacity(0.45)).frame(width: 6, height: 2)
                }
            }
        }
        .frame(height: 2)
        .padding(.horizontal, AppSpacing.md)
    }

    // MARK: Tear interaction → flight

    private var tearGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in
                guard !checked else { return }
                let x = max(0, v.translation.width)
                if x > tearX + 20 { appModel.haptics.tap() }   // a light paper ratchet
                tearX = x
            }
            .onEnded { _ in
                guard !checked else { return }
                if tearX >= threshold {
                    commitTear()
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) { tearX = 0 }
                }
            }
    }

    private func commitTear() {
        guard !checked else { return }
        appModel.haptics.takeoff()
        appModel.uiSound.play(.ticketTear)          // the paper snap
        // `checked` drives effTear → 640, so the strip peels fully away.
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { checked = true }
        withAnimation(AppMotion.sealImpact.respecting(reduceMotion)) { stampIn = true }
        let beat = reduceMotion ? 0.25 : 0.8
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
        DispatchQueue.main.asyncAfter(deadline: .now() + beat + (reduceMotion ? 0.25 : 0.7),
                                      execute: launch)
    }

    @ViewBuilder private var stamp: some View {
        if stampIn {
            InkStamp(text: "Ready", color: skyAccent, rotation: -8)
                .scaleEffect(1.55)
                .offset(x: 60, y: -30)
                .transition(.scale(scale: 1.9).combined(with: .opacity))
        }
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
        for u in ("\(minutes)" + (focus?.title ?? "") + skyName).unicodeScalars {
            h = (h &* 31 &+ Int(u.value)) & 0x7fffffff
        }
        let n = h % 900 + 100
        let base = infinite ? "INF" : String(format: "%03d", min(minutes, 999))
        return "FG\(base)·\(n)"
    }

    private var barcodeSeed: String { "\(minutes)-\(focus?.title ?? "focus")-\(skyName)" }

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

/// Deterministic barcode bars (decoration, accessibility-hidden) for the
/// detachable boarding-pass strip.
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
                             with: .color(color.opacity(0.82)))
                }
                x += barW + CGFloat(1 + ((v / 3) % 3))
                i += 1
            }
        }
        .accessibilityHidden(true)
    }
}
