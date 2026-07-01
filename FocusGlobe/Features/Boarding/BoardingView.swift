import SwiftUI

/// The premium check-in ritual. A real Google route map sits behind a dark
/// graphite "Boarding Pass" that prints in from a slot. Step 1: choose a focus
/// (mandatory). Step 2: swipe horizontally across the perforation to tear off
/// the barcode strip, which takes off. Collectible, tactile, dark-first.
///
/// All the trip info (cities, duration, distance, date, focus) lives on the
/// ticket body; only the barcode strip detaches.
struct BoardingView: View {
    let route: Route

    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPreset: FocusPreset?

    /// `route` is required; `preselectedFocus` carries the focus chosen on the
    /// new pre-boarding ritual so the ticket arrives pre-filled. Everything else
    /// keeps its default boarding behaviour.
    init(route: Route, preselectedFocus: FocusPreset? = nil) {
        self.route = route
        _selectedPreset = State(initialValue: preselectedFocus)
    }

    // Print choreography.
    @State private var printed: CGFloat = 0
    @State private var perforationIn = false
    @State private var barcodeIn = false
    @State private var focusIn = false

    // Tear-to-take-off (horizontal).
    @State private var tearX: CGFloat = 0
    @State private var torn = false

    private let tearThreshold: CGFloat = 120

    private var origin: JourneyOrigin { appModel.originForJourney }
    private var distanceKm: Double { GeoMath.distanceKm(from: origin.coordinate, to: route.destination) }

    var body: some View {
        ZStack {
            JourneyBackdropMap(origin: origin, destination: route, mode: .route,
                               progress: 0.32, showsBalloon: false)
                .ignoresSafeArea()

            scrims

            VStack(spacing: AppSpacing.md) {
                topBar
                Spacer(minLength: AppSpacing.xs)
                ticketStack
                Spacer()
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
    }

    private var scrims: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 150)
            Spacer()
            LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .top, endPoint: .bottom)
                .frame(height: 320)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // Linear flow: focus is chosen in the pre-boarding ritual, so there is no
    // back button or focus selector here — only the centred title.
    private var topBar: some View {
        HStack {
            Color.clear.frame(width: 44, height: 44)
            Spacer()
            Text("Check in").font(AppTypography.headline).foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
    }

    private var ticketStack: some View {
        VStack(spacing: AppSpacing.xs) {
            PrinterSlot()
                .frame(maxWidth: Layout.pad(340, 460))
                .opacity(printed < 1 ? 1 : 0)

            JourneyTicket(origin: origin, route: route, distanceKm: distanceKm,
                          focus: selectedPreset, printed: printed,
                          perforationIn: perforationIn, barcodeIn: barcodeIn,
                          tearX: $tearX, torn: torn,
                          canTear: focusIn && !torn, threshold: tearThreshold,
                          onCommit: commitTear)
                .frame(maxWidth: Layout.pad(420, 560))   // larger premium ticket on iPad/Mac
        }
    }

    // MARK: Choreography

    private func runPrintSequence() {
        guard printed == 0 else { return }
        withAnimation(.easeOut(duration: 1.1)) { printed = 1 }       // body reveals top→down
        for t in [0.18, 0.55, 0.9] {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { appModel.haptics.tap() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {     // perforation after body
            withAnimation(.easeOut(duration: 0.3)) { perforationIn = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {      // barcode last, with scan
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { barcodeIn = true }
            appModel.haptics.resume()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {      // focus options appear
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { focusIn = true }
        }
    }

    private func commitTear() {
        appModel.haptics.takeoff()
        appModel.uiSound.play(.ticketTear)
        withAnimation(.easeIn(duration: 0.45)) { torn = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            router.startJourney(origin: origin, route: route, intention: selectedPreset?.title)
        }
    }
}

// MARK: - Printer slot

private struct PrinterSlot: View {
    @State private var sweep: CGFloat = -0.35

    var body: some View {
        ZStack {
            Capsule().fill(Color.black.opacity(0.55))
                .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
            GeometryReader { g in
                LinearGradient(colors: [.clear, AppColors.gold.opacity(0.9), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: 56)
                    .offset(x: g.size.width * sweep)
                    .blendMode(.screen)
            }
            .allowsHitTesting(false)
        }
        .frame(height: 6)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.95).repeatCount(2, autoreverses: false)) { sweep = 1.25 }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Ticket

private struct JourneyTicket: View {
    let origin: JourneyOrigin
    let route: Route
    let distanceKm: Double
    let focus: FocusPreset?
    let printed: CGFloat
    let perforationIn: Bool
    let barcodeIn: Bool
    @Binding var tearX: CGFloat
    let torn: Bool
    let canTear: Bool
    let threshold: CGFloat
    let onCommit: () -> Void

    private let ink = Color(hex: 0xF1F4FB)
    private let inkSoft = Color(hex: 0xAEB7CC)

    private var effTear: CGFloat { torn ? 620 : tearX }
    /// 0…1 progress of the tear, used to grow the strip's lift shadow as it peels
    /// (zero when attached, so the ticket reads as one connected piece at rest).
    private var tearLift: CGFloat { min(1, effTear / max(1, threshold)) }

    var body: some View {
        VStack(spacing: 0) {   // spacing 0 → the stub touches the ticket's bottom edge
            body_
                .mask(alignment: .top) {
                    GeometryReader { g in
                        Rectangle()
                            .frame(height: max(0, g.size.height * printed))
                            .frame(maxHeight: .infinity, alignment: .top)
                    }
                }
                // The perforation is drawn ON the seam (no vertical gap), so the body
                // and the barcode stub read as one continuous ticket before tearing.
                .overlay(alignment: .bottom) {
                    perforation.opacity(perforationIn && !torn ? 1 : 0)
                }
            // Barcode stub — flush to the ticket's bottom edge. It tears as a paper
            // peel: pivoting from the top-left of the perforation, bending out in 3D
            // and following the finger sideways — never a rigid block flying off flat.
            barcodeStrip
                .rotation3DEffect(.degrees(Double(min(30, effTear * 0.12))),
                                  axis: (x: 0.18, y: 1, z: 0), anchor: .topLeading, perspective: 0.8)
                .rotationEffect(.degrees(Double(min(10, effTear * 0.05))), anchor: .topLeading)
                .offset(x: effTear * 0.8, y: effTear * 0.12)
                .opacity(torn ? 0 : (barcodeIn ? 1 : 0))
                .overlay { if canTear && tearX == 0 { TearFingerHint() } }
                .gesture(tearGesture)
        }
    }

    private var tearGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in
                guard canTear else { return }
                tearX = max(0, v.translation.width)
            }
            .onEnded { _ in
                guard canTear else { return }
                if tearX >= threshold { onCommit() }
                else { withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) { tearX = 0 } }
            }
    }

    // MARK: Body (all trip info stays here)

    private var body_: some View {
        VStack(spacing: 0) {
            TicketSkyHeader(originCode: origin.code, originCity: origin.city,
                            destCode: route.destinationCode, destCity: route.destinationName,
                            duration: route.durationLabel, category: route.category,
                            ink: ink, inkSoft: inkSoft)
                .frame(height: Layout.pad(116, 142))

            VStack(spacing: AppSpacing.sm) {
                HStack(spacing: 0) {
                    detail("DURATION", route.durationLabel)
                    detail("DISTANCE", Formatters.distance(km: distanceKm))
                    detail("DATE", Self.dateText)
                }
                Rectangle().fill(ink.opacity(0.08)).frame(height: 1)
                HStack(spacing: AppSpacing.sm) {
                    ZStack {
                        Circle().fill((focus?.accent ?? inkSoft).opacity(0.20)).frame(width: 34, height: 34)
                        Image(systemName: focus?.systemImage ?? "target")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(focus?.accent ?? inkSoft)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("FOCUS")
                            .font(.system(size: 9, weight: .semibold, design: .rounded)).tracking(0.5)
                            .foregroundStyle(inkSoft)
                        Text(focus?.title ?? "Choose your focus")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(focus == nil ? inkSoft : ink)
                    }
                    Spacer()
                }
            }
            .padding(AppSpacing.md)
        }
        .background(graphite)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: AppSpacing.cardRadius,
                                          bottomLeadingRadius: 0, bottomTrailingRadius: 0,
                                          topTrailingRadius: AppSpacing.cardRadius, style: .continuous))
        .overlay(alignment: .bottomLeading) { notch.offset(x: -9, y: 9) }
        .overlay(alignment: .bottomTrailing) { notch.offset(x: 9, y: 9) }
        .compositingGroup()
        .shadow(color: .black.opacity(0.5), radius: 18, x: 0, y: 10)
    }

    // MARK: Perforation (the cut line above the barcode)

    private var perforation: some View {
        ZStack {
            DashLine()
                .stroke(inkSoft.opacity(0.45), style: StrokeStyle(lineWidth: 1.2, dash: [4, 5]))
                .frame(height: 1)
                .padding(.horizontal, AppSpacing.md)
            // Horizontal shimmer hinting the swipe gesture.
            if barcodeIn && !torn { PerforationShimmer() }
        }
        .frame(height: 12)
        .offset(y: 6)   // centre the dashed line on the seam (the ticket's bottom edge)
    }

    // MARK: Barcode strip (the detachable part)

    private var barcodeStrip: some View {
        HStack(spacing: AppSpacing.sm) {
            BarcodeStrip(seed: origin.code + route.id + route.destinationCode,
                         barColor: ink, scanIn: barcodeIn)
                .frame(height: Layout.pad(54, 76))
            QRBlock(seed: route.id, color: ink).frame(width: Layout.pad(54, 76), height: Layout.pad(54, 76))
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(graphite)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0,
                                          bottomLeadingRadius: AppSpacing.cardRadius,
                                          bottomTrailingRadius: AppSpacing.cardRadius,
                                          topTrailingRadius: 0, style: .continuous))
        .overlay(alignment: .topLeading) { notch.offset(x: -9, y: -9) }
        .overlay(alignment: .topTrailing) { notch.offset(x: 9, y: -9) }
        .compositingGroup()
        // No resting shadow → the stub looks attached to the body. The lift shadow
        // grows only as the strip peels away.
        .shadow(color: .black.opacity(0.5 * Double(tearLift)), radius: 8 + 10 * tearLift, x: 0, y: 4 + 8 * tearLift)
    }

    private var graphite: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x1E2531), Color(hex: 0x12161F)],
                       startPoint: .top, endPoint: .bottom)
    }

    private var notch: some View {
        Circle().fill(Color.black).frame(width: 18, height: 18).blendMode(.destinationOut)
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .rounded)).tracking(0.5)
                .foregroundStyle(inkSoft)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(ink)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let dateText: String = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f.string(from: Date()).uppercased()
    }()
}

// MARK: - Dark sky header (universal, subtle balloon silhouettes)

private struct TicketSkyHeader: View {
    let originCode: String
    let originCity: String
    let destCode: String
    let destCity: String
    let duration: String
    let category: RouteCategory
    let ink: Color
    let inkSoft: Color

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x273141), Color(hex: 0x161D2A)],
                           startPoint: .top, endPoint: .bottom)
            // Faint moon glow.
            Circle()
                .fill(RadialGradient(colors: [Color.white.opacity(0.16), .clear],
                                     center: .center, startRadius: 1, endRadius: 60))
                .frame(width: 120, height: 120)
                .offset(x: 118, y: -42)
            // Dark balloon silhouettes — subtle, not bright.
            BalloonSilhouette().fill(Color.black.opacity(0.30)).frame(width: 22, height: 30).offset(x: -118, y: -18)
            BalloonSilhouette().fill(Color.black.opacity(0.24)).frame(width: 15, height: 21).offset(x: 92, y: -34)
            BalloonSilhouette().fill(Color.black.opacity(0.18)).frame(width: 11, height: 15).offset(x: 28, y: -44)

            VStack {
                HStack {
                    Text("FocusGlobe · Boarding Pass")
                        .font(.system(size: 10, weight: .semibold, design: .rounded)).tracking(0.5)
                        .foregroundStyle(ink.opacity(0.85))
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: category.systemImage).font(.system(size: 9, weight: .bold))
                        Text(category.displayName).font(.system(size: 10, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(ink)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                Spacer()
                HStack(alignment: .center) {
                    codeBlock(originCode, originCity, .leading)
                    Spacer(minLength: AppSpacing.xs)
                    VStack(spacing: 2) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(ink.opacity(0.9))
                        Text(duration)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(inkSoft)
                    }
                    Spacer(minLength: AppSpacing.xs)
                    codeBlock(destCode, destCity, .trailing)
                }
            }
            .padding(AppSpacing.md)
        }
    }

    private func codeBlock(_ code: String, _ city: String, _ align: HorizontalAlignment) -> some View {
        VStack(alignment: align, spacing: 1) {
            Text(code)
                .font(.system(size: Layout.pad(32, 40), weight: .heavy, design: .rounded))
                .foregroundStyle(ink)               // both codes share the same colour
                .minimumScaleFactor(0.7).lineLimit(1)
            Text(city)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(inkSoft).lineLimit(1)
        }
    }
}

private struct BalloonSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.addEllipse(in: CGRect(x: 0, y: 0, width: w, height: h * 0.78))
        let cx = w / 2
        p.move(to: CGPoint(x: cx - w * 0.12, y: h * 0.70))
        p.addLine(to: CGPoint(x: cx + w * 0.12, y: h * 0.70))
        p.addLine(to: CGPoint(x: cx + w * 0.06, y: h * 0.88))
        p.addLine(to: CGPoint(x: cx - w * 0.06, y: h * 0.88))
        p.closeSubpath()
        p.addRect(CGRect(x: cx - w * 0.07, y: h * 0.88, width: w * 0.14, height: h * 0.12))
        return p
    }
}

private struct PerforationShimmer: View {
    @State private var x: CGFloat = -0.4
    var body: some View {
        GeometryReader { g in
            LinearGradient(colors: [.clear, .white.opacity(0.5), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: 60)
                .offset(x: g.size.width * x)
                .blendMode(.screen)
        }
        .frame(height: 14)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false)) { x = 1.2 }
        }
    }
}

/// A subtle animated finger gliding horizontally across the strip — previews the
/// swipe-to-tear gesture without blocking it.
private struct TearFingerHint: View {
    @State private var animate = false
    var body: some View {
        GeometryReader { g in
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .shadow(color: .black.opacity(0.4), radius: 4, y: 1)
                .offset(x: animate ? g.size.width * 0.5 : g.size.width * 0.12, y: 2)
                .opacity(animate ? 0.2 : 0.75)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                        animate = true
                    }
                }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Paper pieces

private struct DashLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

/// A deterministic barcode (off-white bars on the dark strip) with a one-time
/// gold "scan" sweep when the ticket prints.
private struct BarcodeStrip: View {
    let seed: String
    var barColor: Color = .white
    var scanIn: Bool = false
    @State private var sweep: CGFloat = -0.2

    var body: some View {
        ZStack {
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
                                 with: .color(barColor.opacity(0.85)))
                    }
                    x += barW + gapW
                    i += 1
                }
            }
            GeometryReader { g in
                LinearGradient(colors: [.clear, AppColors.gold.opacity(0.9), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: 40)
                    .offset(x: g.size.width * sweep)
                    .blendMode(.screen)
            }
            .allowsHitTesting(false)
        }
        .onChange(of: scanIn) { _, on in
            guard on else { return }
            sweep = -0.2
            withAnimation(.easeInOut(duration: 0.8)) { sweep = 1.1 }
        }
        .accessibilityHidden(true)
    }
}

/// A small deterministic QR-like block (premium ticket detail; not a real code).
private struct QRBlock: View {
    let seed: String
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            let n = 7
            let cell = size.width / CGFloat(n)
            let scalars = Array(seed.unicodeScalars.map { Int($0.value) })
            guard !scalars.isEmpty else { return }
            for r in 0..<n {
                for c in 0..<n {
                    let v = scalars[(r * n + c) % scalars.count] &+ r &* 7 &+ c &* 13
                    let corner = (r < 2 && c < 2) || (r < 2 && c >= n - 2) || (r >= n - 2 && c < 2)
                    if corner || abs(v) % 2 == 0 {
                        ctx.fill(Path(CGRect(x: CGFloat(c) * cell, y: CGFloat(r) * cell,
                                             width: cell - 1, height: cell - 1)),
                                 with: .color(color.opacity(0.88)))
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}
