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
        // Three authored dune fields, each with its own asymmetric crest set —
        // sized so the pilot feels small above a large, sweeping desert.
        let far: [(x: CGFloat, h: CGFloat, wind: CGFloat, lee: CGFloat)] = [
            (0.10, 0.34, 0.16, 0.07), (0.34, 0.48, 0.20, 0.08),
            (0.60, 0.38, 0.17, 0.06), (0.86, 0.5, 0.19, 0.09),
        ]
        let mid: [(x: CGFloat, h: CGFloat, wind: CGFloat, lee: CGFloat)] = [
            (0.05, 0.5, 0.20, 0.09), (0.40, 0.66, 0.26, 0.10), (0.78, 0.54, 0.22, 0.08),
        ]
        let near: [(x: CGFloat, h: CGFloat, wind: CGFloat, lee: CGFloat)] = [
            (0.24, 0.62, 0.30, 0.12), (0.72, 0.72, 0.34, 0.13),
        ]
        ZStack {
            plane(DuneField(crests: far, parallax: drift(t, depth: 0, points: 8)),
                  base: 0.9, height: 0.2, tint: Color(hex: 0x6A4448),
                  top: 0.32, bottom: 0.6, k: k, W: W, H: H)
            plane(DuneField(crests: mid, parallax: drift(t, depth: 1, points: 12)),
                  base: 0.96, height: 0.26, tint: Color(hex: 0x412A38),
                  top: 0.55, bottom: 0.82, k: k, W: W, H: H)
            // The nearest dunes, with a warm moonlit rim caught on their crest
            // (drawn in the SAME geometry so the highlight sits on the ridge).
            ZStack {
                plane(DuneField(crests: near, parallax: drift(t, depth: 2, points: 16)),
                      base: 1.0, height: 0.34, tint: Color(hex: 0x241726),
                      top: 0.82, bottom: 0.97, k: k, W: W, H: H)
                DuneField(crests: near, parallax: drift(t, depth: 2, points: 16))
                    .stroke(Color(hex: 0xE8B080).opacity(0.22 * k), lineWidth: 1.4)
                    .frame(width: W, height: H * 0.34)
                    .position(x: W / 2, y: H - H * 0.17)
                    .blur(radius: 0.5)
            }
        }
    }

    // MARK: Fiji Lagoon — luminous water, island silhouettes

    @ViewBuilder
    static func fijiLagoon(W: CGFloat, H: CGFloat, t: Double, k: Double) -> some View {
        let islands: [(x: CGFloat, h: CGFloat, half: CGFloat, palms: Bool)] = [
            (0.16, 0.09, 0.14, true), (0.44, 0.06, 0.10, false),
            (0.7, 0.11, 0.17, true), (0.92, 0.05, 0.08, false),
        ]
        ZStack {
            // Distant island chain resting on the horizon mist.
            plane(IslandSilhouette(islands: islands, parallax: drift(t, depth: 0, points: 6)),
                  base: 0.72, height: 0.14, tint: Color(hex: 0x0C3E4C),
                  top: 0.45, bottom: 0.75, k: k, W: W, H: H)
            // The lagoon itself — a luminous water plane from the horizon down.
            lagoonWater(W: W, H: H, t: t, k: k)
        }
    }

    private static func lagoonWater(W: CGFloat, H: CGFloat, t: Double, k: Double) -> some View {
        let top = H * 0.72
        return ZStack(alignment: .top) {
            LinearGradient(colors: [Color(hex: 0x0E5A62).opacity(0.5 * k),
                                    Color(hex: 0x08363E).opacity(0.85 * k)],
                           startPoint: .top, endPoint: .bottom)
            // Perspective reflection bands: brighter and wider toward the viewer.
            Canvas { ctx, s in
                for i in 0..<9 {
                    let f = CGFloat(i) / 8.0
                    let y = f * s.height
                    let shimmer = t == 0 ? 0.0 : Foundation.sin(t * (0.3 + Double(i) * 0.05) + Double(i)) * 3
                    let a = (0.05 + f * 0.14) * k
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: y + CGFloat(shimmer)))
                    p.addLine(to: CGPoint(x: s.width, y: y - CGFloat(shimmer)))
                    ctx.stroke(p, with: .color(Color(hex: 0x8DE8D0).opacity(a)),
                               lineWidth: 1 + f * 2)
                }
            }
        }
        .frame(width: W, height: H - top)
        .position(x: W / 2, y: top + (H - top) / 2)
    }

    // MARK: Kyoto — forested hills, temple rooflines, a distant pagoda

    @ViewBuilder
    static func kyoto(W: CGFloat, H: CGFloat, t: Double, k: Double) -> some View {
        let farHills: [(x: CGFloat, h: CGFloat, half: CGFloat)] = [
            (0.12, 0.13, 0.24), (0.42, 0.17, 0.3), (0.74, 0.14, 0.26), (0.96, 0.11, 0.2),
        ]
        let roofs: [(x: CGFloat, half: CGFloat, h: CGFloat)] = [
            (0.1, 0.07, 0.09), (0.26, 0.05, 0.07), (0.62, 0.06, 0.08), (0.84, 0.08, 0.10),
        ]
        ZStack {
            plane(ForestHills(hills: farHills, parallax: drift(t, depth: 0, points: 7)),
                  base: 0.90, height: 0.17, tint: Color(hex: 0x5A3450),
                  top: 0.30, bottom: 0.55, k: k, W: W, H: H)
            // The pagoda, standing on the mid-hill line, slightly right of centre.
            PagodaShape()
                .fill(Color(hex: 0x2A1732).opacity(0.85 * k))
                .frame(width: W * 0.26, height: H * 0.24)
                .position(x: W * 0.7 + drift(t, depth: 1, points: 4), y: H * 0.885)
            plane(TempleRoofline(roofs: roofs, parallax: drift(t, depth: 2, points: 10)),
                  base: 1.0, height: 0.13, tint: Color(hex: 0x1E1330),
                  top: 0.78, bottom: 0.95, k: k, W: W, H: H)
            // Warm windows glowing in the rooftops.
            kyotoWindows(roofs: roofs, W: W, H: H, t: t, k: k)
        }
    }

    private static func kyotoWindows(roofs: [(x: CGFloat, half: CGFloat, h: CGFloat)],
                                     W: CGFloat, H: CGFloat, t: Double, k: Double) -> some View {
        Canvas { ctx, s in
            let base = s.height
            for (i, r) in roofs.enumerated() {
                let cx = r.x * s.width
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
        .frame(width: W, height: H * 0.13)
        .position(x: W / 2, y: H - H * 0.065)
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
            var rng = SeededRNG(seed: 0x70C_1A17)
            for b in tokyoNear {
                let x0 = b.x * s.width, bw = b.width * s.width
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
                let x = sg.x * s.width, y0 = sg.y * s.height
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
        .frame(width: W, height: H * 0.42)
        .position(x: W / 2, y: H - H * 0.21)
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
