import SwiftUI

/// A **sky** the balloon flies through — the landscape is the protagonist.
///
/// Each sky is a stack of altitude *bands* (ground → high sky). `SkySceneView`
/// crossfades between adjacent bands as `progress` (0…1) rises, layers a
/// deterministic star field, slow-drifting clouds and a ground silhouette, and
/// stays cheap: gradients + one small Canvas + a TimelineView for drift. Works
/// for any session length (progress is normalized) and for Infinity mode
/// (progress loops gracefully via `loopedProgress`).
struct SkyScene: Identifiable, Equatable {
    let id: String
    let name: String
    /// Session mood/theme recorded into history & Passport for this sky.
    let mood: RouteMood
    let theme: RouteTheme
    /// Altitude bands, low → high. Each band is a top→bottom gradient.
    let bands: [[Color]]
    /// 0…1 — how starry the upper bands are.
    let starDensity: Double
    /// Cloud tint for this sky.
    let cloudColor: Color
    /// Ground/mountain silhouette colour.
    let groundColor: Color
    /// Warm glow (sun/moon) colour + vertical anchor (0 top … 1 bottom).
    let glowColor: Color
    let glowY: CGFloat

    static func == (l: SkyScene, r: SkyScene) -> Bool { l.id == r.id }

    // MARK: The launch set — three polished free skies.

    /// Dark-to-soft morning; distant mountains; calm.
    static let silentDawn = SkyScene(
        id: "sky-silent-dawn", name: "Silent Dawn", mood: .sunrise, theme: .lavender,
        bands: [
            [Color(hex: 0x1A1B26), Color(hex: 0x3A3350), Color(hex: 0x8A5F6E)],
            [Color(hex: 0x141622), Color(hex: 0x4A3F63), Color(hex: 0xC98A7A)],
            [Color(hex: 0x0E1120), Color(hex: 0x323052), Color(hex: 0x8A6E8E)],
            [Color(hex: 0x080A14), Color(hex: 0x1E2138), Color(hex: 0x4A4468)],
        ],
        starDensity: 0.35, cloudColor: Color(hex: 0xC9B8C4),
        groundColor: Color(hex: 0x11131E), glowColor: Color(hex: 0xE8A98A), glowY: 0.86)

    /// Warm orange/gold; soft sun glow; big cozy clouds.
    static let goldenHour = SkyScene(
        id: "sky-golden-hour", name: "Golden Hour", mood: .sunset, theme: .gold,
        bands: [
            [Color(hex: 0x2A160E), Color(hex: 0x7E3E20), Color(hex: 0xE8964E)],
            [Color(hex: 0x231208), Color(hex: 0x8A4A1E), Color(hex: 0xF0B168)],
            [Color(hex: 0x180D08), Color(hex: 0x5E3418), Color(hex: 0xC98A52)],
            [Color(hex: 0x0E0806), Color(hex: 0x33200F), Color(hex: 0x7E5630)],
        ],
        starDensity: 0.12, cloudColor: Color(hex: 0xF2C89A),
        groundColor: Color(hex: 0x160C07), glowColor: Color(hex: 0xF6C878), glowY: 0.8)

    /// Night sky; stars; subtle galaxy; moon glow.
    static let starfield = SkyScene(
        id: "sky-starfield", name: "Starfield", mood: .night, theme: .indigo,
        bands: [
            [Color(hex: 0x0A0D14), Color(hex: 0x131B2A), Color(hex: 0x27374E)],
            [Color(hex: 0x070A10), Color(hex: 0x101827), Color(hex: 0x1E2C42)],
            [Color(hex: 0x05070C), Color(hex: 0x0B111E), Color(hex: 0x162238)],
            [Color(hex: 0x030408), Color(hex: 0x070B14), Color(hex: 0x0E1626)],
        ],
        starDensity: 1.0, cloudColor: Color(hex: 0x8A97B2),
        groundColor: Color(hex: 0x05070A), glowColor: Color(hex: 0xDCE4F2), glowY: 0.24)

    static let all: [SkyScene] = [silentDawn, goldenHour, starfield]

    /// Today's sky, chosen by local time of day — dawn mornings, gold days and
    /// evenings, stars at night.
    static func today(date: Date = Date()) -> SkyScene {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11:  return .silentDawn
        case 11..<20: return .goldenHour
        default:      return .starfield
        }
    }

    /// Infinity mode: progress keeps climbing, so fold it into a gentle 0…1…0
    /// wave — the flight drifts up through the bands and softly back, forever.
    static func loopedProgress(_ raw: Double) -> Double {
        let t = raw.truncatingRemainder(dividingBy: 2)
        return t <= 1 ? t : 2 - t
    }
}

// MARK: - The scene view

/// Renders a `SkyScene` at a given flight `progress` (0…1). Pure gradients +
/// one static Canvas of stars + a few drifting cloud blobs — no maps, no heavy
/// assets, smooth on old devices.
struct SkySceneView: View {
    let scene: SkyScene
    var progress: Double = 0
    /// Drive slow ambient drift (clouds/glow breathing). Off for static previews.
    var animated: Bool = true
    /// Show the ground/mountain silhouette (fades out as the flight climbs).
    var showsGround: Bool = true

    var body: some View {
        ZStack {
            bandGradient
            glow
            stars
            if animated {
                TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
                    clouds(time: context.date.timeIntervalSinceReferenceDate)
                }
            } else {
                clouds(time: 0)
            }
            if showsGround { ground }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // Crossfade between the two bands around the current altitude.
    private var bandGradient: some View {
        let clamped = min(1, max(0, progress))
        let pos = clamped * Double(scene.bands.count - 1)
        let low = min(scene.bands.count - 1, Int(pos))
        let high = min(scene.bands.count - 1, low + 1)
        let frac = pos - Double(low)
        return ZStack {
            LinearGradient(colors: scene.bands[low].reversed(), startPoint: .top, endPoint: .bottom)
            LinearGradient(colors: scene.bands[high].reversed(), startPoint: .top, endPoint: .bottom)
                .opacity(frac)
        }
    }

    private var glow: some View {
        GeometryReader { geo in
            RadialGradient(colors: [scene.glowColor.opacity(0.5), scene.glowColor.opacity(0.14), .clear],
                           center: .center, startRadius: 6, endRadius: geo.size.width * 0.75)
                .frame(width: geo.size.width * 1.4, height: geo.size.width * 1.4)
                .position(x: geo.size.width * 0.72,
                          // The glow sinks as you climb — the light source falls away below.
                          y: geo.size.height * (scene.glowY + CGFloat(progress) * 0.3))
                .blur(radius: 18)
        }
    }

    // Deterministic star field; stars strengthen with altitude and density.
    private var stars: some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: 0x57A2_F1E1)
            let count = Int(90 * scene.starDensity) + 14
            let strength = 0.25 + progress * 0.75
            for _ in 0..<count {
                let x = rng.unit() * size.width
                let y = rng.unit() * size.height
                let r = 0.5 + rng.unit() * 1.1
                let a = (0.25 + rng.unit() * 0.6) * strength * scene.starDensity
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(a)))
            }
        }
        .opacity(0.9)
    }

    // A few soft cloud blobs drifting sideways; they sink as the flight climbs
    // (you rise *through* them) and park at fixed offsets when not animated.
    private func clouds(time: TimeInterval) -> some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ForEach(0..<4, id: \.self) { i in
                let fi = CGFloat(i)
                let speed = 14.0 + Double(i) * 7
                let drift = animated ? CGFloat((time * speed).truncatingRemainder(dividingBy: Double(w + 300))) : fi * 90
                let baseY = h * (0.24 + fi * 0.18)
                Ellipse()
                    .fill(scene.cloudColor.opacity(0.10 + Double(i % 2) * 0.05))
                    .frame(width: w * (0.55 + fi * 0.12), height: 46 + fi * 16)
                    .blur(radius: 22)
                    .position(x: drift - 150, y: baseY + CGFloat(progress) * h * 0.35 * (fi.truncatingRemainder(dividingBy: 2) == 0 ? 1 : 0.6))
            }
        }
    }

    // Ground / distant mountains — slides away below as the balloon rises.
    private var ground: some View {
        GeometryReader { geo in
            let h = geo.size.height
            MountainSilhouette()
                .fill(scene.groundColor)
                .frame(height: h * 0.3)
                .offset(y: h * 0.78 + CGFloat(progress) * h * 0.6)
                .opacity(1 - min(1, progress * 1.6))
        }
    }
}

/// A calm, jagged mountain/horizon silhouette (deterministic).
struct MountainSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        var rng = SeededRNG(seed: 0x40C4_A11A)
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        var x = rect.minX
        let step = rect.width / 9
        while x < rect.maxX {
            let peakY = rect.minY + CGFloat(rng.unit()) * rect.height * 0.55
            p.addLine(to: CGPoint(x: x + step / 2, y: peakY))
            p.addLine(to: CGPoint(x: x + step, y: rect.midY + CGFloat(rng.unit() - 0.5) * rect.height * 0.2))
            x += step
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
