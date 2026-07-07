import Foundation
import SwiftUI

/// A **sky** the balloon flies through — the landscape is the protagonist.
///
/// A sky is a set of altitude *stages* (ground → deep space). `SkySceneView`
/// renders a living, parallax world: crossfading atmospheric gradients, a sinking
/// sun/moon, drifting aurora ribbons, layered organic mountains and cloud banks
/// that scroll *downward* (so the balloon appears to rise), a fading star field
/// and ambient particles. It's driven by a continuous `climb` value so it feels
/// alive even at slow progress, and it wraps forever for long / Infinity flights.
/// Cheap: gradients + Canvas + one TimelineView, no image assets.
struct SkyScene: Identifiable, Equatable {
    let id: String
    let name: String
    let mood: RouteMood
    let theme: RouteTheme
    /// Atmosphere stages, low → high (each a top→bottom gradient of 3 colours).
    let stages: [[Color]]
    let starDensity: Double
    let cloudColor: Color
    let mountainColor: Color
    let glowColor: Color
    let auroraColor: Color?

    static func == (l: SkyScene, r: SkyScene) -> Bool { l.id == r.id }

    // MARK: The launch set — three polished, distinct skies.

    static let silentDawn = SkyScene(
        id: "sky-silent-dawn", name: "Silent Dawn", mood: .sunrise, theme: .lavender,
        stages: [
            [Color(hex: 0x241C2C), Color(hex: 0x4A3A5A), Color(hex: 0xB47C7E)],   // ground/dawn
            [Color(hex: 0x1C1830), Color(hex: 0x50436E), Color(hex: 0xD79A82)],   // low warm
            [Color(hex: 0x171634), Color(hex: 0x3A3A66), Color(hex: 0x9A7EA0)],   // mid
            [Color(hex: 0x0E0E24), Color(hex: 0x26264C), Color(hex: 0x5A5488)],   // high blue
            [Color(hex: 0x080A1A), Color(hex: 0x16183A), Color(hex: 0x2E3060)],   // night edge
            [Color(hex: 0x05060F), Color(hex: 0x0B0E22), Color(hex: 0x181C3C)],   // stars
        ],
        starDensity: 0.45, cloudColor: Color(hex: 0xD8C4CE),
        mountainColor: Color(hex: 0x171526), glowColor: Color(hex: 0xF0AA88), auroraColor: nil)

    static let goldenHour = SkyScene(
        id: "sky-golden-hour", name: "Golden Hour", mood: .sunset, theme: .gold,
        stages: [
            [Color(hex: 0x321A10), Color(hex: 0x8A4A22), Color(hex: 0xEC9A50)],
            [Color(hex: 0x2A1509), Color(hex: 0x944E1E), Color(hex: 0xF4B76C)],
            [Color(hex: 0x1E1109), Color(hex: 0x6E3C1A), Color(hex: 0xD8944E)],
            [Color(hex: 0x140C0A), Color(hex: 0x3E2814), Color(hex: 0x8A6038)],
            [Color(hex: 0x0C0810), Color(hex: 0x241A24), Color(hex: 0x4A3A52)],
            [Color(hex: 0x06060E), Color(hex: 0x0E0E1E), Color(hex: 0x1C2038)],
        ],
        starDensity: 0.2, cloudColor: Color(hex: 0xF4CE9E),
        mountainColor: Color(hex: 0x180C08), glowColor: Color(hex: 0xF8CE80), auroraColor: nil)

    static let starfield = SkyScene(
        id: "sky-starfield", name: "Starfield", mood: .night, theme: .indigo,
        stages: [
            [Color(hex: 0x0C1020), Color(hex: 0x172440), Color(hex: 0x2C4468)],
            [Color(hex: 0x090C1A), Color(hex: 0x101E38), Color(hex: 0x203858)],
            [Color(hex: 0x06080F), Color(hex: 0x0C1428), Color(hex: 0x162844)],
            [Color(hex: 0x04050B), Color(hex: 0x080E1E), Color(hex: 0x0E1C34)],
            [Color(hex: 0x030409), Color(hex: 0x060A16), Color(hex: 0x0A1428)],
            [Color(hex: 0x020308), Color(hex: 0x040713), Color(hex: 0x081022)],
        ],
        starDensity: 1.0, cloudColor: Color(hex: 0x92A0BE),
        mountainColor: Color(hex: 0x05070E), glowColor: Color(hex: 0xE2E9F6),
        auroraColor: Color(hex: 0x54E6B0))

    static let all: [SkyScene] = [silentDawn, goldenHour, starfield]

    /// Today's sky by local time — dawn mornings, gold days/evenings, stars night.
    static func today(date: Date = Date()) -> SkyScene {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<11:  return .silentDawn
        case 11..<20: return .goldenHour
        default:      return .starfield
        }
    }

    /// Infinity: fold the ever-climbing progress into a gentle up-and-back wave so
    /// the flight drifts through the stages forever without a dead end.
    static func loopedProgress(_ raw: Double) -> Double {
        let t = raw.truncatingRemainder(dividingBy: 2)
        return t <= 1 ? t : 2 - t
    }
}

// MARK: - The living world

/// Renders a `SkyScene` at flight `progress` (0…1). The world scrolls downward
/// (parallax) so the balloon reads as rising; ambient drift keeps it alive even
/// when progress barely moves.
struct SkySceneView: View {
    let scene: SkyScene
    var progress: Double = 0
    /// Ambient motion (drift/scroll). Off for static previews / Reduce Motion.
    var animated: Bool = true
    /// Show the near ground line (Home / pre-flight). Auto-fades as you climb.
    var showsGround: Bool = true

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                atmosphere
                if animated {
                    TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { ctx in
                        world(size: size, time: ctx.date.timeIntervalSinceReferenceDate)
                    }
                } else {
                    world(size: size, time: 0)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // Crossfading atmosphere between the two stages around the current altitude.
    private var atmosphere: some View {
        let clamped = min(1, max(0, progress))
        let pos = clamped * Double(scene.stages.count - 1)
        let low = min(scene.stages.count - 1, Int(pos))
        let high = min(scene.stages.count - 1, low + 1)
        let frac = pos - Double(low)
        return ZStack {
            LinearGradient(colors: scene.stages[low].reversed(), startPoint: .top, endPoint: .bottom)
            LinearGradient(colors: scene.stages[high].reversed(), startPoint: .top, endPoint: .bottom)
                .opacity(frac)
        }
    }

    // All moving layers, composited with parallax.
    private func world(size: CGSize, time: TimeInterval) -> some View {
        // Continuous downward "climb": always-moving ambient + real progress shift.
        let base = animated ? time * 26 : 0
        let climb = base + progress * size.height * 2.6
        let alt = min(1, max(0, progress))

        return ZStack {
            glow(size: size, alt: alt)
            starLayer(size: size, alt: alt)
            if let aurora = scene.auroraColor {
                auroraLayer(size: size, time: time, color: aurora, alt: alt)
            }
            cloudBank(size: size, climb: climb, speed: 0.35, count: 5, scale: 1.3, opacity: 0.10, alt: alt)   // far clouds
            mountains(size: size, climb: climb, speed: 0.5, yBase: 0.62, height: 0.30,
                      color: scene.mountainColor.opacity(0.9), alt: alt)                                     // far ridge
            mountains(size: size, climb: climb, speed: 0.9, yBase: 0.78, height: 0.36,
                      color: scene.mountainColor, alt: alt)                                                  // near ridge
            cloudBank(size: size, climb: climb, speed: 1.5, count: 4, scale: 1.0, opacity: 0.16, alt: alt)   // near clouds
            particles(size: size, time: time, alt: alt)
        }
    }

    // Sun/moon glow that sinks below as you climb.
    private func glow(size: CGSize, alt: Double) -> some View {
        RadialGradient(colors: [scene.glowColor.opacity(0.55), scene.glowColor.opacity(0.12), .clear],
                       center: .center, startRadius: 4, endRadius: size.width * 0.7)
            .frame(width: size.width * 1.3, height: size.width * 1.3)
            .position(x: size.width * 0.7, y: size.height * (0.32 + alt * 0.6))
            .blur(radius: 16)
    }

    // Deterministic star field; fades in with altitude.
    private func starLayer(size: CGSize, alt: Double) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: 0x57A2_F1E1)
            let count = Int(120 * scene.starDensity) + 16
            let strength = 0.2 + alt * 0.8
            for _ in 0..<count {
                let x = rng.unit() * s.width
                let y = rng.unit() * s.height
                let r = 0.4 + rng.unit() * 1.3
                let tw = 0.6 + rng.unit() * 0.4
                let a = (0.2 + rng.unit() * 0.6) * strength * scene.starDensity * tw
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(a)))
            }
        }
    }

    // Soft aurora ribbons drifting near the top of the high sky.
    private func auroraLayer(size: CGSize, time: TimeInterval, color: Color, alt: Double) -> some View {
        Canvas { ctx, s in
            for band in 0..<2 {
                var path = Path()
                let yBase = s.height * (0.16 + CGFloat(band) * 0.1)
                let amp = s.height * 0.05
                let phase = time * (0.4 + Double(band) * 0.2)
                path.move(to: CGPoint(x: 0, y: yBase))
                var x: CGFloat = 0
                while x <= s.width {
                    let y = yBase + CGFloat(sin(Double(x) / 90 + phase)) * amp
                    path.addLine(to: CGPoint(x: x, y: y))
                    x += 12
                }
                path.addLine(to: CGPoint(x: s.width, y: yBase + 60))
                path.addLine(to: CGPoint(x: 0, y: yBase + 60))
                path.closeSubpath()
                ctx.fill(path, with: .linearGradient(
                    Gradient(colors: [color.opacity(0.0), color.opacity(0.22 * alt), color.opacity(0.0)]),
                    startPoint: CGPoint(x: 0, y: yBase - 20),
                    endPoint: CGPoint(x: 0, y: yBase + 60)))
            }
        }
        .blur(radius: 10)
        .opacity(alt)
    }

    // A bank of soft cloud blobs, wrapping vertically as the world scrolls down.
    private func cloudBank(size: CGSize, climb: Double, speed: Double, count: Int,
                           scale: CGFloat, opacity: Double, alt: Double) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: UInt64(0xC10D_0000 + Int(speed * 1000)))
            let wrap = s.height + 200
            for _ in 0..<count {
                let cx = rng.unit() * s.width
                let baseY = rng.unit() * wrap
                let w = (s.width * (0.4 + rng.unit() * 0.4)) * scale
                let h = w * 0.32
                // Scroll down + wrap.
                let y = (baseY + CGFloat(climb * speed)).truncatingRemainder(dividingBy: wrap) - 100
                var blob = Path()
                blob.addEllipse(in: CGRect(x: cx - w / 2, y: y - h / 2, width: w, height: h))
                blob.addEllipse(in: CGRect(x: cx - w * 0.2, y: y - h * 0.8, width: w * 0.6, height: h))
                ctx.fill(blob, with: .color(scene.cloudColor.opacity(opacity + alt * 0.03)))
            }
        }
        .blur(radius: 14 * scale)
    }

    // Layered organic mountains — smooth curved ridgelines (no bare triangles),
    // scrolling down and fading as the flight climbs above them.
    private func mountains(size: CGSize, climb: Double, speed: Double, yBase: CGFloat,
                           height: CGFloat, color: Color, alt: Double) -> some View {
        let wrap = size.height * 1.4
        let offset = CGFloat((climb * speed).truncatingRemainder(dividingBy: Double(wrap)))
        return ZStack {
            RidgeShape(seed: UInt64(speed * 777), height: height)
                .fill(color)
                .frame(height: size.height)
                .offset(y: yBase * size.height - size.height / 2 + offset)
            RidgeShape(seed: UInt64(speed * 777), height: height)
                .fill(color)
                .frame(height: size.height)
                .offset(y: yBase * size.height - size.height / 2 + offset - wrap)
        }
        .opacity(1 - min(1, alt * 1.5))
    }

    // Drifting atmospheric particles (dust / distant birds hint).
    private func particles(size: CGSize, time: TimeInterval, alt: Double) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: 0x9A17_2C4B)
            for _ in 0..<16 {
                let x = (rng.unit() * s.width + CGFloat(time * (8 + rng.unit() * 10)))
                    .truncatingRemainder(dividingBy: s.width)
                let baseY = rng.unit() * s.height
                let y = (baseY + CGFloat(time * 20)).truncatingRemainder(dividingBy: s.height)
                let r = 0.6 + rng.unit() * 1.0
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(0.10)))
            }
        }
    }
}

/// A smooth, organic ridgeline (rolling hills / mountains) — a filled curve.
struct RidgeShape: Shape {
    var seed: UInt64
    var height: CGFloat   // fraction of rect height the peaks occupy
    func path(in rect: CGRect) -> Path {
        var p = Path()
        var rng = SeededRNG(seed: seed == 0 ? 1 : seed)
        let peakBand = rect.midY
        let points = 7
        let dx = rect.width / CGFloat(points - 1)
        var pts: [CGPoint] = []
        for i in 0..<points {
            let x = rect.minX + CGFloat(i) * dx
            let y = peakBand - CGFloat(rng.unit()) * rect.height * height
            pts.append(CGPoint(x: x, y: y))
        }
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: pts[0])
        // Smooth Catmull-Rom-ish curve through the peaks.
        for i in 0..<pts.count - 1 {
            let a = pts[i], b = pts[i + 1]
            let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            p.addQuadCurve(to: mid, control: a)
            p.addQuadCurve(to: b, control: mid)
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Mini balloon (tiny vector — the flight protagonist stays small)

/// A tiny, elegant vector hot-air balloon: a soft envelope with two panels, a
/// hairline basket and burner glow. Drawn in code so it's crisp at 5–8% of the
/// screen and never looks like an oversized asset.
struct MiniBalloonView: View {
    var size: CGFloat = 44
    var envelope: Color = AppColors.balloonWhite
    var showGlow: Bool = true

    var body: some View {
        ZStack {
            if showGlow {
                Circle().fill(AppColors.gold.opacity(0.35))
                    .frame(width: size * 0.5, height: size * 0.5)
                    .blur(radius: size * 0.14)
                    .offset(y: size * 0.42)
            }
            // Envelope
            BalloonEnvelope()
                .fill(envelope)
                .overlay(
                    BalloonEnvelope()
                        .fill(LinearGradient(colors: [.white.opacity(0.0), .black.opacity(0.14)],
                                             startPoint: .leading, endPoint: .trailing))
                        .mask(BalloonEnvelope())
                )
                .frame(width: size * 0.72, height: size * 0.82)
                .offset(y: -size * 0.08)
                .shadow(color: .black.opacity(0.25), radius: size * 0.06, y: size * 0.03)
            // Basket
            RoundedRectangle(cornerRadius: size * 0.03, style: .continuous)
                .fill(Color(hex: 0x6B4A2C))
                .frame(width: size * 0.16, height: size * 0.12)
                .offset(y: size * 0.42)
            // Ropes
            Path { p in
                p.move(to: CGPoint(x: size * 0.34, y: size * 0.4))
                p.addLine(to: CGPoint(x: size * 0.42, y: size * 0.55))
                p.move(to: CGPoint(x: size * 0.66, y: size * 0.4))
                p.addLine(to: CGPoint(x: size * 0.58, y: size * 0.55))
            }
            .stroke(Color(hex: 0x6B4A2C).opacity(0.7), lineWidth: max(0.5, size * 0.012))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A classic hot-air-balloon envelope silhouette (teardrop with a rounded top).
struct BalloonEnvelope: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w * 0.5, y: h))                       // basket mouth
        p.addCurve(to: CGPoint(x: 0, y: h * 0.42),
                   control1: CGPoint(x: w * 0.14, y: h * 0.9),
                   control2: CGPoint(x: 0, y: h * 0.66))
        p.addArc(center: CGPoint(x: w * 0.5, y: h * 0.42),
                 radius: w * 0.5, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addCurve(to: CGPoint(x: w * 0.5, y: h),
                   control1: CGPoint(x: w, y: h * 0.66),
                   control2: CGPoint(x: w * 0.86, y: h * 0.9))
        p.closeSubpath()
        return p
    }
}
