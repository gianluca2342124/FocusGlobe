import SwiftUI

/// The **Expedition Page** — a cream journal page the traveller signs before
/// setting off. It replaces the old boarding-pass ticket entirely: the
/// destination in serif, a hand-drawn dotted route between the two city *names*
/// (no airport codes, no barcode), the date and focus written as ink stamps, and
/// the trip as field-journal entries.
///
/// Setting off presses a red **wax seal** onto the lower-right of the page (a
/// scale-down impact + page shake + heavy haptic + soft thud), then begins the
/// expedition through the *exact same* session-start path as before
/// (`router.startJourney`). No timer/session logic changed — only the surface.
struct BoardingView: View {
    let route: Route

    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedPreset: FocusPreset?
    @State private var appeared = false
    @State private var sealed = false
    @State private var sealScale: CGFloat = 2.4
    @State private var pageShake: CGFloat = 0
    @State private var pageImage: Image?

    /// `route` is required; `preselectedFocus` carries the focus chosen on the
    /// pre-boarding ritual so the page arrives pre-filled.
    init(route: Route, preselectedFocus: FocusPreset? = nil) {
        self.route = route
        _selectedPreset = State(initialValue: preselectedFocus)
    }

    private var origin: JourneyOrigin { appModel.originForJourney }
    private var distanceKm: Double { GeoMath.distanceKm(from: origin.coordinate, to: route.destination) }

    /// A cosmetic "expedition number" for the page — completed expeditions + 1.
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
                               distanceKm: distanceKm, focus: selectedPreset,
                               sealed: sealed, sealScale: sealScale)
                    .frame(maxWidth: Layout.pad(420, 560))
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

    // Linear flow: focus is chosen in the pre-boarding ritual, so there is no
    // back button here — only the centred title.
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

    // MARK: Controls — seal the page (launch) + save (share)

    private var controls: some View {
        VStack(spacing: AppSpacing.sm) {
            ExpeditionButton(title: sealed ? "Setting off…" : "Seal the page",
                             systemImage: "seal.fill", isEnabled: !sealed) {
                setOff()
            }
            if let pageImage {
                ShareLink(item: pageImage,
                          preview: SharePreview("My Expedition Page", image: pageImage)) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 14, weight: .semibold))
                        Text("Save page").font(.system(size: 13, weight: .medium, design: .serif))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.vertical, 4)
                }
                .buttonStyle(SoftPressStyle())
            }
        }
        .clusterMaxWidth()
    }

    // MARK: Set off — the wax-seal ritual, then the real session start

    private func setOff() {
        guard !sealed else { return }
        appModel.haptics.takeoff()                 // heavy, weighty impact
        appModel.uiSound.play(.ticketTear)         // soft thud
        withAnimation((AppMotion.sealImpact).respecting(reduceMotion)) {
            sealed = true
            sealScale = 1
        }
        if !reduceMotion { shakePage() }
        // Then begin the expedition through the exact same code path as before.
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.2 : 0.9)) {
            router.startJourney(origin: origin, route: route, intention: selectedPreset?.title)
        }
    }

    private func shakePage() {
        let seq: [CGFloat] = [-6, 5, -3, 2, 0]
        for (i, dx) in seq.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26 + Double(i) * 0.05) {
                withAnimation(.easeInOut(duration: 0.05)) { pageShake = dx }
            }
        }
    }

    /// Render the sealed page to an image once, so "Save page" can share it.
    @MainActor private func renderSharePage() {
        let snapshot = ExpeditionPage(number: expeditionNumber, origin: origin, route: route,
                                      distanceKm: distanceKm, focus: selectedPreset,
                                      sealed: true, sealScale: 1)
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
    let sealed: Bool
    let sealScale: CGFloat

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
            // The wax seal presses onto the lower-right corner of the page.
            WaxSeal(symbol: "location.north.line.fill", diameter: 74)
                .scaleEffect(sealed ? 1 : sealScale)
                .opacity(sealed ? 1 : 0)
                .rotationEffect(.degrees(sealed ? -8 : 0))
                .padding(22)
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

    // Origin → destination, by name, joined by a hand-drawn dotted arc.
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
