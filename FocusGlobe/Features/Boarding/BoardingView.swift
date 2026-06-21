import SwiftUI

/// The premium check-in ritual. A real Google route map sits behind a white
/// paper "Boarding Pass" that prints in from a slot; the user must pick a focus,
/// then drags the ticket itself down to tear it along the perforation — which
/// takes off. Collectible, tactile, dark-first. One universal ticket design for
/// every journey (a soft sky with drifting balloons; no per-destination art).
struct BoardingView: View {
    let route: Route

    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    /// Mandatory focus — the ticket cannot tear until one is chosen.
    @State private var selectedPreset: FocusPreset?

    // Print choreography.
    @State private var printed: CGFloat = 0
    @State private var barcodeIn = false
    @State private var focusIn = false

    // Tear-to-take-off.
    @State private var tearDrag: CGFloat = 0
    @State private var torn = false
    @State private var nudge = false

    private let tearThreshold: CGFloat = 96

    private var origin: JourneyOrigin { appModel.originForJourney }
    private var distanceKm: Double { GeoMath.distanceKm(from: origin.coordinate, to: route.destination) }
    private var effectiveTear: CGFloat { torn ? 520 : tearDrag }

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
                focusSelector.opacity(focusIn ? 1 : 0)
                takeoffHint.opacity(focusIn ? 1 : 0)
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

    private var topBar: some View {
        HStack {
            AppIconButton(systemImage: "chevron.left", size: 44, tint: .white,
                          accessibilityLabel: "Back") { dismiss() }
            Spacer()
            Text("Check in").font(AppTypography.headline).foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
    }

    // MARK: Ticket (printer slot + tearable pass)

    private var ticketStack: some View {
        VStack(spacing: AppSpacing.xs) {
            PrinterSlot()
                .frame(maxWidth: 340)
                .opacity(printed < 1 ? 1 : 0)

            JourneyTicket(origin: origin, route: route, distanceKm: distanceKm,
                          focus: selectedPreset, barcodeIn: barcodeIn,
                          tear: effectiveTear, torn: torn)
                .frame(maxWidth: 420)
                .opacity(printed)
                .offset(y: (1 - printed) * -26 + (nudge ? -8 : 0))
                .scaleEffect(x: 1, y: 0.97 + 0.03 * printed, anchor: .top)
                .gesture(tearGesture)
                .allowsHitTesting(focusIn && !torn)
        }
    }

    private var tearGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard focusIn, !torn else { return }
                guard selectedPreset != nil else {
                    if value.translation.height > 6 { triggerNudge() }
                    return
                }
                tearDrag = max(0, value.translation.height)
            }
            .onEnded { _ in
                guard focusIn, !torn, selectedPreset != nil else { return }
                if tearDrag >= tearThreshold {
                    commitTear()
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { tearDrag = 0 }
                }
            }
    }

    // MARK: Focus selection (mandatory)

    private var focusSelector: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("CHOOSE YOUR FOCUS")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.6))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(FocusPreset.all) { preset in
                        FocusChip(preset: preset, selected: selectedPreset?.id == preset.id) {
                            appModel.haptics.tap()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedPreset = preset
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .scaleEffect(nudge ? 1.03 : 1)
    }

    private var takeoffHint: some View {
        HStack(spacing: 6) {
            Image(systemName: selectedPreset == nil ? "hand.tap" : "arrow.down")
                .font(.system(size: 12, weight: .bold))
            Text(selectedPreset == nil ? "Choose a focus to take off"
                 : "Pull the ticket down to tear & take off")
                .font(AppTypography.caption)
        }
        .foregroundStyle(selectedPreset == nil ? AppColors.gold : .white.opacity(0.85))
    }

    // MARK: Choreography

    private func runPrintSequence() {
        guard printed == 0 else { return }
        withAnimation(.easeOut(duration: 1.2)) { printed = 1 }
        for t in [0.18, 0.55, 0.9] {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { appModel.haptics.tap() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { barcodeIn = true }
            appModel.haptics.resume()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { focusIn = true }
        }
    }

    private func triggerNudge() {
        guard !nudge else { return }
        appModel.haptics.pause()
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { nudge = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { nudge = false }
        }
    }

    private func commitTear() {
        appModel.haptics.takeoff()
        withAnimation(.easeIn(duration: 0.45)) { torn = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            router.startJourney(origin: origin, route: route, intention: selectedPreset?.title)
        }
    }
}

// MARK: - Printer slot

/// A thin printer slot with a one-time gold light sweep, so the ticket reads as
/// being printed out from above.
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

// MARK: - The ticket

private struct JourneyTicket: View {
    let origin: JourneyOrigin
    let route: Route
    let distanceKm: Double
    let focus: FocusPreset?
    let barcodeIn: Bool
    let tear: CGFloat
    let torn: Bool

    private let paper = Color(hex: 0xF7F4EC)
    private let ink = Color(hex: 0x1A2230)
    private let inkSoft = Color(hex: 0x5B6373)

    var body: some View {
        VStack(spacing: 0) {
            topCard
                .offset(y: -tear * 0.14)
                .opacity(torn ? 0 : 1)
            perforation
            bottomCard
                .offset(y: tear)
                .opacity(torn ? 0 : 1)
        }
    }

    private var topCard: some View {
        TicketSkyHeader(originCode: origin.code, originCity: origin.city,
                        destCode: route.destinationCode, destCity: route.destinationName,
                        duration: route.durationLabel, category: route.category,
                        ink: ink, inkSoft: inkSoft)
            .frame(height: 150)
            .background(paper)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: AppSpacing.cardRadius,
                                              bottomLeadingRadius: 0, bottomTrailingRadius: 0,
                                              topTrailingRadius: AppSpacing.cardRadius, style: .continuous))
            .overlay(alignment: .bottomLeading) { notch.offset(x: -9, y: 9) }
            .overlay(alignment: .bottomTrailing) { notch.offset(x: 9, y: 9) }
            .compositingGroup()
            .shadow(color: .black.opacity(0.4), radius: 18, x: 0, y: 10)
    }

    private var bottomCard: some View {
        ticketDetails
            .background(paper)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0,
                                              bottomLeadingRadius: AppSpacing.cardRadius,
                                              bottomTrailingRadius: AppSpacing.cardRadius,
                                              topTrailingRadius: 0, style: .continuous))
            .overlay(alignment: .topLeading) { notch.offset(x: -9, y: -9) }
            .overlay(alignment: .topTrailing) { notch.offset(x: 9, y: -9) }
            .compositingGroup()
            .shadow(color: .black.opacity(0.4), radius: 18, x: 0, y: 10)
    }

    private var notch: some View {
        Circle().fill(Color.black).frame(width: 18, height: 18).blendMode(.destinationOut)
    }

    // A thin perforation line; the tear gap opens as the bottom card slides down.
    private var perforation: some View {
        DashLine()
            .stroke(inkSoft.opacity(0.45), style: StrokeStyle(lineWidth: 1.2, dash: [4, 5]))
            .frame(height: 1)
            .padding(.horizontal, AppSpacing.md)
            .background(paper.opacity(torn ? 0 : 1))
    }

    private var ticketDetails: some View {
        VStack(spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                ZStack {
                    Circle().fill((focus?.accent ?? inkSoft).opacity(0.16)).frame(width: 36, height: 36)
                    Image(systemName: focus?.systemImage ?? "target")
                        .font(.system(size: 15, weight: .bold))
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

            Rectangle().fill(ink.opacity(0.08)).frame(height: 1)

            HStack(spacing: 0) {
                detail("DURATION", route.durationLabel)
                detail("DISTANCE", Formatters.distance(km: distanceKm))
                detail("DATE", Self.dateText)
            }

            HStack(spacing: AppSpacing.sm) {
                BarcodeStrip(seed: origin.code + route.id + route.destinationCode,
                             barColor: ink, scanIn: barcodeIn)
                    .frame(height: 40)
                QRBlock(seed: route.id, color: ink).frame(width: 40, height: 40)
            }
        }
        .padding(AppSpacing.md)
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

// MARK: - Ticket sky header (universal, no per-destination art)

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
            LinearGradient(colors: [Color(hex: 0xBFD8F0), Color(hex: 0xEADFCB)],
                           startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xFCEAC6), .clear],
                                     center: .center, startRadius: 2, endRadius: 70))
                .frame(width: 140, height: 140)
                .offset(x: 116, y: -48)
            TicketHills().fill(Color.white.opacity(0.40)).offset(y: 34)
            TicketHills().fill(Color.white.opacity(0.24)).scaleEffect(x: -1).offset(y: 50)

            BalloonMark(size: 26).offset(x: -120, y: -20).opacity(0.95)
            BalloonMark(size: 18).offset(x: 96, y: -38).opacity(0.85)
            BalloonMark(size: 13).offset(x: 30, y: -50).opacity(0.7)

            VStack {
                HStack {
                    Text("FocusGlobe · Boarding Pass")
                        .font(.system(size: 10, weight: .semibold, design: .rounded)).tracking(0.5)
                        .foregroundStyle(ink.opacity(0.8))
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: category.systemImage).font(.system(size: 9, weight: .bold))
                        Text(category.displayName).font(.system(size: 10, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(ink)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.55)))
                }
                Spacer()
                HStack(alignment: .center) {
                    codeBlock(originCode, originCity, .leading)
                    Spacer(minLength: AppSpacing.xs)
                    VStack(spacing: 2) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(ink.opacity(0.85))
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
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(ink)               // both codes share the same ink colour
                .minimumScaleFactor(0.7).lineLimit(1)
            Text(city)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(inkSoft).lineLimit(1)
        }
    }
}

private struct TicketHills: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.midY + 12),
                       control: CGPoint(x: rect.width * 0.25, y: rect.midY - 18))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY + 6),
                       control: CGPoint(x: rect.width * 0.75, y: rect.midY + 24))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Focus chip

private struct FocusChip: View {
    let preset: FocusPreset
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                ZStack {
                    Circle().fill(selected ? Color.white.opacity(0.25) : preset.accent.opacity(0.22))
                        .frame(width: 26, height: 26)
                    Image(systemName: preset.systemImage)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(selected ? .white : preset.accent)
                }
                Text(preset.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.leading, 6).padding(.trailing, AppSpacing.sm)
            .padding(.vertical, 7)
            .background {
                if selected {
                    Capsule().fill(preset.accent)
                } else {
                    Capsule().fill(.ultraThinMaterial)
                        .overlay(Capsule().fill(Color.black.opacity(0.25)))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                }
            }
        }
        .buttonStyle(SoftPressStyle())
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

/// A deterministic boarding-pass barcode (dark bars on paper) with a one-time
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
