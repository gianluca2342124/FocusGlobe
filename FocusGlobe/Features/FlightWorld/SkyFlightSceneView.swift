import Foundation
import SwiftUI
import UIKit

/// The **per-Sky flight scene** — one stable place, not a scrolling reel of
/// chapters. The selected Sky keeps a single continuous background (bundled art
/// when present, a seamless procedural gradient otherwise) for the whole
/// session; life comes from gentle, loopable layers on top: twinkling stars,
/// organic drifting clouds, the Sky's signature accent, its weather, a rare
/// meteor — and a take-off ground plate that falls away once and never returns.
///
/// No hard horizontal bands, no chapter seams, no mountains mid-sky, no cloud
/// walls hiding transitions: the background never changes, so there is nothing
/// to hide.
struct SkyFlightSceneView: View {
    let sky: FocusSky
    /// Pause-aware elapsed seconds — drives ONLY the one-shot take-off ground
    /// departure (monotonic while flying, frozen while paused).
    let elapsed: () -> Double
    var animated: Bool = true

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = max(1, geo.size.height)
            TimelineView(.animation(minimumInterval: animated ? 1.0 / 30.0 : 5.0)) { ctx in
                let t = animated ? ctx.date.timeIntervalSinceReferenceDate : 0
                ZStack {
                    background(W: W, H: H)
                    if sky.stars > 0.01 { starLayer(W: W, H: H, t: t) }
                    accentLayer(W: W, H: H, t: t)
                    if hasClouds { OrganicCloudLayer(seed: skySeed, tint: cloudTint, t: t) }
                    weatherLayer(W: W, H: H, t: t)
                    if isCosmic { meteorLayer(W: W, H: H, t: t) }
                    groundLayer(W: W, H: H)
                }
                .frame(width: W, height: H)
                .clipped()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: Identity helpers

    private var skySeed: UInt64 {
        var h: UInt64 = 0xF11E
        for u in sky.id.unicodeScalars { h = (h &* 31) &+ UInt64(u.value) }
        return h
    }
    private var isCosmic: Bool { sky.isCosmicSky || sky.stars > 0.6 }
    private var hasClouds: Bool {
        switch sky.id {
        case "golden-hour", "fiji-lagoon", "moon-garden", "santorini-dawn",
             "paris-sunset", "swiss-alps": return true
        default: return false
        }
    }
    private var cloudTint: Color {
        sky.isCosmicSky ? Color(hex: 0x9FB4DC) : Color(hex: 0xF2E6D4)
    }

    // MARK: 1 — Stable background (art first, seamless gradient fallback)

    @ViewBuilder private func background(W: CGFloat, H: CGFloat) -> some View {
        let assetName = sky.backgroundAssetName(landscape: W > H)
        if let ui = UIImage(named: assetName) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: W, height: H)
                .clipped()
        } else {
            // One continuous gradient for the whole session — no bands, no seams.
            LinearGradient(colors: sky.paletteColors, startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [sky.glowColor.opacity(0.30), .clear],
                           center: UnitPoint(x: 0.5, y: 0.74),
                           startRadius: 4, endRadius: W * 0.85)
            // A soft atmospheric haze low in the frame (depth, not a divider).
            LinearGradient(colors: [.clear, sky.glowColor.opacity(0.10)],
                           startPoint: UnitPoint(x: 0.5, y: 0.55),
                           endPoint: .bottom)
        }
    }

    // MARK: 2 — Stars (seeded positions, gentle twinkle)

    private func starLayer(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0x57A2)
            let count = Int(40 + sky.stars * 150)
            for i in 0..<count {
                let u1 = rng.unit()
                let u2 = rng.unit()
                let u3 = rng.unit()
                let x = CGFloat(u1) * s.width
                let y = CGFloat(u2) * s.height * 0.8
                let r = CGFloat(0.5 + u3 * 1.7)
                let tw = 0.55 + 0.45 * Foundation.sin(t * (0.5 + u3 * 1.6) + Double(i) * 1.3)
                let a = (0.16 + u3 * 0.55) * sky.stars * tw
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(a)))
                if u3 > 0.93 && sky.stars > 0.5 {
                    let g = Gradient(colors: [Color.white.opacity(a * 0.5), .clear])
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r * 3, y: y - r * 3, width: r * 6, height: r * 6)),
                             with: .radialGradient(g, center: CGPoint(x: x + r / 2, y: y + r / 2),
                                                   startRadius: 0, endRadius: r * 3))
                }
            }
        }
    }

    // MARK: 3 — Signature accent (one hero element, slow drift)

    @ViewBuilder private func accentLayer(W: CGFloat, H: CGFloat, t: Double) -> some View {
        let drift = CGFloat(Foundation.sin(t * 0.02)) * W * 0.012
        switch sky.accent {
        case .none:
            EmptyView()
        case .moon:
            detailedMoon(d: min(W * 0.4, 300))
                .position(x: W * 0.7 + drift, y: H * 0.22)
        case .aurora:
            auroraLayer(W: W, H: H, t: t)
        case .planet:
            ZStack {
                Circle().fill(RadialGradient(colors: [sky.glowColor.opacity(0.35), .clear],
                                             center: .center, startRadius: 2, endRadius: W * 0.3))
                    .frame(width: W * 0.6, height: W * 0.6)
                detailedPlanet(d: min(W * 0.24, 180))
            }
            .position(x: W * 0.26 + drift, y: H * 0.2)
        case .lanterns, .rain:
            EmptyView()   // carried by the weather layer
        case .bigStars:
            Canvas { ctx, s in
                var rng = SeededRNG(seed: skySeed &+ 0xB165)
                for _ in 0..<7 {
                    let x = CGFloat(0.08 + rng.unit() * 0.84) * s.width
                    let y = CGFloat(0.05 + rng.unit() * 0.4) * s.height
                    let r = CGFloat(1.8 + rng.unit() * 2.4)
                    let g = Gradient(colors: [Color.white.opacity(0.9), Color.white.opacity(0)])
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r * 3, y: y - r * 3, width: r * 6, height: r * 6)),
                             with: .radialGradient(g, center: CGPoint(x: x, y: y),
                                                   startRadius: 0, endRadius: r * 3))
                }
            }
        }
    }

    /// A moon with real surface detail — lit sphere, maria, terminator, rim.
    private func detailedMoon(d: CGFloat) -> some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [Color(hex: 0xEDF2FB).opacity(0.35), .clear],
                                         center: .center, startRadius: 2, endRadius: d * 0.95))
                .frame(width: d * 1.9, height: d * 1.9)
            Circle().fill(RadialGradient(
                colors: [Color(hex: 0xFCFDFF), Color(hex: 0xDBE2F0), Color(hex: 0xAEB9D2)],
                center: UnitPoint(x: 0.36, y: 0.34), startRadius: 0, endRadius: d * 0.62))
            Circle().fill(Color(hex: 0x93A0BC).opacity(0.30))
                .frame(width: d * 0.2, height: d * 0.2).offset(x: -d * 0.14, y: -d * 0.05)
            Circle().fill(Color(hex: 0x93A0BC).opacity(0.24))
                .frame(width: d * 0.12, height: d * 0.12).offset(x: d * 0.13, y: d * 0.16)
            Circle().fill(Color(hex: 0x93A0BC).opacity(0.2))
                .frame(width: d * 0.08, height: d * 0.08).offset(x: -d * 0.03, y: d * 0.24)
            Circle().fill(RadialGradient(colors: [.clear, Color(hex: 0x0A0F1E).opacity(0.42)],
                                         center: UnitPoint(x: 0.34, y: 0.32),
                                         startRadius: d * 0.2, endRadius: d * 0.72))
            Circle().strokeBorder(Color.white.opacity(0.24), lineWidth: max(0.6, d * 0.005))
        }
        .frame(width: d, height: d)
    }

    /// A banded, shaded distant world (never a flat circle).
    private func detailedPlanet(d: CGFloat) -> some View {
        ZStack {
            Circle().fill(LinearGradient(
                colors: [Color(hex: 0xAABDE6), Color(hex: 0x7E92C2), Color(hex: 0x3A4A72)],
                startPoint: .top, endPoint: .bottom))
            Circle().fill(RadialGradient(colors: [Color.white.opacity(0.14), .clear],
                                         center: UnitPoint(x: 0.34, y: 0.3),
                                         startRadius: 0, endRadius: d * 0.5))
            Circle().fill(RadialGradient(colors: [.clear, Color(hex: 0x05070F).opacity(0.55)],
                                         center: UnitPoint(x: 0.34, y: 0.32),
                                         startRadius: d * 0.18, endRadius: d * 0.66))
        }
        .frame(width: d, height: d)
    }

    /// Soft horizontal aurora ribbons — organic edges, slow undulation, never
    /// vertical algae. Reuses the proven wave path.
    private func auroraLayer(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            let colors = [Color(hex: 0x54E0A8), Color(hex: 0x4FC9DD), Color(hex: 0x8F7BE8)]
            for band in 0..<3 {
                let baseY = s.height * (0.16 + CGFloat(band) * 0.13)
                let amp = s.height * 0.04
                let thick = s.height * 0.11
                let phase = t * 0.10 + Double(band) * 2.1
                let path = flightAuroraRibbon(width: s.width, baseY: baseY,
                                              amp: amp, thickness: thick, phase: phase)
                let c = colors[band]
                let g = Gradient(colors: [c.opacity(0), c.opacity(0.30), c.opacity(0)])
                ctx.fill(path, with: .linearGradient(
                    g, startPoint: CGPoint(x: 0, y: baseY - amp),
                    endPoint: CGPoint(x: 0, y: baseY + thick + amp)))
            }
        }
    }

    // MARK: 4 — Weather (the Sky's identity particles, seamless loops)

    @ViewBuilder private func weatherLayer(W: CGFloat, H: CGFloat, t: Double) -> some View {
        switch sky.flightParticles {
        case .none:
            EmptyView()
        case .snow:
            Canvas { ctx, s in
                var rng = SeededRNG(seed: skySeed &+ 0x5A0F)
                let span = Double(s.height) + 40
                for i in 0..<44 {
                    let di = Double(i)
                    let fx = rng.unit(); let fy = rng.unit()
                    let speed = 16.0 + rng.unit() * 24.0
                    let y = (fy * span + t * speed).truncatingRemainder(dividingBy: span) - 20
                    let sway = Foundation.sin(t * (0.5 + rng.unit()) + di) * (4 + rng.unit() * 8)
                    let x = fx * Double(s.width) + sway
                    let r = 0.9 + rng.unit() * 1.8
                    let a = 0.3 + rng.unit() * 0.4
                    let g = Gradient(colors: [Color.white.opacity(a), .clear])
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .radialGradient(g, center: CGPoint(x: x, y: y),
                                                   startRadius: 0, endRadius: CGFloat(r)))
                }
            }
        case .rain:
            Canvas { ctx, s in
                var rng = SeededRNG(seed: skySeed &+ 0x0A17)
                let span = Double(s.height) + 40
                for _ in 0..<40 {
                    let fx = rng.unit(); let fy = rng.unit()
                    let speed = 130.0 + rng.unit() * 90.0
                    let y = (fy * span + t * speed).truncatingRemainder(dividingBy: span) - 20
                    let x = fx * Double(s.width) - y * 0.05
                    let len = 8.0 + rng.unit() * 9.0
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x - len * 0.13, y: y + len))
                    ctx.stroke(p, with: .color(Color(hex: 0xBFD0EC).opacity(0.10 + rng.unit() * 0.13)),
                               lineWidth: 1)
                }
            }
        case .lanterns:
            Canvas { ctx, s in
                var rng = SeededRNG(seed: skySeed &+ 0x1A27)
                let span = Double(s.height) + 80
                for i in 0..<8 {
                    let di = Double(i)
                    let fx = rng.unit(); let fy = rng.unit()
                    let speed = 7.0 + rng.unit() * 7.0
                    // Lanterns rise: subtract, wrapping seamlessly.
                    var y = (fy * span - t * speed).truncatingRemainder(dividingBy: span)
                    if y < 0 { y += span }
                    y -= 40
                    let sway = Foundation.sin(t * (0.28 + rng.unit() * 0.3) + di) * (7 + rng.unit() * 8)
                    let x = fx * Double(s.width) + sway
                    let r = 2.2 + rng.unit() * 2.6
                    let warm = Color(hex: 0xFFC873)
                    let g = Gradient(colors: [warm.opacity(0.7), warm.opacity(0)])
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r * 3.4, y: y - r * 3.4, width: r * 6.8, height: r * 6.8)),
                             with: .radialGradient(g, center: CGPoint(x: x, y: y),
                                                   startRadius: 0, endRadius: CGFloat(r * 3.4)))
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r / 2, y: y - r * 0.75, width: r, height: r * 1.5)),
                             with: .color(warm.opacity(0.92)))
                }
            }
        }
    }

    // MARK: 5 — Rare meteors (cosmic skies)

    private func meteorLayer(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            let period = 23.0
            let cycle = (t / period).rounded(.down)
            let phase = t / period - cycle
            guard phase < 0.22 else { return }
            let local = phase / 0.22
            var rng = SeededRNG(seed: skySeed &+ UInt64(bitPattern: Int64(cycle)) &* 131)
            let x0 = Double(s.width) * (0.15 + rng.unit() * 0.7)
            let y0 = Double(s.height) * (0.05 + rng.unit() * 0.3)
            let dir: Double = rng.unit() < 0.5 ? -1 : 1
            let travel = Double(s.width) * 0.45 * local
            let hx = x0 + dir * travel
            let hy = y0 + travel * 0.5
            let a = Foundation.sin(.pi * local) * 0.85
            var p = Path()
            p.move(to: CGPoint(x: hx - dir * 90, y: hy - 44))
            p.addLine(to: CGPoint(x: hx, y: hy))
            let g = Gradient(colors: [Color.white.opacity(0), Color(hex: 0xE6F2FF).opacity(a)])
            ctx.stroke(p, with: .linearGradient(g, startPoint: CGPoint(x: hx - dir * 90, y: hy - 44),
                                                endPoint: CGPoint(x: hx, y: hy)), lineWidth: 1.6)
            ctx.fill(Path(ellipseIn: CGRect(x: hx - 1.8, y: hy - 1.8, width: 3.6, height: 3.6)),
                     with: .color(.white.opacity(a)))
        }
    }

    // MARK: 6 — Take-off ground (appears once, falls away, never returns)

    @ViewBuilder private func groundLayer(W: CGFloat, H: CGFloat) -> some View {
        let e = max(0, elapsed())
        // Fully departed after ~11 s of focus; frozen mid-departure while paused.
        if e < 11 {
            let depart = CGFloat(min(1, max(0, (e - 2.0) / 9.0)))   // hold 2 s, then leave
            let eased = depart * depart * (3 - 2 * depart)          // smoothstep
            Group {
                if let ui = UIImage(named: sky.groundAssetName) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: W, height: H * 0.42, alignment: .top)
                        .clipped()
                } else {
                    proceduralGround(W: W, H: H)
                }
            }
            .frame(width: W, height: H * 0.42)
            .position(x: W / 2, y: H - H * 0.21 + eased * H * 0.75)
            .opacity(Double(1 - eased * 0.9))
            .allowsHitTesting(false)
        }
    }

    /// The Sky's home ground: its landmark silhouette layered twice over a dark
    /// base — the place you lift away from.
    private func proceduralGround(W: CGFloat, H: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [.clear, Color.black.opacity(0.5)],
                           startPoint: .top, endPoint: .bottom)
            LandmarkSilhouette(landmark: sky.landmark)
                .fill(Color.black.opacity(0.34))
                .frame(width: W * 1.15, height: H * 0.26)
                .offset(y: -H * 0.05)
            LandmarkSilhouette(landmark: sky.landmark)
                .fill(Color.black.opacity(0.55))
                .frame(width: W * 1.3, height: H * 0.2)
        }
    }
}

/// An organic horizontal aurora ribbon: both edges wave independently, in small
/// typed steps so the type-checker stays fast. (Local copy — the chapter
/// renderer's ribbon helper is file-private.)
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

// MARK: - Organic clouds (irregular masses drifting horizontally, by depth)

/// A few organic clouds crossing the Sky horizontally at different depths and
/// speeds. Each cloud is an irregular multi-lobe mass with jittered radii and a
/// flattened base — never a row of circles, never a wall, never a seam-hider.
struct OrganicCloudLayer: View {
    let seed: UInt64
    let tint: Color
    let t: Double

    var body: some View {
        Canvas { ctx, s in
            drawBand(&ctx, s: s, salt: 1, y: 0.24, scale: 0.10, speed: 5.5, alpha: 0.10)
            drawBand(&ctx, s: s, salt: 2, y: 0.5, scale: 0.15, speed: 9.5, alpha: 0.14)
            drawBand(&ctx, s: s, salt: 3, y: 0.78, scale: 0.2, speed: 15.0, alpha: 0.17)
        }
        .allowsHitTesting(false)
    }

    /// One depth: two clouds wrapping seamlessly across the width.
    private func drawBand(_ ctx: inout GraphicsContext, s: CGSize, salt: UInt64,
                          y: Double, scale: Double, speed: Double, alpha: Double) {
        var rng = SeededRNG(seed: seed &+ salt &* 0x9E37)
        let ref = Double(min(s.width, s.height))
        let margin = ref * scale * 2.6
        let span = Double(s.width) + margin * 2
        for c in 0..<2 {
            let dc = Double(c)
            let phase = rng.unit()
            let x = ((phase * span + t * speed + dc * span / 2)
                        .truncatingRemainder(dividingBy: span)) - margin
            let cy = (y + (rng.unit() - 0.5) * 0.05) * Double(s.height)
            let halfW = ref * scale * (0.85 + rng.unit() * 0.4)
            drawCloudMass(&ctx, cx: x, cy: cy, halfW: halfW, alpha: alpha, rng: &rng)
        }
    }

    /// An irregular soft mass: 9–13 lobes with jittered radii and offsets,
    /// horizontally stretched, denser at the core, wispy at the edges.
    private func drawCloudMass(_ ctx: inout GraphicsContext, cx: Double, cy: Double,
                               halfW: Double, alpha: Double, rng: inout SeededRNG) {
        let lobes = 9 + Int(rng.unit() * 5.0)
        let baseY = cy + halfW * 0.14
        for l in 0..<lobes {
            let u = lobes <= 1 ? 0.5 : Double(l) / Double(lobes - 1)
            let bell = Foundation.sin(u * Double.pi)
            let jx = (rng.unit() - 0.5) * 0.5
            let jy = (rng.unit() - 0.5) * 0.3
            let lx = cx + (u - 0.5 + jx) * halfW * 2.3
            let ly = baseY - bell * halfW * (0.34 + rng.unit() * 0.42) + jy * halfW * 0.3
            let lr = halfW * (0.2 + 0.44 * bell) * (0.65 + rng.unit() * 0.7)
            let la = alpha * (0.5 + bell * 0.5) * (0.7 + rng.unit() * 0.3)
            let g = Gradient(colors: [tint.opacity(la), tint.opacity(la * 0.4), tint.opacity(0)])
            // Horizontally stretched lobes so nothing reads as a circle.
            let w = lr * 2.4
            let h = lr * 1.5
            let rect = CGRect(x: lx - w / 2, y: ly - h / 2, width: w, height: h)
            ctx.fill(Path(ellipseIn: rect),
                     with: .radialGradient(g, center: CGPoint(x: lx, y: ly),
                                           startRadius: 0, endRadius: CGFloat(max(w, h) / 2)))
        }
    }
}
