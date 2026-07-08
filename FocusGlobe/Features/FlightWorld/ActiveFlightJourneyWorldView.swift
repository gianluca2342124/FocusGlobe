import Foundation
import SwiftUI

/// The **active-flight world** — a simple, explicit, reliable vertical journey.
///
/// Six full-screen chapters are stacked into one tall tape (Night Valley at the
/// bottom, Deep Space at the top). As `progress()` rises the whole tape slides
/// **down** behind the tiny balloon, so the balloon reads as rising through:
///
///   Night Valley → Cloud Ocean → Moon Sky → Aurora Field → Starfield → Deep Space
///
/// Progress is read *live* inside the TimelineView (never a stale snapshot), so
/// the world moves continuously and smoothly. Adjacent chapter gradients share
/// their boundary colour, so the scroll is seamless — no hard seams, no popping.
struct ActiveFlightJourneyWorldView: View {
    /// Read live each frame (0…1 across the six chapters).
    let progress: () -> Double
    var animated: Bool = true

    var body: some View {
        GeometryReader { geo in
            let H = geo.size.height
            let W = geo.size.width
            let travel = H * 5
            TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !animated)) { ctx in
                let p = min(1, max(0, progress()))
                let t = animated ? ctx.date.timeIntervalSinceReferenceDate : 0
                // p = 0 → show the bottom chapter (Night Valley); p = 1 → the top
                // (Deep Space). The tape moves DOWN as we climb.
                let yOffset = -travel * (1 - p)
                VStack(spacing: 0) {
                    DeepSpaceSection(size: geo.size, time: t)
                    StarfieldSection(size: geo.size, time: t)
                    AuroraFieldSection(size: geo.size, time: t)
                    MoonSkySection(size: geo.size, time: t)
                    CloudOceanSection(size: geo.size, time: t)
                    NightValleySection(size: geo.size, time: t)
                }
                .frame(width: W, height: H * 6, alignment: .top)
                .offset(y: yOffset)
                .frame(width: W, height: H, alignment: .top)
                .clipped()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Shared star helper

private func chapterStars(_ ctx: inout GraphicsContext, size: CGSize, time: TimeInterval,
                          count: Int, seed: UInt64, maxOpacity: Double) {
    var rng = SeededRNG(seed: seed)
    for _ in 0..<count {
        let u1 = rng.unit(), u2 = rng.unit(), u3 = rng.unit(), u4 = rng.unit()
        let x = u1 * size.width
        let y = u2 * size.height
        let r = 0.5 + u3 * 1.4
        let tw: Double
        if time == 0 {
            tw = 1
        } else {
            let phase = time * (0.6 + u4 * 1.6) + u4 * 6.28
            tw = 0.6 + 0.4 * Foundation.sin(phase)
        }
        let a = (0.3 + u3 * 0.6) * maxOpacity * tw
        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                 with: .color(.white.opacity(a)))
    }
}

private func softPuff(_ ctx: inout GraphicsContext, center: CGPoint, width w: CGFloat,
                      color: Color, alpha: Double) {
    let h = w * 0.42
    var blob = Path()
    blob.addEllipse(in: CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h))
    blob.addEllipse(in: CGRect(x: center.x - w * 0.26, y: center.y - h * 0.9,
                               width: w * 0.55, height: h * 0.9))
    blob.addEllipse(in: CGRect(x: center.x + w * 0.02, y: center.y - h * 0.55,
                               width: w * 0.42, height: h * 0.8))
    ctx.fill(blob, with: .color(color.opacity(alpha)))
}

// MARK: - Chapter 1 · Night Valley

private struct NightValleySection: View {
    let size: CGSize
    let time: TimeInterval
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x2A3A5E), Color(hex: 0x141B30), Color(hex: 0x0B0E18)],
                           startPoint: .top, endPoint: .bottom)
            Canvas { ctx, s in
                chapterStars(&ctx, size: s, time: time, count: 40, seed: 0x0A11, maxOpacity: 0.5)
            }
            .frame(height: size.height * 0.5)
            .frame(maxHeight: .infinity, alignment: .top)
            // Rolling hills — soft curves, no triangles.
            RollingHillsShape(amplitude: 0.05, phase: 0.8, waves: 1.4)
                .fill(Color(hex: 0x161E38))
                .frame(height: size.height)
                .offset(y: size.height * 0.34)
            RollingHillsShape(amplitude: 0.07, phase: 3.9, waves: 1.9)
                .fill(Color(hex: 0x0B1020))
                .frame(height: size.height)
                .offset(y: size.height * 0.44)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

// MARK: - Chapter 2 · Cloud Ocean

private struct CloudOceanSection: View {
    let size: CGSize
    let time: TimeInterval
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x162844), Color(hex: 0x24405E), Color(hex: 0x2A3A5E)],
                           startPoint: .top, endPoint: .bottom)
            // A soft warm horizon glow so it reads brighter than the night below.
            RadialGradient(colors: [Color(hex: 0xF0D6B0).opacity(0.22), .clear],
                           center: .center, startRadius: 4, endRadius: size.width * 0.7)
                .frame(width: size.width * 1.4, height: size.width * 1.4)
                .offset(y: size.height * 0.28)
            Canvas { ctx, s in
                var rng = SeededRNG(seed: 0x5EA_C10D)
                let rows = 3
                for row in 0..<rows {
                    let baseY = s.height * (0.5 + CGFloat(row) * 0.16)
                    for i in 0..<7 {
                        let u1 = rng.unit(), u2 = rng.unit()
                        let sway = time == 0 ? 0 : Foundation.sin(time * 0.06 + Double(i + row)) * 12
                        let cx = s.width * (CGFloat(i) / 6.0) + CGFloat(sway) + CGFloat(u1 - 0.5) * 30
                        let w = s.width * (0.34 + u2 * 0.22)
                        softPuff(&ctx, center: CGPoint(x: cx, y: baseY), width: w,
                                 color: Color(hex: 0xEAF0F8), alpha: 0.24 - Double(row) * 0.05)
                    }
                }
            }
            .blur(radius: 10)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

// MARK: - Chapter 3 · Moon Sky

private struct MoonSkySection: View {
    let size: CGSize
    let time: TimeInterval
    var body: some View {
        let d = size.width * 0.22
        return ZStack {
            LinearGradient(colors: [Color(hex: 0x0C1A2E), Color(hex: 0x122238), Color(hex: 0x162844)],
                           startPoint: .top, endPoint: .bottom)
            Canvas { ctx, s in
                chapterStars(&ctx, size: s, time: time, count: 70, seed: 0x33AA, maxOpacity: 0.7)
            }
            // The moon, off-centre with a soft glow.
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xEDF2FB).opacity(0.4), .clear],
                                         center: .center, startRadius: d * 0.3, endRadius: d * 1.9))
                    .frame(width: d * 4, height: d * 4)
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: 0xF4F6FA), Color(hex: 0xC9D2E4)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: d, height: d)
                    .overlay(
                        Circle().fill(Color(hex: 0x8B97B4).opacity(0.35))
                            .frame(width: d * 0.8, height: d * 0.8)
                            .offset(x: -d * 0.2, y: d * 0.12)
                            .blur(radius: d * 0.12)
                            .mask(Circle().frame(width: d, height: d)))
            }
            .position(x: size.width * 0.72, y: size.height * 0.34)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

// MARK: - Chapter 4 · Aurora Field

private struct AuroraFieldSection: View {
    let size: CGSize
    let time: TimeInterval
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0A1226), Color(hex: 0x0A182C), Color(hex: 0x0C1A2E)],
                           startPoint: .top, endPoint: .bottom)
            Canvas { ctx, s in
                chapterStars(&ctx, size: s, time: time, count: 70, seed: 0x4C0F, maxOpacity: 0.7)
            }
            Canvas { ctx, s in
                let colors = [Color(hex: 0x5CE6A8), Color(hex: 0x4CC8D9), Color(hex: 0x8E7BE8)]
                for band in 0..<3 {
                    let bandValue = Double(band)
                    let base = s.height * (0.24 + CGFloat(band) * 0.14)
                    let breathe: CGFloat
                    if time == 0 {
                        breathe = 1
                    } else {
                        let bp = time * 0.25 + bandValue * 1.9
                        breathe = CGFloat(0.75 + 0.25 * Foundation.sin(bp))
                    }
                    let amp = s.height * 0.07 * breathe
                    let bandH = s.height * 0.18
                    var top = Path()
                    var x: CGFloat = -10
                    var first = true
                    while x <= s.width + 10 {
                        let xv = Double(x)
                        let speed = 0.22 + bandValue * 0.07
                        let ph1 = xv / 90.0 + time * speed + bandValue * 2.1
                        let ph2 = xv / 36.0 - time * 0.13 + bandValue
                        let wave = Foundation.sin(ph1) + 0.4 * Foundation.sin(ph2)
                        let y = base + CGFloat(wave) * amp
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
                        Gradient(colors: [c.opacity(0), c.opacity(0.42), c.opacity(0)]),
                        startPoint: CGPoint(x: 0, y: base - amp),
                        endPoint: CGPoint(x: 0, y: base + bandH)))
                }
            }
            .blur(radius: 7)
            .blendMode(.plusLighter)
            // Snow-like drift.
            Canvas { ctx, s in
                var rng = SeededRNG(seed: 0x5A0F)
                for i in 0..<20 {
                    let u1 = rng.unit(), u2 = rng.unit(), u3 = rng.unit()
                    let sway = time == 0 ? 0 : Foundation.sin(time * 0.5 + Double(i)) * 14
                    let x = (u1 * s.width + CGFloat(sway)).truncatingRemainder(dividingBy: s.width)
                    let y = (u2 * s.height + CGFloat(time * 12)).truncatingRemainder(dividingBy: s.height)
                    let r = 0.9 + u3 * 1.2
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                             with: .color(.white.opacity(0.32)))
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

// MARK: - Chapter 5 · Starfield

private struct StarfieldSection: View {
    let size: CGSize
    let time: TimeInterval
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x060A18), Color(hex: 0x080E1F), Color(hex: 0x0A1226)],
                           startPoint: .top, endPoint: .bottom)
            // Faint nebula haze.
            RadialGradient(colors: [Color(hex: 0x6E4AE8).opacity(0.14), .clear],
                           center: .center, startRadius: 6, endRadius: size.width * 0.6)
                .frame(width: size.width, height: size.width)
                .offset(x: -size.width * 0.2, y: -size.height * 0.1)
                .blendMode(.plusLighter)
            Canvas { ctx, s in
                chapterStars(&ctx, size: s, time: time, count: 150, seed: 0x57A2, maxOpacity: 0.95)
                // A meteor every few seconds.
                if time != 0 {
                    let period = 6.0
                    let cyc = (time / period).rounded(.down)
                    let ph = time / period - cyc
                    if ph < 0.14 {
                        var rr = SeededRNG(seed: UInt64(bitPattern: Int64(cyc)) &* 31 &+ 5)
                        let tt = ph / 0.14
                        let x0 = s.width * (0.25 + rr.unit() * 0.6)
                        let y0 = s.height * (0.1 + rr.unit() * 0.3)
                        let travel = s.width * 0.45 * tt
                        let head = CGPoint(x: x0 - travel, y: y0 + travel * 0.5)
                        let tail = CGPoint(x: head.x + 90, y: head.y - 45)
                        var p = Path(); p.move(to: tail); p.addLine(to: head)
                        let a = Foundation.sin(.pi * tt) * 0.9
                        ctx.stroke(p, with: .linearGradient(
                            Gradient(colors: [.white.opacity(0), .white.opacity(a)]),
                            startPoint: tail, endPoint: head), lineWidth: 1.6)
                    }
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

// MARK: - Chapter 6 · Deep Space

private struct DeepSpaceSection: View {
    let size: CGSize
    let time: TimeInterval
    var body: some View {
        let d = size.width * 0.26
        return ZStack {
            LinearGradient(colors: [Color(hex: 0x02030A), Color(hex: 0x04060F), Color(hex: 0x060A18)],
                           startPoint: .top, endPoint: .bottom)
            ZStack {
                RadialGradient(colors: [Color(hex: 0x6E4AE8).opacity(0.16), .clear],
                               center: .center, startRadius: 8, endRadius: size.width * 0.6)
                    .frame(width: size.width * 1.2, height: size.width * 1.2)
                    .offset(x: -size.width * 0.24, y: -size.height * 0.16)
                RadialGradient(colors: [Color(hex: 0x2AC8B0).opacity(0.12), .clear],
                               center: .center, startRadius: 8, endRadius: size.width * 0.5)
                    .frame(width: size.width, height: size.width)
                    .offset(x: size.width * 0.3, y: size.height * 0.24)
            }
            .blendMode(.plusLighter)
            Canvas { ctx, s in
                chapterStars(&ctx, size: s, time: time, count: 110, seed: 0xDEE5, maxOpacity: 0.9)
            }
            // A distant planet, off-centre.
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: 0x94A9D8), Color(hex: 0x46557E)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().fill(Color(hex: 0x101728).opacity(0.55))
                    .offset(x: d * 0.22, y: d * 0.16).blur(radius: d * 0.16).mask(Circle())
                Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1)
            }
            .frame(width: d, height: d)
            .position(x: size.width * 0.30, y: size.height * 0.4)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}
