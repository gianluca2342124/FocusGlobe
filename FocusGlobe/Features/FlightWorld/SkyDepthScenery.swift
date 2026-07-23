import Foundation
import SwiftUI

// MARK: - Layered atmospheric depth scenery (the shared "world" engine)
//
// The scenery layer that sits between the vast sky above and the balloon: a
// hand-authored, per-Sky composition of silhouette planes with atmospheric
// perspective, a horizon light, and glacial parallax. NOTHING here is a
// generic sine-wave field — each Sky calls its own authored builder (dunes,
// alpine ridges, a rain-hazed skyline, an island lagoon, a Kyoto valley, or a
// cosmic foreground). Every plane extends to the physical bottom of the view,
// so no plane can ever end in an exposed horizontal cut.
//
// Used by BOTH the Home Sky preview and the living flight renderer, so the
// world a pilot chooses is the world they fly. `t == 0` renders a still frame
// (Reduce Motion / off-screen preview pages).
struct SkyDepthScenery: View {
    let sky: FocusSky
    var t: Double = 0
    /// Fraction of height where the horizon light sits.
    var horizon: CGFloat = 0.84
    /// Global strength multiplier (the flight sits scenery back a touch).
    var intensity: Double = 1.0

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = max(1, geo.size.height)
            ZStack {
                horizonLight(W: W, H: H)
                SkyWorld.scenery(for: sky.id, W: W, H: H, t: t, intensity: intensity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func horizonLight(W: CGFloat, H: CGFloat) -> some View {
        if let glow = SkyWorld.horizonGlow(for: sky.id) {
            let breathe = t == 0 ? 1.0 : 0.85 + 0.15 * Foundation.sin(t * 0.05)
            RadialGradient(colors: [glow.opacity(0.22 * intensity * breathe), .clear],
                           center: UnitPoint(x: 0.5, y: Double(horizon)),
                           startRadius: 2, endRadius: W * 0.85)
        }
    }
}

// MARK: - Per-Sky authored worlds

/// The authored scenery for each Sky — a small stack of silhouette planes,
/// composed by hand so every Sky is a distinct place, not a recoloured ridge.
/// A plane's `drift` is a slow horizontal parallax; far planes drift least.
enum SkyWorld {

    /// The soft light where sky meets land, per Sky (nil = no terrestrial horizon).
    static func horizonGlow(for skyID: String) -> Color? {
        switch skyID {
        case "sahara-night":    return Color(hex: 0xE8B080)
        case "fiji-lagoon":     return Color(hex: 0x9FF0DA)
        case "kyoto-lanterns":  return Color(hex: 0xF2AA6A)
        case "aurora-snowfield":return Color(hex: 0x8FE8C4)
        case "rainy-tokyo":     return Color(hex: 0x7E8ED0)
        case "swiss-alps":      return Color(hex: 0xEAF2F6)
        case "galaxy-drift", "deep-space": return nil
        default:                return nil
        }
    }

    /// Horizontal parallax drift in points for a plane at depth `d` (0 = far).
    private static func drift(_ t: Double, depth: Int, points: CGFloat) -> CGFloat {
        t == 0 ? 0 : CGFloat(Foundation.sin(t * (0.006 + Double(depth) * 0.004) + Double(depth) * 1.7)) * points
    }

    @ViewBuilder
    static func scenery(for skyID: String, W: CGFloat, H: CGFloat,
                        t: Double, intensity: Double) -> some View {
        switch skyID {
        case "sahara-night":     desertNight(W: W, H: H, t: t, k: intensity)
        case "fiji-lagoon":      fijiLagoon(W: W, H: H, t: t, k: intensity)
        case "kyoto-lanterns":   kyoto(W: W, H: H, t: t, k: intensity)
        case "aurora-snowfield": auroraSnowfield(W: W, H: H, t: t, k: intensity)
        case "rainy-tokyo":      rainyTokyo(W: W, H: H, t: t, k: intensity)
        case "swiss-alps":       swissAlps(W: W, H: H, t: t, k: intensity)
        case "galaxy-drift":     starfallNebula(W: W, H: H, t: t, k: intensity)
        case "deep-space":       deepSpace(W: W, H: H, t: t, k: intensity)
        default:                 EmptyView()
        }
    }

    // Helper: fill a shape with a top→bottom tint gradient, then hang a skirt of
    // the base tint from the shape's base to the true screen bottom, so a plane
    // whose base sits above H can never reveal a flat cut edge.
    private static func plane<S: Shape>(_ shape: S, base: CGFloat, height: CGFloat,
                                        tint: Color, top: Double, bottom: Double,
                                        k: Double, W: CGFloat, H: CGFloat,
                                        driftX: CGFloat = 0) -> some View {
        let planeH = H * height
        let skirtH = max(0, 1 - base) * H
        let fill = LinearGradient(colors: [tint.opacity(top * k), tint.opacity(bottom * k)],
                                  startPoint: .top, endPoint: .bottom)
        return VStack(spacing: 0) {
            shape.fill(fill).frame(height: planeH)
            if skirtH > 0.25 { Rectangle().fill(tint.opacity(bottom * k)).frame(height: skirtH) }
        }
        .frame(width: W)
        .offset(x: driftX)
        .position(x: W / 2, y: H - (planeH + skirtH) / 2)
    }

    // MARK: Desert Night — the flagship free Sky

    @ViewBuilder
    static func desertNight(W: CGFloat, H: CGFloat, t: Double, k: Double) -> some View {
        // FOUR broad dune layers, each ONE smooth asymmetric ridge (a long
        // windward rise sweeping to a single crest, then a short leeward settle),
        // surface-shaded from a moonlit crest down into a cool indigo/plum
        // shadow — so the sand reads as real 3-D dunes, never flat cut-outs,
        // bumps, waves or childish curves. Distant layers are hazy + low-contrast
        // (atmospheric perspective); the near dune is a large mass reaching the
        // bottom. A tiny camp rests firmly on the broad far ridge, with the mid /
        // near dunes cresting to the RIGHT so they never cover it. Desert Night
        // only — no other Sky is touched.
        let d0 = drift(t, depth: 0, points: 4)
        let d1 = drift(t, depth: 0, points: 8)
        let d2 = drift(t, depth: 1, points: 12)
        let d3 = drift(t, depth: 2, points: 18)

        ZStack {
            // Warm horizon light low on the sand + a soft cool haze band, so the
            // distant ridges melt into the night air rather than into black.
            LinearGradient(colors: [.clear, Color(hex: 0xE6A65E).opacity(0.16 * k)],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: W, height: H * 0.24).position(x: W / 2, y: H * 0.80).blur(radius: 12)
            Rectangle().fill(Color(hex: 0x6C6698).opacity(0.12 * k))
                .frame(width: W, height: H * 0.10).position(x: W / 2, y: H * 0.70).blur(radius: 18)

            // A rare, slow blinking aircraft crossing high over the desert — one
            // deterministic event on a long cycle, absent most of the time.
            ambientAircraft(W: W, H: H, t: t, k: k, period: 64, yFrac: 0.20,
                            seedPhase: 8, tint: Color(hex: 0xF3C77A))

            // 1 — farthest: a very low, hazy, low-contrast ridge near the horizon.
            duneLayer(crestX: 0.40, crestH: 0.34, leftFrac: 0.55, rightFrac: 0.66,
                      base: 0.80, height: 0.14, crest: Color(hex: 0x585578),
                      shadow: Color(hex: 0x494564), moonlit: 0.10, parallax: d0, k: k, W: W, H: H)

            // 2 — far: the broad ridge the camp rests on (crest x ≈ 0.30).
            duneLayer(crestX: 0.30, crestH: 0.55, leftFrac: 0.30, rightFrac: 0.50,
                      base: 0.88, height: 0.20, crest: Color(hex: 0x716C96),
                      shadow: Color(hex: 0x3C365C), moonlit: 0.16, parallax: d1, k: k, W: W, H: H)
            desertCamp(W: W, H: H, t: t, k: k)

            // 3 — midground: a larger flowing dune, crest to the right so it
            //     settles LOW across the camp's x (never covering it).
            duneLayer(crestX: 0.70, crestH: 0.50, leftFrac: 0.24, rightFrac: 0.40,
                      base: 0.94, height: 0.28, crest: Color(hex: 0x847EA8),
                      shadow: Color(hex: 0x2F2846), moonlit: 0.22, parallax: d2, k: k, W: W, H: H)

            // 4 — foreground: the big smooth dune mass reaching the very bottom —
            //     deep cool indigo (never a heavy black block), brightest crest.
            duneLayer(crestX: 0.80, crestH: 0.34, leftFrac: 0.34, rightFrac: 0.20,
                      base: 1.0, height: 0.40, crest: Color(hex: 0x958EB8),
                      shadow: Color(hex: 0x231B36), moonlit: 0.32, parallax: d3, k: k, W: W, H: H)
        }
    }

    /// One surface-shaded dune band: `DuneBand` filled with a crest→shadow
    /// vertical gradient (the 3-D slope) plus a crisp moonlit `DuneCrestLine`,
    /// positioned like `plane()` with a base-colour skirt below.
    private static func duneLayer(crestX: CGFloat, crestH: CGFloat,
                                  leftFrac: CGFloat, rightFrac: CGFloat,
                                  base: CGFloat, height: CGFloat,
                                  crest: Color, shadow: Color, moonlit: Double,
                                  parallax: CGFloat, k: Double, W: CGFloat, H: CGFloat) -> some View {
        let planeH = H * height
        let skirtH = max(0, 1 - base) * H
        let band = DuneBand(crestX: crestX, crestH: crestH,
                            leftFrac: leftFrac, rightFrac: rightFrac, parallax: parallax)
        let line = DuneCrestLine(crestX: crestX, crestH: crestH,
                                 leftFrac: leftFrac, rightFrac: rightFrac, parallax: parallax)
        let grad = LinearGradient(colors: [crest.opacity(k), shadow.opacity(k)],
                                  startPoint: .top, endPoint: .bottom)
        return VStack(spacing: 0) {
            ZStack {
                band.fill(grad)
                line.stroke(Color(hex: 0xD6D2F2).opacity(moonlit * k), lineWidth: 1.4)
                    .blur(radius: 0.5)
            }
            .frame(height: planeH)
            if skirtH > 0.25 { Rectangle().fill(shadow.opacity(k)).frame(height: skirtH) }
        }
        .frame(width: W)
        .position(x: W / 2, y: H - (planeH + skirtH) / 2)
    }

    /// A tiny distant camp on the far dune ridge: two low tents, 2–3 warm
    /// lantern lights that gently flicker, and a couple of faint camels — all
    /// small and secondary, never cartoonish or branded.
    private static func desertCamp(W: CGFloat, H: CGFloat, t: Double, k: Double) -> some View {
        // Sits ON the far dune's crest (x ≈ 0.30, screen y ≈ 0.77 H) and shares
        // its parallax drift, so it never floats; the mid / near dunes crest to
        // the right and stay LOW here, so they never cover it.
        let cx = W * 0.30 + drift(t, depth: 0, points: 8)
        let cy = H * 0.775
        let cw = W * 0.085
        let ch = H * 0.026
        func flicker(_ phase: Double) -> Double {
            t == 0 ? 1.0 : 0.72 + 0.28 * Foundation.sin(t * 0.9 + phase)
        }
        return ZStack {
            // Faint camels just left of the tents.
            CamelSilhouette()
                .fill(Color(hex: 0x1A1020).opacity(0.55 * k))
                .frame(width: cw * 0.66, height: ch * 0.9)
                .position(x: cx - cw * 0.95, y: cy + ch * 0.55)
            // The tents.
            TentCamp()
                .fill(Color(hex: 0x1C1122).opacity(0.9 * k))
                .frame(width: cw, height: ch)
                .position(x: cx, y: cy)
            // 2–3 warm lantern lights with a gentle, uncorrelated flicker.
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(hex: 0xF3BC66))
                    .frame(width: 2.4, height: 2.4)
                    .blur(radius: 0.4)
                    .shadow(color: Color(hex: 0xF3BC66).opacity(0.6 * k), radius: 3)
                    .opacity((0.9 * k) * flicker(Double(i) * 2.1))
                    .position(x: cx + cw * (CGFloat(i) - 1) * 0.26, y: cy + ch * 0.16)
            }
        }
    }

    // MARK: Fiji Lagoon — an immense tropical lagoon seen from above

    @ViewBuilder
    static func fijiLagoon(W: CGFloat, H: CGFloat, t: Double, k: Double) -> some View {
        // The waterline sits high so the lagoon fills the lower ~42 % and the
        // turquoise air the upper ~58 %, with islands meeting at the horizon.
        let seaTop = H * 0.58
        ZStack {
            // Sky: a warm tropical horizon, a cool aqua haze, sparse drifting cloud.
            fijiSkyAtmosphere(W: W, H: H, seaTop: seaTop, t: t, k: k)

            // Far island chain — an irregular, hazy coastline on the waterline
            // (NO repeated semicircle hills). No skirt: the water covers below.
            LagoonIslandChain(parallax: drift(t, depth: 0, points: 5))
                .fill(LinearGradient(colors: [Color(hex: 0x10525A).opacity(0.55 * k),
                                              Color(hex: 0x0B3E48).opacity(0.72 * k)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: W, height: H * 0.17)
                .position(x: W / 2, y: seaTop - H * 0.085)
            // Subtle palm silhouettes on the two tallest far headlands.
            fijiFarPalms(W: W, H: H, seaTop: seaTop, t: t, k: k)

            // A soft mist band settling the far chain into the distance.
            Rectangle().fill(Color(hex: 0xCDEFE4).opacity(0.10 * k))
                .frame(width: W, height: H * 0.05)
                .position(x: W / 2, y: seaTop + H * 0.005).blur(radius: 11)

            // The lagoon water: perspective shimmer, reef & channel colour, glints.
            lagoonWater(W: W, H: H, seaTop: seaTop, t: t, k: k)

            // Midground islets (2–3 distinct) with pale reef edges, over the water.
            fijiIslets(W: W, H: H, seaTop: seaTop, t: t, k: k)

            // Rare living events — a seabird skein, a lone distant boat.
            fijiEvents(W: W, H: H, seaTop: seaTop, t: t, k: k)
        }
    }

    /// The tropical air above the waterline: a warm horizon light, a cool aqua
    /// haze hugging the sea, and a few soft clouds drifting gently (never a wall).
    private static func fijiSkyAtmosphere(W: CGFloat, H: CGFloat, seaTop: CGFloat,
                                          t: Double, k: Double) -> some View {
        ZStack {
            LinearGradient(colors: [.clear, Color(hex: 0xFFE1AC).opacity(0.14 * k)],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: W, height: H * 0.15)
                .position(x: W / 2, y: seaTop - H * 0.02).blur(radius: 14)
            Rectangle().fill(Color(hex: 0x8FE6D8).opacity(0.10 * k))
                .frame(width: W, height: H * 0.10)
                .position(x: W / 2, y: seaTop - H * 0.09).blur(radius: 16)
            Canvas { ctx, s in
                let clouds: [(x: CGFloat, y: CGFloat, w: CGFloat)] = [
                    (0.22, 0.15, 0.34), (0.66, 0.09, 0.26), (0.48, 0.25, 0.22),
                ]
                for (idx, c) in clouds.enumerated() {
                    let dx = t == 0 ? 0 : CGFloat(Foundation.sin(t * 0.01 + Double(idx) * 1.6) * 12)
                    let cx = c.x * s.width + dx
                    let cy = c.y * s.height
                    let cw = c.w * s.width
                    for j in 0..<3 {
                        let ox = CGFloat(j - 1) * cw * 0.3
                        SkyFX.glow(&ctx, x: cx + ox, y: cy,
                                   r: cw * (0.5 - CGFloat(abs(j - 1)) * 0.12),
                                   color: .white.opacity(0.10 * k))
                    }
                }
            }
            .frame(width: W, height: seaTop)
            .position(x: W / 2, y: seaTop / 2)
        }
    }

    /// Two faint palm clusters standing on the tallest far headlands — small and
    /// hazy, the signature tropical note without cluttering the horizon.
    private static func fijiFarPalms(W: CGFloat, H: CGFloat, seaTop: CGFloat,
                                     t: Double, k: Double) -> some View {
        Canvas { ctx, s in
            let dx = drift(t, depth: 0, points: 5)
            let clusters: [(x: CGFloat, palms: Int)] = [(0.24, 2), (0.67, 3)]
            for cl in clusters {
                let baseX = cl.x * s.width + dx
                let baseY = seaTop - H * 0.006
                for pI in 0..<cl.palms {
                    let px = baseX + CGFloat(pI - cl.palms / 2) * W * 0.012
                    let top = baseY - H * 0.045
                    var trunk = Path()
                    trunk.move(to: CGPoint(x: px, y: baseY))
                    trunk.addQuadCurve(to: CGPoint(x: px + W * 0.006, y: top),
                                       control: CGPoint(x: px, y: (baseY + top) / 2))
                    ctx.stroke(trunk, with: .color(Color(hex: 0x123C3E).opacity(0.42 * k)),
                               lineWidth: 1.1)
                    for a in [-0.9, -0.4, 0.4, 0.9] {
                        var fr = Path()
                        fr.move(to: CGPoint(x: px + W * 0.006, y: top))
                        fr.addLine(to: CGPoint(x: px + W * 0.006 + CGFloat(a) * W * 0.012,
                                               y: top - H * 0.008 + CGFloat(abs(a)) * H * 0.006))
                        ctx.stroke(fr, with: .color(Color(hex: 0x123C3E).opacity(0.36 * k)),
                                   lineWidth: 1.0)
                    }
                }
            }
        }
        .frame(width: W, height: H).position(x: W / 2, y: H / 2)
    }

    /// The lagoon itself — a luminous shallow water plane from the waterline to
    /// the bottom: a soft depth gradient, a meandering channel and coral reef
    /// colour variation, perspective shimmer bands (unevenly spaced, each with
    /// its own phase — never identical stripes) and restrained bioluminescence.
    private static func lagoonWater(W: CGFloat, H: CGFloat, seaTop: CGFloat,
                                    t: Double, k: Double) -> some View {
        let waterH = H - seaTop
        return ZStack(alignment: .top) {
            LinearGradient(colors: [Color(hex: 0x5EC8C0).opacity(0.42 * k),
                                    Color(hex: 0x2C8C92).opacity(0.60 * k),
                                    Color(hex: 0x14666E).opacity(0.72 * k)],
                           startPoint: .top, endPoint: .bottom)
            Canvas { ctx, s in
                let ww = s.width, wh = s.height
                // Meandering channel (a slightly deeper, cooler ribbon).
                let chDrift = t == 0 ? 0 : CGFloat(Foundation.sin(t * 0.05) * Double(ww) * 0.02)
                var ch = Path()
                ch.move(to: CGPoint(x: ww * 0.30 + chDrift, y: 0))
                ch.addQuadCurve(to: CGPoint(x: ww * 0.44 + chDrift, y: wh * 0.55),
                                control: CGPoint(x: ww * 0.20 + chDrift, y: wh * 0.28))
                ch.addQuadCurve(to: CGPoint(x: ww * 0.36 + chDrift, y: wh),
                                control: CGPoint(x: ww * 0.54 + chDrift, y: wh * 0.80))
                ch.addLine(to: CGPoint(x: ww * 0.54 + chDrift, y: wh))
                ch.addQuadCurve(to: CGPoint(x: ww * 0.58 + chDrift, y: wh * 0.5),
                                control: CGPoint(x: ww * 0.66 + chDrift, y: wh * 0.80))
                ch.closeSubpath()
                ctx.fill(ch, with: .color(Color(hex: 0x0C4A56).opacity(0.26 * k)))
                // Coral-reef shallows — irregular lighter-aqua blooms.
                let reefs: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
                    (0.72, 0.34, 0.20), (0.20, 0.62, 0.16), (0.58, 0.80, 0.22), (0.87, 0.60, 0.14),
                ]
                for rf in reefs {
                    SkyFX.glow(&ctx, x: rf.x * ww, y: rf.y * wh, r: rf.r * ww,
                               color: Color(hex: 0x9BF0DC).opacity(0.16 * k))
                }
                // Perspective shimmer bands — seeded uneven spacing/phase, wider &
                // brighter toward the viewer, each a gently wobbling polyline.
                var rng = SeededRNG(seed: 0xF1DA_A6)
                var y: CGFloat = wh * 0.05
                var i = 0
                while y < wh {
                    let f = y / wh
                    let jitter = CGFloat(rng.unit())
                    let gap = wh * (0.035 + f * 0.075) * (0.7 + jitter * 0.7)
                    let amp = 0.6 + Double(f) * 2.6
                    let phase = Double(i) * 1.7 + Double(jitter) * 6.2
                    let shimmer = t == 0 ? 0.0 : Foundation.sin(t * (0.18 + Double(f) * 0.22) + phase) * amp
                    let a = (0.05 + f * 0.16) * (0.6 + jitter * 0.6) * k
                    var p = Path()
                    let segs = 5
                    for sIdx in 0...segs {
                        let sx = ww * CGFloat(sIdx) / CGFloat(segs)
                        let wob = Foundation.sin(Double(sIdx) * 1.3 + phase + t * 0.1) * amp * 0.5
                        let py = y + CGFloat(sIdx.isMultiple(of: 2) ? shimmer : -shimmer) + CGFloat(wob)
                        if sIdx == 0 { p.move(to: CGPoint(x: sx, y: py)) }
                        else { p.addLine(to: CGPoint(x: sx, y: py)) }
                    }
                    ctx.stroke(p, with: .color(Color(hex: 0xBFF4E4).opacity(a)),
                               lineWidth: 0.8 + f * 1.8)
                    y += gap
                    i += 1
                }
                // Restrained bioluminescence — a few cyan glints that slowly wax,
                // not a per-frame sparkle field. All rng draws are unconditional so
                // nothing teleports between frames.
                var brng = SeededRNG(seed: 0xB101_07)
                for _ in 0..<10 {
                    let bx = CGFloat(brng.unit()) * ww
                    let by = (0.35 + CGFloat(brng.unit()) * 0.6) * wh
                    let rate = 0.15 + brng.unit() * 0.2
                    let ph = brng.unit() * 6.28
                    let rr = 5 + 4 * CGFloat(brng.unit())
                    let wax = t == 0 ? 0.0 : max(0, Foundation.sin(t * rate + ph))
                    guard wax > 0.6 else { continue }
                    let a = (wax - 0.6) / 0.4 * 0.45 * k
                    SkyFX.glow(&ctx, x: bx, y: by, r: rr, color: Color(hex: 0x7BFBE6).opacity(a))
                }
            }
        }
        .frame(width: W, height: waterH)
        .position(x: W / 2, y: seaTop + waterH / 2)
    }

    /// The 2–3 distinct midground islets, each with a pale reef edge in the
    /// water and its own crown/palm authoring so none reads as a duplicate.
    private static func fijiIslets(W: CGFloat, H: CGFloat, seaTop: CGFloat,
                                   t: Double, k: Double) -> some View {
        let dx = drift(t, depth: 1, points: 6)
        let islets: [(x: CGFloat, by: CGFloat, w: CGFloat, h: CGFloat, palms: Int, lean: CGFloat)] = [
            (0.24, 0.70, 0.24, 0.11, 2, 1.0),
            (0.60, 0.66, 0.16, 0.075, 1, -0.8),
            (0.84, 0.74, 0.20, 0.12, 3, 0.7),
        ]
        return ZStack {
            ForEach(islets.indices, id: \.self) { i in
                let isl = islets[i]
                let cx = W * isl.x + dx
                let by = H * isl.by
                let iw = W * isl.w
                let ih = H * isl.h
                Ellipse().fill(Color(hex: 0xAFF4E2).opacity(0.14 * k))
                    .frame(width: iw * 1.7, height: ih * 0.7)
                    .position(x: cx, y: by).blur(radius: 6)
                LagoonIslet(crownH: 0.66, palms: isl.palms, lean: isl.lean)
                    .fill(LinearGradient(colors: [Color(hex: 0x1E6E60).opacity(0.92 * k),
                                                  Color(hex: 0x0E4038).opacity(0.96 * k)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: iw, height: ih)
                    .position(x: cx, y: by - ih / 2)
            }
        }
    }

    /// Rare, deterministic living events on a slow cycle: a small seabird skein
    /// crossing the sky, and — on a longer cycle — a lone distant boat drifting
    /// across the far water. Both absent most of the time; keyed to a floor()
    /// cycle of `t`, so they never reset on re-render and never teleport.
    private static func fijiEvents(W: CGFloat, H: CGFloat, seaTop: CGFloat,
                                   t: Double, k: Double) -> some View {
        Canvas { ctx, s in
            guard t != 0 else { return }
            let ww = s.width, hh = s.height
            // Seabird skein — visible for a third of a 46 s cycle.
            let cyc = t / 46.0
            let ph = cyc - cyc.rounded(.down)
            if ph < 0.34 {
                let p = ph / 0.34
                let bx = CGFloat(-0.1 + p * 1.2) * ww
                let by = (0.18 + 0.05 * CGFloat(Foundation.sin(p * 6.28))) * hh
                for b in 0..<5 {
                    let x = bx + CGFloat(b) * ww * 0.02 - ww * 0.04
                    let y = by + CGFloat(abs(b - 2)) * hh * 0.012
                    let flap = 1 + 0.5 * Foundation.sin(t * 6 + Double(b))
                    var wing = Path()
                    wing.move(to: CGPoint(x: x - 4, y: y + CGFloat(flap)))
                    wing.addQuadCurve(to: CGPoint(x: x, y: y - 1),
                                      control: CGPoint(x: x - 2, y: y - CGFloat(flap)))
                    wing.addQuadCurve(to: CGPoint(x: x + 4, y: y + CGFloat(flap)),
                                      control: CGPoint(x: x + 2, y: y - CGFloat(flap)))
                    ctx.stroke(wing, with: .color(Color(hex: 0x24333A).opacity(0.5 * k)),
                               lineWidth: 1.2)
                }
            }
            // Lone distant boat — visible for half of a longer, offset cycle.
            let bcyc = (t + 30) / 82.0
            let bph = bcyc - bcyc.rounded(.down)
            if bph < 0.5 {
                let p = bph / 0.5
                let x = CGFloat(-0.08 + p * 1.16) * ww
                let y = seaTop + hh * 0.03
                let bw = ww * 0.05, bh = hh * 0.03
                var hull = Path()
                hull.move(to: CGPoint(x: x - bw / 2, y: y))
                hull.addQuadCurve(to: CGPoint(x: x + bw / 2, y: y),
                                  control: CGPoint(x: x, y: y + bh * 0.6))
                hull.closeSubpath()
                ctx.fill(hull, with: .color(Color(hex: 0x17323A).opacity(0.55 * k)))
                var sail = Path()
                sail.move(to: CGPoint(x: x, y: y - bh * 0.1))
                sail.addLine(to: CGPoint(x: x, y: y - bh * 2.2))
                sail.addLine(to: CGPoint(x: x + bw * 0.5, y: y - bh * 0.3))
                sail.closeSubpath()
                ctx.fill(sail, with: .color(Color(hex: 0x2A4A52).opacity(0.5 * k)))
            }
        }
        .frame(width: W, height: H).position(x: W / 2, y: H / 2)
    }

    // MARK: Kyoto Lantern Night — a poetic Japanese evening under many lanterns

    @ViewBuilder
    static func kyoto(W: CGFloat, H: CGFloat, t: Double, k: Double) -> some View {
        // Far forested hills — irregular, uneven crowns (never matched bumps).
        let farHills: [(x: CGFloat, h: CGFloat, half: CGFloat)] = [
            (0.10, 0.34, 0.22), (0.30, 0.52, 0.30), (0.48, 0.30, 0.20),
            (0.66, 0.60, 0.34), (0.86, 0.40, 0.26), (1.02, 0.30, 0.20),
        ]
        // Varied traditional rooftops — widths AND ridge heights all differ, so
        // no roof is a copy of its neighbour.
        let roofs: [(x: CGFloat, half: CGFloat, h: CGFloat)] = [
            (0.08, 0.075, 0.10), (0.22, 0.05, 0.07), (0.34, 0.09, 0.12),
            (0.52, 0.055, 0.08), (0.72, 0.07, 0.10), (0.88, 0.10, 0.13),
        ]
        ZStack {
            // 1 — Far forested hills hazed into the evening, with tiny distant
            //     temple roofs and drifting valley mist.
            plane(ForestHills(hills: farHills, parallax: drift(t, depth: 0, points: 6)),
                  base: 0.80, height: 0.24, tint: Color(hex: 0x3A2848),
                  top: 0.34, bottom: 0.58, k: k, W: W, H: H)
            kyotoDistantRoofs(W: W, H: H, t: t, k: k)
            kyotoMist(W: W, H: H, t: t, k: k)

            // 2 — Midground: the pagoda (believable multi-tier), a torii gate and
            //     a footbridge, then the varied village roofline in front.
            kyotoPagoda(W: W, H: H, t: t, k: k)
            ToriiGate()
                .fill(Color(hex: 0x5A1E22).opacity(0.85 * k))
                .frame(width: W * 0.16, height: H * 0.13)
                .position(x: W * 0.15 + drift(t, depth: 1, points: 5), y: H * 0.775)
            ArchedBridge()
                .fill(Color(hex: 0x241528).opacity(0.9 * k))
                .frame(width: W * 0.22, height: H * 0.05)
                .position(x: W * 0.50 + drift(t, depth: 1, points: 6), y: H * 0.805)
            plane(TempleRoofline(roofs: roofs, parallax: drift(t, depth: 2, points: 9)),
                  base: 0.94, height: 0.14, tint: Color(hex: 0x1E1330),
                  top: 0.72, bottom: 0.92, k: k, W: W, H: H)

            // 3 — Foreground: a dark, organic terrace treeline with swaying bamboo
            //     — never a flat brown rectangle, never a triangular stack.
            kyotoForeground(W: W, H: H, t: t, k: k)

            // Warm windows in the village roofs.
            kyotoWindows(roofs: roofs, W: W, H: H, t: t, k: k)

            // 4 — The signature: MANY lanterns across depth layers + a few that
            //     float and drift slowly upward.
            kyotoLanternField(W: W, H: H, t: t, k: k)
        }
    }

    /// Tiny distant temple roofs perched on the far hill line, hazy and small.
    private static func kyotoDistantRoofs(W: CGFloat, H: CGFloat, t: Double, k: Double) -> some View {
        Canvas { ctx, s in
            let dx = drift(t, depth: 0, points: 6)
            let items: [(x: CGFloat, y: CGFloat, w: CGFloat)] = [
                (0.30, 0.545, 0.055), (0.40, 0.55, 0.04), (0.66, 0.52, 0.065), (0.78, 0.55, 0.045),
            ]
            for it in items {
                let cx = it.x * s.width + dx
                let cy = it.y * s.height
                let rw = it.w * s.width
                var roof = Path()
                roof.move(to: CGPoint(x: cx - rw / 2, y: cy))
                roof.addQuadCurve(to: CGPoint(x: cx, y: cy - rw * 0.34),
                                  control: CGPoint(x: cx - rw * 0.25, y: cy - rw * 0.22))
                roof.addQuadCurve(to: CGPoint(x: cx + rw / 2, y: cy),
                                  control: CGPoint(x: cx + rw * 0.25, y: cy - rw * 0.22))
                roof.addLine(to: CGPoint(x: cx + rw * 0.34, y: cy + rw * 0.14))
                roof.addLine(to: CGPoint(x: cx - rw * 0.34, y: cy + rw * 0.14))
                roof.closeSubpath()
                ctx.fill(roof, with: .color(Color(hex: 0x281A34).opacity(0.7 * k)))
            }
        }
        .frame(width: W, height: H).position(x: W / 2, y: H / 2)
    }

    /// Soft valley mist breathing between the hills and the village.
    private static func kyotoMist(W: CGFloat, H: CGFloat, t: Double, k: Double) -> some View {
        Canvas { ctx, s in
            for i in 0..<3 {
                let mdrift = t == 0 ? 0.0 : Foundation.sin(t * 0.02 + Double(i) * 1.7) * Double(s.width) * 0.02
                let breathe = t == 0 ? 1.0 : 0.7 + 0.3 * Foundation.sin(t * 0.04 + Double(i) * 1.3)
                let x = (0.24 + Double(i) * 0.28) * Double(s.width) + mdrift
                SkyFX.glow(&ctx, x: CGFloat(x), y: s.height * 0.60,
                           r: s.width * 0.22, color: Color(hex: 0xC8A6C0).opacity(0.10 * breathe * k))
            }
        }
        .frame(width: W, height: H).position(x: W / 2, y: H / 2)
    }

    /// The pagoda, standing slightly right of centre on the mid-hill line, with
    /// a warm aura and softly-lit tiers.
    private static func kyotoPagoda(W: CGFloat, H: CGFloat, t: Double, k: Double) -> some View {
        let dx = drift(t, depth: 1, points: 4)
        return ZStack {
            PagodaShape()
                .fill(LinearGradient(colors: [Color(hex: 0x3A2038).opacity(0.92 * k),
                                              Color(hex: 0x1C1024).opacity(0.96 * k)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: W * 0.26, height: H * 0.30)
                .position(x: W * 0.70 + dx, y: H * 0.67)
            Canvas { ctx, s in
                let cx = s.width * 0.5
                for i in 0..<5 {
                    let f = CGFloat(i) / 4
                    let tierY = s.height - s.height * (0.16 + f * 0.70) + s.height * 0.05
                    let flick = t == 0 ? 1.0 : 0.72 + 0.28 * Foundation.sin(t * (0.5 + Double(i) * 0.4) + Double(i))
                    let warm = Color(hex: 0xFFB863)
                    ctx.fill(Path(roundedRect: CGRect(x: cx - s.width * 0.03, y: tierY,
                                                      width: s.width * 0.06, height: s.height * 0.028),
                                  cornerRadius: 1),
                             with: .color(warm.opacity(0.8 * flick * k)))
                    SkyFX.glow(&ctx, x: cx, y: tierY + s.height * 0.014,
                               r: s.width * 0.13, color: warm.opacity(0.20 * flick * k))
                }
            }
            .frame(width: W * 0.26, height: H * 0.30)
            .position(x: W * 0.70 + dx, y: H * 0.67)
        }
    }

    /// The dark foreground: an organic treeline terrace with a few tall, gently
    /// swaying bamboo stalks. No flat rectangle, no giant triangles.
    private static func kyotoForeground(W: CGFloat, H: CGFloat, t: Double, k: Double) -> some View {
        let hills: [(x: CGFloat, h: CGFloat, half: CGFloat)] = [
            (0.12, 0.50, 0.26), (0.40, 0.66, 0.34), (0.72, 0.54, 0.30), (0.96, 0.44, 0.22),
        ]
        return ZStack {
            plane(ForestHills(hills: hills, parallax: drift(t, depth: 2, points: 8)),
                  base: 1.0, height: 0.20, tint: Color(hex: 0x120A1C),
                  top: 0.80, bottom: 1.0, k: k, W: W, H: H)
            kyotoBamboo(W: W, H: H, t: t, k: k)
        }
    }

    private static func kyotoBamboo(W: CGFloat, H: CGFloat, t: Double, k: Double) -> some View {
        Canvas { ctx, s in
            let stalks: [(x: CGFloat, h: CGFloat, phase: Double)] = [
                (0.06, 0.34, 0.0), (0.10, 0.28, 1.1), (0.93, 0.36, 2.0), (0.88, 0.26, 0.6),
            ]
            for st in stalks {
                let sway = t == 0 ? 0.0 : Foundation.sin(t * 0.3 + st.phase) * 3
                let baseX = st.x * s.width
                let topY = s.height * (1 - st.h)
                var stalk = Path()
                stalk.move(to: CGPoint(x: baseX, y: s.height))
                stalk.addQuadCurve(to: CGPoint(x: baseX + CGFloat(sway), y: topY),
                                   control: CGPoint(x: baseX + CGFloat(sway) * 0.4, y: (s.height + topY) / 2))
                ctx.stroke(stalk, with: .color(Color(hex: 0x1A2A16).opacity(0.85 * k)),
                           lineWidth: max(1.4, s.width * 0.006))
                for lf in [0.0, 0.12, 0.24] {
                    let ly = topY + CGFloat(lf) * s.height * 0.2
                    let lx = baseX + CGFloat(sway) * (1 - CGFloat(lf))
                    var leaf = Path()
                    leaf.move(to: CGPoint(x: lx, y: ly))
                    leaf.addQuadCurve(to: CGPoint(x: lx + s.width * 0.03, y: ly - s.height * 0.02),
                                      control: CGPoint(x: lx + s.width * 0.02, y: ly - s.height * 0.026))
                    ctx.stroke(leaf, with: .color(Color(hex: 0x24361E).opacity(0.7 * k)), lineWidth: 1.2)
                }
            }
        }
        .frame(width: W, height: H).position(x: W / 2, y: H / 2)
    }

    private static func kyotoWindows(roofs: [(x: CGFloat, half: CGFloat, h: CGFloat)],
                                     W: CGFloat, H: CGFloat, t: Double, k: Double) -> some View {
        Canvas { ctx, s in
            let base = s.height
            // Ride the SAME parallax as the TempleRoofline plane, so the warm
            // windows stay glued to the roofs (not just vertically aligned).
            let dx = drift(t, depth: 2, points: 9)
            for (i, r) in roofs.enumerated() {
                let cx = r.x * s.width + dx
                let flick = t == 0 ? 1.0 : 0.7 + 0.3 * Foundation.sin(t * (0.4 + Double(i) * 0.3) + Double(i) * 2.0)
                let warm = Color(hex: 0xFFC873)
                let y = base - r.h * s.height * 0.5
                let ww = r.half * s.width * 0.5
                let rect = CGRect(x: cx - ww / 2, y: y, width: ww, height: r.h * s.height * 0.22)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 1),
                         with: .color(warm.opacity(0.7 * flick * k)))
                SkyFX.glow(&ctx, x: cx, y: y + 2, r: r.half * s.width * 0.9,
                           color: warm.opacity(0.22 * flick * k))
            }
        }
        // Match the roofline plane (base 0.94, height 0.14) so windows sit ON the
        // roofs: the shape rect is [0.80H … 0.94H] → centre 0.87H.
        .frame(width: W, height: H * 0.14)
        .position(x: W / 2, y: H * 0.87)
    }

    /// The lantern signature — MANY warm lanterns across three depth layers plus
    /// a few floating ones drifting slowly upward. Each is a recognisable paper
    /// chōchin (top fitting, ribbed barrel, tassel), warm amber / red-orange,
    /// with a restrained glow and its own slow flicker — never plain circles.
    private static func kyotoLanternField(W: CGFloat, H: CGFloat, t: Double, k: Double) -> some View {
        Canvas { ctx, s in
            let ww = s.width, hh = s.height
            func lantern(_ ctx: inout GraphicsContext, cx: CGFloat, cy: CGFloat,
                         lw: CGFloat, lh: CGFloat, warm: Color, a: Double, glowMul: Double) {
                SkyFX.glow(&ctx, x: cx, y: cy, r: lw * 1.9, color: warm.opacity(0.22 * a * glowMul))
                var cord = Path()
                cord.move(to: CGPoint(x: cx, y: cy - lh * 0.9))
                cord.addLine(to: CGPoint(x: cx, y: cy - lh * 0.5))
                ctx.stroke(cord, with: .color(Color(hex: 0x2A1414).opacity(0.6 * a)), lineWidth: 0.7)
                ctx.fill(Path(roundedRect: CGRect(x: cx - lw * 0.17, y: cy - lh * 0.56,
                                                  width: lw * 0.34, height: lh * 0.10), cornerRadius: 1),
                         with: .color(Color(hex: 0x241010).opacity(0.9 * a)))
                let barrel = Path(roundedRect: CGRect(x: cx - lw / 2, y: cy - lh * 0.45,
                                                      width: lw, height: lh * 0.9), cornerRadius: lw * 0.44)
                ctx.fill(barrel, with: .color(warm.opacity(0.92 * a)))
                SkyFX.glow(&ctx, x: cx, y: cy, r: lw * 0.55, color: Color(hex: 0xFFE6AE).opacity(0.7 * a))
                for r in [-0.24, 0.0, 0.24] {
                    var rib = Path()
                    let ry = cy + CGFloat(r) * lh
                    rib.move(to: CGPoint(x: cx - lw * 0.42, y: ry))
                    rib.addLine(to: CGPoint(x: cx + lw * 0.42, y: ry))
                    ctx.stroke(rib, with: .color(Color(hex: 0x8A3A22).opacity(0.45 * a)), lineWidth: 0.6)
                }
                ctx.fill(Path(roundedRect: CGRect(x: cx - lw * 0.13, y: cy + lh * 0.42,
                                                  width: lw * 0.26, height: lh * 0.08), cornerRadius: 1),
                         with: .color(Color(hex: 0x241010).opacity(0.9 * a)))
                var tassel = Path()
                tassel.move(to: CGPoint(x: cx, y: cy + lh * 0.5))
                tassel.addLine(to: CGPoint(x: cx, y: cy + lh * 0.64))
                ctx.stroke(tassel, with: .color(Color(hex: 0xC23A2A).opacity(0.8 * a)), lineWidth: 1)
            }

            let warmA = Color(hex: 0xFF9A4E)   // amber
            let warmB = Color(hex: 0xE85A3A)   // red-orange
            // Far row — small, dim, hazy, high along the eaves.
            let dx0 = drift(t, depth: 0, points: 6)
            for i in 0..<7 {
                let cx = ww * (0.12 + CGFloat(i) * 0.12) + dx0
                let cy = hh * 0.60
                let flick = t == 0 ? 1.0 : 0.78 + 0.22 * Foundation.sin(t * (0.5 + Double(i) * 0.2) + Double(i) * 1.7)
                lantern(&ctx, cx: cx, cy: cy, lw: ww * 0.016, lh: hh * 0.03,
                        warm: i % 2 == 0 ? warmA : warmB, a: 0.5 * flick * k, glowMul: 0.7)
            }
            // Mid row — brighter, along the path / village line.
            let dx1 = drift(t, depth: 1, points: 9)
            for i in 0..<8 {
                let cx = ww * (0.08 + CGFloat(i) * 0.115) + dx1
                let cy = hh * (0.74 + 0.01 * CGFloat(i % 2))
                let flick = t == 0 ? 1.0 : 0.72 + 0.28 * Foundation.sin(t * (0.6 + Double(i) * 0.25) + Double(i) * 2.1)
                lantern(&ctx, cx: cx, cy: cy, lw: ww * 0.026, lh: hh * 0.05,
                        warm: i % 3 == 0 ? warmB : warmA, a: 0.8 * flick * k, glowMul: 1.0)
            }
            // Near row — a few large, bright foreground lanterns.
            let dx2 = drift(t, depth: 2, points: 12)
            let near: [(x: CGFloat, y: CGFloat)] = [(0.16, 0.90), (0.50, 0.93), (0.84, 0.90)]
            for (i, n) in near.enumerated() {
                let cx = n.x * ww + dx2
                let cy = n.y * hh
                let flick = t == 0 ? 1.0 : 0.7 + 0.3 * Foundation.sin(t * (0.5 + Double(i) * 0.3) + Double(i) * 1.3)
                lantern(&ctx, cx: cx, cy: cy, lw: ww * 0.05, lh: hh * 0.09,
                        warm: i % 2 == 0 ? warmA : warmB, a: 0.95 * flick * k, glowMul: 1.3)
            }
            // Floating lanterns — a few drifting slowly upward on a slow cycle.
            var rng = SeededRNG(seed: 0x1A27_0F)
            for _ in 0..<6 {
                let baseX = CGFloat(rng.unit())
                let sway = rng.unit()
                let rate = 0.4 + rng.unit() * 0.5
                let size = 0.6 + rng.unit() * 0.8
                let startY = rng.unit()
                let cycle = t == 0 ? 0.4 : (t * (0.01 + rate * 0.006) + startY).truncatingRemainder(dividingBy: 1.0)
                let cy = hh * CGFloat(0.9 - cycle * 0.7)
                let cx = baseX * ww + CGFloat(Foundation.sin(t * 0.1 + sway * 6) * 10)
                let fade = 1 - abs(cycle - 0.5) * 0.6
                lantern(&ctx, cx: cx, cy: cy, lw: ww * 0.02 * CGFloat(size), lh: hh * 0.038 * CGFloat(size),
                        warm: warmA, a: 0.55 * fade * k, glowMul: 0.9)
            }
        }
        .frame(width: W, height: H).position(x: W / 2, y: H / 2)
    }

    // MARK: Northern Aurora — sharp icy ridges (the aurora itself is in the flight/preview effect layer)

    @ViewBuilder
    static func auroraSnowfield(W: CGFloat, H: CGFloat, t: Double, k: Double) -> some View {
        let far: [(x: CGFloat, h: CGFloat, left: CGFloat, right: CGFloat)] = [
            (0.14, 0.44, 0.13, 0.11), (0.4, 0.56, 0.15, 0.16), (0.66, 0.48, 0.12, 0.14), (0.9, 0.52, 0.14, 0.1),
        ]
        let near: [(x: CGFloat, h: CGFloat, left: CGFloat, right: CGFloat)] = [
            (0.22, 0.6, 0.2, 0.16), (0.56, 0.74, 0.22, 0.2), (0.86, 0.58, 0.18, 0.18),
        ]
        ZStack {
            plane(AlpineRidge(peaks: far, parallax: drift(t, depth: 0, points: 6), sharpness: 0.62),
                  base: 0.9, height: 0.22, tint: Color(hex: 0x16404A),
                  top: 0.35, bottom: 0.6, k: k, W: W, H: H)
            plane(AlpineRidge(peaks: near, parallax: drift(t, depth: 1, points: 10), sharpness: 0.72),
                  base: 1.0, height: 0.32, tint: Color(hex: 0x081E2C),
                  top: 0.68, bottom: 0.92, k: k, W: W, H: H)
            SnowCaps(peaks: near, parallax: drift(t, depth: 1, points: 10), coverage: 0.32)
                .fill(Color(hex: 0xBFE8DA).opacity(0.5 * k))
                .frame(width: W, height: H * 0.32)
                .position(x: W / 2, y: H - H * 0.16)
            // Gentle, continuous snow drifting down over the field — a calm living
            // layer (deterministic, slow), on top of the ridges.
            driftingSnow(W: W, H: H, t: t, k: k)
        }
    }

    // MARK: Rainy Tokyo — dense authored skyline, lit windows, neon signs

    @ViewBuilder
    static func rainyTokyo(W: CGFloat, H: CGFloat, t: Double, k: Double) -> some View {
        ZStack {
            // Far skyline stratum — tall, softened, hazed.
            plane(CitySkyline(buildings: SkyWorld.tokyoFar, parallax: drift(t, depth: 0, points: 5)),
                  base: 0.86, height: 0.30, tint: Color(hex: 0x27335A),
                  top: 0.34, bottom: 0.55, k: k, W: W, H: H)
            // Near skyline stratum — denser, darker, detailed rooftops.
            plane(CitySkyline(buildings: SkyWorld.tokyoNear, parallax: drift(t, depth: 1, points: 9)),
                  base: 1.0, height: 0.34, tint: Color(hex: 0x121A34),
                  top: 0.7, bottom: 0.92, k: k, W: W, H: H)
            cityLights(W: W, H: H, t: t, k: k)
            // A rare blinking aircraft crossing the wet Tokyo sky on a long cycle.
            ambientAircraft(W: W, H: H, t: t, k: k, period: 58, yFrac: 0.16,
                            seedPhase: 20, tint: Color(hex: 0xE86A9E))
        }
    }

    static let tokyoFar: [Building] = [
        Building(x: 0.02, width: 0.07, height: 0.42, roof: .antenna),
        Building(x: 0.11, width: 0.05, height: 0.30, roof: .flat),
        Building(x: 0.18, width: 0.09, height: 0.55, roof: .stepped),
        Building(x: 0.29, width: 0.06, height: 0.36, roof: .watertank),
        Building(x: 0.37, width: 0.05, height: 0.26, roof: .flat),
        Building(x: 0.44, width: 0.10, height: 0.62, roof: .antenna),   // the distinctive tower
        Building(x: 0.56, width: 0.06, height: 0.34, roof: .flat),
        Building(x: 0.64, width: 0.08, height: 0.48, roof: .stepped),
        Building(x: 0.74, width: 0.05, height: 0.28, roof: .peak),
        Building(x: 0.81, width: 0.09, height: 0.52, roof: .watertank),
        Building(x: 0.92, width: 0.06, height: 0.38, roof: .antenna),
    ]
    static let tokyoNear: [Building] = [
        Building(x: -0.02, width: 0.1, height: 0.5, roof: .watertank),
        Building(x: 0.1, width: 0.07, height: 0.34, roof: .flat),
        Building(x: 0.19, width: 0.06, height: 0.44, roof: .antenna),
        Building(x: 0.27, width: 0.11, height: 0.3, roof: .stepped),
        Building(x: 0.4, width: 0.07, height: 0.56, roof: .antenna),
        Building(x: 0.49, width: 0.09, height: 0.38, roof: .flat),
        Building(x: 0.6, width: 0.06, height: 0.5, roof: .watertank),
        Building(x: 0.68, width: 0.1, height: 0.32, roof: .stepped),
        Building(x: 0.8, width: 0.07, height: 0.46, roof: .antenna),
        Building(x: 0.89, width: 0.12, height: 0.36, roof: .flat),
    ]

    /// Warm/cool window grids (a few lit), plus a couple of restrained vertical
    /// neon sign panels — all deterministically seeded so nothing teleports.
    private static func cityLights(W: CGFloat, H: CGFloat, t: Double, k: Double) -> some View {
        Canvas { ctx, s in
            let base = s.height
            // Ride the SAME parallax as the near skyline plane, so lit windows
            // and neon stay on their buildings at every frame (incl. static).
            let dx = drift(t, depth: 1, points: 9)
            var rng = SeededRNG(seed: 0x70C_1A17)
            for b in tokyoNear {
                let x0 = b.x * s.width + dx, bw = b.width * s.width
                let topY = base - b.height * s.height
                let cols = max(1, Int(bw / 9))
                let rows = max(2, Int((base - topY) / 12))
                for c in 0..<cols {
                    for r in 0..<rows {
                        guard rng.unit() > 0.62 else { continue }   // most windows dark
                        let lx = x0 + (CGFloat(c) + 0.5) * bw / CGFloat(cols)
                        let ly = topY + (CGFloat(r) + 0.5) * (base - topY) / CGFloat(rows)
                        let warm = rng.unit() > 0.4
                        let seed = rng.unit()
                        let flick = (seed > 0.9 && t != 0)
                            ? 0.5 + 0.5 * Foundation.sin(t * 2.0 + seed * 20) : 1.0
                        let col = warm ? Color(hex: 0xF6C88A) : Color(hex: 0x8FD0E8)
                        ctx.fill(Path(CGRect(x: lx - 1.4, y: ly - 1.4, width: 2.8, height: 2.8)),
                                 with: .color(col.opacity((0.35 + seed * 0.5) * flick * k)))
                    }
                }
            }
            // Two vertical neon sign panels (abstract, not fake text).
            let signs: [(x: CGFloat, y: CGFloat, col: UInt)] = [
                (0.22, 0.62, 0xE86A9E), (0.74, 0.56, 0x6AC8E8),
            ]
            for sg in signs {
                let x = sg.x * s.width + dx, y0 = sg.y * s.height
                let pulse = t == 0 ? 1.0 : 0.7 + 0.3 * Foundation.sin(t * 0.6 + sg.x * 10)
                for j in 0..<3 {
                    let ry = y0 + CGFloat(j) * 10
                    ctx.fill(Path(roundedRect: CGRect(x: x, y: ry, width: 3, height: 7), cornerRadius: 1),
                             with: .color(Color(hex: sg.col).opacity(0.7 * pulse * k)))
                }
                SkyFX.glow(&ctx, x: x + 1.5, y: y0 + 12, r: 22,
                           color: Color(hex: sg.col).opacity(0.16 * pulse * k))
            }
        }
        // Match the NEAR skyline plane's geometry EXACTLY (base 1.0, height 0.34)
        // so the lit windows sit on the buildings, not floating above them.
        .frame(width: W, height: H * 0.34)
        .position(x: W / 2, y: H - H * 0.17)
        .blur(radius: 0.4)
    }

    // MARK: Swiss Alps — dramatic sharp ranges, snow caps, valley mist

    @ViewBuilder
    static func swissAlps(W: CGFloat, H: CGFloat, t: Double, k: Double) -> some View {
        let far: [(x: CGFloat, h: CGFloat, left: CGFloat, right: CGFloat)] = [
            (0.1, 0.22, 0.14, 0.13), (0.34, 0.3, 0.18, 0.16), (0.58, 0.26, 0.15, 0.18), (0.84, 0.32, 0.19, 0.15),
        ]
        let mid: [(x: CGFloat, h: CGFloat, left: CGFloat, right: CGFloat)] = [
            (0.05, 0.28, 0.16, 0.14), (0.4, 0.4, 0.22, 0.2), (0.74, 0.32, 0.18, 0.2),
        ]
        let near: [(x: CGFloat, h: CGFloat, left: CGFloat, right: CGFloat)] = [
            (0.24, 0.4, 0.24, 0.2), (0.7, 0.48, 0.28, 0.24),
        ]
        ZStack {
            plane(AlpineRidge(peaks: far, parallax: drift(t, depth: 0, points: 5), sharpness: 0.8),
                  base: 0.9, height: 0.34, tint: Color(hex: 0x7C9CB8),
                  top: 0.28, bottom: 0.5, k: k, W: W, H: H)
            plane(AlpineRidge(peaks: mid, parallax: drift(t, depth: 1, points: 8), sharpness: 0.85),
                  base: 0.96, height: 0.42, tint: Color(hex: 0x3E607E),
                  top: 0.5, bottom: 0.72, k: k, W: W, H: H)
            plane(AlpineRidge(peaks: near, parallax: drift(t, depth: 2, points: 12), sharpness: 0.9),
                  base: 1.0, height: 0.5, tint: Color(hex: 0x1A2E44),
                  top: 0.78, bottom: 0.95, k: k, W: W, H: H)
            // Snow caps sit at each ridge plane's BASE (H*base), so the mid
            // plane's 0.04·H skirt is accounted for (y = H*base − planeH/2).
            SnowCaps(peaks: mid, parallax: drift(t, depth: 1, points: 8), coverage: 0.34)
                .fill(Color(hex: 0xEAF2F6).opacity(0.55 * k))
                .frame(width: W, height: H * 0.42)
                .position(x: W / 2, y: H * 0.96 - H * 0.21)
            SnowCaps(peaks: near, parallax: drift(t, depth: 2, points: 12), coverage: 0.3)
                .fill(Color(hex: 0xF4FAFA).opacity(0.6 * k))
                .frame(width: W, height: H * 0.5)
                .position(x: W / 2, y: H - H * 0.25)
            valleyMist(W: W, H: H, t: t, k: k, tint: Color(hex: 0xEAF2F6))
            // A rare, high-altitude aircraft drifting over the range on a long
            // cycle — a small living note in the still alpine air.
            ambientAircraft(W: W, H: H, t: t, k: k, period: 70, yFrac: 0.14,
                            seedPhase: 40, tint: Color(hex: 0xBFD4E4))
        }
    }

    private static func valleyMist(W: CGFloat, H: CGFloat, t: Double, k: Double, tint: Color) -> some View {
        Canvas { ctx, s in
            for i in 0..<3 {
                let drift = t == 0 ? 0.0 : Foundation.sin(t * 0.02 + Double(i) * 2.0) * Double(s.width) * 0.02
                let breathe = t == 0 ? 1.0 : 0.7 + 0.3 * Foundation.sin(t * 0.04 + Double(i) * 1.5)
                let x = (0.2 + Double(i) * 0.3) * Double(s.width) + drift
                SkyFX.glow(&ctx, x: CGFloat(x), y: s.height * 0.68,
                           r: s.width * 0.22, color: tint.opacity(0.10 * breathe * k))
            }
        }
        .frame(width: W, height: H * 0.4)
        .position(x: W / 2, y: H - H * 0.2)
    }

    // MARK: Starfall Nebula — a cosmic foreground (no terrestrial mountains)

    @ViewBuilder
    static func starfallNebula(W: CGFloat, H: CGFloat, t: Double, k: Double) -> some View {
        ZStack {
            // A very distant shadowed planetary limb curving across the base.
            PlanetLimb(rise: 0.09)
                .fill(LinearGradient(colors: [Color(hex: 0x2A1A54).opacity(0.7 * k),
                                              Color(hex: 0x140C30).opacity(0.95 * k)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: W, height: H)
            // A faint rim light along the limb where starlight catches it.
            PlanetLimb(rise: 0.092)
                .stroke(Color(hex: 0xB48CE8).opacity(0.3 * k), lineWidth: 1.4)
                .frame(width: W, height: H)
                .blur(radius: 1)
            SkyCosmic.asteroids(W: W, H: H, t: t, k: k, seed: 0xA57E_04)
        }
    }

    // MARK: Deep Space — the ringed planet lives in the celestial layer; here a dark limb + asteroids

    @ViewBuilder
    static func deepSpace(W: CGFloat, H: CGFloat, t: Double, k: Double) -> some View {
        ZStack {
            PlanetLimb(rise: 0.07)
                .fill(LinearGradient(colors: [Color(hex: 0x0A1024).opacity(0.8 * k),
                                              Color(hex: 0x03060F).opacity(0.98 * k)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: W, height: H)
            PlanetLimb(rise: 0.072)
                .stroke(Color(hex: 0x4A5E8E).opacity(0.28 * k), lineWidth: 1.2)
                .frame(width: W, height: H)
                .blur(radius: 1)
            SkyCosmic.asteroids(W: W, H: H, t: t, k: k, seed: 0xDEE9_02)
        }
    }

    // MARK: Shared ambient living events (deterministic, rare — no per-frame rng)

    /// A rare, slow, blinking distant aircraft crossing high in the sky on a long
    /// cycle — absent for most of it, keyed to a floor() cycle of `t`, so it never
    /// resets on re-render and never teleports. Still (`t == 0` / Reduce Motion)
    /// shows nothing, so an off-screen preview page stays perfectly calm.
    private static func ambientAircraft(W: CGFloat, H: CGFloat, t: Double, k: Double,
                                        period: Double, yFrac: CGFloat,
                                        seedPhase: Double, tint: Color) -> some View {
        Canvas { ctx, s in
            guard t != 0 else { return }
            let cyc = (t + seedPhase) / period
            let ph = cyc - cyc.rounded(.down)
            guard ph < 0.4 else { return }
            let p = ph / 0.4
            let x = CGFloat(-0.06 + p * 1.12) * s.width
            let y = yFrac * s.height
            let blink = Foundation.sin(t * 5) > 0.2 ? 1.0 : 0.2
            ctx.fill(Path(ellipseIn: CGRect(x: x - 2.4, y: y - 1, width: 4.8, height: 2)),
                     with: .color(Color(hex: 0x0E1220).opacity(0.5 * k)))
            SkyFX.glow(&ctx, x: x + 2.4, y: y, r: 3.2, color: tint.opacity(0.75 * blink * k))
        }
        .frame(width: W, height: H).position(x: W / 2, y: H / 2)
    }

    /// Calm, continuous snow drifting down — a living layer for the aurora field.
    /// Deterministic: seeded positions rise-free (all rng draws unconditional), a
    /// slow lateral sway, and a wrapped vertical fall from `t`. Still frame settles.
    private static func driftingSnow(W: CGFloat, H: CGFloat, t: Double, k: Double) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: 0x5A0F_11)
            let span = s.height + 24
            for _ in 0..<28 {
                let fx = CGFloat(rng.unit())
                let baseY = rng.unit()
                let speed = 8.0 + rng.unit() * 11.0
                let sway = rng.unit()
                let rr = 0.8 + CGFloat(rng.unit()) * 1.5
                let x = fx * s.width + CGFloat(Foundation.sin(t * 0.3 + sway * 6) * 6)
                let fall = t == 0 ? 0.0 : t * speed
                let y = CGFloat((baseY * Double(span) + fall).truncatingRemainder(dividingBy: Double(span)))
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: rr, height: rr)),
                         with: .color(Color.white.opacity((0.28 + Double(sway) * 0.25) * k)))
            }
        }
        .frame(width: W, height: H).position(x: W / 2, y: H / 2)
    }
}

// MARK: - Shared scenery drawing helpers

enum SkyFX {
    /// A soft radial glow inside a Canvas — the universal organic light block.
    static func glow(_ ctx: inout GraphicsContext, x: CGFloat, y: CGFloat, r: CGFloat, color: Color) {
        let g = Gradient(colors: [color, color.opacity(0)])
        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                 with: .radialGradient(g, center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r))
    }
}
