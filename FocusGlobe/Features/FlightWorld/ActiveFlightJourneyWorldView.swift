import Foundation
import SwiftUI

// MARK: - Colour model
//
// A tiny RGB value type so palettes can be *interpolated* smoothly. The whole
// flight is one continuously-morphing full-screen scene — worlds cross-fade by
// blending these, so there is never a stacked-chapter seam or a hard band.

private struct RGBA {
    var r: Double; var g: Double; var b: Double
    func mix(_ o: RGBA, _ t: Double) -> RGBA {
        RGBA(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t)
    }
    func color(_ a: Double = 1) -> Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
}

private func rgb(_ hex: UInt) -> RGBA {
    RGBA(r: Double((hex >> 16) & 0xFF) / 255.0,
         g: Double((hex >> 8) & 0xFF) / 255.0,
         b: Double(hex & 0xFF) / 255.0)
}

// MARK: - Small maths helpers (all in tiny typed steps; trig via Foundation)

private func clamp01(_ x: Double) -> Double { x < 0 ? 0 : (x > 1 ? 1 : x) }
private func smoothstep(_ x: Double) -> Double { let t = clamp01(x); return t * t * (3 - 2 * t) }
private func smootherstep(_ x: Double) -> Double { let t = clamp01(x); return t * t * t * (t * (t * 6 - 15) + 10) }
private func fract(_ x: Double) -> Double { x - x.rounded(.down) }
/// Cheap deterministic pseudo-random in [0,1) — stable per index+seed, so nothing
/// jitters frame to frame (the values depend only on the seeds, never the clock).
private func hash1(_ n: Double) -> Double { fract(Foundation.sin(n) * 43758.5453) }
private func hash2(_ a: Double, _ b: Double) -> Double { fract(Foundation.sin(a * 127.1 + b * 311.7) * 43758.5453) }

// MARK: - World presets

private enum Celestial {
    case none, moon, crescentMoon, ringedPlanet, gasGiant, icePlanet, giantHazy, twinMoons
}

private struct GlowSpec { let tint: RGBA; let x: Double; let y: Double; let radius: Double; let alpha: Double }

/// A composable sky world. Only `name` + `sky` are required; everything else
/// defaults off, so each world literal only declares the layers it uses. Worlds
/// are blended pairwise every frame, so all these fields interpolate.
private struct SkyWorld {
    var name: String
    var sky: [RGBA]                       // 4 stops, top → bottom
    var starDensity: Double = 0.5
    var starTint: RGBA = rgb(0xFFFFFF)
    var nebulaAmt: Double = 0
    var nebula: [RGBA] = []
    var auroraAmt: Double = 0
    var aurora: [RGBA] = []
    var cloudAmt: Double = 0
    var cloud: RGBA = rgb(0xFFFFFF)
    var cloudLit: RGBA = rgb(0xFFFFFF)
    var fogAmt: Double = 0
    var fog: RGBA = rgb(0xFFFFFF)
    var horizonAmt: Double = 0
    var horizon: RGBA = rgb(0x0A0F1E)
    var celestial: Celestial = .none
    var glowA: GlowSpec? = nil
    var glowB: GlowSpec? = nil
    var mood: Double = 0.5               // brightness bias (drives event tone)
}

private enum SkyWorldLibrary {
    static let worlds: [SkyWorld] = [
        // 1 — Deep starfield: a vast blue-black void, dense stars, faint nebula.
        SkyWorld(name: "Deep Starfield",
                 sky: [rgb(0x05070F), rgb(0x080B1C), rgb(0x0B1024), rgb(0x0E1430)],
                 starDensity: 1.0, nebulaAmt: 0.4, nebula: [rgb(0x3A2E6E), rgb(0x22406E)], mood: 0.30),
        // 2 — Moonlit clouds: navy sky, a bright moon, lit cloud banks.
        SkyWorld(name: "Moonlit Clouds",
                 sky: [rgb(0x141B33), rgb(0x1E2A4A), rgb(0x2C3A5E), rgb(0x35456B)],
                 starDensity: 0.5, cloudAmt: 0.95, cloud: rgb(0x8898B8), cloudLit: rgb(0xE8F0FF),
                 celestial: .moon, mood: 0.5),
        // 3 — Aurora field: green/teal curtains undulating over stars.
        SkyWorld(name: "Aurora Field",
                 sky: [rgb(0x040A18), rgb(0x08132A), rgb(0x0C1B38), rgb(0x102244)],
                 starDensity: 0.85, auroraAmt: 1.0,
                 aurora: [rgb(0x54E0A8), rgb(0x4FC9DD), rgb(0x8F7BE8)], mood: 0.4),
        // 4 — Misty twilight: indigo haze, a soft moon, low ridges.
        SkyWorld(name: "Misty Twilight",
                 sky: [rgb(0x241E44), rgb(0x33305E), rgb(0x474072), rgb(0x574D80)],
                 starDensity: 0.35, fogAmt: 0.9, fog: rgb(0xB9A8E8),
                 horizonAmt: 0.45, horizon: rgb(0x14102A), celestial: .moon, mood: 0.5),
        // 5 — Cosmic void: blue-purple, a ringed planet, drifting nebula.
        SkyWorld(name: "Cosmic Void",
                 sky: [rgb(0x0A0620), rgb(0x140A34), rgb(0x1C1048), rgb(0x241458)],
                 starDensity: 0.7, nebulaAmt: 0.55, nebula: [rgb(0x6E3AE8), rgb(0x3A6EE8), rgb(0x9B3AE8)],
                 celestial: .ringedPlanet, mood: 0.4),
        // 6 — Giant planet passage: a huge banded gas giant, warm glow.
        SkyWorld(name: "Giant Passage",
                 sky: [rgb(0x1A1024), rgb(0x2A1630), rgb(0x3A1E38), rgb(0x241634)],
                 starDensity: 0.6, celestial: .gasGiant,
                 glowA: GlowSpec(tint: rgb(0xE8B080), x: 0.5, y: 0.7, radius: 0.6, alpha: 0.16), mood: 0.55),
        // 7 — Nebula glow: violet / teal / rose pools of light.
        SkyWorld(name: "Nebula Glow",
                 sky: [rgb(0x0C0A26), rgb(0x161042), rgb(0x1E1650), rgb(0x120E36)],
                 starDensity: 0.8, nebulaAmt: 0.95,
                 nebula: [rgb(0x8A6CE8), rgb(0x4C6CE8), rgb(0x3CC8C0), rgb(0xE86C9B)], mood: 0.45),
        // 8 — Icy upper atmosphere: silver-blue, ice planet, high haze.
        SkyWorld(name: "Icy Atmosphere",
                 sky: [rgb(0x1A2E44), rgb(0x274460), rgb(0x3A5C7C), rgb(0x50748E)],
                 starDensity: 0.4, cloudAmt: 0.35, cloud: rgb(0xD8E6F2), cloudLit: rgb(0xFFFFFF),
                 fogAmt: 0.6, fog: rgb(0xCFE2F2), celestial: .icePlanet, mood: 0.6),
        // 9 — Lavender haze: dreamy violet, soft fog, a crescent moon.
        SkyWorld(name: "Lavender Haze",
                 sky: [rgb(0x2E2450), rgb(0x413066), rgb(0x574080), rgb(0x6B5296)],
                 starDensity: 0.3, cloudAmt: 0.5, cloud: rgb(0xB9A0DC), cloudLit: rgb(0xF0E4FF),
                 fogAmt: 0.75, fog: rgb(0xC9B4E8), celestial: .crescentMoon, mood: 0.55),
        // 10 — Dawn celestial: pale peach / gold gradient, thin backlit cloud.
        SkyWorld(name: "Dawn Celestial",
                 sky: [rgb(0x3A3658), rgb(0x6A4E6E), rgb(0x9E6E72), rgb(0xD0A488)],
                 starDensity: 0.2, cloudAmt: 0.7, cloud: rgb(0xF0DCC8), cloudLit: rgb(0xFFF0E0),
                 horizonAmt: 0.3, horizon: rgb(0x2A2036),
                 glowA: GlowSpec(tint: rgb(0xF4D9A6), x: 0.5, y: 0.82, radius: 0.5, alpha: 0.3), mood: 0.7),
        // 11 — Green-blue currents: surreal teal sky rivers.
        SkyWorld(name: "Teal Currents",
                 sky: [rgb(0x06181C), rgb(0x0A2A2E), rgb(0x0E3A3A), rgb(0x124A44)],
                 starDensity: 0.5, auroraAmt: 0.75, aurora: [rgb(0x3CC8A0), rgb(0x2AB0C8), rgb(0x54E0B0)],
                 fogAmt: 0.4, fog: rgb(0x8AD8C8), mood: 0.45),
        // 12 — Deep focus: near-black premium void, a giant hazy silhouette.
        SkyWorld(name: "Deep Focus",
                 sky: [rgb(0x030512), rgb(0x05060F), rgb(0x070914), rgb(0x0A0C18)],
                 starDensity: 0.9, nebulaAmt: 0.2, nebula: [rgb(0x1E2A50)],
                 celestial: .giantHazy, mood: 0.2),
        // 13 — Silver moon: cratered silver moon over cool cloud.
        SkyWorld(name: "Silver Moon",
                 sky: [rgb(0x10182C), rgb(0x1C2A44), rgb(0x2A3A56), rgb(0x36486A)],
                 starDensity: 0.55, cloudAmt: 0.7, cloud: rgb(0x9AA8C0), cloudLit: rgb(0xEFF4FF),
                 celestial: .moon, mood: 0.5),
        // 14 — Rose dusk: muted rose / violet, a moon, warm rose glow.
        SkyWorld(name: "Rose Dusk",
                 sky: [rgb(0x2A1E38), rgb(0x442A4A), rgb(0x6E3E5A), rgb(0x9E5E6E)],
                 starDensity: 0.3, cloudAmt: 0.7, cloud: rgb(0xE8C4C8), cloudLit: rgb(0xFFE8E0),
                 celestial: .twinMoons,
                 glowA: GlowSpec(tint: rgb(0xE8A0A8), x: 0.4, y: 0.6, radius: 0.5, alpha: 0.16), mood: 0.6),
    ]

    /// A seeded, adjacent-safe ordering of the worlds. Cheap to rebuild (called
    /// once per frame), fully deterministic per session seed — no caching needed.
    static func sequence(seed: UInt64) -> [Int] {
        var rng = SeededRNG(seed: seed == 0 ? 0xA5A5_1234 : seed)
        let count = worlds.count
        var order = Array(0..<count)
        var i = count - 1
        while i > 0 {
            let j = Int(rng.unit() * Double(i + 1))
            order.swapAt(i, min(j, i))
            i -= 1
        }
        return order
    }
}

// MARK: - The active-flight world view

/// The active flight: one continuously-alive, continuously-morphing sky. There
/// are no stacked chapters and no vertical tape — the whole screen is a single
/// composited scene whose palette and dressing blend smoothly from one world to
/// the next, so transitions never reveal a seam. Every layer moves (drifting
/// clouds, flowing mist, twinkling parallax stars, undulating aurora, slowly
/// drifting celestial bodies) and a multi-track event system keeps something
/// happening every few seconds.
struct ActiveFlightJourneyWorldView: View {
    /// Live elapsed focus seconds (pause-aware) — drives world progression.
    let elapsed: () -> Double
    /// Stable per-session seed: world order and dressing vary between flights.
    var seed: UInt64 = 1
    var animated: Bool = true

    var body: some View {
        TimelineView(.animation(minimumInterval: animated ? 1.0 / 40.0 : 1.0 / 5.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                renderScene(&ctx, size: size, clock: t, elapsed: max(0, elapsed()),
                            seed: seed, animated: animated)
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Scene compositor

private func renderScene(_ c: inout GraphicsContext, size: CGSize, clock: Double,
                         elapsed e: Double, seed: UInt64, animated: Bool) {
    let W = Double(size.width)
    let H = Double(max(1, size.height))
    let mt = animated ? clock : 0                 // motion clock (frozen for reduce-motion)
    let sd = Double(seed % 100_000) * 0.001 + 1

    // World morph: continuously interpolate world[i] → world[i+1] across the slot,
    // eased so we settle near each world yet never fully stop evolving. Continuous
    // at every boundary (blend→1 equals the next slot's blend→0), so it is seamless.
    let worlds = SkyWorldLibrary.worlds
    let seq = SkyWorldLibrary.sequence(seed: seed)
    let dwell = 44.0
    let fpos = e / dwell
    let idx = Int(fpos.rounded(.down))
    let blend = smootherstep(fpos - Double(idx))
    let A = worlds[seq[idx % seq.count]]
    let B = worlds[seq[(idx + 1) % seq.count]]

    // 1 — Sky gradient (full screen; never a seam).
    let stops = zip(A.sky, B.sky).map { $0.mix($1, blend) }
    drawSky(&c, W: W, H: H, stops: stops)

    // 2 — Far star layer (slow parallax drift, twinkle).
    let starDen = lerp(A.starDensity, B.starDensity, blend)
    let starTint = A.starTint.mix(B.starTint, blend)
    drawStars(&c, W: W, H: H, t: mt, density: starDen, tint: starTint, sd: sd, near: false)

    // 3 — Nebula pools (both worlds cross-fade).
    if !A.nebula.isEmpty && A.nebulaAmt > 0.001 {
        drawNebula(&c, W: W, H: H, t: mt, amt: A.nebulaAmt * (1 - blend), colors: A.nebula, sd: sd)
    }
    if !B.nebula.isEmpty && B.nebulaAmt > 0.001 {
        drawNebula(&c, W: W, H: H, t: mt, amt: B.nebulaAmt * blend, colors: B.nebula, sd: sd + 13)
    }

    // 4 — Aurora curtains (both worlds cross-fade).
    if !A.aurora.isEmpty && A.auroraAmt > 0.001 {
        drawAurora(&c, W: W, H: H, t: mt, amt: A.auroraAmt * (1 - blend), colors: A.aurora, sd: sd)
    }
    if !B.aurora.isEmpty && B.auroraAmt > 0.001 {
        drawAurora(&c, W: W, H: H, t: mt, amt: B.auroraAmt * blend, colors: B.aurora, sd: sd + 9)
    }

    // 5 — Moving glow pools.
    drawGlow(&c, W: W, H: H, t: mt, spec: A.glowA, fade: 1 - blend)
    drawGlow(&c, W: W, H: H, t: mt, spec: A.glowB, fade: 1 - blend)
    drawGlow(&c, W: W, H: H, t: mt, spec: B.glowA, fade: blend)
    drawGlow(&c, W: W, H: H, t: mt, spec: B.glowB, fade: blend)

    // 6 — Celestial bodies (cross-fade the two worlds' bodies).
    if A.celestial != .none && blend < 0.999 {
        drawCelestial(&c, W: W, H: H, t: mt, kind: A.celestial, alpha: 1 - blend, sd: sd)
    }
    if B.celestial != .none && blend > 0.001 {
        drawCelestial(&c, W: W, H: H, t: mt, kind: B.celestial, alpha: blend, sd: sd + 47)
    }

    // 7 — Near star layer (brighter, faster parallax, in front of nebula).
    drawStars(&c, W: W, H: H, t: mt, density: starDen, tint: starTint, sd: sd + 3, near: true)

    // 8 — Cloud banks (three parallax depths).
    let cloudAmt = lerp(A.cloudAmt, B.cloudAmt, blend)
    if cloudAmt > 0.001 {
        drawClouds(&c, W: W, H: H, t: mt, amt: cloudAmt,
                   tint: A.cloud.mix(B.cloud, blend), lit: A.cloudLit.mix(B.cloudLit, blend), sd: sd)
    }

    // 9 — Fog / mist (flowing sheets + swaying haze columns).
    let fogAmt = lerp(A.fogAmt, B.fogAmt, blend)
    if fogAmt > 0.001 {
        drawFog(&c, W: W, H: H, t: mt, amt: fogAmt, tint: A.fog.mix(B.fog, blend), sd: sd)
    }

    // 10 — Horizon silhouettes (grounded worlds only).
    let horAmt = lerp(A.horizonAmt, B.horizonAmt, blend)
    if horAmt > 0.001 {
        drawHorizon(&c, W: W, H: H, amt: horAmt, tint: A.horizon.mix(B.horizon, blend), sd: sd)
    }

    // 11 — Events (foreground; only when animated).
    if animated {
        let mood = lerp(A.mood, B.mood, blend)
        drawEvents(&c, W: W, H: H, t: clock, sd: sd, mood: mood)
    }

    // 12 — Atmospheric vignette for depth + legibility.
    drawVignette(&c, W: W, H: H)
}

private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

// MARK: - Low-level draw primitives (all casts to CGFloat centralised here)

private func softDisc(_ c: inout GraphicsContext, x: Double, y: Double, r: Double, _ color: Color) {
    guard r > 0.5 else { return }
    let g = Gradient(colors: [color, color.opacity(0)])
    c.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
           with: .radialGradient(g, center: CGPoint(x: x, y: y), startRadius: 0, endRadius: CGFloat(r)))
}

private func fillDisc(_ c: inout GraphicsContext, x: Double, y: Double, r: Double, _ color: Color) {
    guard r > 0.3 else { return }
    c.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(color))
}

private func strokeCircle(_ c: inout GraphicsContext, x: Double, y: Double, r: Double, _ color: Color, _ w: Double) {
    c.stroke(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
             with: .color(color), lineWidth: CGFloat(w))
}

private func lineGrad(_ c: inout GraphicsContext, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double,
                      _ from: Color, _ to: Color, _ w: Double) {
    var p = Path(); p.move(to: CGPoint(x: x1, y: y1)); p.addLine(to: CGPoint(x: x2, y: y2))
    let g = Gradient(colors: [from, to])
    c.stroke(p, with: .linearGradient(g, startPoint: CGPoint(x: x1, y: y1), endPoint: CGPoint(x: x2, y: y2)),
             lineWidth: CGFloat(w))
}

// MARK: - Sky

private func drawSky(_ c: inout GraphicsContext, W: Double, H: Double, stops: [RGBA]) {
    let colors = stops.map { $0.color() }
    let g = Gradient(colors: colors)
    c.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)),
           with: .linearGradient(g, startPoint: CGPoint(x: W / 2, y: 0), endPoint: CGPoint(x: W / 2, y: H)))
}

// MARK: - Stars (two parallax layers, drifting + twinkling)

private func drawStars(_ c: inout GraphicsContext, W: Double, H: Double, t: Double,
                       density: Double, tint: RGBA, sd: Double, near: Bool) {
    let base = near ? 80.0 : 220.0
    let n = Int(base * (0.45 + density))
    let drift = near ? 15.0 : 6.0
    let span = H + 40
    var i = 0
    while i < n {
        let di = Double(i)
        let fx = hash2(di + sd, near ? 5.1 : 2.3)
        let fy = hash2(di + sd, near ? 9.7 : 4.9)
        let x = fx * W
        let y = fract((fy * span + t * drift) / span) * span - 20
        let sz = near ? (0.8 + hash1(di + sd) * 2.0) : (0.4 + hash1(di + sd) * 0.8)
        let twSpeed = 0.5 + hash1(di * 1.7 + sd) * 2.4
        let tw = 0.55 + 0.45 * Foundation.sin(t * twSpeed + di * 1.3)
        let baseA = (near ? 0.55 : 0.30) * (0.4 + hash1(di + sd) * 0.6)
        let a = baseA * tw
        fillDisc(&c, x: x, y: y, r: sz, tint.color(a))
        if near && hash1(di * 3.1 + sd) > 0.9 {
            let gl = sz * 3.6
            lineGrad(&c, x - gl, y, x + gl, y, tint.color(0), tint.color(a * 0.6), 0.7)
            lineGrad(&c, x, y - gl, x, y + gl, tint.color(0), tint.color(a * 0.6), 0.7)
        }
        i += 1
    }
}

// MARK: - Nebula (soft breathing, drifting pools)

private func drawNebula(_ c: inout GraphicsContext, W: Double, H: Double, t: Double,
                        amt: Double, colors: [RGBA], sd: Double) {
    let pools = 6
    var i = 0
    while i < pools {
        let di = Double(i)
        let col = colors[i % colors.count]
        let bx = hash2(di + sd, 3.3)
        let by = hash2(di + sd, 8.1)
        let dx = Foundation.sin(t * (0.02 + hash1(di + sd) * 0.03) + di) * 0.06
        let dy = Foundation.cos(t * 0.015 + di) * 0.04
        let x = (bx + dx) * W
        let y = (by * 0.85 + dy) * H
        let breathe = 0.75 + 0.25 * Foundation.sin(t * 0.08 + di * 2)
        let r = (0.30 + hash1(di + sd) * 0.24) * min(W, H) * 1.5 * breathe
        let a = amt * (0.10 + hash1(di * 2 + sd) * 0.10)
        softDisc(&c, x: x, y: y, r: r, col.color(a))
        i += 1
    }
}

// MARK: - Aurora (vertical undulating curtains)

private func drawAurora(_ c: inout GraphicsContext, W: Double, H: Double, t: Double,
                        amt: Double, colors: [RGBA], sd: Double) {
    let curtains = 5
    var k = 0
    while k < curtains {
        let dk = Double(k)
        let col = colors[k % colors.count]
        let cxBase = 0.12 + 0.76 * (dk / Double(curtains - 1))
        let sway = Foundation.sin(t * (0.12 + hash1(dk + sd) * 0.1) + dk) * 0.05
        let cx = (cxBase + sway) * W
        let width = (0.06 + hash1(dk + sd) * 0.055) * W
        let topY = 0.02 * H
        let botY = (0.48 + hash1(dk * 2 + sd) * 0.3) * H
        let path = auroraCurtainPath(cx: cx, width: width, topY: topY, botY: botY, t: t, phase: dk * 1.7 + sd)
        let a = amt * (0.30 + hash1(dk + sd) * 0.16)
        let g = Gradient(stops: [
            .init(color: col.color(0), location: 0),
            .init(color: col.color(a), location: 0.32),
            .init(color: col.color(a * 0.5), location: 0.7),
            .init(color: col.color(0), location: 1)
        ])
        c.fill(path, with: .linearGradient(g, startPoint: CGPoint(x: cx, y: topY), endPoint: CGPoint(x: cx, y: botY)))
        k += 1
    }
}

private func auroraCurtainPath(cx: Double, width: Double, topY: Double, botY: Double,
                               t: Double, phase: Double) -> Path {
    let steps = 22
    let dh = (botY - topY) / Double(steps)
    var left: [CGPoint] = []
    var right: [CGPoint] = []
    var i = 0
    while i <= steps {
        let yy = topY + Double(i) * dh
        let w1 = Foundation.sin(yy * 0.012 + t * 0.6 + phase)
        let w2 = 0.4 * Foundation.sin(yy * 0.03 + t * 0.9 + phase * 1.4)
        let off = (w1 + w2) * width * 0.5
        let taper = 0.35 + 0.65 * Foundation.sin(Double(i) / Double(steps) * Double.pi)
        let half = width * 0.5 * taper
        left.append(CGPoint(x: cx + off - half, y: yy))
        right.append(CGPoint(x: cx + off + half, y: yy))
        i += 1
    }
    var p = Path()
    p.addLines(left + right.reversed())
    p.closeSubpath()
    return p
}

// MARK: - Moving glow pools

private func drawGlow(_ c: inout GraphicsContext, W: Double, H: Double, t: Double, spec: GlowSpec?, fade: Double) {
    guard let s = spec, fade > 0.001 else { return }
    let dx = Foundation.sin(t * 0.03) * 0.03
    let dy = Foundation.cos(t * 0.025) * 0.02
    let breathe = 0.85 + 0.15 * Foundation.sin(t * 0.1)
    softDisc(&c, x: (s.x + dx) * W, y: (s.y + dy) * H,
             r: s.radius * min(W, H) * 1.6 * breathe, s.tint.color(s.alpha * fade))
}

// MARK: - Clouds (organic multi-lobe masses, three parallax depths)

private func drawClouds(_ c: inout GraphicsContext, W: Double, H: Double, t: Double,
                        amt: Double, tint: RGBA, lit: RGBA, sd: Double) {
    drawCloudBand(&c, W: W, H: H, t: t, amt: amt * 0.7, tint: tint, lit: lit, sd: sd + 1,
                  yFrac: 0.28, scale: 0.11, speed: 7, count: 3, litAmt: 0.25)
    drawCloudBand(&c, W: W, H: H, t: t, amt: amt * 0.9, tint: tint, lit: lit, sd: sd + 2,
                  yFrac: 0.55, scale: 0.17, speed: 15, count: 3, litAmt: 0.4)
    drawCloudBand(&c, W: W, H: H, t: t, amt: amt, tint: tint, lit: lit, sd: sd + 3,
                  yFrac: 0.82, scale: 0.26, speed: 26, count: 3, litAmt: 0.5)
}

private func drawCloudBand(_ c: inout GraphicsContext, W: Double, H: Double, t: Double,
                           amt: Double, tint: RGBA, lit: RGBA, sd: Double,
                           yFrac: Double, scale: Double, speed: Double, count: Int, litAmt: Double) {
    let margin = min(W, H) * scale * 2.4
    let span = W + margin * 2
    var i = 0
    while i < count {
        let di = Double(i)
        let phase = hash2(di + sd, 2.7)
        let x = fract((phase * span + t * speed) / span) * span - margin
        let y = (yFrac + (hash1(di + sd) - 0.5) * 0.06) * H
        let cw = min(W, H) * scale * (0.8 + hash1(di * 3 + sd) * 0.6)
        drawCloud(&c, cx: x, cy: y, halfW: cw, tint: tint, lit: lit, amt: amt, litAmt: litAmt, sd: di * 7 + sd)
        i += 1
    }
}

private func drawCloud(_ c: inout GraphicsContext, cx: Double, cy: Double, halfW: Double,
                       tint: RGBA, lit: RGBA, amt: Double, litAmt: Double, sd: Double) {
    let lobes = 10 + Int(hash1(sd) * 6)      // 10…15 lobes — irregular, non-repeating
    let baseY = cy + halfW * 0.18
    softDisc(&c, x: cx, y: baseY + halfW * 0.1, r: halfW * 1.15, tint.color(amt * 0.16))  // grounding under-shadow
    var l = 0
    while l < lobes {
        let dl = Double(l)
        let u = Double(l) / Double(lobes - 1)          // 0…1 across
        let jitterX = (hash2(dl + sd, 1.1) - 0.5) * 0.4
        let lx = cx + (u - 0.5 + jitterX) * halfW * 2.0
        let bell = Foundation.sin(u * Double.pi)       // arch: tall in the middle
        let ly = baseY - bell * halfW * (0.45 + hash1(dl + sd) * 0.5) - hash2(dl + sd, 3.3) * halfW * 0.12
        let lr = halfW * (0.22 + 0.5 * bell) * (0.7 + hash1(dl * 2 + sd) * 0.6)
        let la = amt * (0.16 + hash1(dl + sd) * 0.14)
        softDisc(&c, x: lx, y: ly, r: lr, tint.color(la))
        if bell > 0.5 && litAmt > 0 {
            softDisc(&c, x: lx - lr * 0.15, y: ly - lr * 0.35, r: lr * 0.55, lit.color(amt * litAmt * 0.5))
        }
        l += 1
    }
}

// MARK: - Fog / mist (flowing sheets + swaying columns)

private func drawFog(_ c: inout GraphicsContext, W: Double, H: Double, t: Double,
                     amt: Double, tint: RGBA, sd: Double) {
    var i = 0
    while i < 3 {
        let di = Double(i)
        let y = (0.48 + di * 0.16 + Foundation.sin(t * 0.1 + di) * 0.02) * H
        let h = H * (0.10 + hash1(di + sd) * 0.06)
        let drift = Foundation.sin(t * (0.05 + di * 0.02) + di) * W * 0.05
        let a = amt * (0.11 + hash1(di + sd) * 0.06)
        let g = Gradient(colors: [tint.color(0), tint.color(a), tint.color(0)])
        let rect = CGRect(x: -W * 0.1 + drift, y: y - h, width: W * 1.2, height: h * 2)
        c.fill(Path(ellipseIn: rect),
               with: .radialGradient(g, center: CGPoint(x: W / 2 + drift, y: y),
                                     startRadius: 0, endRadius: CGFloat(max(W * 0.6, h))))
        i += 1
    }
    var k = 0
    while k < 2 {
        let dk = Double(k)
        let x = (0.3 + dk * 0.4 + Foundation.sin(t * 0.06 + dk) * 0.05) * W
        let a = amt * 0.06
        let g = Gradient(colors: [tint.color(0), tint.color(a), tint.color(0)])
        let rect = CGRect(x: x - W * 0.12, y: H * 0.2, width: W * 0.24, height: H * 0.7)
        c.fill(Path(ellipseIn: rect),
               with: .linearGradient(g, startPoint: CGPoint(x: x, y: H * 0.2), endPoint: CGPoint(x: x, y: H * 0.9)))
        k += 1
    }
}

// MARK: - Horizon silhouettes

private func drawHorizon(_ c: inout GraphicsContext, W: Double, H: Double, amt: Double, tint: RGBA, sd: Double) {
    drawRidge(&c, W: W, H: H, tint: tint.color(amt * 0.8), baseY: 0.86, amp: 0.05, phase: sd, waves: 2.2)
    drawRidge(&c, W: W, H: H, tint: tint.mix(rgb(0x000000), 0.4).color(amt), baseY: 0.93, amp: 0.06, phase: sd + 5, waves: 1.6)
}

private func drawRidge(_ c: inout GraphicsContext, W: Double, H: Double, tint: Color,
                       baseY: Double, amp: Double, phase: Double, waves: Double) {
    var p = Path()
    p.move(to: CGPoint(x: 0, y: H))
    let steps = 48
    var i = 0
    while i <= steps {
        let fx = Double(i) / Double(steps)
        let w1 = Foundation.sin(fx * waves * 2 * Double.pi + phase)
        let w2 = 0.4 * Foundation.sin(fx * waves * 5 * Double.pi + phase * 1.6)
        let y = (baseY - (w1 + w2) * amp) * H
        p.addLine(to: CGPoint(x: fx * W, y: y))
        i += 1
    }
    p.addLine(to: CGPoint(x: W, y: H))
    p.closeSubpath()
    c.fill(p, with: .color(tint))
}

// MARK: - Celestial bodies

private func drawCelestial(_ c: inout GraphicsContext, W: Double, H: Double, t: Double,
                           kind: Celestial, alpha: Double, sd: Double) {
    c.drawLayer { l in
        l.opacity = alpha
        let base = min(W, H)
        let px = (0.28 + hash1(sd) * 0.44) * W + Foundation.sin(t * 0.02 + sd) * W * 0.02
        let py = (0.18 + hash1(sd + 1) * 0.24) * H + Foundation.cos(t * 0.016 + sd) * H * 0.015
        let lightX = 0.34, lightY = 0.32
        switch kind {
        case .moon:
            let r = base * 0.14
            softDisc(&l, x: px, y: py, r: r * 1.9, rgb(0xEAF0FF).color(0.10))
            drawSphere(&l, cx: px, cy: py, r: r, lightX: lightX, lightY: lightY,
                       bright: rgb(0xFDFEFF), mid: rgb(0xCED8EC), dark: rgb(0x8C97B4))
            addCraters(&l, cx: px, cy: py, r: r, bright: rgb(0xFFFFFF), dark: rgb(0x7C88A8), sd: sd)
            strokeCircle(&l, x: px, y: py, r: r, rgb(0xFFFFFF).color(0.22), max(0.6, r * 0.02))
        case .crescentMoon:
            let r = base * 0.13
            softDisc(&l, x: px, y: py, r: r * 1.8, rgb(0xE8E0FF).color(0.10))
            drawSphere(&l, cx: px, cy: py, r: r, lightX: 0.22, lightY: 0.3,
                       bright: rgb(0xFBF6FF), mid: rgb(0xCBBEEA), dark: rgb(0x5A4E86))
            addCraters(&l, cx: px, cy: py, r: r, bright: rgb(0xFFFFFF), dark: rgb(0x5A4E86), sd: sd)
        case .ringedPlanet:
            drawRingedPlanet(&l, cx: px, cy: py, r: base * 0.15, lightX: lightX, lightY: lightY)
        case .gasGiant:
            let r = base * 0.36
            let gx = (hash1(sd) < 0.5 ? -0.06 : 1.06) * W        // partly off-screen for scale
            let gy = (0.32 + hash1(sd + 2) * 0.16) * H
            softDisc(&l, x: gx, y: gy, r: r * 1.4, rgb(0xE8C0A0).color(0.10))
            drawSphere(&l, cx: gx, cy: gy, r: r, lightX: lightX, lightY: lightY,
                       bright: rgb(0xE9C8A6), mid: rgb(0xB07E64), dark: rgb(0x5A3A44))
            addBands(&l, cx: gx, cy: gy, r: r, bright: rgb(0xF0D6B4), mid: rgb(0x8A5A54), sd: sd)
            strokeCircle(&l, x: gx, y: gy, r: r, rgb(0xF0D6B4).color(0.14), max(0.8, r * 0.015))
        case .icePlanet:
            let r = base * 0.15
            softDisc(&l, x: px, y: py, r: r * 1.9, rgb(0xCDEBFF).color(0.14))
            drawSphere(&l, cx: px, cy: py, r: r, lightX: lightX, lightY: lightY,
                       bright: rgb(0xF2FBFF), mid: rgb(0xA8D2EC), dark: rgb(0x4E7CA0))
            addCraters(&l, cx: px, cy: py, r: r, bright: rgb(0xFFFFFF), dark: rgb(0x5E8AB0), sd: sd + 4)
            strokeCircle(&l, x: px, y: py, r: r, rgb(0xEAF7FF).color(0.24), max(0.6, r * 0.02))
        case .giantHazy:
            // A vast, mysterious silhouette resting mostly off the bottom edge.
            let r = base * 0.72
            let gy = H * 1.06
            softDisc(&l, x: px, y: gy, r: r * 1.1, rgb(0x101830).color(0.55))
            strokeCircle(&l, x: px, y: gy, r: r * 0.86, rgb(0x8FA6D8).color(0.10), 2)
        case .twinMoons:
            let r = base * 0.11
            drawSphere(&l, cx: px, cy: py, r: r, lightX: lightX, lightY: lightY,
                       bright: rgb(0xFDFEFF), mid: rgb(0xD6C4CE), dark: rgb(0x8A6E7C))
            addCraters(&l, cx: px, cy: py, r: r, bright: rgb(0xFFFFFF), dark: rgb(0x8A6E7C), sd: sd)
            let r2 = r * 0.5
            let p2x = px + r * 2.4, p2y = py + r * 1.4
            drawSphere(&l, cx: p2x, cy: p2y, r: r2, lightX: lightX, lightY: lightY,
                       bright: rgb(0xF4EEF2), mid: rgb(0xC2AEBA), dark: rgb(0x74586A))
        case .none:
            break
        }
    }
}

/// A premium shaded sphere: radial light falloff, limb darkening, and a soft
/// terminator opposite the light — all clipped to the disc.
private func drawSphere(_ c: inout GraphicsContext, cx: Double, cy: Double, r: Double,
                        lightX: Double, lightY: Double, bright: RGBA, mid: RGBA, dark: RGBA) {
    let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
    c.drawLayer { l in
        l.clip(to: Path(ellipseIn: rect))
        let g = Gradient(stops: [
            .init(color: bright.color(1), location: 0),
            .init(color: mid.color(1), location: 0.55),
            .init(color: dark.color(1), location: 1)
        ])
        let lc = CGPoint(x: cx + (lightX - 0.5) * r * 0.9, y: cy + (lightY - 0.5) * r * 0.9)
        l.fill(Path(rect), with: .radialGradient(g, center: lc, startRadius: 0, endRadius: CGFloat(r * 1.25)))
        // limb darkening
        let lg = Gradient(stops: [.init(color: dark.color(0), location: 0.68),
                                  .init(color: dark.color(0.5), location: 1)])
        l.fill(Path(rect), with: .radialGradient(lg, center: CGPoint(x: cx, y: cy),
                                                 startRadius: 0, endRadius: CGFloat(r)))
        // terminator opposite the light
        let tg = Gradient(colors: [Color.black.opacity(0), Color.black.opacity(0.5)])
        let tc = CGPoint(x: cx - (lightX - 0.5) * r * 1.7, y: cy - (lightY - 0.5) * r * 1.7)
        l.fill(Path(rect), with: .radialGradient(tg, center: tc,
                                                 startRadius: CGFloat(r * 0.2), endRadius: CGFloat(r * 1.5)))
    }
}

private func addCraters(_ c: inout GraphicsContext, cx: Double, cy: Double, r: Double,
                        bright: RGBA, dark: RGBA, sd: Double) {
    let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
    c.drawLayer { l in
        l.clip(to: Path(ellipseIn: rect))
        var k = 0
        while k < 8 {
            let dk = Double(k)
            let ang = hash2(dk + sd, 1.9) * 6.2831853
            let dist = hash1(dk + sd) * r * 0.72
            let ccx = cx + Foundation.cos(ang) * dist
            let ccy = cy + Foundation.sin(ang) * dist
            let cr = r * (0.05 + hash1(dk * 2 + sd) * 0.1)
            fillDisc(&l, x: ccx, y: ccy, r: cr, dark.color(0.28))
            fillDisc(&l, x: ccx, y: ccy - cr * 0.25, r: cr * 0.7, bright.color(0.07))
            k += 1
        }
    }
}

private func addBands(_ c: inout GraphicsContext, cx: Double, cy: Double, r: Double,
                      bright: RGBA, mid: RGBA, sd: Double) {
    let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
    c.drawLayer { l in
        l.clip(to: Path(ellipseIn: rect))
        var k = 0
        while k < 6 {
            let dk = Double(k)
            let by = cy - r + (dk + 0.5) / 6 * r * 2
            let bh = r * (0.10 + hash1(dk + sd) * 0.08)
            let bt = (k % 2 == 0) ? bright : mid
            let a = 0.18 + hash1(dk + sd) * 0.14
            let bandRect = CGRect(x: cx - r, y: by - bh, width: r * 2, height: bh * 2)
            l.fill(Path(ellipseIn: bandRect), with: .color(bt.color(a)))
            k += 1
        }
    }
}

/// A ringed planet whose ring passes **behind** the top of the globe and **in
/// front** of the bottom: draw the full ring, cover it with the globe, then
/// redraw only the front (lower) arc clipped below the globe's centre.
private func drawRingedPlanet(_ c: inout GraphicsContext, cx: Double, cy: Double, r: Double,
                              lightX: Double, lightY: Double) {
    let rw = r * 2.5
    let rh = r * 0.66
    let ringRect = CGRect(x: cx - rw / 2, y: cy - rh / 2, width: rw, height: rh)
    let ringPath = Path(ellipseIn: ringRect)
    let ringGrad = Gradient(stops: [
        .init(color: rgb(0xE7D8B0).color(0), location: 0.0),
        .init(color: rgb(0xEADFBC).color(0.55), location: 0.16),
        .init(color: rgb(0xB6A279).color(0.30), location: 0.5),
        .init(color: rgb(0xEADFBC).color(0.55), location: 0.84),
        .init(color: rgb(0xE7D8B0).color(0), location: 1.0)
    ])
    let ringShade = GraphicsContext.Shading.linearGradient(
        ringGrad, startPoint: CGPoint(x: ringRect.minX, y: cy), endPoint: CGPoint(x: ringRect.maxX, y: cy))
    let lw = CGFloat(r * 0.16)

    softDisc(&c, x: cx, y: cy, r: r * 1.6, rgb(0xBFA6E0).color(0.10))      // atmosphere halo
    c.stroke(ringPath, with: ringShade, lineWidth: lw)                     // full ring (back)
    drawSphere(&c, cx: cx, cy: cy, r: r, lightX: lightX, lightY: lightY,   // globe on top
               bright: rgb(0xC9D6F0), mid: rgb(0x6E7EA8), dark: rgb(0x2A3352))
    addBands(&c, cx: cx, cy: cy, r: r, bright: rgb(0xB9C8E8), mid: rgb(0x4E5E88), sd: cx)
    strokeCircle(&c, x: cx, y: cy, r: r, rgb(0xC9D6F0).color(0.16), max(0.6, r * 0.02))
    c.drawLayer { l in                                                     // front arc, over the globe
        l.clip(to: Path(CGRect(x: cx - rw, y: cy, width: rw * 2, height: rh)))
        l.stroke(ringPath, with: ringShade, lineWidth: lw)
    }
}

// MARK: - Events (multi-track; something happens every few seconds)

private func drawEvents(_ c: inout GraphicsContext, W: Double, H: Double, t: Double, sd: Double, mood: Double) {
    drawSmallEvent(&c, W: W, H: H, t: t, sd: sd)
    drawMediumEvent(&c, W: W, H: H, t: t, sd: sd)
    drawLargeEvent(&c, W: W, H: H, t: t, sd: sd, mood: mood)
}

/// Frequent, small: a drifting sparkle bloom roughly every ~5.5s.
private func drawSmallEvent(_ c: inout GraphicsContext, W: Double, H: Double, t: Double, sd: Double) {
    let period = 5.5
    let cyc = (t / period).rounded(.down)
    let ph = t / period - cyc
    guard ph < 0.4 else { return }
    let local = ph / 0.4
    let env = Foundation.sin(Double.pi * local)
    let x = hash2(cyc + sd, 2.1) * W
    let y = hash2(cyc + sd, 5.5) * H * 0.8
    drawSparkle(&c, x: x, y: y, s: min(W, H) * 0.03, a: env * 0.85, rot: cyc)
}

private func drawSparkle(_ c: inout GraphicsContext, x: Double, y: Double, s: Double, a: Double, rot: Double) {
    softDisc(&c, x: x, y: y, r: s * 1.5, Color.white.opacity(a * 0.5))
    var k = 0
    while k < 4 {
        let ang = Double(k) / 4 * Double.pi + rot * 0.3
        let dx = Foundation.cos(ang) * s * 2.2
        let dy = Foundation.sin(ang) * s * 2.2
        lineGrad(&c, x - dx, y - dy, x + dx, y + dy, Color.white.opacity(0), Color.white.opacity(a * 0.7), 1.1)
        k += 1
    }
}

/// Medium: a shooting star or a comet roughly every ~11s.
private func drawMediumEvent(_ c: inout GraphicsContext, W: Double, H: Double, t: Double, sd: Double) {
    let period = 11.0
    let cyc = (t / period).rounded(.down)
    let ph = t / period - cyc
    guard ph < 0.3 else { return }
    let local = ph / 0.3
    if hash2(cyc + sd, 9.1) < 0.6 {
        drawShootingStar(&c, W: W, H: H, cyc: cyc, sd: sd, local: local)
    } else {
        drawComet(&c, W: W, H: H, cyc: cyc, sd: sd, local: local)
    }
}

private func drawShootingStar(_ c: inout GraphicsContext, W: Double, H: Double, cyc: Double, sd: Double, local: Double) {
    let x0 = (0.2 + hash2(cyc + sd, 1.3) * 0.6) * W
    let y0 = (0.06 + hash2(cyc + sd, 4.4) * 0.32) * H
    let dir = hash1(cyc + sd) < 0.5 ? -1.0 : 1.0
    let travel = W * 0.5 * local
    let hx = x0 + dir * travel
    let hy = y0 + travel * 0.5
    let tx = hx - dir * 95
    let ty = hy - 46
    let a = Foundation.sin(Double.pi * local) * 0.9
    lineGrad(&c, tx, ty, hx, hy, Color.white.opacity(0), rgb(0xE6F2FF).color(a), 1.7)
    fillDisc(&c, x: hx, y: hy, r: 2.0, Color.white.opacity(a))
    softDisc(&c, x: hx, y: hy, r: 8, rgb(0xDCEBFF).color(a * 0.5))
}

private func drawComet(_ c: inout GraphicsContext, W: Double, H: Double, cyc: Double, sd: Double, local: Double) {
    let x0 = (0.15 + hash2(cyc + sd, 2.7) * 0.7) * W
    let y0 = (0.1 + hash2(cyc + sd, 6.6) * 0.3) * H
    let dir = hash1(cyc + sd * 2) < 0.5 ? -1.0 : 1.0
    let travel = W * 0.42 * local
    let hx = x0 + dir * travel
    let hy = y0 + travel * 0.35
    let a = Foundation.sin(Double.pi * local) * 0.85
    // long curved glowing tail
    var i = 0
    while i < 10 {
        let di = Double(i)
        let f = di / 9
        let tx = hx - dir * 150 * f
        let ty = hy - 60 * f + Foundation.sin(f * 2) * 6
        softDisc(&c, x: tx, y: ty, r: 9 * (1 - f) + 1.5, rgb(0xBFE0FF).color(a * (1 - f) * 0.35))
        i += 1
    }
    softDisc(&c, x: hx, y: hy, r: 14, rgb(0xDCEBFF).color(a * 0.6))
    fillDisc(&c, x: hx, y: hy, r: 3, Color.white.opacity(a))
}

/// Large & rare: a meteor shower, an elegant starburst, an aurora sweep or a
/// giant drifting silhouette, roughly every ~34s.
private func drawLargeEvent(_ c: inout GraphicsContext, W: Double, H: Double, t: Double, sd: Double, mood: Double) {
    let period = 34.0
    let cyc = (t / period).rounded(.down)
    let ph = t / period - cyc
    guard ph < 0.16 else { return }
    let local = ph / 0.16
    let roll = hash2(cyc + sd, 3.7)
    if roll < 0.3 {
        drawMeteorShower(&c, W: W, H: H, cyc: cyc, sd: sd, local: local)
    } else if roll < 0.62 {
        drawStarburst(&c, x: (0.25 + hash2(cyc + sd, 1.1) * 0.5) * W,
                      y: (0.18 + hash2(cyc + sd, 2.2) * 0.34) * H, progress: local)
    } else if roll < 0.83 {
        drawGiantSilhouette(&c, W: W, H: H, cyc: cyc, sd: sd, local: local)
    } else {
        drawAuroraSweep(&c, W: W, H: H, local: local)
    }
}

private func drawMeteorShower(_ c: inout GraphicsContext, W: Double, H: Double, cyc: Double, sd: Double, local: Double) {
    var i = 0
    while i < 5 {
        let di = Double(i)
        let stagger = clamp01((local - di * 0.12) / 0.55)
        if stagger > 0 && stagger < 1 {
            let x0 = (0.1 + hash2(cyc + di + sd, 1.7) * 0.85) * W
            let y0 = (0.02 + hash2(cyc + di + sd, 3.9) * 0.25) * H
            let travel = W * 0.4 * stagger
            let hx = x0 - travel
            let hy = y0 + travel * 0.55
            let a = Foundation.sin(Double.pi * stagger) * 0.8
            lineGrad(&c, hx + 70, hy - 38, hx, hy, Color.white.opacity(0), rgb(0xE6F2FF).color(a), 1.4)
            fillDisc(&c, x: hx, y: hy, r: 1.8, Color.white.opacity(a))
        }
        i += 1
    }
}

/// An elegant celestial bloom: a glowing core, fine tapered rays and an
/// expanding light ring with sparkling tips — no "circles separating".
private func drawStarburst(_ c: inout GraphicsContext, x: Double, y: Double, progress: Double) {
    let bloom = Foundation.sin(Double.pi * progress)
    let grow = progress
    softDisc(&c, x: x, y: y, r: 40 * bloom + 12, rgb(0xFFF3D6).color(bloom * 0.55))
    let rays = 18
    var k = 0
    while k < rays {
        let ang = Double(k) / Double(rays) * Double.pi * 2
        let len = 30 + 135 * grow
        let x2 = x + Foundation.cos(ang) * len
        let y2 = y + Foundation.sin(ang) * len
        lineGrad(&c, x, y, x2, y2, rgb(0xFFF6E0).color(bloom * 0.85), rgb(0xFFE0A8).color(0), 1.6)
        softDisc(&c, x: x2, y: y2, r: 3.2 * bloom, Color.white.opacity(bloom * 0.6))
        k += 1
    }
    let rr = 30 + 155 * grow
    strokeCircle(&c, x: x, y: y, r: rr, rgb(0xFFE9C0).color((1 - grow) * 0.4), 1.3)
}

/// A vast dark silhouette that drifts slowly across the far background.
private func drawGiantSilhouette(_ c: inout GraphicsContext, W: Double, H: Double, cyc: Double, sd: Double, local: Double) {
    let r = min(W, H) * 0.55
    let y = (0.32 + hash1(cyc + sd) * 0.2) * H
    let x = -r + (W + 2 * r) * local
    let fade = Foundation.sin(Double.pi * local)
    softDisc(&c, x: x, y: y, r: r, Color.black.opacity(0.42 * fade))
    strokeCircle(&c, x: x, y: y, r: r * 0.82, rgb(0x9FB4E0).color(0.1 * fade), 2)
}

private func drawAuroraSweep(_ c: inout GraphicsContext, W: Double, H: Double, local: Double) {
    let fade = Foundation.sin(Double.pi * local)
    let y = 0.3 * H
    let g = Gradient(colors: [rgb(0x54E0A8).color(0), rgb(0x6EF0C0).color(0.22 * fade), rgb(0x54E0A8).color(0)])
    let sweepX = (local * 1.4 - 0.2) * W
    let rect = CGRect(x: sweepX - W * 0.3, y: y - H * 0.18, width: W * 0.6, height: H * 0.36)
    c.fill(Path(ellipseIn: rect),
           with: .radialGradient(g, center: CGPoint(x: sweepX, y: y), startRadius: 0, endRadius: CGFloat(W * 0.3)))
}

// MARK: - Vignette

private func drawVignette(_ c: inout GraphicsContext, W: Double, H: Double) {
    let g = Gradient(colors: [Color.black.opacity(0), Color.black.opacity(0.28)])
    c.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)),
           with: .radialGradient(g, center: CGPoint(x: W / 2, y: H * 0.42),
                                 startRadius: CGFloat(min(W, H) * 0.5), endRadius: CGFloat(max(W, H) * 0.78)))
    let tg = Gradient(colors: [Color.black.opacity(0.22), Color.black.opacity(0)])
    c.fill(Path(CGRect(x: 0, y: 0, width: W, height: H * 0.25)),
           with: .linearGradient(tg, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: H * 0.25)))
}
