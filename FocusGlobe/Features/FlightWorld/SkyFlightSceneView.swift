import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if DEBUG
/// Code-only switch for the DEBUG sky inspector (sky · seed · palette segment ·
/// elapsed). Never compiled into release builds.
private let livingSkyInspectorEnabled = false
#endif

/// **The living animated sky** — FocusGlobe's authoritative flight renderer,
/// shared by real flights, Cabin View and locked-Sky previews.
///
/// Direction: premium digital sky art, not a scrolling world and not a
/// procedural collage. The composition is:
///
///   1. A full-screen gradient that **evolves continuously** through the Sky's
///      authored palette timeline (~70 s between keyframes, ping-pong looped —
///      no cuts, no seams, no banding).
///   2. Soft breathing haze and a slowly wandering highlight — organic light,
///      never a hard-edged disc.
///   3. The Sky's **permanent Ground** artwork anchored at the bottom for the
///      whole flight (it never scrolls, fades or repeats).
///   4. Per-Sky atmospheric moments that fade in, live briefly in place
///      (drift a little, breathe, twinkle) and fade out — birds, lanterns,
///      aurora, rain, petals, shimmer. Nothing travels top-to-bottom as
///      scenery; there are no rings, no vector geometry, no procedural mini
///      balloons, at most ONE restrained celestial body.
///
/// All motion derives from the pause-aware flight clock: pause freezes the
/// world; Cabin/preview share the same seed + clock, so they show the same sky.
struct SkyFlightSceneView: View {
    let sky: FocusSky
    /// Pause-aware elapsed seconds — the single source of motion.
    let elapsed: () -> Double
    var animated: Bool = true
    /// Stable per-session seed (shared with Cabin) — varies effect placement
    /// between flights while staying fixed across pause/resume.
    var seed: UInt64 = 1

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = max(1, geo.size.height)
            TimelineView(.animation(minimumInterval: animated ? 1.0 / 30.0 : 5.0)) { _ in
                let t = animated ? max(0, elapsed()) : 0
                ZStack {
                    gradientField(W: W, H: H, t: t)
                    atmosphere(W: W, H: H, t: t)
                    celestial(W: W, H: H, t: t)
                    effects(W: W, H: H, t: t)
                    // Layered silhouette planes with glacial parallax — the
                    // depth between the vast sky above and the Ground below.
                    SkyDepthScenery(sky: sky, t: t, horizon: 0.82, intensity: 0.9)
                    weather(W: W, H: H, t: t)
                    groundLayer(W: W, H: H)
                    #if DEBUG
                    if livingSkyInspectorEnabled { inspector(t: t) }
                    #endif
                }
                .frame(width: W, height: H)
                .clipped()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var skySeed: UInt64 {
        var h: UInt64 = seed == 0 ? 0xF0C0 : seed
        for u in sky.id.unicodeScalars { h = (h &* 31) &+ UInt64(u.value) }
        return h
    }

    // MARK: 1 — The evolving gradient field

    private func gradientField(W: CGFloat, H: CGFloat, t: Double) -> some View {
        let stops = SkyGradientTimeline.stops(skyID: sky.id, at: t)
        // The highlight wanders extremely slowly and stays soft-edged.
        let hx = 0.5 + 0.22 * Foundation.sin(t * 0.011)
        let hy = 0.30 + 0.08 * Foundation.sin(t * 0.007 + 1.7)
        let breathe = 0.8 + 0.2 * Foundation.sin(t * 0.05)
        return ZStack {
            LinearGradient(colors: stops, startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [sky.glowColor.opacity(0.16 * breathe), .clear],
                           center: UnitPoint(x: hx, y: hy),
                           startRadius: 2, endRadius: W * 1.05)
            // Two vast, ultra-soft haze masses breathing out of phase — organic
            // depth with no identifiable boundary.
            RadialGradient(colors: [stops[3].opacity(0.10 + 0.04 * Foundation.sin(t * 0.03)), .clear],
                           center: UnitPoint(x: 0.24 + 0.06 * Foundation.sin(t * 0.013 + 2.2), y: 0.62),
                           startRadius: 2, endRadius: W * 0.9)
            RadialGradient(colors: [stops[1].opacity(0.10 + 0.04 * Foundation.sin(t * 0.026 + 3.1)), .clear],
                           center: UnitPoint(x: 0.78 - 0.06 * Foundation.sin(t * 0.017), y: 0.4),
                           startRadius: 2, endRadius: W * 0.85)
            // Zenith depth: the top of the sky deepens gently, so looking up
            // reads as looking into vastness rather than at a flat wall.
            LinearGradient(stops: [
                .init(color: stops[0].opacity(0.55), location: 0),
                .init(color: stops[0].opacity(0), location: 0.30),
                .init(color: .clear, location: 1),
            ], startPoint: .top, endPoint: .bottom)
            // Horizon bloom: light accumulating in the thick air low in the
            // frame — the classic "big world" cue, breathing very slowly.
            RadialGradient(colors: [sky.glowColor.opacity(0.11 + 0.04 * breathe), .clear],
                           center: UnitPoint(x: 0.5, y: 0.82),
                           startRadius: 4, endRadius: W * 0.95)
        }
    }

    // MARK: 2 — Ambient atmosphere (stars, near-ground shimmer)

    @ViewBuilder private func atmosphere(W: CGFloat, H: CGFloat, t: Double) -> some View {
        if sky.stars > 0.01 { starField(W: W, H: H, t: t) }
        switch sky.id {
        case "fiji-lagoon":
            groundShimmer(W: W, H: H, t: t, tint: Color(hex: 0xBFF2E0))
            seaGlow(W: W, H: H, t: t)
        case "rainy-tokyo":
            neonShimmer(W: W, H: H, t: t)
        case "paris-sunset":
            groundShimmer(W: W, H: H, t: t, tint: Color(hex: 0xF6C88A))
        case "sahara-night":
            milkyWay(W: W, H: H, t: t)
        case "galaxy-drift", "deep-space":
            // The great diagonal star-river gives the cosmos its sense of
            // immense, structured depth — the emptiest Skies feel the largest.
            milkyWay(W: W, H: H, t: t)
        default:
            EmptyView()
        }
    }

    /// Fiji — a luminous aqua band where sea light saturates the low air,
    /// breathing on a long period. Pure light, no boundary.
    private func seaGlow(W: CGFloat, H: CGFloat, t: Double) -> some View {
        let breathe = 0.8 + 0.2 * Foundation.sin(t * 0.045)
        return LinearGradient(colors: [Color(hex: 0x8DE8D0).opacity(0),
                                       Color(hex: 0x8DE8D0).opacity(0.12 * breathe),
                                       Color(hex: 0x8DE8D0).opacity(0)],
                              startPoint: .top, endPoint: .bottom)
            .frame(height: H * 0.22)
            .position(x: W / 2, y: H * 0.76)
    }

    /// Stars twinkle **in place** — the world does not scroll. Star-heavy Skies
    /// gain a second plane of fine background dust (depth through density) and
    /// a handful of hero stars with soft cross glints (depth through hierarchy).
    private func starField(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0x57A2)
            let count = Int(40 + sky.stars * 140)
            for i in 0..<count {
                let x = CGFloat(rng.unit()) * s.width
                let y = CGFloat(rng.unit()) * s.height * 0.85
                let u = rng.unit()
                let tw = 0.55 + 0.45 * Foundation.sin(t * (0.4 + u * 1.4) + Double(i) * 1.31)
                let a = (0.14 + u * 0.5) * sky.stars * tw
                let r = CGFloat(0.5 + u * 1.5)
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(a)))
                if u > 0.93 && sky.stars > 0.5 {
                    softGlow(&ctx, x: x, y: y, r: r * 3.4, color: .white.opacity(a * 0.4))
                }
                // Hero stars: rare, brighter, with a delicate 4-point glint that
                // swells and fades with the twinkle — never a hard sparkle.
                if u > 0.972 && sky.stars > 0.4 {
                    let glint = CGFloat(6 + u * 5) * CGFloat(0.6 + 0.4 * tw)
                    var cross = Path()
                    cross.move(to: CGPoint(x: x - glint, y: y)); cross.addLine(to: CGPoint(x: x + glint, y: y))
                    cross.move(to: CGPoint(x: x, y: y - glint)); cross.addLine(to: CGPoint(x: x, y: y + glint))
                    ctx.stroke(cross, with: .color(.white.opacity(a * 0.35)), lineWidth: 0.7)
                }
            }
            // The dust plane: dense micro-stars for the deep cosmic Skies only.
            if sky.stars > 0.75 {
                var dustRNG = SeededRNG(seed: skySeed &+ 0xD0_57A2)
                for _ in 0..<110 {
                    let x = CGFloat(dustRNG.unit()) * s.width
                    let y = CGFloat(dustRNG.unit()) * s.height
                    let a = 0.05 + dustRNG.unit() * 0.12
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 0.7, height: 0.7)),
                             with: .color(.white.opacity(a)))
                }
            }
        }
    }

    /// Soft glints twinkling just above the ground line (ocean / city lights).
    private func groundShimmer(W: CGFloat, H: CGFloat, t: Double, tint: Color) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0x0CEA)
            for _ in 0..<20 {
                let fx = rng.unit()
                let fy = 0.84 + rng.unit() * 0.1
                let tw = 0.5 + 0.5 * Foundation.sin(t * (0.4 + rng.unit() * 1.2) + fx * 6.0)
                let a = 0.06 + tw * 0.18
                let x = CGFloat(fx) * s.width
                let y = CGFloat(fy) * s.height
                softGlow(&ctx, x: x, y: y, r: CGFloat(3 + rng.unit() * 5), color: tint.opacity(a))
            }
        }
    }

    /// Blurred neon reflections breathing low in the rain haze.
    private func neonShimmer(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0x0C17)
            let neon = [Color(hex: 0xE86A9E), Color(hex: 0x6AC8E8), Color(hex: 0x8F7BE8)]
            for i in 0..<14 {
                let fx = rng.unit()
                let fy = 0.72 + rng.unit() * 0.2
                let pulse = 0.5 + 0.5 * Foundation.sin(t * (0.5 + rng.unit()) + Double(i))
                let a = 0.05 + pulse * 0.16
                softGlow(&ctx, x: CGFloat(fx) * s.width, y: CGFloat(fy) * s.height,
                         r: CGFloat(9 + rng.unit() * 12), color: neon[i % neon.count].opacity(a))
            }
        }
    }

    /// A faint diagonal Milky-Way glow: a tilted band of dense micro-stars
    /// inside a very soft luminous haze — no edges, no geometry.
    private func milkyWay(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0x3117)
            let cx = Double(s.width) * 0.5
            let cy = Double(s.height) * 0.34
            let tilt = -0.5
            ctx.drawLayer { l in
                l.translateBy(x: CGFloat(cx), y: CGFloat(cy))
                l.rotate(by: .radians(tilt))
                let len = Double(s.width) * 1.3
                let g = Gradient(colors: [Color(hex: 0xD8CCF0).opacity(0.10),
                                          Color(hex: 0x9A88C8).opacity(0.04), .clear])
                l.fill(Path(ellipseIn: CGRect(x: -len / 2, y: -len * 0.09,
                                              width: len, height: len * 0.18)),
                       with: .radialGradient(g, center: .zero, startRadius: 0,
                                             endRadius: CGFloat(len / 2)))
                for _ in 0..<70 {
                    let x = (rng.unit() - 0.5) * len
                    let y = (rng.unit() - 0.5) * len * 0.13
                    let a = 0.1 + rng.unit() * 0.35
                    let r = 0.5 + rng.unit() * 1.1
                    l.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                           with: .color(.white.opacity(a)))
                }
            }
        }
    }

    // MARK: 3 — One restrained celestial body (never more)

    @ViewBuilder private func celestial(W: CGFloat, H: CGFloat, t: Double) -> some View {
        // Placed in an upper corner, small, fading in over ~20 s, then nearly
        // stationary — never behind the balloon, headline or controls.
        let fadeIn = min(1.0, t / 20.0)
        let drift = CGFloat(Foundation.sin(t * 0.004)) * W * 0.01
        switch sky.id {
        case "moon-garden":
            softMoon(d: W * 0.24)
                .position(x: W * 0.74 + drift, y: H * 0.20)
                .opacity(fadeIn)
        case "sahara-night":
            softMoon(d: W * 0.12, dim: true)
                .position(x: W * 0.26 + drift, y: H * 0.16)
                .opacity(fadeIn * 0.8)
        case "galaxy-drift":
            softPlanet(d: W * 0.14)
                .position(x: W * 0.24 + drift, y: H * 0.18)
                .opacity(fadeIn * 0.9)
        case "deep-space":
            ZStack {
                galaxySmudge(W: W, H: H)
                softPlanet(d: W * 0.10)
                    .position(x: W * 0.78 + drift, y: H * 0.22)
            }
            .opacity(fadeIn * 0.85)
        default:
            EmptyView()
        }
    }

    /// A moon with a fully diffused limb — sphere shading, soft maria, a wide
    /// glow. No rim strokes, no rings, no hard boundary.
    private func softMoon(d: CGFloat, dim: Bool = false) -> some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [Color(hex: 0xEDF2FB).opacity(dim ? 0.16 : 0.28), .clear],
                                         center: .center, startRadius: 2, endRadius: d))
                .frame(width: d * 2, height: d * 2)
            Circle().fill(RadialGradient(
                colors: [Color(hex: 0xF6F8FE).opacity(dim ? 0.7 : 0.95),
                         Color(hex: 0xD5DCEC).opacity(dim ? 0.55 : 0.85),
                         Color(hex: 0xAEB9D2).opacity(0)],
                center: UnitPoint(x: 0.38, y: 0.34), startRadius: 0, endRadius: d * 0.66))
                .frame(width: d, height: d)
            Circle().fill(Color(hex: 0x93A0BC).opacity(0.22))
                .frame(width: d * 0.18, height: d * 0.18).offset(x: -d * 0.12, y: -d * 0.04)
            Circle().fill(Color(hex: 0x93A0BC).opacity(0.16))
                .frame(width: d * 0.1, height: d * 0.1).offset(x: d * 0.12, y: d * 0.14)
        }
        .frame(width: d, height: d)
    }

    /// A small distant world with soft limb shading — no rings, no strokes.
    private func softPlanet(d: CGFloat) -> some View {
        Circle().fill(RadialGradient(
            colors: [Color(hex: 0xB4C4E8).opacity(0.85), Color(hex: 0x7E92C2).opacity(0.6),
                     Color(hex: 0x3A4A72).opacity(0)],
            center: UnitPoint(x: 0.36, y: 0.32), startRadius: 0, endRadius: d * 0.68))
            .frame(width: d, height: d)
    }

    /// A faint tilted galaxy smudge — soft elliptical haze with a brighter core.
    private func galaxySmudge(W: CGFloat, H: CGFloat) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0x6A1A)
            let gx = Double(s.width) * (0.24 + rng.unit() * 0.16)
            let gy = Double(s.height) * (0.14 + rng.unit() * 0.1)
            let r = Double(min(s.width, s.height)) * 0.16
            ctx.drawLayer { l in
                l.translateBy(x: CGFloat(gx), y: CGFloat(gy))
                l.rotate(by: .radians(rng.unit() * 0.8 - 0.4))
                let g = Gradient(colors: [Color(hex: 0xB49CE8).opacity(0.12),
                                          Color(hex: 0x6E7EC8).opacity(0.05), .clear])
                l.fill(Path(ellipseIn: CGRect(x: -r, y: -r * 0.4, width: r * 2, height: r * 0.8)),
                       with: .radialGradient(g, center: .zero, startRadius: 0, endRadius: CGFloat(r)))
                let cg = Gradient(colors: [Color.white.opacity(0.12), .clear])
                l.fill(Path(ellipseIn: CGRect(x: -r * 0.14, y: -r * 0.07, width: r * 0.28, height: r * 0.14)),
                       with: .radialGradient(cg, center: .zero, startRadius: 0, endRadius: CGFloat(r * 0.2)))
            }
        }
    }

    // MARK: 4 — Per-Sky atmospheric moments (fade in · live · fade out)

    @ViewBuilder private func effects(W: CGFloat, H: CGFloat, t: Double) -> some View {
        switch sky.id {
        case "golden-hour":
            ZStack {
                sunBloom(W: W, H: H, t: t)
                cirrus(W: W, H: H, t: t, tint: Color(hex: 0xF6D8A8))
                flockCrossing(W: W, H: H, t: t)
                dustMotes(W: W, H: H, t: t, tint: Color(hex: 0xF6C88A), count: 14)
            }
        case "paris-sunset":
            ZStack {
                sunBloom(W: W, H: H, t: t)
                cirrus(W: W, H: H, t: t, tint: Color(hex: 0xEEB0A0))
                flockCrossing(W: W, H: H, t: t)
                dustMotes(W: W, H: H, t: t, tint: Color(hex: 0xF6C88A), count: 10)
            }
        case "fiji-lagoon":
            ZStack {
                sunBloom(W: W, H: H, t: t)
                cirrus(W: W, H: H, t: t, tint: Color(hex: 0xEAFBF4))
                flockCrossing(W: W, H: H, t: t)
            }
        case "kyoto-lanterns":
            ZStack {
                lanternMoments(W: W, H: H, t: t)
                petals(W: W, H: H, t: t, tint: Color(hex: 0xF2C4C8))
                moonGlow(W: W, H: H, t: t)
            }
        case "aurora-snowfield":
            ZStack {
                auroraCurtains(W: W, H: H, t: t)
                moonGlow(W: W, H: H, t: t)
                lightPillar(W: W, H: H, t: t)
            }
        case "rainy-tokyo":
            cloudGlow(W: W, H: H, t: t)
        case "moon-garden":
            ZStack {
                mistBreath(W: W, H: H, t: t, tint: Color(hex: 0xB4C4D8))
                petals(W: W, H: H, t: t, tint: Color(hex: 0xD8DEEE))
            }
        case "swiss-alps":
            ZStack {
                sunBloom(W: W, H: H, t: t)
                cirrus(W: W, H: H, t: t, tint: Color(hex: 0xEEF6F8))
                flockCrossing(W: W, H: H, t: t)
            }
        case "sahara-night":
            ZStack {
                shootingStar(W: W, H: H, t: t, period: 26)
                dustMotes(W: W, H: H, t: t, tint: Color(hex: 0xE8B080), count: 10)
            }
        case "galaxy-drift":
            ZStack {
                nebulaBreath(W: W, H: H, t: t,
                             tints: [Color(hex: 0x8A6CE8), Color(hex: 0x4C6CE8), Color(hex: 0xE870B4)])
                shootingStar(W: W, H: H, t: t, period: 21)
            }
        case "deep-space":
            ZStack {
                nebulaBreath(W: W, H: H, t: t,
                             tints: [Color(hex: 0x2E3E64), Color(hex: 0x46567E), Color(hex: 0x6E7EC8)])
                shootingStar(W: W, H: H, t: t, period: 34)
            }
        default:
            EmptyView()
        }
    }

    /// A big diffused sun bloom high in the frame, breathing very slowly —
    /// pure light, no disc edge, no rings.
    private func sunBloom(W: CGFloat, H: CGFloat, t: Double) -> some View {
        var rng = SeededRNG(seed: skySeed &+ 0x50B1)
        let x = 0.3 + rng.unit() * 0.4
        let breathe = 0.75 + 0.25 * Foundation.sin(t * 0.04)
        return ZStack {
            RadialGradient(colors: [Color(hex: 0xFFF4DC).opacity(0.34 * breathe),
                                    Color(hex: 0xF6D89A).opacity(0.14 * breathe), .clear],
                           center: UnitPoint(x: x, y: 0.22), startRadius: 2, endRadius: W * 0.5)
            RadialGradient(colors: [Color.white.opacity(0.18 * breathe), .clear],
                           center: UnitPoint(x: x, y: 0.22), startRadius: 1, endRadius: W * 0.14)
        }
    }

    /// Thin illuminated cirrus streaks: each moment fades in at a seeded height,
    /// drifts a few points sideways, and fades away (~46 s cycle). Drawn as a
    /// chain of overlapping ultra-soft glows — organic, no visible ellipse.
    private func cirrus(W: CGFloat, H: CGFloat, t: Double, tint: Color) -> some View {
        Canvas { ctx, s in
            for slot in 0..<2 {
                let period = 46.0
                let shifted = t / period + Double(slot) * 0.5
                let cycle = shifted.rounded(.down)
                let local = shifted - cycle
                let env = Foundation.sin(.pi * local)                // fade in → out
                guard env > 0.02 else { continue }
                var rng = SeededRNG(seed: skySeed &+ UInt64(bitPattern: Int64(cycle)) &* 73 &+ UInt64(slot) &* 7)
                let y = Double(s.height) * (0.14 + rng.unit() * 0.3)
                let cx = Double(s.width) * (0.2 + rng.unit() * 0.6) + local * 14 - 7
                let len = Double(s.width) * (0.3 + rng.unit() * 0.25)
                let n = 7
                for k in 0..<n {
                    let f = Double(k) / Double(n - 1) - 0.5
                    let px = cx + f * len
                    let py = y + Foundation.sin(f * 3.0 + rng.unit() * 6) * Double(s.height) * 0.008
                    let bell = Foundation.cos(f * .pi) * 0.5 + 0.5
                    softGlow(&ctx, x: CGFloat(px), y: CGFloat(py),
                             r: CGFloat(Double(s.width) * 0.055 * (0.6 + bell * 0.6)),
                             color: tint.opacity(0.10 * env * bell))
                }
            }
        }
    }

    /// A small flock crossing horizontally (~every 44 s) — the only travelling
    /// element, because birds genuinely fly.
    private func flockCrossing(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            let period = 44.0
            let cycle = (t / period).rounded(.down)
            let phase = t / period - cycle
            guard phase < 0.22 else { return }
            let local = phase / 0.22
            var rng = SeededRNG(seed: skySeed &+ UInt64(bitPattern: Int64(cycle)) &* 97 &+ 3)
            let dir: Double = rng.unit() < 0.5 ? -1 : 1
            let baseY = 0.16 + rng.unit() * 0.26
            let x = (dir > 0 ? -0.12 : 1.12) + dir * 1.24 * local
            let a = Foundation.sin(.pi * min(1, local)) * 0.4 + 0.12
            for i in 0..<6 {
                let di = Double(i)
                let row = (di + 1) / 2
                let side: Double = i % 2 == 0 ? 1 : -1
                let bx = (x - dir * row * 0.032) * Double(s.width)
                let by = (baseY + side * row * 0.02) * Double(s.height)
                let flap = 0.5 + 0.5 * Foundation.sin(t * 3.4 + di * 1.4)
                let wing = 2.8 + flap * 3.2
                var p = Path()
                p.move(to: CGPoint(x: bx - wing, y: by + wing * 0.5))
                p.addLine(to: CGPoint(x: bx, y: by))
                p.addLine(to: CGPoint(x: bx + wing, y: by + wing * 0.5))
                ctx.stroke(p, with: .color(Color(hex: 0x2A2438).opacity(a)), lineWidth: 1.5)
            }
        }
    }

    /// Warm floating motes catching the light: stable seeded homes, tiny local
    /// sway, twinkling alpha — nothing streams anywhere.
    private func dustMotes(W: CGFloat, H: CGFloat, t: Double, tint: Color, count: Int) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0xD057)
            for i in 0..<count {
                let di = Double(i)
                let fx = rng.unit()
                let fy = 0.1 + rng.unit() * 0.7
                let sway = Foundation.sin(t * (0.1 + rng.unit() * 0.14) + di) * 8
                let bob = Foundation.sin(t * (0.08 + rng.unit() * 0.1) + di * 1.7) * 6
                let tw = 0.5 + 0.5 * Foundation.sin(t * (0.4 + rng.unit()) + di * 2.1)
                let a = (0.05 + 0.2 * tw)
                let x = fx * Double(s.width) + sway
                let y = fy * Double(s.height) + bob
                softGlow(&ctx, x: CGFloat(x), y: CGFloat(y),
                         r: CGFloat(1.6 + rng.unit() * 2.2), color: tint.opacity(a))
            }
        }
    }

    /// Lantern moments: each lantern fades in low, rises only a short distance
    /// with a gentle sway, and fades out (~22 s lives, staggered slots).
    private func lanternMoments(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            let warm = Color(hex: 0xFFC873)
            for slot in 0..<7 {
                let period = 22.0
                let shifted = t / period + Double(slot) / 7.0
                let cycle = shifted.rounded(.down)
                let local = shifted - cycle
                let env = Foundation.sin(.pi * local)
                guard env > 0.03 else { continue }
                var rng = SeededRNG(seed: skySeed &+ UInt64(bitPattern: Int64(cycle)) &* 53 &+ UInt64(slot) &* 11)
                let fx = 0.08 + rng.unit() * 0.84
                let baseY = 0.36 + rng.unit() * 0.44
                let rise = local * 0.11                          // ~a tenth of the screen, no more
                let sway = Foundation.sin(t * (0.3 + rng.unit() * 0.3) + rng.unit() * 6) * 7
                let x = fx * Double(s.width) + sway
                let y = (baseY - rise) * Double(s.height)
                let r = 2.2 + rng.unit() * 2.4
                softGlow(&ctx, x: CGFloat(x), y: CGFloat(y), r: CGFloat(r * 3.6),
                         color: warm.opacity(0.55 * env))
                ctx.fill(Path(ellipseIn: CGRect(x: x - r / 2, y: y - r * 0.7, width: r, height: r * 1.4)),
                         with: .color(warm.opacity(0.8 * env)))
            }
        }
    }

    /// Delicate petals: short diagonal flutters that fade in and out locally.
    private func petals(W: CGFloat, H: CGFloat, t: Double, tint: Color) -> some View {
        Canvas { ctx, s in
            for slot in 0..<6 {
                let period = 17.0
                let shifted = t / period + Double(slot) / 6.0
                let cycle = shifted.rounded(.down)
                let local = shifted - cycle
                let env = Foundation.sin(.pi * local)
                guard env > 0.04 else { continue }
                var rng = SeededRNG(seed: skySeed &+ UInt64(bitPattern: Int64(cycle)) &* 41 &+ UInt64(slot) &* 13)
                let fx = rng.unit()
                let fy = 0.12 + rng.unit() * 0.6
                let dx = local * 40 * (rng.unit() < 0.5 ? 1 : -1)
                let dy = local * 26
                let flutter = Foundation.sin(t * 2.2 + rng.unit() * 6) * 3
                let x = fx * Double(s.width) + dx + flutter
                let y = fy * Double(s.height) + dy
                let r = 1.4 + rng.unit() * 1.4
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r * 0.6, width: r * 2, height: r * 1.2)),
                         with: .color(tint.opacity(0.4 * env)))
            }
        }
    }

    /// A soft distant moon glow — light only, no disc.
    private func moonGlow(W: CGFloat, H: CGFloat, t: Double) -> some View {
        let breathe = 0.7 + 0.3 * Foundation.sin(t * 0.03)
        return RadialGradient(colors: [Color(hex: 0xEDF2FB).opacity(0.14 * breathe), .clear],
                              center: UnitPoint(x: 0.76, y: 0.16),
                              startRadius: 2, endRadius: W * 0.4)
    }

    /// Full-width organic aurora curtains, deforming slowly. Pure gradient fill
    /// inside a hand-wavy path — no geometric edge. Each ribbon carries faint
    /// vertical curtain rays that breathe independently, so the light reads as
    /// a true hanging curtain rather than a coloured band.
    private func auroraCurtains(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            let colors = [Color(hex: 0x54E0A8), Color(hex: 0x4FC9DD), Color(hex: 0x8F7BE8)]
            for band in 0..<3 {
                let baseY = s.height * (0.14 + CGFloat(band) * 0.13)
                let amp = s.height * 0.045
                let thick = s.height * 0.15
                let phase = t * 0.09 + Double(band) * 2.1
                let path = flightAuroraRibbon(width: s.width, baseY: baseY,
                                              amp: amp, thickness: thick, phase: phase)
                let c = colors[band]
                let g = Gradient(colors: [c.opacity(0), c.opacity(0.38), c.opacity(0)])
                ctx.fill(path, with: .linearGradient(
                    g, startPoint: CGPoint(x: 0, y: baseY - amp),
                    endPoint: CGPoint(x: 0, y: baseY + thick + amp)))
                // Curtain rays: soft luminous columns hanging inside the ribbon,
                // each swelling on its own slow rhythm.
                for k in 0..<7 {
                    let fx = (Double(k) + 0.5) / 7.0
                    let sway = Foundation.sin(t * 0.05 + Double(k) * 1.7 + Double(band)) * 0.03
                    let x = CGFloat(fx + sway) * s.width
                    let wave = Foundation.sin(Double(x) / 120.0 + phase)
                        + 0.4 * Foundation.sin(Double(x) / 51.0 + phase * 1.6)
                    let topY = baseY + CGFloat(wave) * amp
                    let pulse = 0.5 + 0.5 * Foundation.sin(t * (0.16 + Double(k) * 0.04) + Double(k) * 2.3 + Double(band) * 1.1)
                    let rayA = 0.10 * pulse
                    guard rayA > 0.015 else { continue }
                    var ray = Path()
                    ray.move(to: CGPoint(x: x, y: topY))
                    ray.addLine(to: CGPoint(x: x, y: topY + thick * CGFloat(0.7 + 0.3 * pulse)))
                    ctx.stroke(ray, with: .linearGradient(
                        Gradient(colors: [c.opacity(rayA), c.opacity(0)]),
                        startPoint: CGPoint(x: x, y: topY),
                        endPoint: CGPoint(x: x, y: topY + thick)),
                        lineWidth: s.width * 0.02)
                }
            }
        }
        .blur(radius: 3)
    }

    /// A rare, restrained vertical light pillar (~every 70 s), fully diffused.
    private func lightPillar(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            let period = 70.0
            let cycle = (t / period).rounded(.down)
            let phase = t / period - cycle
            guard phase < 0.2 else { return }
            let env = Foundation.sin(.pi * (phase / 0.2))
            var rng = SeededRNG(seed: skySeed &+ UInt64(bitPattern: Int64(cycle)) &* 29 &+ 5)
            let x = Double(s.width) * (0.2 + rng.unit() * 0.6)
            let n = 6
            for k in 0..<n {
                let f = Double(k) / Double(n - 1)
                let y = Double(s.height) * (0.1 + f * 0.5)
                softGlow(&ctx, x: CGFloat(x), y: CGFloat(y),
                         r: CGFloat(Double(s.width) * 0.05),
                         color: Color(hex: 0x9AE8CE).opacity(0.06 * env))
            }
        }
    }

    /// A soft glow pulsing inside the rain ceiling (never a lightning bolt).
    private func cloudGlow(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            let period = 47.0
            let cycle = (t / period).rounded(.down)
            let phase = t / period - cycle
            guard phase < 0.1 else { return }
            let env = Foundation.sin(.pi * (phase / 0.1))
            var rng = SeededRNG(seed: skySeed &+ UInt64(bitPattern: Int64(cycle)) &* 89 &+ 7)
            let x = CGFloat(0.2 + rng.unit() * 0.6) * s.width
            let y = CGFloat(0.1 + rng.unit() * 0.16) * s.height
            softGlow(&ctx, x: x, y: y, r: s.width * 0.24,
                     color: Color(hex: 0xC8D4F2).opacity(0.16 * env))
        }
    }

    /// Silver mist masses breathing and drifting a few points — never crossing.
    private func mistBreath(W: CGFloat, H: CGFloat, t: Double, tint: Color) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0x315B)
            for i in 0..<3 {
                let di = Double(i)
                let fx = 0.16 + rng.unit() * 0.68
                let fy = 0.3 + rng.unit() * 0.42
                let drift = Foundation.sin(t * 0.02 + di * 2.0) * Double(s.width) * 0.015
                let breathe = 0.7 + 0.3 * Foundation.sin(t * 0.04 + di * 1.4)
                softGlow(&ctx, x: CGFloat(fx * Double(s.width) + drift),
                         y: CGFloat(fy) * s.height,
                         r: s.width * CGFloat(0.2 + rng.unit() * 0.1),
                         color: tint.opacity(0.07 * breathe))
            }
        }
    }

    /// Slow-breathing nebula haze masses — organic colour, no boundaries.
    private func nebulaBreath(W: CGFloat, H: CGFloat, t: Double, tints: [Color]) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0x4EB0)
            for i in 0..<3 {
                let di = Double(i)
                let fx = 0.14 + rng.unit() * 0.72
                let fy = 0.12 + rng.unit() * 0.5
                let drift = Foundation.sin(t * 0.015 + di * 2.4) * Double(s.width) * 0.02
                let breathe = 0.65 + 0.35 * Foundation.sin(t * 0.03 + di * 1.9)
                softGlow(&ctx, x: CGFloat(fx * Double(s.width) + drift),
                         y: CGFloat(fy) * s.height,
                         r: s.width * CGFloat(0.24 + rng.unit() * 0.14),
                         color: tints[i % tints.count].opacity(0.11 * breathe))
            }
        }
    }

    /// An occasional shooting star — a natural streak with a gradient tail.
    private func shootingStar(W: CGFloat, H: CGFloat, t: Double, period: Double) -> some View {
        Canvas { ctx, s in
            let cycle = (t / period).rounded(.down)
            let phase = t / period - cycle
            guard phase < 0.16 else { return }
            let local = phase / 0.16
            var rng = SeededRNG(seed: skySeed &+ UInt64(bitPattern: Int64(cycle)) &* 131 &+ 7)
            let x0 = s.width * CGFloat(0.12 + rng.unit() * 0.76)
            let y0 = s.height * CGFloat(0.05 + rng.unit() * 0.4)
            let dir: CGFloat = rng.unit() < 0.5 ? -1 : 1
            let travel = s.width * 0.4 * CGFloat(local)
            let head = CGPoint(x: x0 - dir * travel, y: y0 + travel * 0.4)
            let tail = CGPoint(x: head.x + dir * 80, y: head.y - 34)
            let a = Foundation.sin(.pi * local) * 0.8
            var p = Path()
            p.move(to: tail)
            p.addLine(to: head)
            let g = Gradient(colors: [Color.white.opacity(0), Color(hex: 0xE6F2FF).opacity(a)])
            ctx.stroke(p, with: .linearGradient(g, startPoint: tail, endPoint: head), lineWidth: 1.5)
            ctx.fill(Path(ellipseIn: CGRect(x: head.x - 1.6, y: head.y - 1.6, width: 3.2, height: 3.2)),
                     with: .color(.white.opacity(a)))
        }
    }

    // MARK: 5 — Weather (rain / snow fall naturally; they are weather, not scenery)

    @ViewBuilder private func weather(W: CGFloat, H: CGFloat, t: Double) -> some View {
        switch sky.flightParticles {
        case .none, .lanterns:
            EmptyView()   // lanterns are an effect moment, not falling weather
        case .snow:
            Canvas { ctx, s in
                var rng = SeededRNG(seed: skySeed &+ 0x5A0F)
                let span = Double(s.height) + 40
                for i in 0..<36 {
                    let di = Double(i)
                    let fx = rng.unit(); let fy = rng.unit()
                    let speed = 12.0 + rng.unit() * 16.0
                    let y = (fy * span + t * speed).truncatingRemainder(dividingBy: span) - 20
                    let sway = Foundation.sin(t * (0.4 + rng.unit()) + di) * (4 + rng.unit() * 7)
                    let x = fx * Double(s.width) + sway
                    let r = 0.9 + rng.unit() * 1.7
                    softGlow(&ctx, x: CGFloat(x), y: CGFloat(y), r: CGFloat(r),
                             color: .white.opacity(0.28 + rng.unit() * 0.34))
                }
            }
        case .rain:
            Canvas { ctx, s in
                var rng = SeededRNG(seed: skySeed &+ 0x0A17)
                let span = Double(s.height) + 40
                for _ in 0..<44 {
                    let fx = rng.unit(); let fy = rng.unit()
                    let speed = 140.0 + rng.unit() * 100.0
                    let y = (fy * span + t * speed).truncatingRemainder(dividingBy: span) - 20
                    let x = fx * Double(s.width) - y * 0.05
                    let len = 8.0 + rng.unit() * 9.0
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x - len * 0.12, y: y + len))
                    ctx.stroke(p, with: .color(Color(hex: 0xBFD0EC).opacity(0.09 + rng.unit() * 0.12)),
                               lineWidth: 1)
                }
            }
        }
    }

    // MARK: 6 — The permanent Ground

    /// The Sky's Ground artwork, anchored to the bottom for the WHOLE flight —
    /// never scrolling, never fading, never repeating. Its top edge dissolves
    /// into the sky, and a whisper of the current palette settles over it.
    @ViewBuilder private func groundLayer(W: CGFloat, H: CGFloat) -> some View {
        let gh = H * 0.30
        let tintColor = SkyGradientTimeline.stops(skyID: sky.id, at: max(0, elapsed())).last ?? sky.glowColor
        Group {
            #if canImport(UIKit)
            if let ui = UIImage(named: sky.groundAssetName) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: W, height: gh, alignment: .top)
                    .clipped()
                    .mask(LinearGradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.3),
                        .init(color: .black, location: 1),
                    ], startPoint: .top, endPoint: .bottom))
                    .overlay(LinearGradient(colors: [.clear, tintColor.opacity(0.16)],
                                            startPoint: .top, endPoint: .bottom))
            } else {
                proceduralGround(W: W, H: H)
            }
            #else
            proceduralGround(W: W, H: H)
            #endif
        }
        .frame(width: W, height: gh)
        .position(x: W / 2, y: H - gh / 2)
    }

    /// Fallback ground: the Sky's landmark silhouette resting low, permanent.
    private func proceduralGround(W: CGFloat, H: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [.clear, Color.black.opacity(0.45)],
                           startPoint: .top, endPoint: .bottom)
            LandmarkSilhouette(landmark: sky.landmark)
                .fill(Color.black.opacity(0.3))
                .frame(width: W * 1.15, height: H * 0.16)
                .offset(y: -H * 0.03)
            LandmarkSilhouette(landmark: sky.landmark)
                .fill(Color.black.opacity(0.5))
                .frame(width: W * 1.3, height: H * 0.12)
        }
    }

    #if DEBUG
    private func inspector(t: Double) -> some View {
        let seg = SkyGradientTimeline.segmentInfo(skyID: sky.id, at: t)
        return VStack(alignment: .leading, spacing: 2) {
            Text("sky \(sky.id) · seed \(seed)")
            Text("palette segment \(seg.index) · blend \(Int(seg.blend * 100))%")
            Text(String(format: "elapsed %.1fs · clock %@", t, animated ? "live" : "static"))
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white)
        .padding(6)
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 60)
        .padding(.leading, 10)
    }
    #endif
}

// MARK: - The per-Sky gradient timeline

/// Authored palette keyframes per Sky (5 stops, top → bottom). The sky blends
/// between neighbouring keyframes over ~70 s each, ping-pong looped so every
/// transition — including the turnaround — is perfectly smooth. Every keyframe
/// belongs to the Sky's colour family: Golden Hour never leaves warm light.
enum SkyGradientTimeline {
    static let segmentDuration: Double = 70

    static func stops(skyID: String, at t: Double) -> [Color] {
        let frames = timelines[skyID] ?? timelines["golden-hour"]!
        let info = segmentInfo(skyID: skyID, at: t)
        let a = frames[info.index]
        let b = frames[info.nextIndex]
        let e = smooth(info.blend)
        var out: [Color] = []
        for i in 0..<min(a.count, b.count) {
            out.append(lerpHex(a[i], b[i], e))
        }
        return out
    }

    /// Ping-pong indexing: 0,1,…,n-1,n-2,…,0,1,… — no wrap seam ever.
    static func segmentInfo(skyID: String, at t: Double) -> (index: Int, nextIndex: Int, blend: Double) {
        let frames = timelines[skyID] ?? timelines["golden-hour"]!
        let n = frames.count
        guard n > 1 else { return (0, 0, 0) }
        let pos = max(0, t) / segmentDuration
        let seg = Int(pos)
        let blend = pos - Double(seg)
        let cycle = 2 * (n - 1)
        let m = seg % cycle
        let i = m < n - 1 ? m : cycle - m
        let j = m < n - 1 ? i + 1 : i - 1
        return (i, max(0, min(n - 1, j)), blend)
    }

    private static func smooth(_ x: Double) -> Double { x * x * (3 - 2 * x) }

    private static func lerpHex(_ a: UInt, _ b: UInt, _ f: Double) -> Color {
        let ar = Double((a >> 16) & 0xFF), ag = Double((a >> 8) & 0xFF), ab = Double(a & 0xFF)
        let br = Double((b >> 16) & 0xFF), bg = Double((b >> 8) & 0xFF), bb = Double(b & 0xFF)
        return Color(red: (ar + (br - ar) * f) / 255,
                     green: (ag + (bg - ag) * f) / 255,
                     blue: (ab + (bb - ab) * f) / 255)
    }

    /// The authored timelines. Each row is one keyframe: 5 stops top → bottom.
    static let timelines: [String: [[UInt]]] = [
        // Warm from first light to dusk: gold → honey → coral → rose → warm plum.
        "golden-hour": [
            [0x3A2338, 0x8E4A46, 0xD9814E, 0xF2A96A, 0xF6C48C],
            [0x46283C, 0x9E5648, 0xE0925A, 0xF6BE7E, 0xFAD9A8],
            [0x48223E, 0xA04A50, 0xE0745A, 0xF29B6A, 0xF6B88C],
            [0x3A1F40, 0x8A4058, 0xC96058, 0xE8906E, 0xEEB08A],
            [0x2A1838, 0x5E3450, 0x94505E, 0xBE7060, 0xD08E6A],
        ],
        "fiji-lagoon": [
            [0x0C3644, 0x156274, 0x2E96A0, 0x6CC8C4, 0xC8F0E0],
            [0x0E3E4E, 0x1A7080, 0x3AA8AC, 0x86D8CC, 0xE2FAEE],
            [0x0A3240, 0x14586C, 0x2A8C9C, 0x62C0BE, 0xBCEADC],
            [0x0E4452, 0x1E7C88, 0x46B0B0, 0x92DCD0, 0xE8FBF2],
            [0x082C3A, 0x125064, 0x268494, 0x58B8B8, 0xACE2D6],
        ],
        "kyoto-lanterns": [
            [0x241534, 0x4A2A4E, 0x7E4260, 0xB86A6E, 0xE8A882],
            [0x2A1838, 0x543054, 0x8E4A66, 0xC87878, 0xF2BE94],
            [0x1E1230, 0x422648, 0x743E5C, 0xAA6068, 0xD89678],
            [0x281640, 0x502C5C, 0x86466C, 0xBE7080, 0xECAC90],
            [0x1A0F2C, 0x381F42, 0x643654, 0x985462, 0xC48470],
        ],
        "aurora-snowfield": [
            [0x04101E, 0x0A2434, 0x104C48, 0x2E9678, 0x7EDCB4],
            [0x061424, 0x0E2C40, 0x166058, 0x3CB08C, 0x96E8C4],
            [0x040E1C, 0x0A2030, 0x0E4450, 0x2A8880, 0x6ED0BE],
            [0x081828, 0x123448, 0x1C6862, 0x48BC9A, 0xA6ECCE],
            [0x030B18, 0x081C2C, 0x0C3A44, 0x227670, 0x5EC4AE],
        ],
        "rainy-tokyo": [
            [0x0A0F20, 0x141E38, 0x243354, 0x3E4E78, 0x5C6A9A],
            [0x0C1224, 0x18243E, 0x2A3A5E, 0x485A84, 0x6E7EA8],
            [0x080D1C, 0x121B34, 0x202E4E, 0x384870, 0x546294],
            [0x0E1428, 0x1C2842, 0x304264, 0x50628C, 0x7888B0],
            [0x070B18, 0x101830, 0x1C2A48, 0x324068, 0x4C5A8A],
        ],
        "moon-garden": [
            [0x0C1226, 0x1C2A46, 0x35486A, 0x6A80A0, 0xB4C4D8],
            [0x101830, 0x243452, 0x405476, 0x7C92B0, 0xC8D6E6],
            [0x0A0F22, 0x18243E, 0x2E4060, 0x5E7494, 0xA6B8CE],
            [0x121A34, 0x283A58, 0x485E80, 0x8AA0BC, 0xD4E0EC],
            [0x080C1E, 0x141E36, 0x283A58, 0x54688A, 0x9AACC4],
        ],
        "swiss-alps": [
            [0x14283E, 0x2A4A66, 0x4E7A96, 0x8CB4C8, 0xE0EEF2],
            [0x18304A, 0x325674, 0x5C88A4, 0x9EC2D2, 0xEEF6F8],
            [0x102236, 0x24425C, 0x446E8C, 0x7EA8C0, 0xD2E6EE],
            [0x1C3852, 0x3A6280, 0x6896B0, 0xACCCDA, 0xF4FAFA],
            [0x0E1E30, 0x1F3A54, 0x3C6284, 0x729CB6, 0xC4DCE8],
        ],
        "sahara-night": [
            [0x120C24, 0x2E1C3E, 0x583452, 0x94585A, 0xD08A5E],
            [0x160E2A, 0x362246, 0x643C58, 0xA46460, 0xDC9866],
            [0x0E0A20, 0x281838, 0x4E2E4C, 0x845052, 0xBE7C58],
            [0x1A1230, 0x3E284E, 0x704460, 0xB47066, 0xE8A66E],
            [0x0B081C, 0x221430, 0x442846, 0x74464C, 0xAA6E52],
        ],
        "galaxy-drift": [
            [0x0A0620, 0x1E1148, 0x3C2472, 0x6E44A8, 0xA878D0],
            [0x0C0826, 0x241554, 0x462C80, 0x7E52B8, 0xBC8ADC],
            [0x080518, 0x180D3C, 0x321E64, 0x5E3A98, 0x9468C4],
            [0x0E0A2C, 0x2A1960, 0x50338C, 0x8A5CC4, 0xC896E4],
            [0x060412, 0x120A30, 0x281852, 0x4E3084, 0x8058B4],
        ],
        "deep-space": [
            [0x020308, 0x060B18, 0x0E1630, 0x1E2A4E, 0x3A4A72],
            [0x030410, 0x080E20, 0x121C3A, 0x263458, 0x46567E],
            [0x010206, 0x050912, 0x0B1226, 0x182242, 0x303E64],
            [0x04051A, 0x0A1228, 0x162244, 0x2E3E62, 0x526288],
            [0x010204, 0x04070E, 0x090F1E, 0x141C38, 0x283454],
        ],
        "paris-sunset": [
            [0x32204A, 0x7A3E5E, 0xC06058, 0xEE9066, 0xF8BE8C],
            [0x3A2452, 0x8A4866, 0xD06A5E, 0xF6A070, 0xFCD0A0],
            [0x2C1C44, 0x6E3858, 0xB25654, 0xE08462, 0xF2B284],
            [0x241740, 0x5C3060, 0x9A4C64, 0xCC7470, 0xE8A488],
            [0x1C1236, 0x482852, 0x7E4260, 0xAE6468, 0xD08E7A],
        ],
    ]
}

// MARK: - Shared drawing helpers

/// A soft radial glow — the universal organic building block. Always fades
/// fully to clear, so nothing ever shows a boundary.
private func softGlow(_ ctx: inout GraphicsContext, x: CGFloat, y: CGFloat, r: CGFloat, color: Color) {
    let g = Gradient(colors: [color, color.opacity(0)])
    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
             with: .radialGradient(g, center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r))
}

/// An organic aurora ribbon: both edges wave independently, in small typed
/// steps so the type-checker stays fast.
private func flightAuroraRibbon(width: CGFloat, baseY: CGFloat, amp: CGFloat,
                                thickness: CGFloat, phase: Double) -> Path {
    var p = Path()
    var x: CGFloat = -12
    var first = true
    while x <= width + 12 {
        let xv = Double(x)
        let w1 = Foundation.sin(xv / 120.0 + phase)
        let w2 = 0.4 * Foundation.sin(xv / 51.0 + phase * 1.6)
        let y = baseY + CGFloat(w1 + w2) * amp
        if first { p.move(to: CGPoint(x: x, y: y)); first = false }
        else { p.addLine(to: CGPoint(x: x, y: y)) }
        x += 14
    }
    var xr: CGFloat = width + 12
    while xr >= -12 {
        let xv = Double(xr)
        let w1 = Foundation.sin(xv / 120.0 + phase + 0.6)
        let w2 = 0.4 * Foundation.sin(xv / 51.0 + phase * 1.6 + 0.4)
        let y = baseY + thickness + CGFloat(w1 + w2) * (amp * 0.8)
        p.addLine(to: CGPoint(x: xr, y: y))
        xr -= 14
    }
    p.closeSubpath()
    return p
}
