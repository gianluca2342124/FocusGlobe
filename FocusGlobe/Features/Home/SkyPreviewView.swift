import Foundation
import SwiftUI
import UIKit

/// A full-screen **living preview** of one Sky — the paging background of the
/// Home Sky selector. This is the first world the pilot sees, so it carries
/// the same visual language as the flight itself:
///
///   • the Sky's authored 5-stop palette (the flight's own gradient timeline,
///     evolving imperceptibly slowly — never a flat colour wall),
///   • zenith depth above and a soft horizon bloom below,
///   • layered silhouette scenery with glacial parallax (`SkyDepthScenery`),
///   • the Sky's signature accent, gently alive (twinkle, lantern warmth,
///     breathing aurora, falling rain),
///   • one or two tiny distant travellers.
///
/// Orientation-aware artwork is the foundation when bundled; the procedural
/// world remains the safe fallback. Motion is calm and cheap (a single
/// low-rate TimelineView), and Reduce Motion renders a perfectly still frame.
struct SkyPreviewView: View {
    let sky: FocusSky
    var animated: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            let art = SkyArtworkResolver.image(for: sky, landscape: W > H)
            if animated && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { ctx in
                    content(W: W, H: H, t: ctx.date.timeIntervalSinceReferenceDate, art: art)
                }
            } else {
                // A settled still frame keeps Reduce Motion rich without
                // advancing any animation or landing on an empty event phase.
                content(W: W, H: H, t: 24, art: art)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func content(W: CGFloat, H: CGFloat, t: Double, art: UIImage?) -> some View {
        ZStack {
            background(W: W, H: H, t: t, art: art)
            if previewStarDensity > 0.01 {
                starField(W: W, H: H, t: t)
                    .opacity(art == nil ? 1 : artworkStarOpacity)
            }
            if art == nil {
                accent(W: W, H: H, t: t)
            } else {
                artworkAccent(W: W, H: H, t: t)
            }
            glowPool(W: W, H: H, t: t)
                .opacity(art == nil ? 1 : 0.28)
            // The authored per-Sky scenery IS the ground (it skirts to the
            // bottom). Procedural depth belongs to procedural skies only —
            // bundled art already carries its own scenery.
            if art == nil { SkyDepthScenery(sky: sky, t: t, horizon: 0.84) }
            distantBalloons(W: W, H: H, t: t)
        }
        .frame(width: W, height: H)
        .clipped()
    }

    // MARK: Layers

    @ViewBuilder private func background(W: CGFloat, H: CGFloat, t: Double,
                                         art: UIImage?) -> some View {
        // The flight's own authored palette, drifting through its keyframes so
        // slowly the change is felt rather than seen. Never a flat gradient.
        let stops = SkyGradientTimeline.stops(skyID: sky.id, at: t * 0.5)
        let breathe = t == 0 ? 1.0 : 0.85 + 0.15 * Foundation.sin(t * 0.05)
        LinearGradient(colors: stops, startPoint: .top, endPoint: .bottom)
        if let ui = art {
            SkyArtworkFoundation(image: ui)
            artworkGrade(W: W, H: H, t: t)
        } else {
            // Zenith depth — the top of the sky deepens into vastness.
            LinearGradient(stops: [
                .init(color: stops[0].opacity(0.55), location: 0),
                .init(color: stops[0].opacity(0), location: 0.28),
                .init(color: .clear, location: 1),
            ], startPoint: .top, endPoint: .bottom)
            // A wandering soft highlight — organic light, no disc.
            RadialGradient(colors: [sky.glowColor.opacity(0.14 * breathe), .clear],
                           center: UnitPoint(x: 0.5 + 0.18 * Foundation.sin(t * 0.008),
                                             y: 0.30 + 0.05 * Foundation.sin(t * 0.006 + 1.4)),
                           startRadius: 2, endRadius: W * 1.0)
            // Horizon bloom — light gathering in the thick air low in the frame.
            RadialGradient(colors: [sky.glowColor.opacity(0.12 * breathe), .clear],
                           center: UnitPoint(x: 0.5, y: 0.84),
                           startRadius: 4, endRadius: W * 0.9)
        }
    }

    /// A restrained readability/atmosphere grade over finished art. It never
    /// redraws terrain or architecture; it only keeps Home chrome legible and
    /// lets the authored glow breathe almost imperceptibly.
    private func artworkGrade(W: CGFloat, H: CGFloat, t: Double) -> some View {
        let breathe = t == 0 ? 1.0 : 0.86 + 0.14 * Foundation.sin(t * 0.035)
        return ZStack {
            LinearGradient(stops: [
                .init(color: .black.opacity(0.10), location: 0),
                .init(color: .clear, location: 0.34),
                .init(color: .clear, location: 0.72),
                .init(color: .black.opacity(0.08), location: 1),
            ], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [sky.glowColor.opacity(0.055 * breathe), .clear],
                           center: UnitPoint(x: 0.5, y: 0.76),
                           startRadius: 2, endRadius: W * 0.72)
        }
    }

    /// Deterministic star sprinkle, denser for cosmic skies — twinkling gently
    /// in place, with soft glints on the brightest few.
    private func starField(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: skySeed &+ 0x57AB)
            let density = previewStarDensity
            let count = Int(48 + density * 150)
            for i in 0..<count {
                let x = CGFloat(rng.unit()) * size.width
                let desertCeiling: CGFloat = size.width > size.height ? 0.64 : 0.67
                let maxY: CGFloat = sky.id == "sahara-night" ? desertCeiling : 0.84
                let y = CGFloat(rng.unit()) * size.height * maxY
                let r = CGFloat(0.45 + rng.unit() * 1.7)
                let u = rng.unit()
                let pulse = 0.5 + 0.5 * Foundation.sin(t * (0.30 + u * 1.1) + Double(i) * 1.37)
                let tw = 0.34 + 0.66 * pow(pulse, u > 0.88 ? 2.2 : 1)
                let a = (0.16 + u * 0.62) * density * tw
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(a)))
                if u > 0.92 && density > 0.4 {
                    softHalo(&ctx, x: x, y: y, r: r * 3.2, color: .white.opacity(a * 0.35))
                }
                if u > 0.968 && density > 0.4 {
                    let glint = CGFloat(4.5 + u * 4.5) * CGFloat(tw)
                    var p = Path()
                    p.move(to: CGPoint(x: x - glint, y: y)); p.addLine(to: CGPoint(x: x + glint, y: y))
                    p.move(to: CGPoint(x: x, y: y - glint)); p.addLine(to: CGPoint(x: x, y: y + glint))
                    ctx.stroke(p, with: .color(.white.opacity(a * 0.34)), lineWidth: 0.65)
                }
            }
        }
    }

    /// The Sky's signature accent — one tasteful hero element, gently alive.
    @ViewBuilder private func accent(W: CGFloat, H: CGFloat, t: Double) -> some View {
        switch sky.accent {
        case .none:
            EmptyView()
        case .moon:
            let breathe = t == 0 ? 1.0 : 0.85 + 0.15 * Foundation.sin(t * 0.04)
            ZStack {
                Circle().fill(RadialGradient(colors: [Color(hex: 0xF5F7FB).opacity(0.5 * breathe), .clear],
                                             center: .center, startRadius: 2, endRadius: W * 0.42))
                    .frame(width: W * 0.84, height: W * 0.84)
                Circle().fill(LinearGradient(colors: [Color(hex: 0xFCFDFF), Color(hex: 0xC2CCE2)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: W * 0.42, height: W * 0.42)
                    .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
            }
            .position(x: W * 0.68, y: H * 0.24)
        case .aurora:
            auroraAccent(W: W, H: H, t: t)
        case .planet:
            let drift = CGFloat(t == 0 ? 0 : Foundation.sin(t * 0.05) * 5)
            if sky.id == "deep-space" {
                // Parity with the flight: the same Saturn-like ringed planet.
                SkyCosmic.ringedPlanet(d: W * 0.22)
                    .position(x: W * 0.72, y: H * 0.22 + drift)
            } else {
                let breathe = t == 0 ? 1.0 : 0.8 + 0.2 * Foundation.sin(t * 0.05 + 1.1)
                ZStack {
                    Circle().fill(RadialGradient(colors: [sky.glowColor.opacity(0.4 * breathe), .clear],
                                                 center: .center, startRadius: 1, endRadius: W * 0.3))
                        .frame(width: W * 0.6, height: W * 0.6)
                    Circle().fill(LinearGradient(colors: [Color(hex: 0xAABDE6), Color(hex: 0x3A4A72)],
                                                 startPoint: .top, endPoint: .bottom))
                        .frame(width: W * 0.22, height: W * 0.22)
                }
                .position(x: W * 0.26, y: H * 0.2 + drift)
            }
        case .lanterns:
            lanternAccent(W: W, H: H, t: t)
        case .rain:
            rainAccent(W: W, H: H, t: t)
        case .bigStars:
            bigStarAccent(W: W, H: H, t: t)
        }
    }

    /// Finished artwork already owns every landmark and celestial body. Only the
    /// effects that genuinely move remain above it. These mirror the active
    /// journey's signature behavior, so Home is an honest window into the same
    /// world without duplicating painted planets, terrain or architecture.
    @ViewBuilder private func artworkAccent(W: CGFloat, H: CGFloat, t: Double) -> some View {
        switch sky.effectKind {
        case .lagoon:
            lagoonAccent(W: W, H: H, t: t)
        case .lanterns:
            ZStack {
                lanternAccent(W: W, H: H, t: t)
                previewHaze(W: W, H: H, t: t, tint: Color(hex: 0xE6A67A), y: 0.68)
            }
        case .aurora:
            ZStack {
                auroraAccent(W: W, H: H, t: t).opacity(0.42)
                previewSnow(W: W, H: H, t: t)
            }
        case .rain:
            ZStack {
                rainAccent(W: W, H: H, t: t)
                cityGlowAccent(W: W, H: H, t: t)
                previewHaze(W: W, H: H, t: t, tint: Color(hex: 0x8FA6D8), y: 0.62)
            }
        case .snow:
            ZStack {
                previewSnow(W: W, H: H, t: t).opacity(0.72)
                previewHaze(W: W, H: H, t: t, tint: Color(hex: 0xE7F1F4), y: 0.66)
                previewCloudWisps(W: W, H: H, t: t, tint: Color(hex: 0xF0F7F8))
            }
        case .starfall:
            ZStack {
                cosmicAccent(W: W, H: H, t: t, tint: Color(hex: 0xB49CE8))
                previewShootingStars(W: W, H: H, t: t,
                                     periods: [12, 19], offsets: [0.10, 0.62])
            }
        case .none:
            legacyArtworkAccent(W: W, H: H, t: t)
        }
    }

    @ViewBuilder private func legacyArtworkAccent(W: CGFloat, H: CGFloat, t: Double) -> some View {
        switch sky.id {
        case "sahara-night":
            ZStack {
                bigStarAccent(W: W, H: H, t: t).opacity(0.62)
                previewShootingStars(W: W, H: H, t: t,
                                     periods: [14, 23], offsets: [0.08, 0.58])
                previewHaze(W: W, H: H, t: t, tint: Color(hex: 0xE8A06A), y: 0.72)
            }
        case "deep-space":
            ZStack {
                cosmicAccent(W: W, H: H, t: t, tint: Color(hex: 0x8AA6E8))
                previewShootingStars(W: W, H: H, t: t,
                                     periods: [16, 27], offsets: [0.18, 0.70])
            }
        default:
            switch sky.accent {
            case .aurora: auroraAccent(W: W, H: H, t: t).opacity(0.32)
            case .lanterns: lanternAccent(W: W, H: H, t: t)
            case .rain: rainAccent(W: W, H: H, t: t)
            case .bigStars: bigStarAccent(W: W, H: H, t: t).opacity(0.45)
            case .none, .moon, .planet: EmptyView()
            }
        }
    }

    /// Two soft aurora bands breathing over the polar sky.
    private func auroraAccent(W: CGFloat, H: CGFloat, t: Double) -> some View {
        let breathe = t == 0 ? 1.0 : 0.72 + 0.28 * Foundation.sin(t * 0.07)
        let lift = t == 0 ? 0.0 : Foundation.sin(t * 0.03) * 8
        return ZStack {
            AuroraBandShape()
                .fill(LinearGradient(colors: [Color(hex: 0x54E0A8).opacity(0),
                                              Color(hex: 0x54E0A8).opacity(0.42 * breathe),
                                              Color(hex: 0x8F7BE8).opacity(0.26 * breathe),
                                              Color(hex: 0x54E0A8).opacity(0)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: W * 1.2, height: H * 0.3)
                .position(x: W * 0.5, y: H * 0.26 + CGFloat(lift))
                .blur(radius: 8)
            AuroraBandShape()
                .fill(LinearGradient(colors: [Color(hex: 0x4FC9DD).opacity(0),
                                              Color(hex: 0x4FC9DD).opacity(0.20 * breathe),
                                              Color(hex: 0x4FC9DD).opacity(0)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: W * 1.3, height: H * 0.22)
                .position(x: W * 0.46, y: H * 0.40 - CGFloat(lift) * 0.6)
                .blur(radius: 10)
        }
    }

    /// The same illustrated Kyoto lantern family used in flight. Lanterns start
    /// below the horizon, rise through staggered depth lanes and fade beyond the
    /// top; a quiet anchored row keeps the architecture warmly inhabited.
    private func lanternAccent(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, size in
            let sprites = [
                ctx.resolve(Image("SkyOverlay_KyotoLantern_Ivory")),
                ctx.resolve(Image("SkyOverlay_KyotoLantern_Vermilion")),
                ctx.resolve(Image("SkyOverlay_KyotoLantern_Coral")),
            ]
            for slot in 0..<13 {
                let period = 52.0
                let shifted = t / period + Double(slot) / 13.0
                let cycle = shifted.rounded(.down)
                let local = shifted - cycle
                let fadeIn = previewSmoothStep(0.03, 0.16, local)
                let fadeOut = 1 - previewSmoothStep(0.78, 0.98, local)
                let env = fadeIn * fadeOut
                guard env > 0.01 else { continue }
                var rng = SeededRNG(seed: skySeed &+ UInt64(bitPattern: Int64(cycle)) &* 53 &+ UInt64(slot) &* 11)
                let depth = rng.unit()
                let startX = 0.06 + rng.unit() * 0.88
                let endDrift = (rng.unit() - 0.5) * (0.10 + depth * 0.08)
                let startY = 1.06 + rng.unit() * 0.10
                let endY = -0.16 + (1 - depth) * 0.22
                let progress = local * local * (3 - 2 * local)
                let sway = Foundation.sin(t * (0.09 + rng.unit() * 0.10) + Double(slot) * 1.27)
                    * (2 + depth * 7)
                let x = (startX + endDrift * progress) * Double(size.width) + sway
                let y = (startY + (endY - startY) * progress) * Double(size.height)
                let side = CGFloat(9 + depth * 18)
                let flicker = 0.82 + 0.18 * Foundation.sin(t * (1 + rng.unit()) + Double(slot) * 1.9)
                let alpha = env * flicker * (0.40 + depth * 0.56)
                softHalo(&ctx, x: CGFloat(x), y: CGFloat(y), r: side * 0.45,
                         color: Color(hex: 0xFFC873).opacity(0.24 * alpha))
                let rect = CGRect(x: CGFloat(x) - side / 2, y: CGFloat(y) - side / 2,
                                  width: side, height: side)
                ctx.drawLayer { layer in
                    layer.opacity = alpha
                    layer.draw(sprites[slot % sprites.count], in: rect)
                }
            }

            var anchoredRNG = SeededRNG(seed: skySeed &+ 0xA11C)
            for i in 0..<6 {
                let x = CGFloat(0.08 + anchoredRNG.unit() * 0.84) * size.width
                let y = CGFloat(0.69 + anchoredRNG.unit() * 0.15) * size.height
                let side = CGFloat(7 + anchoredRNG.unit() * 7)
                let pulse = 0.72 + 0.28 * Foundation.sin(t * (0.55 + anchoredRNG.unit() * 0.7) + Double(i))
                softHalo(&ctx, x: x, y: y, r: side * 0.7,
                         color: Color(hex: 0xFFB95E).opacity(0.30 * pulse))
                ctx.drawLayer { layer in
                    layer.opacity = 0.42 + 0.46 * pulse
                    layer.draw(sprites[i % sprites.count],
                               in: CGRect(x: x - side / 2, y: y - side / 2,
                                          width: side, height: side))
                }
            }
        }
    }

    /// Soft rain drifting down through the preview — quiet, cool, alive.
    private func rainAccent(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: skySeed &+ 0x0A1D)
            let span = size.height * 0.8 + 30
            for _ in 0..<72 {
                let fx = rng.unit()
                let fy = rng.unit()
                let depth = rng.unit()
                let speed = 30.0 + depth * 52.0
                let y = CGFloat((fy * Double(span) + t * speed)
                    .truncatingRemainder(dividingBy: Double(span))) - 15
                let x = CGFloat(fx) * size.width - y * CGFloat(0.02 + depth * 0.035)
                let len = CGFloat(7 + depth * 14)
                var p = Path()
                p.move(to: CGPoint(x: x, y: y))
                p.addLine(to: CGPoint(x: x - len * 0.18, y: y + len))
                ctx.stroke(p, with: .color(Color(hex: 0xC9DCF6).opacity(0.10 + depth * 0.25)),
                           lineWidth: CGFloat(0.65 + depth * 0.65))
            }
        }
    }

    private func previewShootingStars(W: CGFloat, H: CGFloat, t: Double,
                                      periods: [Double], offsets: [Double]) -> some View {
        Canvas { ctx, size in
            for lane in periods.indices {
                let period = periods[lane]
                let shifted = t / period + offsets[min(lane, offsets.count - 1)]
                let cycle = shifted.rounded(.down)
                let phase = shifted - cycle
                guard phase < 0.16 else { continue }
                let local = phase / 0.16
                var rng = SeededRNG(seed: skySeed &+ UInt64(bitPattern: Int64(cycle)) &* 131
                                    &+ UInt64(lane) &* 41)
                let x0 = size.width * CGFloat(0.12 + rng.unit() * 0.76)
                let y0 = size.height * CGFloat(0.05 + rng.unit() * 0.36)
                let dir: CGFloat = rng.unit() < 0.5 ? -1 : 1
                let travel = size.width * 0.38 * CGFloat(local)
                let head = CGPoint(x: x0 - dir * travel, y: y0 + travel * 0.36)
                let tail = CGPoint(x: head.x + dir * 64, y: head.y - 27)
                let alpha = Foundation.sin(.pi * local) * 0.78
                var path = Path()
                path.move(to: tail); path.addLine(to: head)
                ctx.stroke(path, with: .linearGradient(
                    Gradient(colors: [.clear, Color(hex: 0xEAF4FF).opacity(alpha)]),
                    startPoint: tail, endPoint: head), lineWidth: 1.25)
                softHalo(&ctx, x: head.x, y: head.y, r: 1.1,
                         color: .white.opacity(alpha))
            }
        }
    }

    private func previewHaze(W: CGFloat, H: CGFloat, t: Double,
                             tint: Color, y: Double) -> some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: skySeed &+ 0xA2_113)
            for i in 0..<3 {
                let baseX = 0.10 + rng.unit() * 0.80
                let drift = Foundation.sin(t * (0.010 + rng.unit() * 0.012) + Double(i) * 1.8)
                    * Double(size.width) * 0.05
                let breathe = 0.64 + 0.36 * Foundation.sin(t * (0.025 + rng.unit() * 0.018) + Double(i))
                softHalo(&ctx, x: CGFloat(baseX * Double(size.width) + drift),
                         y: CGFloat(y + (rng.unit() - 0.5) * 0.07) * size.height,
                         r: size.width * CGFloat(0.065 + rng.unit() * 0.035),
                         color: tint.opacity(0.12 * breathe))
            }
        }
    }

    private func lagoonAccent(W: CGFloat, H: CGFloat, t: Double) -> some View {
        ZStack {
            previewCloudWisps(W: W, H: H, t: t, tint: Color(hex: 0xEAFBF4))
            previewHaze(W: W, H: H, t: t, tint: Color(hex: 0x9BE8DA), y: 0.63)
            Canvas { ctx, size in
                var rng = SeededRNG(seed: skySeed &+ 0xF1_711)
                for i in 0..<26 {
                    let fx = rng.unit()
                    let fy = 0.66 + rng.unit() * 0.29
                    let depth = (fy - 0.66) / 0.29
                    let pulse = pow(0.5 + 0.5 * Foundation.sin(t * (0.22 + rng.unit() * 0.65)
                                                                  + Double(i) * 1.37), 2.1)
                    let x = fx * Double(size.width) + Foundation.sin(t * 0.045 + Double(i)) * 4
                    let y = fy * Double(size.height)
                    let width = 3 + depth * 11 + rng.unit() * 6
                    var line = Path()
                    line.move(to: CGPoint(x: x - width / 2, y: y))
                    line.addLine(to: CGPoint(x: x + width / 2, y: y))
                    ctx.stroke(line, with: .linearGradient(
                        Gradient(colors: [.clear,
                                          Color(hex: 0xD8FFF3).opacity(0.10 + pulse * 0.34),
                                          .clear]),
                        startPoint: CGPoint(x: x - width / 2, y: y),
                        endPoint: CGPoint(x: x + width / 2, y: y)),
                        lineWidth: CGFloat(0.6 + depth))
                }
                for i in 0..<12 {
                    let x = CGFloat(0.06 + rng.unit() * 0.88) * size.width
                    let y = CGFloat(0.16 + rng.unit() * 0.58) * size.height
                    let pulse = pow(0.5 + 0.5 * Foundation.sin(t * (0.24 + rng.unit() * 0.5) + Double(i)), 2.5)
                    softHalo(&ctx, x: x, y: y, r: CGFloat(1.0 + rng.unit() * 1.4),
                             color: Color(hex: 0xE2FFF4).opacity(0.20 * pulse))
                }
            }
        }
    }

    private func previewCloudWisps(W: CGFloat, H: CGFloat, t: Double,
                                   tint: Color) -> some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: skySeed &+ 0xC10D)
            for i in 0..<3 {
                let y = Double(size.height) * (0.12 + rng.unit() * 0.34)
                let cx = Double(size.width) * (0.16 + rng.unit() * 0.68)
                    + Foundation.sin(t * (0.008 + rng.unit() * 0.008) + Double(i)) * Double(size.width) * 0.06
                let breathe = 0.70 + 0.30 * Foundation.sin(t * 0.025 + Double(i) * 1.9)
                for k in 0..<6 {
                    let f = Double(k) / 5.0 - 0.5
                    softHalo(&ctx, x: CGFloat(cx + f * Double(size.width) * 0.28),
                             y: CGFloat(y + Foundation.sin(f * 3 + Double(i)) * 4),
                             r: size.width * CGFloat(0.035 + 0.018 * Foundation.cos(f * .pi)),
                             color: tint.opacity(0.075 * breathe))
                }
            }
        }
    }

    private func previewSnow(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: skySeed &+ 0x5A0F)
            let span = Double(size.height) + 30
            for i in 0..<44 {
                let fx = rng.unit(), fy = rng.unit(), depth = rng.unit()
                let speed = 8 + depth * 16
                let y = (fy * span + t * speed).truncatingRemainder(dividingBy: span) - 15
                let x = fx * Double(size.width) + Foundation.sin(t * (0.3 + rng.unit() * 0.6)
                                                                 + Double(i)) * (2 + depth * 7)
                softHalo(&ctx, x: CGFloat(x), y: CGFloat(y), r: CGFloat(0.55 + depth * 1.3),
                         color: .white.opacity(0.18 + depth * 0.40))
            }
        }
    }

    private func cityGlowAccent(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: skySeed &+ 0xC17A)
            let colors = [Color(hex: 0xF48DB8), Color(hex: 0x77D6EE),
                          Color(hex: 0xB39AF4), Color(hex: 0xFFD089)]
            for i in 0..<18 {
                let x = CGFloat(0.04 + rng.unit() * 0.92) * size.width
                let y = CGFloat(0.48 + rng.unit() * 0.36) * size.height
                let pulse = 0.35 + 0.65 * pow(0.5 + 0.5 * Foundation.sin(
                    t * (0.10 + rng.unit() * 0.28) + Double(i) * 1.7), 2)
                softHalo(&ctx, x: x, y: y, r: CGFloat(2.5 + rng.unit() * 6),
                         color: colors[i % colors.count].opacity(0.08 + pulse * 0.19))
            }
        }
    }

    private func cosmicAccent(W: CGFloat, H: CGFloat, t: Double,
                              tint: Color) -> some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: skySeed &+ 0xC05D)
            for i in 0..<42 {
                let baseX = rng.unit() * Double(size.width)
                let baseY = rng.unit() * Double(size.height) * 0.88
                let depth = rng.unit()
                let orbit = 2 + depth * 7
                let angle = t * (0.025 + rng.unit() * 0.055) + Double(i) * 2.17
                let x = baseX + Foundation.sin(angle) * orbit
                let y = baseY + Foundation.cos(angle * 0.83) * orbit * 0.6
                let pulse = 0.45 + 0.55 * Foundation.sin(t * (0.18 + rng.unit() * 0.34) + Double(i))
                softHalo(&ctx, x: CGFloat(x), y: CGFloat(y), r: CGFloat(0.55 + depth),
                         color: tint.opacity((0.07 + depth * 0.16) * max(0.12, pulse)))
            }
            for i in 0..<3 {
                let x = CGFloat(0.16 + rng.unit() * 0.68) * size.width
                let y = CGFloat(0.12 + rng.unit() * 0.50) * size.height
                let drift = Foundation.sin(t * 0.014 + Double(i) * 2.2) * size.width * 0.02
                let breathe = 0.65 + 0.35 * Foundation.sin(t * 0.03 + Double(i) * 1.9)
                softHalo(&ctx, x: x + drift, y: y, r: size.width * 0.10,
                         color: tint.opacity(0.08 * breathe))
            }
        }
    }

    /// A handful of big desert stars with wide, slowly-breathing halos.
    private func bigStarAccent(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: skySeed &+ 0xB165)
            for i in 0..<7 {
                let x = CGFloat(0.08 + rng.unit() * 0.84) * size.width
                let y = CGFloat(0.05 + rng.unit() * 0.4) * size.height
                let r = CGFloat(1.8 + rng.unit() * 2.2)
                // Unconditional draw keeps still and live layouts identical.
                let rate = 0.25 + rng.unit() * 0.5
                let tw = t == 0 ? 1.0
                    : 0.65 + 0.35 * Foundation.sin(t * rate + Double(i) * 2.1)
                softHalo(&ctx, x: x, y: y, r: r * 3, color: .white.opacity(0.9 * tw))
            }
        }
    }

    private func glowPool(W: CGFloat, H: CGFloat, t: Double) -> some View {
        let breathe = t == 0 ? 1.0 : 0.86 + 0.14 * Foundation.sin(t * 0.045 + 0.8)
        return RadialGradient(colors: [sky.glowColor.opacity(0.34 * breathe), .clear],
                              center: .center, startRadius: 4, endRadius: W * 0.62)
            .frame(width: W * 1.3, height: W * 1.3)
            .position(x: W * 0.5, y: H * 0.64)
    }

    /// The place far below — the Sky's landmark silhouette, layered twice for
    /// depth (reuses the Passport postcard silhouette art). These stay the
    /// darkest, nearest planes; the hazed distance behind them comes from
    /// `SkyDepthScenery`.
    /// One or two tiny travellers far away — ambient life, never a crowd.
    private func distantBalloons(W: CGFloat, H: CGFloat, t: Double) -> some View {
        let bobA = t == 0 ? 0.0 : Foundation.sin(t * 0.11) * 6
        let bobB = t == 0 ? 0.0 : Foundation.sin(t * 0.14 + 2.3) * 4
        let driftA = t == 0 ? 0.0 : Foundation.sin(t * 0.02) * 10
        return ZStack {
            MiniBalloonView(size: 20, showGlow: false)
                .opacity(0.5)
                .position(x: W * 0.2 + CGFloat(driftA), y: H * 0.36 + CGFloat(bobA))
            MiniBalloonView(size: 13, showGlow: false)
                .opacity(0.34)
                .position(x: W * 0.79 - CGFloat(driftA) * 0.6, y: H * 0.48 + CGFloat(bobB))
        }
    }

    private var previewStarDensity: Double {
        switch sky.id {
        case "sahara-night":     return 1.00
        case "fiji-lagoon":      return 0.07
        case "kyoto-lanterns":   return 0.38
        case "aurora-snowfield": return 0.82
        case "rainy-tokyo":      return 0.16
        case "swiss-alps":       return 0.42
        case "galaxy-drift", "deep-space": return 1.00
        default:                 return sky.stars
        }
    }

    private var artworkStarOpacity: Double {
        switch sky.id {
        case "sahara-night", "galaxy-drift", "deep-space": return 0.72
        case "aurora-snowfield": return 0.60
        case "swiss-alps", "kyoto-lanterns": return 0.48
        default: return 0.38
        }
    }

    private var skySeed: UInt64 {
        var h: UInt64 = 0x5EED
        for u in sky.id.unicodeScalars { h = (h &* 31) &+ UInt64(u.value) }
        return h
    }
}

/// A soft radial halo (preview-local drawing helper).
private func softHalo(_ ctx: inout GraphicsContext, x: CGFloat, y: CGFloat,
                      r: CGFloat, color: Color) {
    let g = Gradient(colors: [color, color.opacity(0)])
    ctx.fill(Path(ellipseIn: CGRect(x: x - r * 3, y: y - r * 3, width: r * 6, height: r * 6)),
             with: .radialGradient(g, center: CGPoint(x: x, y: y),
                                   startRadius: 0, endRadius: r * 3))
}

private func previewSmoothStep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
    guard edge1 > edge0 else { return x < edge0 ? 0 : 1 }
    let v = max(0, min(1, (x - edge0) / (edge1 - edge0)))
    return v * v * (3 - 2 * v)
}

/// A soft, wavy horizontal aurora band (preview-only; the flight has the real one).
private struct AuroraBandShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let steps = 24
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        for i in 0...steps {
            let f = Double(i) / Double(steps)
            let x = rect.minX + rect.width * CGFloat(f)
            let y = rect.midY + CGFloat(Foundation.sin(f * .pi * 2.2)) * rect.height * 0.22
            p.addLine(to: CGPoint(x: x, y: y))
        }
        for i in (0...steps).reversed() {
            let f = Double(i) / Double(steps)
            let x = rect.minX + rect.width * CGFloat(f)
            let y = rect.midY + CGFloat(Foundation.sin(f * .pi * 2.2 + 0.7)) * rect.height * 0.2 + rect.height * 0.36
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.closeSubpath()
        return p
    }
}
