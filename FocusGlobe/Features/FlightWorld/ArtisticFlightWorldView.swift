import Foundation
import SwiftUI

/// The **active-flight world** — an explicit *vertical world tape*.
///
/// Every landmark (hills, the cloud ocean, the moon, aurora, a distant planet)
/// lives at a fixed *altitude* on a virtual vertical tape that is far taller than
/// the screen. The balloon stays pinned at screen centre; as `altitude` rises the
/// whole tape slides **downward** through the viewport, so each landmark sweeps
/// top → centre → bottom and out, and the six chapters appear in turn:
///
///   Night Valley → Cloud Ocean → Moon Sky → Aurora Field → Starfield → Deep Space
///
/// Motion is produced by *offsetting pre-rendered views* (cheap to composite),
/// not by redrawing many blurred Canvas layers each frame — so the animation
/// stays smooth and never starves the main thread. Only the star field and
/// aurora use a per-frame Canvas, and both are lightweight with no blur stacks.
struct ArtisticFlightWorldView: View {
    let scene: SkyScene
    /// 0…1 across the six chapters (finite: flight progress; ∞: a slow cycle).
    var altitude: Double = 0
    /// Continuous seconds, for ambient drift so the world breathes even when
    /// `altitude` barely moves (long / endless flights).
    var time: TimeInterval = 0
    var animated: Bool = true

    private var alt: Double { min(1, max(0, altitude)) }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                atmosphere(size: size)
                // A gentle constant descent keeps the ascent legible even when
                // altitude is nearly still; grounded callers pass animated:false.
                let drift = animated ? time * 16 : 0
                StarTape(scene: scene, alt: alt, drift: drift, time: animated ? time : 0)
                    .allowsHitTesting(false)

                nebula(size: size)
                planet(size: size, drift: drift)
                aurora(size: size, time: animated ? time : 0)
                moon(size: size, drift: drift)
                cloudOcean(size: size, drift: drift, time: animated ? time : 0)
                hills(size: size, drift: drift)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: Sky gradient — crossfaded across the six stages

    private func atmosphere(size: CGSize) -> some View {
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

    // MARK: Tape maths

    /// Screen Y for a landmark that sits at altitude `a`. At `alt == a` it rests at
    /// `focal`; as the flight climbs the whole world slides down (+span·Δ).
    private func sweptY(_ a: Double, focal: CGFloat, span: CGFloat, _ H: CGFloat) -> CGFloat {
        focal * H + CGFloat(alt - a) * span * H
    }
    /// A soft 0…1 visibility bump centred on altitude `a`.
    private func window(_ a: Double, _ half: Double) -> Double {
        let d = abs(alt - a) / half
        return d >= 1 ? 0 : 0.5 * (1 + cos(.pi * d))
    }

    // MARK: Chapter 1 — Night Valley (rolling hills + low fog)

    private func hills(size: CGSize, drift: Double) -> some View {
        let w = window(0.0, 0.18)
        let farY = sweptY(0.02, focal: 0.80, span: 1.5, size.height)
        let nearY = sweptY(0.0, focal: 0.90, span: 1.9, size.height)
        return ZStack {
            // low fog band hugging the ridge
            LinearGradient(colors: [scene.cloudTint.opacity(0), scene.cloudTint.opacity(0.16)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: size.height * 0.26)
                .position(x: size.width / 2, y: farY - size.height * 0.06)
                .blur(radius: 10)
                .opacity(w)
            RollingHillsShape(amplitude: 0.045, phase: 0.8, waves: 1.4)
                .fill(scene.hillFar)
                .frame(width: size.width, height: size.height)
                .position(x: size.width / 2, y: farY)
                .opacity(w)
            RollingHillsShape(amplitude: 0.06, phase: 3.9, waves: 1.9)
                .fill(scene.hillNear)
                .frame(width: size.width, height: size.height)
                .position(x: size.width / 2, y: nearY)
                .opacity(w)
        }
    }

    // MARK: Chapter 2 — Cloud Ocean (a sunlit bank you rise through)

    private func cloudOcean(size: CGSize, drift: Double, time: TimeInterval) -> some View {
        let w = window(0.24, 0.19)
        let y = sweptY(0.24, focal: 0.5, span: 2.3, size.height)
        return CloudOceanBand(tint: scene.cloudTint, time: time)
            .frame(width: size.width * 1.1, height: size.height * 0.42)
            .position(x: size.width / 2, y: y)
            .opacity(w)
    }

    // MARK: Chapter 3 — Moon Sky (off-centre moon + glow)

    private func moon(size: CGSize, drift: Double) -> some View {
        let w = window(0.42, 0.24)
        let d = size.width * 0.15
        let y = sweptY(0.42, focal: 0.30, span: 1.25, size.height)
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xF2F5FC).opacity(0.32), .clear],
                                     center: .center, startRadius: d * 0.3, endRadius: d * 2.1))
                .frame(width: d * 4.2, height: d * 4.2)
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0xF4F6FA), Color(hex: 0xCAD3E5)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: d, height: d)
                .overlay(
                    Circle().fill(Color(hex: 0x8B97B4).opacity(0.35))
                        .frame(width: d * 0.8, height: d * 0.8)
                        .offset(x: -d * 0.2, y: d * 0.12)
                        .blur(radius: d * 0.12)
                        .mask(Circle().frame(width: d, height: d)))
        }
        .position(x: size.width * 0.72, y: y)
        .opacity(w)
    }

    // MARK: Chapter 4 — Aurora Field (breathing ribbons)

    private func aurora(size: CGSize, time: TimeInterval) -> some View {
        let w = window(0.58, 0.17)
        let y = sweptY(0.58, focal: 0.40, span: 1.9, size.height)
        return AuroraRibbons(time: time)
            .frame(width: size.width, height: size.height * 0.5)
            .position(x: size.width / 2, y: y)
            .opacity(w)
    }

    // MARK: Chapter 6 — Deep Space (planet + nebula)

    private func planet(size: CGSize, drift: Double) -> some View {
        let w = smoothstep(0.80, 0.95, alt)
        let d = size.width * 0.17
        let y = sweptY(0.9, focal: 0.42, span: 1.1, size.height)
        return ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0x94A9D8), Color(hex: 0x46557E)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().fill(Color(hex: 0x101728).opacity(0.55))
                .offset(x: d * 0.22, y: d * 0.16).blur(radius: d * 0.16).mask(Circle())
            Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
        .frame(width: d, height: d)
        .position(x: size.width * 0.28, y: y)
        .opacity(w)
    }

    private func nebula(size: CGSize) -> some View {
        let w = smoothstep(0.72, 0.94, alt)
        return ZStack {
            RadialGradient(colors: [Color(hex: 0x6E4AE8).opacity(0.18), .clear],
                           center: .center, startRadius: 8, endRadius: size.width * 0.6)
                .frame(width: size.width * 1.2, height: size.width * 1.2)
                .position(x: size.width * 0.26, y: size.height * 0.32)
            RadialGradient(colors: [Color(hex: 0x2AC8B0).opacity(0.12), .clear],
                           center: .center, startRadius: 8, endRadius: size.width * 0.5)
                .frame(width: size.width, height: size.width)
                .position(x: size.width * 0.82, y: size.height * 0.16)
        }
        .blendMode(.plusLighter)
        .opacity(w)
    }

    // MARK: Easing

    private func smoothstep(_ e0: Double, _ e1: Double, _ x: Double) -> Double {
        let t = min(1, max(0, (x - e0) / max(0.0001, e1 - e0)))
        return t * t * (3 - 2 * t)
    }
    private func smooth01(_ x: Double) -> Double { smoothstep(0, 1, x) }
}

// MARK: - Star tape (Chapters 1 & 5) — density ramps, drifts down, twinkles

private struct StarTape: View {
    let scene: SkyScene
    let alt: Double
    let drift: Double
    let time: TimeInterval

    var body: some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: 0x57A2_F1E1)
            let count = 150
            // Baseline visibility for a night sky; ramps up with altitude toward
            // the star field, so stars visibly multiply as the flight climbs.
            let base = max(scene.starFloor, smoothstep(0.22, 0.78, alt))
            let spaceW = smoothstep(0.75, 0.96, alt)
            let dy = CGFloat(drift * 0.12)
            for i in 0..<count {
                let u1 = rng.unit(), u2 = rng.unit(), u3 = rng.unit(), u4 = rng.unit()
                let member = Double(i) / Double(count)
                let vis = member < 0.5 ? 1.0 : spaceW      // half only at high altitude
                if vis <= 0.01 { continue }
                let x = u1 * s.width
                let y = (u2 * s.height + dy).truncatingRemainder(dividingBy: s.height)
                let r = 0.5 + u3 * (1.0 + spaceW)
                let tw = time == 0 ? 1.0 : 0.6 + 0.4 * sin(time * (0.7 + u4 * 1.6) + u4 * 6.28)
                let a = (0.28 + u3 * 0.6) * base * vis * tw
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(a)))
            }
            // A meteor in the star/space chapters.
            if spaceW > 0.05 && time != 0 {
                let period = 7.0
                let cyc = floor(time / period)
                let ph = time / period - cyc
                if ph < 0.13 {
                    var rr = SeededRNG(seed: UInt64(bitPattern: Int64(cyc)) &* 31 &+ 7)
                    let t = ph / 0.13
                    let x0 = s.width * (0.25 + rr.unit() * 0.6)
                    let y0 = s.height * (0.08 + rr.unit() * 0.28)
                    let travel = s.width * 0.4 * t
                    let head = CGPoint(x: x0 - travel, y: y0 + travel * 0.5)
                    let tail = CGPoint(x: head.x + 80, y: head.y - 40)
                    var p = Path(); p.move(to: tail); p.addLine(to: head)
                    ctx.stroke(p, with: .linearGradient(
                        Gradient(colors: [.white.opacity(0), .white.opacity(0.85 * sin(.pi * t) * spaceW)]),
                        startPoint: tail, endPoint: head), lineWidth: 1.4)
                }
            }
        }
    }

    private func smoothstep(_ e0: Double, _ e1: Double, _ x: Double) -> Double {
        let t = min(1, max(0, (x - e0) / max(0.0001, e1 - e0)))
        return t * t * (3 - 2 * t)
    }
}

// MARK: - Cloud ocean band (Chapter 2)

private struct CloudOceanBand: View {
    let tint: Color
    let time: TimeInterval

    var body: some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: 0x5EA_C10D)
            let baseY = s.height * 0.5
            for i in 0..<9 {
                let u1 = rng.unit(), u2 = rng.unit()
                let sway = time == 0 ? 0 : sin(time * 0.05 + Double(i)) * 14
                let cx = s.width * (CGFloat(i) / 8.0) + CGFloat(sway)
                let w = s.width * (0.30 + u2 * 0.22)
                let lift = CGFloat(sin(Double(i) * 1.7)) * s.height * 0.10
                puff(&ctx, center: CGPoint(x: cx, y: baseY + lift + CGFloat(u1 - 0.5) * 20),
                     width: w, color: tint, alpha: 0.20)
            }
            // bright crest
            var crest = Path()
            crest.move(to: CGPoint(x: 0, y: baseY - 18))
            crest.addLine(to: CGPoint(x: s.width, y: baseY - 18))
            ctx.stroke(crest, with: .color(tint.opacity(0.12)), lineWidth: 22)
        }
        .blur(radius: 16)
    }

    private func puff(_ ctx: inout GraphicsContext, center: CGPoint, width w: CGFloat,
                      color: Color, alpha: Double) {
        let h = w * 0.42
        var blob = Path()
        blob.addEllipse(in: CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h))
        blob.addEllipse(in: CGRect(x: center.x - w * 0.26, y: center.y - h * 0.9,
                                   width: w * 0.55, height: h * 0.9))
        ctx.fill(blob, with: .color(color.opacity(alpha)))
    }
}

// MARK: - Aurora ribbons (Chapter 4)

private struct AuroraRibbons: View {
    let time: TimeInterval

    var body: some View {
        Canvas { ctx, s in
            let colors = [Color(hex: 0x5CE6A8), Color(hex: 0x4CC8D9), Color(hex: 0x8E7BE8)]
            for band in 0..<3 {
                let bandValue: Double = Double(band)
                let base = s.height * (0.30 + CGFloat(band) * 0.12)
                let breatheValue: Double
                if time == 0 {
                    breatheValue = 1.0
                } else {
                    let breathePhase: Double = time * 0.25 + bandValue * 1.9
                    breatheValue = 0.75 + 0.25 * Foundation.sin(breathePhase)
                }
                let breathe: CGFloat = CGFloat(breatheValue)
                let amp = s.height * 0.06 * breathe
                let bandH = s.height * 0.16
                var top = Path()
                var x: CGFloat = -10
                var first = true
                while x <= s.width + 10 {
                    let xValue: Double = Double(x)
                    let primarySpeed: Double = 0.22 + bandValue * 0.07
                    let primaryPhase: Double = xValue / 90.0 + time * primarySpeed + bandValue * 2.1
                    let secondaryPhase: Double = xValue / 36.0 - time * 0.13 + bandValue
                    let primaryWave: Double = Foundation.sin(primaryPhase)
                    let secondaryWave: Double = 0.4 * Foundation.sin(secondaryPhase)
                    let waveValue: Double = primaryWave + secondaryWave
                    let y = base + CGFloat(waveValue) * amp
                    if first { top.move(to: CGPoint(x: x, y: y)); first = false }
                    else { top.addLine(to: CGPoint(x: x, y: y)) }
                    x += 16
                }
                var ribbon = top
                ribbon.addLine(to: CGPoint(x: s.width + 10, y: base + bandH))
                ribbon.addLine(to: CGPoint(x: -10, y: base + bandH))
                ribbon.closeSubpath()
                let c = colors[band]
                ctx.fill(ribbon, with: .linearGradient(
                    Gradient(colors: [c.opacity(0), c.opacity(0.4), c.opacity(0)]),
                    startPoint: CGPoint(x: 0, y: base - amp),
                    endPoint: CGPoint(x: 0, y: base + bandH)))
            }
        }
        .blur(radius: 8)
        .blendMode(.plusLighter)
    }
}
