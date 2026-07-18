import SwiftUI
import UIKit

/// The **Expedition Page** — a cream journal page the traveller signs before
/// setting off: destination in serif, a hand-drawn dotted route between the two
/// city *names* (no airport codes, no barcode), date + focus as ink stamps.
///
/// The signature moment is the **wax seal**. A stamp handle rests at the page's
/// lower-right corner; the user **presses and holds** it — building haptic ticks
/// while it rises and tilts — and on release it SLAMS down: impact, page shake,
/// wax splat, heavy haptic and a soft thud. Then the expedition begins through the
/// *exact same* session-start path as before (`router.startJourney`). Reduce Motion
/// / VoiceOver fall back to a single tap. No timer/session logic changed.
struct BoardingView: View {
    let route: Route

    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    @State private var selectedPreset: FocusPreset?
    @State private var appeared = false

    // Seal interaction state.
    @State private var sealed = false
    @State private var holdProgress: CGFloat = 0   // 0…1 while pressing
    @State private var splat: CGFloat = 0          // wax spread on impact
    @State private var pageShake: CGFloat = 0
    @State private var showHint = true
    @State private var holdTicks: [DispatchWorkItem] = []
    @State private var pageImage: Image?

    init(route: Route, preselectedFocus: FocusPreset? = nil) {
        self.route = route
        _selectedPreset = State(initialValue: preselectedFocus)
    }

    private var origin: JourneyOrigin { appModel.originForJourney }
    private var distanceKm: Double { GeoMath.distanceKm(from: origin.coordinate, to: route.destination) }
    private var expeditionNumber: Int { appModel.history.filter(\.completed).count + 1 }

    var body: some View {
        ZStack {
            JourneyBackdropMap(origin: origin, destination: route, mode: .route,
                               progress: 0.32, showsBalloon: false)
                .ignoresSafeArea()

            scrims

            VStack(spacing: AppSpacing.md) {
                topBar
                Spacer(minLength: AppSpacing.xs)
                ExpeditionPage(number: expeditionNumber, origin: origin, route: route,
                               distanceKm: distanceKm, focus: selectedPreset, showSeal: false)
                    .frame(maxWidth: Layout.pad(420, 560))
                    .overlay(alignment: .bottomTrailing) { sealArea }
                    .offset(x: pageShake)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 26)
                Spacer()
                controls
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.lg)
        }
        .focusScreenChrome()
        .onAppear {
            appModel.analytics.log(.journeyPassViewed, ["route": route.id])
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { renderSharePage() }
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
            Color.clear.frame(width: 44, height: 44)
            Spacer()
            Text("Set Off")
                .font(.system(size: Layout.pad(19, 22), weight: .semibold, design: .serif))
                .foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
    }

    // MARK: The interactive wax seal

    private var sealArea: some View {
        ZStack {
            // Wax splat under the seal — spreads on impact.
            Circle()
                .fill(RadialGradient(colors: [AppColors.waxSeal.opacity(0.85), AppColors.waxSeal.opacity(0.32)],
                                     center: .center, startRadius: 1, endRadius: 44))
                .frame(width: 86, height: 86)
                .scaleEffect(splat)
                .opacity(Double(splat))
                .blur(radius: 2)

            // The seal: hovers + rises/tilts while held, then slams down on release.
            WaxSeal(symbol: "location.north.line.fill", diameter: 66)
                .scaleEffect(sealed ? 1 : 1 + holdProgress * 0.06)
                .rotationEffect(.degrees(sealed ? -8 : holdProgress * -12))
                .offset(y: sealed ? 0 : -(26 + holdProgress * 30))
                .shadow(color: .black.opacity(0.35),
                        radius: sealed ? 4 : 10 + holdProgress * 8,
                        y: sealed ? 3 : 12 + holdProgress * 8)
                .contentShape(Circle())
                .onLongPressGesture(minimumDuration: 0.7, maximumDistance: 90,
                                    pressing: { handlePressing($0) },
                                    perform: { completeSeal() })
                .onTapGesture { if reduceMotion || voiceOver { completeSeal() } }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Wax seal — set off")
                .accessibilityHint("Double-tap to seal the page and begin the expedition")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { completeSeal() }

            if showHint && !sealed {
                Text("hold to seal")
                    .font(.system(size: 11, weight: .regular, design: .serif)).italic()
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                    .offset(y: 42)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 120, height: 120)
        .padding(4)
    }

    private func handlePressing(_ isPressing: Bool) {
        guard !sealed else { return }
        if isPressing {
            showHint = false
            withAnimation(.easeOut(duration: 0.7)) { holdProgress = 1 }
            scheduleTicks()
        } else {
            cancelTicks()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { holdProgress = 0 }
        }
    }

    /// Building haptic ticks over the hold — soft, then firmer.
    private func scheduleTicks() {
        cancelTicks()
        guard !reduceMotion else { return }
        let gen = UIImpactFeedbackGenerator(style: .rigid)
        gen.prepare()
        for i in 1...6 {
            let item = DispatchWorkItem { gen.impactOccurred(intensity: CGFloat(min(1.0, 0.35 + Double(i) * 0.11))) }
            holdTicks.append(item)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.11, execute: item)
        }
    }

    private func cancelTicks() {
        holdTicks.forEach { $0.cancel() }
        holdTicks = []
    }

    /// The slam: impact, splat, page shake, heavy haptic, thud → then set off.
    private func completeSeal() {
        guard !sealed else { return }
        cancelTicks()
        showHint = false
        appModel.haptics.takeoff()             // heavy, weighty impact
        appModel.uiSound.play(.ticketTear)     // soft thud
        withAnimation(AppMotion.sealImpact.respecting(reduceMotion)) {
            sealed = true
            splat = 1
            holdProgress = 0
        }
        if !reduceMotion { shakePage() }
        // Then begin the expedition through the exact same code path as before.
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.2 : 0.85)) {
            router.raiseTakeoffCurtain()
            router.startJourney(origin: origin, route: route, intention: selectedPreset?.title)
        }
    }

    private func shakePage() {
        let seq: [CGFloat] = [-6, 5, -3, 2, 0]
        for (i, dx) in seq.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06 + Double(i) * 0.05) {
                withAnimation(.easeInOut(duration: 0.05)) { pageShake = dx }
            }
        }
    }

    // MARK: Controls — share the page

    private var controls: some View {
        VStack(spacing: AppSpacing.sm) {
            if let pageImage {
                ShareLink(item: pageImage,
                          preview: SharePreview("My Expedition Page", image: pageImage)) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 14, weight: .semibold))
                        Text("Share").font(.system(size: 14, weight: .medium, design: .serif))
                    }
                    .foregroundStyle(.white.opacity(0.88))
                    .padding(.vertical, 6)
                }
                .buttonStyle(SoftPressStyle())
            }
        }
        .clusterMaxWidth()
    }

    /// Render the sealed page to an image once, so "Share" can export it.
    @MainActor private func renderSharePage() {
        let snapshot = ExpeditionPage(number: expeditionNumber, origin: origin, route: route,
                                      distanceKm: distanceKm, focus: selectedPreset, showSeal: true)
            .frame(width: 360)
            .padding(24)
            .background(Color(hex: 0xEADFC4))
        let renderer = ImageRenderer(content: snapshot)
        renderer.scale = 3
        if let ui = renderer.uiImage { pageImage = Image(uiImage: ui) }
    }
}

// MARK: - The Expedition Page

private struct ExpeditionPage: View {
    let number: Int
    let origin: JourneyOrigin
    let route: Route
    let distanceKm: Double
    let focus: FocusPreset?
    /// Draw a static wax seal on the page (used only for the shareable snapshot;
    /// the live page shows the *interactive* seal overlaid by `BoardingView`).
    var showSeal: Bool = false

    private let paper = Color(hex: 0xF5EFE2)
    private let ink   = Color(hex: 0x2B2620)
    private let sepia = Color(hex: 0x8A6F4D)
    private let terra = Color(hex: 0xC4633F)

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            header
            destinationBlock
            routeSketch
            TornPaperDivider()
            entries
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(paper)
                .overlay(PaperGrain(intensity: 0.7).clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous)))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(ink.opacity(0.18), lineWidth: 1))
        }
        .overlay(alignment: .bottomTrailing) {
            if showSeal {
                WaxSeal(symbol: "location.north.line.fill", diameter: 74)
                    .rotationEffect(.degrees(-8))
                    .padding(22)
            }
        }
        .shadow(color: .black.opacity(0.4), radius: 18, y: 10)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("EXPEDITION")
                    .font(.system(size: 11, weight: .semibold, design: .serif)).tracking(3)
                    .foregroundStyle(sepia)
                Text("No. \(number)")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(ink)
            }
            Spacer()
            InkStamp(text: Self.dateText, color: terra, rotation: 6)
        }
    }

    private var destinationBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Destination")
                .font(.system(size: 12, weight: .regular, design: .serif)).italic()
                .foregroundStyle(sepia)
            Text(route.destinationName)
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(ink)
                .lineLimit(2).minimumScaleFactor(0.7)
        }
    }

    private var routeSketch: some View {
        HStack(spacing: 8) {
            Circle().fill(terra).frame(width: 9, height: 9)
            Text(origin.city)
                .font(.system(size: 13, weight: .medium, design: .serif))
                .foregroundStyle(ink).lineLimit(1)
            DottedRoute()
                .stroke(sepia.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [2, 4]))
                .frame(height: 14).frame(maxWidth: .infinity)
            Text(route.destinationName)
                .font(.system(size: 13, weight: .medium, design: .serif))
                .foregroundStyle(ink).lineLimit(1)
            Image(systemName: "mappin.circle.fill").font(.system(size: 13)).foregroundStyle(terra)
        }
    }

    private var entries: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                entry("Duration", route.durationLabel)
                entry("Distance", Formatters.distance(km: distanceKm))
            }
            HStack(spacing: AppSpacing.sm) {
                Text("Bringing aboard")
                    .font(.system(size: 12, weight: .regular, design: .serif)).italic()
                    .foregroundStyle(sepia)
                InkStamp(text: focus?.title ?? "—", color: ink, rotation: -4)
                Spacer()
            }
        }
    }

    private func entry(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .regular, design: .serif)).italic()
                .foregroundStyle(sepia)
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(ink)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static let dateText: String = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        return f.string(from: Date())
    }()
}

/// A gentle hand-drawn arc for the dotted route between two places.
private struct DottedRoute: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY),
                       control: CGPoint(x: rect.midX, y: rect.minY))
        return p
    }
}
