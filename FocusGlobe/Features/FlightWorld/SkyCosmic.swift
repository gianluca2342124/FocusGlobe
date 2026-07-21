import Foundation
import SwiftUI

// MARK: - Cosmic hero elements (ringed planet, asteroids, rare UFO)
//
// Authored celestial art for the two space Skies. The ringed planet is a
// layered element (glow · rear ring · shaded sphere · front ring · rim light),
// NOT a flat circle with a line through it. All motion is glacial parallax;
// rare events (a distant UFO) are seeded per time-cycle so they never jump.
enum SkyCosmic {

    // MARK: A Saturn-like ringed planet

    /// A distant ringed world. `d` is the sphere diameter; the rings extend well
    /// beyond it. Drawn back-to-front with correct ring/sphere occlusion so the
    /// rings pass *behind* the top of the globe and *in front of* the bottom.
    static func ringedPlanet(d: CGFloat, tilt: Double = -0.42,
                             sphere: [Color] = [Color(hex: 0xE9D9B6), Color(hex: 0xB98C64), Color(hex: 0x5A3E38)],
                             ring: Color = Color(hex: 0xD8C6A0)) -> some View {
        RingedPlanetView(d: d, tilt: tilt, sphere: sphere, ring: ring)
    }

    // MARK: A drifting field of small asteroid silhouettes

    static func asteroids(W: CGFloat, H: CGFloat, t: Double, k: Double, seed: UInt64) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: seed)
            let n = 9
            for i in 0..<n {
                let fx = rng.unit()
                let fy = 0.62 + rng.unit() * 0.34
                let size = CGFloat(3 + rng.unit() * 9)
                let drift = t == 0 ? 0.0 : Foundation.sin(t * 0.01 + Double(i) * 1.3) * 10
                let cx = CGFloat(fx) * s.width + CGFloat(drift)
                let cy = CGFloat(fy) * s.height
                // An irregular rock: a lumpy closed path, not a circle.
                var p = Path()
                let lobes = 7
                for j in 0...lobes {
                    let a = Double(j) / Double(lobes) * 2 * .pi
                    let rr = size * (0.7 + 0.5 * CGFloat(rng.unit()))
                    let pt = CGPoint(x: cx + CGFloat(cos(a)) * rr, y: cy + CGFloat(sin(a)) * rr * 0.8)
                    if j == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
                p.closeSubpath()
                ctx.fill(p, with: .color(Color(hex: 0x1A2338).opacity(0.9 * k)))
                ctx.stroke(p, with: .color(Color(hex: 0x4A5E8E).opacity(0.3 * k)), lineWidth: 0.6)
            }
        }
        .frame(width: W, height: H)
        .allowsHitTesting(false)
    }

    // MARK: A very rare, very distant UFO — an easter egg, never central

    /// Crosses a small patch of sky about once every ~90 s, briefly, high up and
    /// far away. Seeded per cycle so it never teleports across re-renders.
    static func rareUFO(W: CGFloat, H: CGFloat, t: Double, k: Double, seed: UInt64) -> some View {
        Canvas { ctx, s in
            guard t != 0 else { return }
            let period = 90.0
            let cycle = (t / period).rounded(.down)
            let phase = t / period - cycle
            guard phase < 0.14 else { return }                 // visible ~12.6 s per 90 s
            var rng = SeededRNG(seed: seed &+ UInt64(bitPattern: Int64(cycle)) &* 101 &+ 7)
            let local = phase / 0.14
            let dir: CGFloat = rng.unit() < 0.5 ? 1 : -1
            let baseY = CGFloat(0.14 + rng.unit() * 0.16) * s.height
            let x = (dir > 0 ? -0.1 : 1.1) + dir * 1.2 * CGFloat(local)
            let cx = x * s.width
            let cy = baseY + CGFloat(Foundation.sin(local * 6) * 4)
            let a = Foundation.sin(.pi * local) * 0.85 * k
            let scale = s.width * 0.014
            // Saucer body: a flattened ellipse with a small dome.
            let body = CGRect(x: cx - scale * 2.4, y: cy - scale * 0.5, width: scale * 4.8, height: scale)
            ctx.fill(Path(ellipseIn: body), with: .color(Color(hex: 0xC8D2E8).opacity(a)))
            let dome = CGRect(x: cx - scale * 0.9, y: cy - scale * 1.2, width: scale * 1.8, height: scale * 1.1)
            ctx.fill(Path(ellipseIn: dome), with: .color(Color(hex: 0xEAF0FF).opacity(a * 0.9)))
            // A soft glow underneath.
            SkyFX.glow(&ctx, x: cx, y: cy + scale * 0.4, r: scale * 3.4,
                       color: Color(hex: 0x8FE0FF).opacity(a * 0.5))
        }
        .frame(width: W, height: H)
        .allowsHitTesting(false)
    }
}

/// The layered ringed planet. Correct occlusion is achieved by masking the rear
/// half of the ring with the sphere and drawing the front half on top.
private struct RingedPlanetView: View {
    let d: CGFloat
    let tilt: Double
    let sphere: [Color]
    let ring: Color

    var body: some View {
        let ringW = d * 2.3
        let ringH = d * 0.5
        ZStack {
            // Ambient glow.
            Circle()
                .fill(RadialGradient(colors: [sphere[0].opacity(0.18), .clear],
                                     center: .center, startRadius: d * 0.3, endRadius: d * 1.1))
                .frame(width: d * 2.2, height: d * 2.2)

            // Rear ring (upper half occluded by the globe) — drawn first, then
            // the globe covers its top, so it reads as passing behind.
            ringShape(w: ringW, h: ringH)
                .rotationEffect(.radians(tilt))

            // The shaded globe.
            Circle()
                .fill(RadialGradient(colors: sphere,
                                     center: UnitPoint(x: 0.38, y: 0.34),
                                     startRadius: 0, endRadius: d * 0.66))
                .frame(width: d, height: d)
                .overlay(
                    // A subtle banding + terminator for planetary depth.
                    Circle().fill(Color(hex: 0x2A1E20).opacity(0.35))
                        .frame(width: d * 0.9, height: d * 0.9)
                        .offset(x: d * 0.2, y: d * 0.12)
                        .blur(radius: d * 0.14)
                        .mask(Circle().frame(width: d, height: d))
                )
                .overlay(
                    // Rim light on the lit edge.
                    Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                        .frame(width: d, height: d)
                )

            // Front ring (lower half) — masked to only the part in front of the
            // globe's lower hemisphere, drawn over the sphere.
            ringShape(w: ringW, h: ringH)
                .rotationEffect(.radians(tilt))
                .mask(
                    // Keep only the ring pixels BELOW the globe centre line.
                    Rectangle()
                        .frame(width: ringW * 1.4, height: ringH * 1.4)
                        .offset(y: ringH * 0.7)
                        .rotationEffect(.radians(tilt))
                )
        }
        .frame(width: ringW, height: ringW)
    }

    private func ringShape(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .stroke(LinearGradient(colors: [ring.opacity(0), ring.opacity(0.75),
                                                ring.opacity(0.2), ring.opacity(0.7), ring.opacity(0)],
                                       startPoint: .leading, endPoint: .trailing),
                        lineWidth: h * 0.34)
                .frame(width: w, height: h)
            Ellipse()
                .stroke(ring.opacity(0.35), lineWidth: h * 0.12)
                .frame(width: w * 0.86, height: h * 0.86)
        }
    }
}
