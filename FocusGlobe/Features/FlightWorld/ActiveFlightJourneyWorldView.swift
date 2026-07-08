import Foundation
import SwiftUI

/// The **active-flight world** — a vertical journey tape, engineered so the
/// motion cannot fail and cannot stutter:
///
/// * Six full-screen chapters are drawn **once** into a static 6×-screen-tall
///   tape (plain gradients + one-shot Canvases, **zero blur**, zero per-frame
///   redrawing). Adjacent chapters share their boundary colour, so the tape is
///   one continuous sky with no seams.
/// * A single `TimelineView(.animation)` moves that cached tape downward by
///   `offset` only — a pure GPU translation. As `progress()` rises 0→1 the
///   viewport travels Night Valley → Cloud Ocean → Moon Sky → Aurora Field →
///   Starfield → Deep Space.
/// * A tiny screen-sized overlay adds life (twinkling stars + two drifting
///   foreground wisps) without ever touching the tape.
///
/// Used **only** by the active flight — Home and the ritual keep their still
/// scene, so the world starts moving exactly when the flight does.
struct ActiveFlightJourneyWorldView: View {
    /// Read live every frame; 0 shows Night Valley, 1 shows Deep Space.
    let progress: () -> Double
    var animated: Bool = true

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = max(1, geo.size.height)
            ZStack {
                // Base colour behind everything (never visible once laid out).
                Color(hex: 0x0D1322)

                TimelineView(.animation(minimumInterval: animated ? 1.0 / 30.0 : 5.0)) { _ in
                    let p = CGFloat(min(1, max(0, progress())))
                    // p = 0 → shift the tape up by 5 screens (bottom chapter in
                    // view). As p grows the shift shrinks → the tape slides DOWN
                    // past the viewport and the balloon reads as rising.
                    WorldTape(width: W, height: H)
                        .offset(y: -H * 5 * (1 - p))
                        .frame(width: W, height: H, alignment: .top)
                        .clipped()
                }

                if animated {
                    AmbientLifeOverlay()
                }
            }
            .frame(width: W, height: H)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - The tape (static — drawn once, moved by offset only)

private struct WorldTape: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            DeepSpaceSection(width: width, height: height)
            StarfieldSection(width: width, height: height)
            AuroraFieldSection(width: width, height: height)
            MoonSkySection(width: width, height: height)
            CloudOceanSection(width: width, height: height)
            NightValleySection(width: width, height: height)
        }
        .frame(width: width, height: height * 6)
    }
}

// MARK: - Static drawing helpers (typed, small expressions)

private func drawStars(_ ctx: inout GraphicsContext, in size: CGSize, count: Int,
                       seed: UInt64, brightness: Double) {
    var rng = SeededRNG(seed: seed)
    for _ in 0..<count {
        let u1 = rng.unit()
        let u2 = rng.unit()
        let u3 = rng.unit()
        let x = CGFloat(u1) * size.width
        let y = CGFloat(u2) * size.height
        let r = CGFloat(0.6 + u3 * 1.6)
        let a = (0.25 + u3 * 0.65) * brightness
        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                 with: .color(.white.opacity(a)))
    }
}

/// A soft cloud puff: an ellipse filled with a radial falloff — softness with
/// no blur pass at all.
private func drawSoftPuff(_ ctx: inout GraphicsContext, center: CGPoint,
                          radius: CGFloat, squash: CGFloat, color: Color, alpha: Double) {
    let rect = CGRect(x: center.x - radius,
                      y: center.y - radius * squash,
                      width: radius * 2,
                      height: radius * 2 * squash)
    let g = Gradient(colors: [color.opacity(alpha),
                              color.opacity(alpha * 0.55),
                              color.opacity(0)])
    ctx.fill(Path(ellipseIn: rect),
             with: .radialGradient(g, center: center, startRadius: 0, endRadius: radius))
}

/// An organic aurora ribbon: both edges wave independently. All maths in small
/// typed steps (Swift's type-checker stays fast; nothing to time out on).
private func auroraRibbonPath(width: CGFloat, baseY: CGFloat, amp: CGFloat,
                              thickness: CGFloat, phase: Double) -> Path {
    var p = Path()
    var x: CGFloat = -12
    var first = true
    while x <= width + 12 {
        let xv = Double(x)
        let w1 = Foundation.sin(xv / 110.0 + phase)
        let w2 = 0.45 * Foundation.sin(xv / 47.0 + phase * 1.7)
        let wave = w1 + w2
        let y = baseY + CGFloat(wave) * amp
        if first { p.move(to: CGPoint(x: x, y: y)); first = false }
        else { p.addLine(to: CGPoint(x: x, y: y)) }
        x += 14
    }
    var xr: CGFloat = width + 12
    while xr >= -12 {
        let xv = Double(xr)
        let w1 = Foundation.sin(xv / 110.0 + phase + 0.6)
        let w2 = 0.45 * Foundation.sin(xv / 47.0 + phase * 1.7 + 0.4)
        let wave = w1 + w2
        let y = baseY + thickness + CGFloat(wave) * (amp * 0.8)
        p.addLine(to: CGPoint(x: xr, y: y))
        xr -= 14
    }
    p.closeSubpath()
    return p
}

// MARK: - Chapter 1 · Night Valley (tape bottom — the launch)

private struct NightValleySection: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x2C4368), Color(hex: 0x1A2A47), Color(hex: 0x0D1322)],
                           startPoint: .top, endPoint: .bottom)
            Canvas { ctx, s in
                drawStars(&ctx, in: CGSize(width: s.width, height: s.height * 0.55),
                          count: 45, seed: 0x0A11, brightness: 0.55)
            }
            // A quiet warm glow low on the horizon.
            RadialGradient(colors: [Color(hex: 0xE8C48A).opacity(0.10), .clear],
                           center: .center, startRadius: 2, endRadius: width * 0.55)
                .frame(width: width * 1.1, height: width * 1.1)
                .offset(y: height * 0.16)
            // Low valley fog above the ridgeline.
            LinearGradient(colors: [Color(hex: 0xAAB8D0).opacity(0), Color(hex: 0xAAB8D0).opacity(0.12)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: height * 0.2)
                .offset(y: height * 0.18)
            RollingHillsShape(amplitude: 0.05, phase: 0.8, waves: 1.35)
                .fill(Color(hex: 0x1B2A45))
                .frame(width: width, height: height)
                .offset(y: height * 0.02)
            RollingHillsShape(amplitude: 0.065, phase: 3.9, waves: 1.8)
                .fill(Color(hex: 0x0B101E))
                .frame(width: width, height: height)
                .offset(y: height * 0.12)
        }
        .frame(width: width, height: height)
        .clipped()
    }
}

// MARK: - Chapter 2 · Cloud Ocean

private struct CloudOceanSection: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x18294A), Color(hex: 0x223A5E), Color(hex: 0x2C4368)],
                           startPoint: .top, endPoint: .bottom)
            // Sunlit warmth suffusing the cloud sea.
            RadialGradient(colors: [Color(hex: 0xF2DFC0).opacity(0.18), .clear],
                           center: .center, startRadius: 4, endRadius: width * 0.62)
                .frame(width: width * 1.24, height: width * 1.24)
                .offset(y: height * 0.10)
            Canvas { ctx, s in
                var rng = SeededRNG(seed: 0x5EAC)
                // Back row — cool and distant.
                for i in 0..<6 {
                    let u = rng.unit()
                    let cx = s.width * (CGFloat(i) / 5.0) + CGFloat(u - 0.5) * 34
                    let cy = s.height * 0.44
                    drawSoftPuff(&ctx, center: CGPoint(x: cx, y: cy),
                                 radius: s.width * 0.17, squash: 0.55,
                                 color: Color(hex: 0xDCE8F6), alpha: 0.22)
                }
                // Middle row.
                for i in 0..<5 {
                    let u = rng.unit()
                    let cx = s.width * (CGFloat(i) / 4.0) + CGFloat(u - 0.5) * 40
                    let cy = s.height * 0.60
                    drawSoftPuff(&ctx, center: CGPoint(x: cx, y: cy),
                                 radius: s.width * 0.23, squash: 0.5,
                                 color: Color(hex: 0xE9F0FA), alpha: 0.30)
                }
                // Front row — big, bright, cream-kissed.
                for i in 0..<6 {
                    let u = rng.unit()
                    let cx = s.width * (CGFloat(i) / 5.0) + CGFloat(u - 0.5) * 44
                    let cy = s.height * 0.80
                    let tint = i % 2 == 0 ? Color(hex: 0xF2F1EC) : Color(hex: 0xF3EADA)
                    drawSoftPuff(&ctx, center: CGPoint(x: cx, y: cy),
                                 radius: s.width * 0.27, squash: 0.5,
                                 color: tint, alpha: 0.38)
                }
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }
}

// MARK: - Chapter 3 · Moon Sky

private struct MoonSkySection: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let d = width * 0.20
        return ZStack {
            LinearGradient(colors: [Color(hex: 0x0F1B33), Color(hex: 0x142442), Color(hex: 0x18294A)],
                           startPoint: .top, endPoint: .bottom)
            Canvas { ctx, s in
                drawStars(&ctx, in: s, count: 85, seed: 0x33AA, brightness: 0.75)
            }
            // Halo, then the moon itself with soft maria.
            RadialGradient(colors: [Color(hex: 0xEDF2FB).opacity(0.22), .clear],
                           center: .center, startRadius: d * 0.4, endRadius: d * 2.2)
                .frame(width: d * 4.4, height: d * 4.4)
                .position(x: width * 0.70, y: height * 0.32)
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: 0xF5F7FB), Color(hex: 0xC8D2E6)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().fill(Color(hex: 0x9AA6C0).opacity(0.35))
                    .frame(width: d * 0.18, height: d * 0.18)
                    .offset(x: -d * 0.15, y: -d * 0.05)
                Circle().fill(Color(hex: 0x9AA6C0).opacity(0.30))
                    .frame(width: d * 0.11, height: d * 0.11)
                    .offset(x: d * 0.12, y: d * 0.16)
                Circle().fill(Color(hex: 0x9AA6C0).opacity(0.25))
                    .frame(width: d * 0.08, height: d * 0.08)
                    .offset(x: -d * 0.02, y: d * 0.24)
                Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
            }
            .frame(width: d, height: d)
            .position(x: width * 0.70, y: height * 0.32)
            // Thin high wisps.
            Capsule()
                .fill(LinearGradient(colors: [.clear, Color(hex: 0xC9D6EC).opacity(0.12), .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: width * 0.72, height: 10)
                .position(x: width * 0.42, y: height * 0.56)
            Capsule()
                .fill(LinearGradient(colors: [.clear, Color(hex: 0xC9D6EC).opacity(0.10), .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: width * 0.5, height: 8)
                .position(x: width * 0.62, y: height * 0.70)
        }
        .frame(width: width, height: height)
        .clipped()
    }
}

// MARK: - Chapter 4 · Aurora Field

private struct AuroraFieldSection: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0B1226), Color(hex: 0x0D1730), Color(hex: 0x0F1B33)],
                           startPoint: .top, endPoint: .bottom)
            Canvas { ctx, s in
                drawStars(&ctx, in: s, count: 70, seed: 0x4C0F, brightness: 0.7)
            }
            Canvas { ctx, s in
                let ribbons: [(base: CGFloat, color: Color, alpha: Double, phase: Double)] = [
                    (0.28, Color(hex: 0x54E0A8), 0.40, 0.0),
                    (0.45, Color(hex: 0x4FC9DD), 0.34, 2.1),
                    (0.60, Color(hex: 0x8F7BE8), 0.30, 4.4),
                ]
                for r in ribbons {
                    let baseY = s.height * r.base
                    let amp = s.height * 0.05
                    let thick = s.height * 0.15
                    let path = auroraRibbonPath(width: s.width, baseY: baseY,
                                                amp: amp, thickness: thick, phase: r.phase)
                    let g = Gradient(colors: [r.color.opacity(0),
                                              r.color.opacity(r.alpha),
                                              r.color.opacity(0)])
                    ctx.fill(path, with: .linearGradient(
                        g,
                        startPoint: CGPoint(x: 0, y: baseY - amp),
                        endPoint: CGPoint(x: 0, y: baseY + thick + amp)))
                }
            }
            Canvas { ctx, s in
                var rng = SeededRNG(seed: 0x5A0F)
                for _ in 0..<24 {
                    let u1 = rng.unit()
                    let u2 = rng.unit()
                    let u3 = rng.unit()
                    let x = CGFloat(u1) * s.width
                    let y = CGFloat(u2) * s.height
                    let r = CGFloat(1.0 + u3 * 1.3)
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                             with: .color(.white.opacity(0.30)))
                }
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }
}

// MARK: - Chapter 5 · Starfield

private struct StarfieldSection: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x070B1A), Color(hex: 0x091026), Color(hex: 0x0B1226)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(hex: 0x6E4AE8).opacity(0.10), .clear],
                           center: .center, startRadius: 6, endRadius: width * 0.5)
                .frame(width: width, height: width)
                .position(x: width * 0.28, y: height * 0.35)
            Canvas { ctx, s in
                drawStars(&ctx, in: s, count: 180, seed: 0x57A2, brightness: 1.0)
                // A few hero stars.
                var rng = SeededRNG(seed: 0xB16)
                for _ in 0..<6 {
                    let u1 = rng.unit()
                    let u2 = rng.unit()
                    let x = CGFloat(u1) * s.width
                    let y = CGFloat(u2) * s.height
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 3, height: 3)),
                             with: .color(.white.opacity(0.95)))
                }
                // A quiet comet with a long tail.
                let head = CGPoint(x: s.width * 0.62, y: s.height * 0.30)
                let tail = CGPoint(x: s.width * 0.82, y: s.height * 0.20)
                var streak = Path()
                streak.move(to: tail)
                streak.addLine(to: head)
                let g = Gradient(colors: [Color.white.opacity(0), Color(hex: 0xD9F0FF).opacity(0.7)])
                ctx.stroke(streak, with: .linearGradient(g, startPoint: tail, endPoint: head),
                           lineWidth: 1.8)
                ctx.fill(Path(ellipseIn: CGRect(x: head.x - 2.2, y: head.y - 2.2, width: 4.4, height: 4.4)),
                         with: .color(.white.opacity(0.9)))
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }
}

// MARK: - Chapter 6 · Deep Space (tape top — the summit)

private struct DeepSpaceSection: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let d = width * 0.26
        return ZStack {
            LinearGradient(colors: [Color(hex: 0x030208), Color(hex: 0x050514), Color(hex: 0x070B1A)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(hex: 0x6E4AE8).opacity(0.16), .clear],
                           center: .center, startRadius: 8, endRadius: width * 0.55)
                .frame(width: width * 1.1, height: width * 1.1)
                .position(x: width * 0.76, y: height * 0.28)
            RadialGradient(colors: [Color(hex: 0x2AC8B0).opacity(0.10), .clear],
                           center: .center, startRadius: 8, endRadius: width * 0.5)
                .frame(width: width, height: width)
                .position(x: width * 0.18, y: height * 0.72)
            Canvas { ctx, s in
                drawStars(&ctx, in: s, count: 130, seed: 0xDEE5, brightness: 0.9)
            }
            // The distant planet — the destination you never quite reach.
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: 0x9DB2DE), Color(hex: 0x4A5A84)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                // Soft terminator shading, no blur needed.
                Circle()
                    .fill(RadialGradient(colors: [Color.clear, Color(hex: 0x0A0F1E).opacity(0.6)],
                                         center: UnitPoint(x: 0.32, y: 0.36),
                                         startRadius: d * 0.2, endRadius: d * 0.62))
                Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            }
            .frame(width: d, height: d)
            .position(x: width * 0.30, y: height * 0.42)
            // Its tiny companion moon.
            Circle()
                .fill(Color(hex: 0xC9D2E4))
                .frame(width: d * 0.10, height: d * 0.10)
                .position(x: width * 0.30 + d * 0.85, y: height * 0.42 - d * 0.55)
        }
        .frame(width: width, height: height)
        .clipped()
    }
}

// MARK: - Ambient life (the only animated layer — screen-sized, no blur)

/// Twinkling stars and two slow foreground wisps, drawn over the tape. Keeps
/// the world alive at any flight length without ever re-rendering the tape.
private struct AmbientLifeOverlay: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            Canvas { c, s in
                var rng = SeededRNG(seed: 0x71F1)
                for i in 0..<22 {
                    let u1 = rng.unit()
                    let u2 = rng.unit()
                    let u3 = rng.unit()
                    let x = CGFloat(u1) * s.width
                    let y = CGFloat(u2) * s.height * 0.85
                    let speed = 0.6 + u3 * 1.5
                    let phase = t * speed + Double(i) * 1.3
                    let a = 0.08 + 0.16 * (0.5 + 0.5 * Foundation.sin(phase))
                    let r = CGFloat(0.8 + u3 * 1.4)
                    c.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                           with: .color(.white.opacity(a)))
                }
                for k in 0..<2 {
                    let kd = Double(k)
                    let speed = 9.0 + kd * 5.0
                    let span = Double(s.width) + 360.0
                    let raw = (t * speed + kd * 500.0).truncatingRemainder(dividingBy: span)
                    let x = CGFloat(raw) - 180
                    let y = s.height * (0.30 + CGFloat(k) * 0.36)
                    let radius = s.width * (0.34 - CGFloat(k) * 0.08)
                    let g = Gradient(colors: [Color(hex: 0xDCE6F4).opacity(0.07),
                                              Color(hex: 0xDCE6F4).opacity(0)])
                    let rect = CGRect(x: x - radius, y: y - radius * 0.35,
                                      width: radius * 2, height: radius * 0.7)
                    c.fill(Path(ellipseIn: rect),
                           with: .radialGradient(g, center: CGPoint(x: x, y: y),
                                                 startRadius: 0, endRadius: radius))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
