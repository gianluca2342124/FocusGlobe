import Foundation
import SwiftUI

// MARK: - Sky scene (world identity)

/// A **sky** the balloon flies through. Every sky is a full vertical *world*:
/// six altitude stages that blend seamlessly into one another —
///
///   1. golden lower sky (soft rolling hills, low fog, warm glow)
///   2. the cloud sea (a huge bank of sunlit cloud you rise through)
///   3. high blue sky (thin air, drifting light)
///   4. twilight (violet haze, the moon, first stars)
///   5. aurora (cold air, breathing ribbons of light, snow sparks)
///   6. space (dense stars, meteors, a distant planet, nebula dust)
///
/// The scene struct only carries *identity + palette*; all drawing lives in
/// `SkySceneView`. Identity fields (`id`, `name`, `mood`, `theme`) feed the
/// synthetic `Route`, so the whole session engine keeps working unchanged.
struct SkyScene: Identifiable, Equatable {
    let id: String
    let name: String
    let mood: RouteMood
    let theme: RouteTheme
    /// Six altitude stages, each three colours **top → bottom**.
    let stages: [[Color]]
    /// The low-sky light source (sun for day skies, moonlight for night).
    let glowColor: Color
    let glowStrength: Double
    let cloudTint: Color
    let hillFar: Color
    let hillNear: Color
    /// Baseline star visibility at ground level (night skies start starry).
    let starFloor: Double

    static func == (l: SkyScene, r: SkyScene) -> Bool { l.id == r.id }

    // MARK: The launch set — three distinct worlds, no mud, no brown.

    static let silentDawn = SkyScene(
        id: "sky-silent-dawn", name: "Silent Dawn", mood: .sunrise, theme: .lavender,
        stages: [
            [Color(hex: 0x2C2452), Color(hex: 0x8A5C88), Color(hex: 0xF0A88E)],
            [Color(hex: 0x362D62), Color(hex: 0xA87CA6), Color(hex: 0xF6CCB2)],
            [Color(hex: 0x122048), Color(hex: 0x32507E), Color(hex: 0x7290C2)],
            [Color(hex: 0x0B1034), Color(hex: 0x282C5E), Color(hex: 0x504A86)],
            [Color(hex: 0x051119), Color(hex: 0x0E2636), Color(hex: 0x1C4252)],
            [Color(hex: 0x03050D), Color(hex: 0x090E1F), Color(hex: 0x111B32)],
        ],
        glowColor: Color(hex: 0xFFB79E), glowStrength: 0.9,
        cloudTint: Color(hex: 0xF0C8C8),
        hillFar: Color(hex: 0x342A52), hillNear: Color(hex: 0x1E1834),
        starFloor: 0)

    static let goldenHour = SkyScene(
        id: "sky-golden-hour", name: "Golden Hour", mood: .sunset, theme: .gold,
        stages: [
            [Color(hex: 0x2E2350), Color(hex: 0x9A4A56), Color(hex: 0xF29B5C)],
            [Color(hex: 0x342A5E), Color(hex: 0xB06A78), Color(hex: 0xF6C08A)],
            [Color(hex: 0x101E44), Color(hex: 0x2C4878), Color(hex: 0x6C8BBE)],
            [Color(hex: 0x0A0E30), Color(hex: 0x232858), Color(hex: 0x4C4680)],
            [Color(hex: 0x041018), Color(hex: 0x0C2434), Color(hex: 0x1A4050)],
            [Color(hex: 0x03040C), Color(hex: 0x080D1D), Color(hex: 0x101A30)],
        ],
        glowColor: Color(hex: 0xFFC873), glowStrength: 1.0,
        cloudTint: Color(hex: 0xF6CDA0),
        hillFar: Color(hex: 0x3A2C4E), hillNear: Color(hex: 0x241A34),
        starFloor: 0)

    static let starfield = SkyScene(
        id: "sky-starfield", name: "Starfield", mood: .night, theme: .indigo,
        stages: [
            [Color(hex: 0x0A1226), Color(hex: 0x1C2E52), Color(hex: 0x3A5580)],
            [Color(hex: 0x081022), Color(hex: 0x162648), Color(hex: 0x2E4670)],
            [Color(hex: 0x060B1A), Color(hex: 0x101E3A), Color(hex: 0x22365C)],
            [Color(hex: 0x04081A), Color(hex: 0x0C1430), Color(hex: 0x1A2448)],
            [Color(hex: 0x030A12), Color(hex: 0x081C28), Color(hex: 0x123642)],
            [Color(hex: 0x020309), Color(hex: 0x060A16), Color(hex: 0x0C1424)],
        ],
        glowColor: Color(hex: 0xAEC6EC), glowStrength: 0.32,
        cloudTint: Color(hex: 0x9FB4DC),
        hillFar: Color(hex: 0x101A32), hillNear: Color(hex: 0x0A1020),
        starFloor: 0.55)

    static let all: [SkyScene] = [silentDawn, goldenHour, starfield]

    /// Today's sky by local time — dawn mornings, gold days/evenings, stars night.
    static func today(date: Date = Date()) -> SkyScene {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<11:  return .silentDawn
        case 11..<20: return .goldenHour
        default:      return .starfield
        }
    }

    /// Infinity flights: fold ever-growing progress into a gentle up-and-back
    /// wave so the flight drifts through the stages forever, never dead-ending.
    static func loopedProgress(_ raw: Double) -> Double {
        let t = raw.truncatingRemainder(dividingBy: 2)
        return t <= 1 ? t : 2 - t
    }
}

/// How the world behaves behind a screen.
enum SkyMotion {
    /// A single static frame (Reduce Motion).
    case still
    /// Alive but grounded — twinkle, breathing aurora, slow cloud drift.
    /// **No vertical scroll**: used on Home and through the whole pre-flight
    /// ritual, so the world only begins to move when the flight does.
    case ambient
    /// In flight: the whole world streams downward with parallax.
    case flight
}

// MARK: - The world renderer

/// Renders a `SkyScene` at a given `altitude` (0…1 across the six stages).
/// Everything is procedural — gradients + a handful of lightweight Canvas
/// layers under one TimelineView — no image assets, no maps.
struct SkySceneView: View {
    let scene: SkyScene
    var altitude: Double = 0
    var motion: SkyMotion = .ambient

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                atmosphere
                if motion == .still {
                    world(size: size, time: 0)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                        world(size: size, time: ctx.date.timeIntervalSinceReferenceDate)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var alt: Double { min(1, max(0, altitude)) }

    // MARK: Atmosphere — smoothly crossfaded stage gradients

    private var atmosphere: some View {
        let pos = alt * Double(scene.stages.count - 1)
        let low = min(scene.stages.count - 1, Int(pos))
        let high = min(scene.stages.count - 1, low + 1)
        let f = smooth01(pos - Double(low))
        return ZStack {
            LinearGradient(colors: scene.stages[low], startPoint: .top, endPoint: .bottom)
            LinearGradient(colors: scene.stages[high], startPoint: .top, endPoint: .bottom)
                .opacity(f)
        }
    }

    // MARK: The living layers

    private func world(size: CGSize, time: TimeInterval) -> some View {
        let h = size.height
        // The downward stream. Progress carries the big journey displacement;
        // a gentle constant drift keeps the ascent readable even when progress
        // barely moves (long / infinity flights). Grounded modes never scroll.
        let climb: Double = motion == .flight ? alt * Double(h) * 2.4 + time * 22 : 0

        // Stage weights — every layer fades in/out on a smooth curve, so no
        // element ever pops or hard-cuts.
        let hillsW   = 1 - smoothstep(0.045, 0.16, alt)
        let fogW     = 1 - smoothstep(0.03, 0.13, alt)
        let glowW    = (1 - smoothstep(0.28, 0.58, alt)) * scene.glowStrength
        let seaW     = bell(center: 0.24, width: 0.15, alt)
        let cloudW   = (0.55 + seaW * 0.45) * (1 - smoothstep(0.55, 0.86, alt))
        let moonW    = smoothstep(0.42, 0.60, alt)
        let starW    = max(scene.starFloor * (0.4 + 0.6 * alt + 0.6), smoothstep(0.38, 0.72, alt))
        let auroraW  = bell(center: 0.72, width: 0.14, alt)
        let snowW    = bell(center: 0.70, width: 0.16, alt)
        let spaceW   = smoothstep(0.78, 0.95, alt)
        let dustW    = (1 - smoothstep(0.30, 0.52, alt)) * 0.7

        return ZStack {
            sunGlow(size: size, weight: glowW)
            moon(size: size, weight: moonW)
            if spaceW > 0.01 {
                nebula(size: size, weight: spaceW)
                planet(size: size, weight: spaceW, time: time)
            }
            starLayer(size: size, time: time, weight: min(1, starW), spaceW: spaceW)
            if auroraW > 0.01 {
                auroraLayer(size: size, time: time, weight: auroraW)
            }
            cloudLayer(size: size, time: time, climb: climb,
                       depth: 0, weight: cloudW)                       // far, slow
            cloudSea(size: size, weight: seaW)
            if hillsW > 0.001 {
                hills(size: size, weight: hillsW)
                fog(size: size, weight: fogW)
            }
            cloudLayer(size: size, time: time, climb: climb,
                       depth: 1, weight: cloudW)                       // near, fast
            particles(size: size, time: time, climb: climb,
                      dustW: dustW, snowW: snowW)
        }
    }

    // MARK: Celestial bodies

    /// The low-sky light — sun for day skies, cool moonlight for the night sky.
    /// Sinks below the frame as the balloon climbs away from the ground.
    private func sunGlow(size: CGSize, weight: Double) -> some View {
        RadialGradient(colors: [scene.glowColor.opacity(0.52 * weight),
                                scene.glowColor.opacity(0.15 * weight),
                                .clear],
                       center: .center, startRadius: 2, endRadius: size.width * 0.62)
            .frame(width: size.width * 1.3, height: size.width * 1.3)
            .position(x: size.width * 0.68,
                      y: size.height * (0.34 + alt * 1.35))
            .blur(radius: 12)
    }

    /// The moon fades up through twilight and holds through the high stages.
    private func moon(size: CGSize, weight: Double) -> some View {
        let d = size.width * 0.13
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xF2F5FC).opacity(0.30), .clear],
                                     center: .center, startRadius: d * 0.3, endRadius: d * 1.9))
                .frame(width: d * 3.8, height: d * 3.8)
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0xF4F6FA), Color(hex: 0xC9D2E4)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: d, height: d)
                .overlay(
                    // A soft terminator shadow so it reads as a body, not a dot.
                    Circle().fill(Color(hex: 0x8B97B4).opacity(0.35))
                        .frame(width: d * 0.82, height: d * 0.82)
                        .offset(x: -d * 0.18, y: d * 0.12)
                        .blur(radius: d * 0.12)
                        .mask(Circle().frame(width: d, height: d))
                )
        }
        .position(x: size.width * 0.26,
                  y: size.height * (0.34 - weight * 0.16))
        .opacity(weight)
    }

    /// Faint nebula dust for the space stage — two soft tinted pools of light.
    private func nebula(size: CGSize, weight: Double) -> some View {
        ZStack {
            RadialGradient(colors: [Color(hex: 0x6E4AE8).opacity(0.16), .clear],
                           center: .center, startRadius: 8, endRadius: size.width * 0.55)
                .frame(width: size.width * 1.1, height: size.width * 1.1)
                .position(x: size.width * 0.24, y: size.height * 0.30)
            RadialGradient(colors: [Color(hex: 0x2AC8B0).opacity(0.10), .clear],
                           center: .center, startRadius: 8, endRadius: size.width * 0.5)
                .frame(width: size.width, height: size.width)
                .position(x: size.width * 0.82, y: size.height * 0.14)
        }
        .blendMode(.plusLighter)
        .opacity(weight)
    }

    /// A distant, quiet planet that drifts up into the star field.
    private func planet(size: CGSize, weight: Double, time: TimeInterval) -> some View {
        let d = size.width * 0.15
        let bob = motion == .still ? 0.0 : sin(time * 0.10) * 4
        return ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0x93A8D6), Color(hex: 0x46557E)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle()
                .fill(Color(hex: 0x101728).opacity(0.55))
                .offset(x: d * 0.22, y: d * 0.16)
                .blur(radius: d * 0.16)
                .mask(Circle())
            Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
        .frame(width: d, height: d)
        .position(x: size.width * 0.80,
                  y: size.height * (0.60 - weight * 0.38) + CGFloat(bob))
        .opacity(weight * 0.95)
    }

    // MARK: Stars, meteors, comet

    private func starLayer(size: CGSize, time: TimeInterval,
                           weight: Double, spaceW: Double) -> some View {
        Canvas { ctx, s in
            guard weight > 0.01 else { return }
            var rng = SeededRNG(seed: 0x57A2_F1E1)
            let count = 150
            for i in 0..<count {
                let u1 = rng.unit(), u2 = rng.unit(), u3 = rng.unit(), u4 = rng.unit()
                let x = u1 * s.width
                let y = u2 * s.height
                let r = 0.5 + u3 * (1.0 + spaceW * 0.9)
                // Deep-space stars only join at high altitude.
                let member = Double(i) / Double(count)
                let visible = member < 0.55 ? 1.0 : spaceW
                guard visible > 0.01 else { continue }
                let tw = motion == .still
                    ? 1.0
                    : 0.62 + 0.38 * sin(time * (0.7 + u4 * 1.7) + u4 * 6.28)
                let a = (0.25 + u3 * 0.65) * weight * visible * tw
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(a)))
            }
            guard spaceW > 0.05, motion != .still else { return }
            drawMeteor(&ctx, size: s, time: time, period: 6.5, seedSalt: 11, alpha: spaceW)
            drawMeteor(&ctx, size: s, time: time, period: 9.7, seedSalt: 29, alpha: spaceW * 0.8)
            drawComet(&ctx, size: s, time: time, alpha: spaceW)
        }
    }

    /// A brief streak of light. Deterministic per cycle — a new path each time,
    /// nothing allocated per frame beyond the path itself.
    private func drawMeteor(_ ctx: inout GraphicsContext, size s: CGSize,
                            time: TimeInterval, period: Double, seedSalt: UInt64,
                            alpha: Double) {
        let cycle = floor(time / period)
        let phase = (time / period) - cycle
        guard phase < 0.14 else { return }
        var rng = SeededRNG(seed: UInt64(bitPattern: Int64(cycle)) &* 31 &+ seedSalt)
        let t = phase / 0.14
        let x0 = s.width * (0.2 + rng.unit() * 0.7)
        let y0 = s.height * (0.06 + rng.unit() * 0.30)
        let dx: CGFloat = -1, dy: CGFloat = 0.55
        let travel = s.width * 0.45 * t
        let head = CGPoint(x: x0 + dx * travel, y: y0 + dy * travel)
        let tail = CGPoint(x: head.x - dx * 90, y: head.y - dy * 90)
        var p = Path()
        p.move(to: tail); p.addLine(to: head)
        let a = sin(.pi * t) * alpha
        ctx.stroke(p, with: .linearGradient(
            Gradient(colors: [.white.opacity(0), .white.opacity(0.85 * a)]),
            startPoint: tail, endPoint: head), lineWidth: 1.4)
    }

    /// A slow, elegant comet with a long soft tail — rare, memorable.
    private func drawComet(_ ctx: inout GraphicsContext, size s: CGSize,
                           time: TimeInterval, alpha: Double) {
        let period = 27.0
        let phase = (time / period).truncatingRemainder(dividingBy: 1)
        guard phase < 0.30 else { return }
        let t = phase / 0.30
        let head = CGPoint(x: s.width * (1.05 - 1.15 * t),
                           y: s.height * (0.12 + 0.14 * t))
        let tail = CGPoint(x: head.x + 150, y: head.y - 34)
        let a = sin(.pi * t) * alpha * 0.8
        var p = Path()
        p.move(to: tail); p.addLine(to: head)
        ctx.stroke(p, with: .linearGradient(
            Gradient(colors: [Color(hex: 0x9FE8FF).opacity(0),
                              Color(hex: 0xD9F4FF).opacity(0.7 * a)]),
            startPoint: tail, endPoint: head), lineWidth: 2.2)
        ctx.fill(Path(ellipseIn: CGRect(x: head.x - 2.4, y: head.y - 2.4, width: 4.8, height: 4.8)),
                 with: .color(.white.opacity(a)))
    }

    // MARK: Aurora

    /// Three breathing ribbons of light, additive over the cold high sky.
    private func auroraLayer(size: CGSize, time: TimeInterval, weight: Double) -> some View {
        Canvas { ctx, s in
            let colors = [Color(hex: 0x5CE6A8), Color(hex: 0x4CC8D9), Color(hex: 0x8E7BE8)]
            for band in 0..<3 {
                let base = s.height * (0.16 + CGFloat(band) * 0.095)
                let breathe = motion == .still
                    ? 1.0
                    : 0.75 + 0.25 * sin(time * 0.25 + Double(band) * 1.9)
                let amp = s.height * 0.05 * breathe
                let bandH = s.height * (0.11 + CGFloat(band) * 0.012)
                var top = Path()
                var x: CGFloat = -10
                var first = true
                while x <= s.width + 10 {
                    let wave = sin(Double(x) / 92 + time * (0.22 + Double(band) * 0.07) + Double(band) * 2.1)
                        + 0.4 * sin(Double(x) / 37 - time * 0.13 + Double(band))
                    let y = base + CGFloat(wave) * amp
                    if first { top.move(to: CGPoint(x: x, y: y)); first = false }
                    else { top.addLine(to: CGPoint(x: x, y: y)) }
                    x += 14
                }
                var ribbon = top
                ribbon.addLine(to: CGPoint(x: s.width + 10, y: base + bandH))
                ribbon.addLine(to: CGPoint(x: -10, y: base + bandH))
                ribbon.closeSubpath()
                let c = colors[band]
                ctx.fill(ribbon, with: .linearGradient(
                    Gradient(colors: [c.opacity(0), c.opacity(0.34 * weight), c.opacity(0)]),
                    startPoint: CGPoint(x: 0, y: base - amp),
                    endPoint: CGPoint(x: 0, y: base + bandH)))
            }
        }
        .blur(radius: 9)
        .blendMode(.plusLighter)
    }

    // MARK: Clouds

    /// A drifting bank of soft cloud puffs. In flight the bank streams downward
    /// and wraps — with alpha fades at the wrap edges, so no puff ever pops in.
    private func cloudLayer(size: CGSize, time: TimeInterval, climb: Double,
                            depth: Int, weight: Double) -> some View {
        let speed = depth == 0 ? 0.34 : 0.85
        let blur: CGFloat = depth == 0 ? 10 : 16
        let baseAlpha = depth == 0 ? 0.085 : 0.13
        return Canvas { ctx, s in
            guard weight > 0.01 else { return }
            var rng = SeededRNG(seed: 0xC10D_0A00 &+ UInt64(depth))
            let wrap = s.height + 320
            let count = depth == 0 ? 6 : 5
            for i in 0..<count {
                let u1 = rng.unit(), u2 = rng.unit(), u3 = rng.unit()
                let drift = motion == .still ? 0.0 : sin(time * 0.03 + Double(i) * 1.7) * 16
                let cx = u1 * s.width + CGFloat(drift)
                let raw = (u2 * wrap + CGFloat(climb * speed))
                    .truncatingRemainder(dividingBy: wrap)
                let edge = smoothstep(0, 0.10, Double(raw / wrap))
                    * (1 - smoothstep(0.90, 1, Double(raw / wrap)))
                let y = raw - 160
                let w = s.width * (0.34 + u3 * 0.30) * (depth == 0 ? 0.9 : 1.15)
                let a = baseAlpha * weight * edge
                guard a > 0.003 else { continue }
                puff(&ctx, center: CGPoint(x: cx, y: y), width: w,
                     color: scene.cloudTint, alpha: a)
            }
        }
        .blur(radius: blur)
    }

    /// The **cloud sea** — a wide sunlit bank pinned at its own altitude. It
    /// rises into view as the balloon approaches stage two, slides past, and
    /// sinks away below; the one big "I'm above the clouds now" moment.
    private func cloudSea(size: CGSize, weight: Double) -> some View {
        Canvas { ctx, s in
            guard weight > 0.005 else { return }
            let y = s.height * 0.5 - CGFloat(0.24 - alt) * s.height * 3.2
            var rng = SeededRNG(seed: 0x5EA_C10D)
            for i in 0..<9 {
                let u1 = rng.unit(), u2 = rng.unit()
                let cx = s.width * (CGFloat(i) / 8.0) + (u1 - 0.5) * 40
                let w = s.width * (0.30 + u2 * 0.22)
                let lift = CGFloat(sin(Double(i) * 1.7)) * s.height * 0.02
                puff(&ctx, center: CGPoint(x: cx, y: y + lift), width: w,
                     color: scene.cloudTint, alpha: 0.16 * weight)
            }
            // A soft bright crest along the top of the bank.
            var crest = Path()
            crest.move(to: CGPoint(x: 0, y: y - 14))
            crest.addLine(to: CGPoint(x: s.width, y: y - 14))
            ctx.stroke(crest, with: .color(scene.cloudTint.opacity(0.10 * weight)), lineWidth: 26)
        }
        .blur(radius: 18)
    }

    private func puff(_ ctx: inout GraphicsContext, center: CGPoint, width w: CGFloat,
                      color: Color, alpha: Double) {
        let h = w * 0.34
        var blob = Path()
        blob.addEllipse(in: CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h))
        blob.addEllipse(in: CGRect(x: center.x - w * 0.26, y: center.y - h * 0.9,
                                   width: w * 0.55, height: h * 0.9))
        blob.addEllipse(in: CGRect(x: center.x - w * 0.05, y: center.y - h * 0.55,
                                   width: w * 0.42, height: h * 0.8))
        ctx.fill(blob, with: .color(color.opacity(alpha)))
    }

    // MARK: Ground — rolling hills + low fog (stage one only)

    /// Two layers of smooth rolling hills. Pure low-frequency sine sums — soft
    /// shoulders, no peaks, nothing triangular. They sink out of frame within
    /// the first stage of the climb and never wrap back.
    private func hills(size: CGSize, weight: Double) -> some View {
        let sink = CGFloat(alt) * size.height * 2.2
        return ZStack {
            RollingHillsShape(amplitude: 0.040, phase: 0.8, waves: 1.35)
                .fill(scene.hillFar)
                .offset(y: size.height * 0.015 + sink * 0.8)
            RollingHillsShape(amplitude: 0.055, phase: 3.9, waves: 1.9)
                .fill(scene.hillNear)
                .offset(y: size.height * 0.075 + sink)
        }
        .opacity(weight)
    }

    private func fog(size: CGSize, weight: Double) -> some View {
        LinearGradient(colors: [scene.cloudTint.opacity(0), scene.cloudTint.opacity(0.13)],
                       startPoint: .top, endPoint: .bottom)
            .frame(height: size.height * 0.22)
            .position(x: size.width / 2,
                      y: size.height * 0.80 + CGFloat(alt) * size.height * 2.2)
            .blur(radius: 10)
            .opacity(weight)
    }

    // MARK: Ambient particles — warm dust low, snow sparks in the cold band

    private func particles(size: CGSize, time: TimeInterval, climb: Double,
                           dustW: Double, snowW: Double) -> some View {
        Canvas { ctx, s in
            if dustW > 0.01 {
                var rng = SeededRNG(seed: 0x9A17_2C4B)
                for i in 0..<14 {
                    let u1 = rng.unit(), u2 = rng.unit(), u3 = rng.unit()
                    let x = (u1 * s.width + CGFloat(time * (5 + u3 * 7)))
                        .truncatingRemainder(dividingBy: s.width)
                    let y = (u2 * s.height + CGFloat(climb * 0.25 + time * 3 * Double(i % 3)))
                        .truncatingRemainder(dividingBy: s.height)
                    let r = 0.7 + u3 * 1.0
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                             with: .color(scene.cloudTint.opacity(0.16 * dustW)))
                }
            }
            if snowW > 0.01 {
                var rng = SeededRNG(seed: 0x5A0_FF1A)
                for i in 0..<22 {
                    let u1 = rng.unit(), u2 = rng.unit(), u3 = rng.unit()
                    let sway = motion == .still ? 0.0 : sin(time * 0.5 + Double(i)) * 16
                    let x = (u1 * s.width + CGFloat(sway)).truncatingRemainder(dividingBy: s.width)
                    let y = (u2 * s.height + CGFloat(time * 13 + climb * 0.5))
                        .truncatingRemainder(dividingBy: s.height)
                    let r = 0.9 + u3 * 1.2
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                             with: .color(.white.opacity(0.34 * snowW)))
                }
            }
        }
    }

    // MARK: Easing helpers

    private func smoothstep(_ e0: Double, _ e1: Double, _ x: Double) -> Double {
        let t = min(1, max(0, (x - e0) / max(0.0001, e1 - e0)))
        return t * t * (3 - 2 * t)
    }
    private func smooth01(_ x: Double) -> Double { smoothstep(0, 1, x) }
    private func bell(center: Double, width: Double, _ x: Double) -> Double {
        let d = abs(x - center) / width
        guard d < 1 else { return 0 }
        return 0.5 * (1 + cos(.pi * d))
    }
}

/// A soft rolling hill silhouette — a sum of two low-frequency sines, so the
/// ridge has round shoulders and gentle valleys. Never a triangle in sight.
struct RollingHillsShape: Shape {
    /// Peak amplitude as a fraction of rect height.
    var amplitude: CGFloat
    var phase: CGFloat
    /// How many broad waves span the width.
    var waves: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let baseY = rect.height * 0.80
        let steps = 48
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for i in 0...steps {
            let fx = CGFloat(i) / CGFloat(steps)
            let x = rect.minX + fx * rect.width
            let w1 = sin(Double(fx * waves * .pi * 2 + phase))
            let w2 = 0.45 * sin(Double(fx * waves * 2.6 * .pi + phase * 1.7))
            let y = baseY - (CGFloat(w1 + w2) * amplitude * rect.height) - amplitude * rect.height
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Mini balloon (tiny vector — the flight protagonist stays small)

/// A tiny, elegant vector hot-air balloon: a soft envelope with a hairline
/// basket and a warm burner glow. Drawn in code so it's crisp at 5–8% of the
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
            RoundedRectangle(cornerRadius: size * 0.03, style: .continuous)
                .fill(Color(hex: 0x6B4A2C))
                .frame(width: size * 0.16, height: size * 0.12)
                .offset(y: size * 0.42)
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
