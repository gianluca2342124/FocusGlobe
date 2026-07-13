import Foundation
import SwiftUI
import UIKit

/// The **per-Sky flight world** — one coherent place per session, but genuinely
/// alive and vertical.
///
/// The immersion comes from many **large** layers travelling **downward at
/// different speeds**, so the balloon reads as rising through a living sky:
///
///   • a continuous background (bundled art or a seamless gradient) — no bands
///   • big, soft atmospheric strata that undulate and scroll down (the "moving
///     layers" — translucent haze, never hard mountains or colour bands)
///   • a far detail field per Sky (ocean shimmer / city glow / silver mist /
///     cosmic nebula)
///   • a drifting, parallaxed starfield
///   • a large signature celestial (moon / planet / aurora) that barely moves
///     (it is far away — correct parallax)
///   • big organic cloud banks descending
///   • the Sky's signature life (birds / lanterns / islands / orbs)
///   • weather particles (snow / rain / lanterns) and cosmic events
///   • fast, soft foreground wisps rushing down (near parallax)
///   • a take-off ground plate that leaves once and never returns
///
/// All motion derives from the **pause-aware** flight clock, so the world only
/// travels while flying and freezes the instant it pauses. No unrelated Sky
/// changes, no mid-sky mountains, no hard colour bands, no cloud walls.
struct SkyFlightSceneView: View {
    let sky: FocusSky
    /// Pause-aware elapsed seconds — the single source of motion for the world.
    let elapsed: () -> Double
    var animated: Bool = true

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = max(1, geo.size.height)
            TimelineView(.animation(minimumInterval: animated ? 1.0 / 30.0 : 5.0)) { _ in
                let t = animated ? max(0, elapsed()) : 0
                ZStack {
                    deepWorld(W: W, H: H, t: t)
                    nearWorld(W: W, H: H, t: t)
                }
                .frame(width: W, height: H)
                .clipped()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: Layer groups (kept small so the ViewBuilder stays fast)

    /// Background → big moving strata → far detail → stars → far celestial.
    @ViewBuilder private func deepWorld(W: CGFloat, H: CGFloat, t: Double) -> some View {
        background(W: W, H: H)
        bigMovingLayer(W: W, H: H, t: t)
        farDetail(W: W, H: H, t: t)
        if sky.stars > 0.01 { starLayer(W: W, H: H, t: t) }
        heroCelestial(W: W, H: H, t: t)
    }

    /// Big clouds → signature life → weather → cosmic events → fast wisps → ground.
    @ViewBuilder private func nearWorld(W: CGFloat, H: CGFloat, t: Double) -> some View {
        if hasClouds { OrganicCloudLayer(seed: skySeed, tint: cloudTint, t: t) }
        signatureLife(W: W, H: H, t: t)
        weatherLayer(W: W, H: H, t: t)
        if isCosmic { cosmicLayer(W: W, H: H, t: t) }
        foregroundWisps(W: W, H: H, t: t)
        groundLayer(W: W, H: H)
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
        case "golden-hour", "paris-sunset", "fiji-lagoon", "moon-garden",
             "swiss-alps", "rainy-tokyo", "kyoto-lanterns": return true
        default: return false
        }
    }
    private var cloudTint: Color {
        switch sky.id {
        case "rainy-tokyo":                    return Color(hex: 0x9FB0D0)
        case "aurora-snowfield", "swiss-alps": return Color(hex: 0xD8E6F2)
        case "moon-garden":                    return Color(hex: 0xC9D2E6)
        case "fiji-lagoon":                    return Color(hex: 0xDCEFE8)
        default: return sky.isCosmicSky ? Color(hex: 0x9FB4DC) : Color(hex: 0xF2E6D4)
        }
    }
    /// Three soft strata tints drawn from the Sky's own palette (skip the very
    /// dark top stop) — so the big moving layers always belong to the Sky.
    private var bandTints: [Color] {
        let cols = sky.paletteColors
        guard cols.count >= 3 else { return [sky.glowColor, sky.glowColor, sky.glowColor] }
        return [cols[cols.count - 1], cols[cols.count - 2], cols[max(0, cols.count - 3)]]
    }

    // MARK: 1 — Stable background (art first, seamless gradient fallback)

    @ViewBuilder private func background(W: CGFloat, H: CGFloat) -> some View {
        let assetName = sky.backgroundAssetName(landscape: W > H)
        if let ui = UIImage(named: assetName) {
            Image(uiImage: ui).resizable().scaledToFill()
                .frame(width: W, height: H).clipped()
        } else {
            LinearGradient(colors: sky.paletteColors, startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [sky.glowColor.opacity(0.30), .clear],
                           center: UnitPoint(x: 0.5, y: 0.74),
                           startRadius: 4, endRadius: W * 0.85)
            LinearGradient(colors: [.clear, sky.glowColor.opacity(0.10)],
                           startPoint: UnitPoint(x: 0.5, y: 0.55), endPoint: .bottom)
        }
    }

    // MARK: 2 — Big moving layer (the immersion: strata OR cosmic nebula)

    @ViewBuilder private func bigMovingLayer(W: CGFloat, H: CGFloat, t: Double) -> some View {
        if isCosmic {
            nebulaField(W: W, H: H, t: t)
        } else {
            atmosphereBands(W: W, H: H, t: t)
        }
    }

    /// Large, soft atmospheric strata that undulate and scroll downward, wrapping
    /// seamlessly — the balloon rises past band after band. Each band fades in and
    /// out (peak in its middle) so there is never a hard edge or a mountain line.
    private func atmosphereBands(W: CGFloat, H: CGFloat, t: Double) -> some View {
        let tints = bandTints
        return Canvas { ctx, s in
            let n = tints.count
            let bandH = Double(s.height) * 0.62
            let span = Double(s.height) + bandH
            for i in 0..<n {
                let di = Double(i)
                let speed = 10.0 + di * 7.0                 // nearer strata travel faster
                let phase0 = (di + 0.35) / Double(n)
                var yTop = (phase0 * span + t * speed).truncatingRemainder(dividingBy: span)
                if yTop < 0 { yTop += span }
                yTop -= bandH
                drawBand(&ctx, s: s, yTop: yTop, height: bandH, tint: tints[i],
                         amp: Double(s.height) * (0.03 + di * 0.016),
                         waveLen: 340.0 - di * 44.0,
                         phase: t * (0.05 + di * 0.02) + di * 1.7,
                         alpha: 0.20 - di * 0.03)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawBand(_ ctx: inout GraphicsContext, s: CGSize, yTop: Double, height: Double,
                          tint: Color, amp: Double, waveLen: Double, phase: Double, alpha: Double) {
        let w = Double(s.width)
        var p = Path()
        p.move(to: CGPoint(x: 0, y: yTop + height))
        p.addLine(to: CGPoint(x: 0, y: yTop))
        var x = 0.0
        while x <= w {
            let y = yTop + Foundation.sin(x / waveLen + phase) * amp
            p.addLine(to: CGPoint(x: x, y: y))
            x += 26
        }
        p.addLine(to: CGPoint(x: w, y: yTop + height))
        p.closeSubpath()
        // Peaks in the middle, fades to nothing at the wavy top and the bottom —
        // reads as drifting haze, never a defined band or a ridge line.
        let g = Gradient(colors: [tint.opacity(0), tint.opacity(alpha), tint.opacity(alpha * 0.5), tint.opacity(0)])
        ctx.fill(p, with: .linearGradient(g, startPoint: CGPoint(x: 0, y: yTop),
                                          endPoint: CGPoint(x: 0, y: yTop + height)))
    }

    /// Big, colourful nebula clouds descending behind the stars (cosmic Skies).
    private func nebulaField(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0x4EB0)
            let cols = [Color(hex: 0x6E4AE8), Color(hex: 0x3A2E7E), Color(hex: 0x2AC8B0),
                        Color(hex: 0x8F7BE8), Color(hex: 0x4C6CE8)]
            let span = Double(s.height) + Double(s.width)
            for i in 0..<6 {
                let fx = rng.unit()
                let baseY = rng.unit()
                let speed = 5.0 + rng.unit() * 8.0
                let yv = descend(baseY * span, span: span, t: t, speed: speed) - Double(s.width) * 0.5
                let x = CGFloat(fx) * s.width
                let y = CGFloat(yv)
                let r = CGFloat(Double(min(s.width, s.height)) * (0.34 + rng.unit() * 0.3))
                let c = cols[i % cols.count]
                let g = Gradient(colors: [c.opacity(0.18), c.opacity(0.06), .clear])
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r * 0.7, width: r * 2, height: r * 1.4)),
                         with: .radialGradient(g, center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r))
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: 3 — Far detail per Sky

    @ViewBuilder private func farDetail(W: CGFloat, H: CGFloat, t: Double) -> some View {
        switch sky.id {
        case "fiji-lagoon":  oceanShimmer(W: W, H: H, t: t)
        case "rainy-tokyo":  cityNeonGlow(W: W, H: H, t: t)
        case "moon-garden":  silverMist(W: W, H: H, t: t)
        default:             EmptyView()
        }
    }

    private func oceanShimmer(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            let bandY = s.height * 0.78
            let g = Gradient(colors: [Color(hex: 0x4FB4B4).opacity(0), Color(hex: 0x4FB4B4).opacity(0.2)])
            ctx.fill(Path(CGRect(x: 0, y: bandY, width: s.width, height: s.height - bandY)),
                     with: .linearGradient(g, startPoint: CGPoint(x: 0, y: bandY),
                                           endPoint: CGPoint(x: 0, y: s.height)))
            var rng = SeededRNG(seed: skySeed &+ 0x0CEA)
            for _ in 0..<30 {
                let fx = rng.unit()
                let fy = 0.78 + rng.unit() * 0.2
                let tw = 0.5 + 0.5 * Foundation.sin(t * (0.5 + rng.unit() * 1.4) + fx * 6.0)
                let a = 0.08 + tw * 0.24
                let x = CGFloat(fx) * s.width
                let y = CGFloat(fy) * s.height
                let ww = CGFloat(10.0 + rng.unit() * 22.0)
                ctx.fill(Path(ellipseIn: CGRect(x: x - ww / 2, y: y - 1, width: ww, height: 2)),
                         with: .color(Color(hex: 0xBFE8D8).opacity(a)))
            }
        }
        .allowsHitTesting(false)
    }

    private func cityNeonGlow(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            let bandY = s.height * 0.70
            let g = Gradient(colors: [Color(hex: 0x2E3A60).opacity(0), Color(hex: 0x50548E).opacity(0.28)])
            ctx.fill(Path(CGRect(x: 0, y: bandY, width: s.width, height: s.height - bandY)),
                     with: .linearGradient(g, startPoint: CGPoint(x: 0, y: bandY),
                                           endPoint: CGPoint(x: 0, y: s.height)))
            var rng = SeededRNG(seed: skySeed &+ 0x0C17)
            let neon = [Color(hex: 0xE86A9E), Color(hex: 0x6AC8E8), Color(hex: 0xE8C86A), Color(hex: 0x8F7BE8)]
            for i in 0..<30 {
                let di = Double(i)
                let fx = rng.unit()
                let fy = 0.74 + rng.unit() * 0.24
                let pulse = 0.5 + 0.5 * Foundation.sin(t * (0.6 + rng.unit() * 1.2) + di)
                let a = 0.1 + pulse * 0.34
                let x = CGFloat(fx) * s.width
                let y = CGFloat(fy) * s.height
                let r = CGFloat(1.6 + rng.unit() * 2.4)
                softGlow(&ctx, x: x, y: y, r: r * 3.2, color: neon[i % neon.count].opacity(a))
            }
        }
        .allowsHitTesting(false)
    }

    private func silverMist(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            let span = Double(s.height) + 160
            for i in 0..<5 {
                let di = Double(i)
                let baseY = di / 5.0
                let yv = descend(baseY * span, span: span, t: t, speed: 6.0 + di * 2.4) - 80
                let cy = CGFloat(yv)
                let ww = s.width * CGFloat(0.8 + 0.12 * Foundation.sin(t * 0.1 + di))
                let g = Gradient(colors: [.clear, Color(hex: 0x8A98B4).opacity(0.12), .clear])
                ctx.fill(Path(ellipseIn: CGRect(x: s.width * 0.5 - ww / 2, y: cy - 26, width: ww, height: 52)),
                         with: .linearGradient(g, startPoint: CGPoint(x: s.width * 0.5 - ww / 2, y: cy),
                                               endPoint: CGPoint(x: s.width * 0.5 + ww / 2, y: cy)))
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: 4 — Stars (seeded, drifting downward with parallax + twinkle)

    private func starLayer(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0x57A2)
            let count = Int(50 + sky.stars * 170)
            let span = Double(s.height)
            for i in 0..<count {
                let u1 = rng.unit()
                let u2 = rng.unit()
                let u3 = rng.unit()
                let drift = t * (2.0 + u3 * 6.0)
                let y = CGFloat((u2 * span * 0.92 + drift).truncatingRemainder(dividingBy: span))
                let x = CGFloat(u1) * s.width
                let r = CGFloat(0.5 + u3 * 1.8)
                let tw = 0.55 + 0.45 * Foundation.sin(t * (0.5 + u3 * 1.6) + Double(i) * 1.3)
                let a = (0.16 + u3 * 0.55) * sky.stars * tw
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(a)))
                if u3 > 0.92 && sky.stars > 0.5 {
                    let g = Gradient(colors: [Color.white.opacity(a * 0.5), .clear])
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r * 3, y: y - r * 3, width: r * 6, height: r * 6)),
                             with: .radialGradient(g, center: CGPoint(x: x + r / 2, y: y + r / 2),
                                                   startRadius: 0, endRadius: r * 3))
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: 5 — Far celestial (large, barely moving — correct far parallax)

    @ViewBuilder private func heroCelestial(W: CGFloat, H: CGFloat, t: Double) -> some View {
        let bob = CGFloat(Foundation.sin(t * 0.05)) * H * 0.01
        let drift = CGFloat(Foundation.sin(t * 0.02)) * W * 0.015
        switch sky.accent {
        case .none:
            EmptyView()
        case .moon:
            detailedMoon(d: min(W * 0.52, 360))
                .position(x: W * 0.68 + drift, y: H * 0.24 + bob)
        case .aurora:
            auroraLayer(W: W, H: H, t: t)
        case .planet:
            ZStack {
                Circle().fill(RadialGradient(colors: [sky.glowColor.opacity(0.35), .clear],
                                             center: .center, startRadius: 2, endRadius: W * 0.34))
                    .frame(width: W * 0.68, height: W * 0.68)
                detailedPlanet(d: min(W * 0.32, 230))
            }
            .position(x: W * 0.28 + drift, y: H * 0.22 + bob)
        case .lanterns, .rain:
            EmptyView()
        case .bigStars:
            Canvas { ctx, s in
                var rng = SeededRNG(seed: skySeed &+ 0xB165)
                for _ in 0..<9 {
                    let x = CGFloat(0.08 + rng.unit() * 0.84) * s.width
                    let y = CGFloat(0.05 + rng.unit() * 0.42) * s.height
                    let r = CGFloat(2.0 + rng.unit() * 2.8)
                    let g = Gradient(colors: [Color.white.opacity(0.9), Color.white.opacity(0)])
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r * 3, y: y - r * 3, width: r * 6, height: r * 6)),
                             with: .radialGradient(g, center: CGPoint(x: x, y: y),
                                                   startRadius: 0, endRadius: r * 3))
                }
            }
        }
    }

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

    private func auroraLayer(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            let colors = [Color(hex: 0x54E0A8), Color(hex: 0x4FC9DD), Color(hex: 0x8F7BE8)]
            for band in 0..<3 {
                let baseY = s.height * (0.14 + CGFloat(band) * 0.14)
                let amp = s.height * 0.05
                let thick = s.height * 0.16
                let phase = t * 0.12 + Double(band) * 2.1
                let path = flightAuroraRibbon(width: s.width, baseY: baseY,
                                              amp: amp, thickness: thick, phase: phase)
                let c = colors[band]
                let g = Gradient(colors: [c.opacity(0), c.opacity(0.34), c.opacity(0)])
                ctx.fill(path, with: .linearGradient(
                    g, startPoint: CGPoint(x: 0, y: baseY - amp),
                    endPoint: CGPoint(x: 0, y: baseY + thick + amp)))
            }
        }
    }

    // MARK: 6 — Per-Sky signature life

    @ViewBuilder private func signatureLife(W: CGFloat, H: CGFloat, t: Double) -> some View {
        switch sky.id {
        case "golden-hour":
            ZStack { birdsFlock(W: W, H: H, t: t); distantBalloonSpeck(W: W, H: H, t: t) }
        case "paris-sunset":
            ZStack {
                birdsFlock(W: W, H: H, t: t)
                warmOrbs(W: W, H: H, t: t, tint: Color(hex: 0xF6C88A))
                distantBalloonSpeck(W: W, H: H, t: t)
            }
        case "fiji-lagoon":
            ZStack { islandsLow(W: W, H: H, t: t); distantBalloonSpeck(W: W, H: H, t: t) }
        case "kyoto-lanterns":
            warmOrbs(W: W, H: H, t: t, tint: Color(hex: 0xFFC873))
        default:
            EmptyView()
        }
    }

    private func birdsFlock(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0xB1D5)
            let span = Double(s.height) + 90
            for i in 0..<6 {
                let di = Double(i)
                let fx = rng.unit()
                let baseY = rng.unit() * 0.55
                let speed = 9.0 + rng.unit() * 8.0
                let yv = descend(baseY * span, span: span, t: t, speed: speed) - 45
                let driftX = Foundation.sin(t * 0.08 + di) * Double(s.width) * 0.05
                let flap = 0.5 + 0.5 * Foundation.sin(t * 3.4 + di * 1.7)
                let wing = 3.0 + flap * 3.6
                let a = 0.22 + rng.unit() * 0.16
                let x = CGFloat(fx * Double(s.width) + driftX)
                let y = CGFloat(yv)
                let ww = CGFloat(wing)
                var p = Path()
                p.move(to: CGPoint(x: x - ww, y: y + ww * 0.5))
                p.addLine(to: CGPoint(x: x, y: y))
                p.addLine(to: CGPoint(x: x + ww, y: y + ww * 0.5))
                ctx.stroke(p, with: .color(Color(hex: 0x2A2438).opacity(a)), lineWidth: 1.6)
            }
        }
        .allowsHitTesting(false)
    }

    private func islandsLow(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0x15A0)
            let span = Double(s.height) * 0.5
            let base = Double(s.height) * 0.58
            for _ in 0..<4 {
                let fx = 0.12 + rng.unit() * 0.76
                let speed = 5.0 + rng.unit() * 5.0
                let phase = rng.unit()
                let yy = descend(phase * span, span: span, t: t, speed: speed)
                let y = CGFloat(base + yy - span * 0.1)
                let x = CGFloat(fx) * s.width
                let ww = CGFloat(Double(min(s.width, s.height)) * (0.16 + rng.unit() * 0.12))
                let hh = ww * 0.32
                let a = 0.16 + rng.unit() * 0.1
                ctx.fill(Path(ellipseIn: CGRect(x: x - ww / 2, y: y - hh / 2, width: ww, height: hh)),
                         with: .color(Color(hex: 0x14524E).opacity(a)))
                softGlow(&ctx, x: x, y: y, r: ww * 0.6, color: Color(hex: 0x4FB4B4).opacity(a * 0.4))
            }
        }
        .allowsHitTesting(false)
    }

    private func warmOrbs(W: CGFloat, H: CGFloat, t: Double, tint: Color) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0x0A25)
            let span = Double(s.height) + 80
            for i in 0..<18 {
                let di = Double(i)
                let fx = rng.unit()
                let baseY = 0.45 + rng.unit() * 0.55
                let speed = 6.0 + rng.unit() * 7.0
                var yy = (baseY * span - t * speed).truncatingRemainder(dividingBy: span)
                if yy < 0 { yy += span }
                let y = CGFloat(yy - 40)
                let pulse = 0.5 + 0.5 * Foundation.sin(t * (0.5 + rng.unit()) + di)
                let a = (0.14 + pulse * 0.3) * 0.9
                let x = CGFloat(fx) * s.width
                let r = CGFloat(1.8 + rng.unit() * 2.4)
                softGlow(&ctx, x: x, y: y, r: r * 3.6, color: tint.opacity(a))
                ctx.fill(Path(ellipseIn: CGRect(x: x - r / 2, y: y - r * 0.7, width: r, height: r * 1.4)),
                         with: .color(tint.opacity(a * 1.1)))
            }
        }
        .allowsHitTesting(false)
    }

    private func distantBalloonSpeck(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0xBA11)
            let baseX = 0.2 + rng.unit() * 0.6
            let baseY = 0.22 + rng.unit() * 0.4
            let drift = Foundation.sin(t * 0.05 + rng.unit() * 6) * 0.02
            let x = CGFloat((baseX + drift) * Double(s.width))
            let y = CGFloat(baseY * Double(s.height) + Foundation.sin(t * 0.35) * 3)
            let hh = CGFloat(11.0 + rng.unit() * 6.0)
            let a = 0.26 + rng.unit() * 0.16
            let env = CGRect(x: x - hh * 0.36, y: y - hh, width: hh * 0.72, height: hh * 0.8)
            ctx.fill(Path(ellipseIn: env), with: .color(Color(hex: 0xF4EFE4).opacity(a)))
            let basket = CGRect(x: x - hh * 0.09, y: y - hh * 0.08, width: hh * 0.18, height: hh * 0.14)
            ctx.fill(Path(basket), with: .color(Color(hex: 0x6B4A2C).opacity(a)))
        }
        .allowsHitTesting(false)
    }

    // MARK: 7 — Weather (seamless loops)

    @ViewBuilder private func weatherLayer(W: CGFloat, H: CGFloat, t: Double) -> some View {
        switch sky.flightParticles {
        case .none:
            EmptyView()
        case .snow:
            Canvas { ctx, s in
                var rng = SeededRNG(seed: skySeed &+ 0x5A0F)
                let span = Double(s.height) + 40
                for i in 0..<52 {
                    let di = Double(i)
                    let fx = rng.unit(); let fy = rng.unit()
                    let speed = 18.0 + rng.unit() * 30.0
                    let y = (fy * span + t * speed).truncatingRemainder(dividingBy: span) - 20
                    let sway = Foundation.sin(t * (0.5 + rng.unit()) + di) * (5 + rng.unit() * 9)
                    let x = fx * Double(s.width) + sway
                    let r = 0.9 + rng.unit() * 2.0
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
                for _ in 0..<52 {
                    let fx = rng.unit(); let fy = rng.unit()
                    let speed = 150.0 + rng.unit() * 110.0
                    let y = (fy * span + t * speed).truncatingRemainder(dividingBy: span) - 20
                    let x = fx * Double(s.width) - y * 0.05
                    let len = 9.0 + rng.unit() * 10.0
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x - len * 0.13, y: y + len))
                    ctx.stroke(p, with: .color(Color(hex: 0xBFD0EC).opacity(0.1 + rng.unit() * 0.14)),
                               lineWidth: 1)
                }
            }
        case .lanterns:
            Canvas { ctx, s in
                var rng = SeededRNG(seed: skySeed &+ 0x1A27)
                let span = Double(s.height) + 90
                for i in 0..<12 {
                    let di = Double(i)
                    let fx = rng.unit(); let fy = rng.unit()
                    let speed = 8.0 + rng.unit() * 8.0
                    var y = (fy * span - t * speed).truncatingRemainder(dividingBy: span)
                    if y < 0 { y += span }
                    y -= 45
                    let sway = Foundation.sin(t * (0.28 + rng.unit() * 0.3) + di) * (8 + rng.unit() * 9)
                    let x = fx * Double(s.width) + sway
                    let r = 2.6 + rng.unit() * 3.0
                    let warm = Color(hex: 0xFFC873)
                    let g = Gradient(colors: [warm.opacity(0.72), warm.opacity(0)])
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r * 3.6, y: y - r * 3.6, width: r * 7.2, height: r * 7.2)),
                             with: .radialGradient(g, center: CGPoint(x: x, y: y),
                                                   startRadius: 0, endRadius: CGFloat(r * 3.6)))
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r / 2, y: y - r * 0.75, width: r, height: r * 1.5)),
                             with: .color(warm.opacity(0.92)))
                }
            }
        }
    }

    // MARK: 8 — Cosmic events (meteors + shooting stars)

    @ViewBuilder private func cosmicLayer(W: CGFloat, H: CGFloat, t: Double) -> some View {
        ZStack {
            meteorLayer(W: W, H: H, t: t)
            shootingStar(W: W, H: H, t: t)
        }
    }

    private func meteorLayer(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            let period = 21.0
            let cycle = (t / period).rounded(.down)
            let phase = t / period - cycle
            guard phase < 0.22 else { return }
            let local = phase / 0.22
            var rng = SeededRNG(seed: skySeed &+ UInt64(bitPattern: Int64(cycle)) &* 131)
            let x0 = Double(s.width) * (0.15 + rng.unit() * 0.7)
            let y0 = Double(s.height) * (0.05 + rng.unit() * 0.3)
            let dir: Double = rng.unit() < 0.5 ? -1 : 1
            let travel = Double(s.width) * 0.5 * local
            let hx = x0 + dir * travel
            let hy = y0 + travel * 0.5
            let a = Foundation.sin(.pi * local) * 0.85
            var p = Path()
            p.move(to: CGPoint(x: hx - dir * 100, y: hy - 48))
            p.addLine(to: CGPoint(x: hx, y: hy))
            let g = Gradient(colors: [Color.white.opacity(0), Color(hex: 0xE6F2FF).opacity(a)])
            ctx.stroke(p, with: .linearGradient(g, startPoint: CGPoint(x: hx - dir * 100, y: hy - 48),
                                                endPoint: CGPoint(x: hx, y: hy)), lineWidth: 1.8)
            ctx.fill(Path(ellipseIn: CGRect(x: hx - 2, y: hy - 2, width: 4, height: 4)),
                     with: .color(.white.opacity(a)))
        }
    }

    private func shootingStar(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            let period = 12.0
            let cycle = (t / period).rounded(.down)
            let phase = t / period - cycle
            guard phase < 0.24 else { return }
            let local = phase / 0.24
            var rng = SeededRNG(seed: skySeed &+ UInt64(bitPattern: Int64(cycle)) &* 131 &+ 7)
            let x0 = s.width * CGFloat(0.12 + rng.unit() * 0.76)
            let y0 = s.height * CGFloat(0.05 + rng.unit() * 0.5)
            let dir: CGFloat = rng.unit() < 0.5 ? -1 : 1
            let travel = s.width * 0.55 * CGFloat(local)
            let head = CGPoint(x: x0 - dir * travel, y: y0 + travel * 0.5)
            let tail = CGPoint(x: head.x + dir * 100, y: head.y - 48)
            let a = Foundation.sin(.pi * local) * 0.9
            var p = Path()
            p.move(to: tail)
            p.addLine(to: head)
            let g = Gradient(colors: [Color.white.opacity(0), Color(hex: 0xE6F2FF).opacity(a)])
            ctx.stroke(p, with: .linearGradient(g, startPoint: tail, endPoint: head), lineWidth: 1.8)
            ctx.fill(Path(ellipseIn: CGRect(x: head.x - 2, y: head.y - 2, width: 4, height: 4)),
                     with: .color(.white.opacity(a)))
        }
    }

    // MARK: 9 — Fast foreground wisps (near parallax)

    /// A few large, soft, translucent wisps rushing downward close to the pilot —
    /// the fastest layer, so the near sky clearly streams past as the balloon rises.
    private func foregroundWisps(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0x3F09)
            let span = Double(s.height) + Double(s.height) * 0.5
            let tint = sky.isCosmicSky ? Color(hex: 0x9FB4DC) : Color(hex: 0xF4ECDC)
            for i in 0..<3 {
                let di = Double(i)
                let fx = rng.unit()
                let speed = 60.0 + rng.unit() * 34.0
                let phase = rng.unit()
                var y = (phase * span + t * speed).truncatingRemainder(dividingBy: span)
                if y < 0 { y += span }
                y -= Double(s.height) * 0.25
                let cx = fx * Double(s.width) + Foundation.sin(t * 0.2 + di) * Double(s.width) * 0.05
                let ww = Double(s.width) * (0.6 + rng.unit() * 0.5)
                let hh = Double(s.height) * 0.09
                let g = Gradient(colors: [.clear, tint.opacity(0.1), .clear])
                ctx.fill(Path(ellipseIn: CGRect(x: cx - ww / 2, y: y - hh / 2, width: ww, height: hh)),
                         with: .linearGradient(g, startPoint: CGPoint(x: cx - ww / 2, y: y),
                                               endPoint: CGPoint(x: cx + ww / 2, y: y)))
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: 10 — Take-off ground (appears once, falls away, never returns)

    @ViewBuilder private func groundLayer(W: CGFloat, H: CGFloat) -> some View {
        let e = max(0, elapsed())
        if e < 11 {
            let depart = CGFloat(min(1, max(0, (e - 2.0) / 9.0)))
            let eased = depart * depart * (3 - 2 * depart)
            Group {
                if let ui = UIImage(named: sky.groundAssetName) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .frame(width: W, height: H * 0.42, alignment: .top).clipped()
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

// MARK: - Shared drawing helpers

private func softGlow(_ ctx: inout GraphicsContext, x: CGFloat, y: CGFloat, r: CGFloat, color: Color) {
    let g = Gradient(colors: [color, color.opacity(0)])
    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
             with: .radialGradient(g, center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r))
}

/// Downward-scrolling wrap: advances by `t * speed`, staying within 0 up to span.
private func descend(_ base: Double, span: Double, t: Double, speed: Double) -> Double {
    var y = (base + t * speed).truncatingRemainder(dividingBy: span)
    if y < 0 { y += span }
    return y
}

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

// MARK: - Organic clouds (big irregular masses descending by depth = ascent)

/// Big organic cloud banks crossing the Sky at several depths, descending so the
/// balloon reads as rising past them. Each cloud is an irregular multi-lobe mass
/// — never a row of circles, never a wall, never a seam-hider.
struct OrganicCloudLayer: View {
    let seed: UInt64
    let tint: Color
    let t: Double

    var body: some View {
        Canvas { ctx, s in
            drawBand(&ctx, s: s, salt: 1, scale: 0.17, speed: 16.0, alpha: 0.12, count: 3)
            drawBand(&ctx, s: s, salt: 2, scale: 0.26, speed: 27.0, alpha: 0.16, count: 3)
            drawBand(&ctx, s: s, salt: 3, scale: 0.36, speed: 42.0, alpha: 0.19, count: 2)
        }
        .allowsHitTesting(false)
    }

    private func drawBand(_ ctx: inout GraphicsContext, s: CGSize, salt: UInt64,
                          scale: Double, speed: Double, alpha: Double, count: Int) {
        var rng = SeededRNG(seed: seed &+ salt &* 0x9E37)
        let ref = Double(min(s.width, s.height))
        let margin = ref * scale * 2.8
        let span = Double(s.height) + margin * 2
        for c in 0..<count {
            let dc = Double(c)
            let phase = rng.unit()
            let cx0 = rng.unit()
            let sway = Foundation.sin(t * 0.05 + phase * 6.28) * ref * scale * 0.5
            let cx = cx0 * Double(s.width) + sway
            var cy = (phase * span + t * speed + dc * span / Double(count)).truncatingRemainder(dividingBy: span)
            if cy < 0 { cy += span }
            cy -= margin
            let halfW = ref * scale * (0.85 + rng.unit() * 0.5)
            drawCloudMass(&ctx, cx: cx, cy: cy, halfW: halfW, alpha: alpha, rng: &rng)
        }
    }

    private func drawCloudMass(_ ctx: inout GraphicsContext, cx: Double, cy: Double,
                               halfW: Double, alpha: Double, rng: inout SeededRNG) {
        let lobes = 9 + Int(rng.unit() * 4.0)
        let baseY = cy + halfW * 0.14
        for l in 0..<lobes {
            let u = lobes <= 1 ? 0.5 : Double(l) / Double(lobes - 1)
            let bell = Foundation.sin(u * Double.pi)
            let jx = (rng.unit() - 0.5) * 0.5
            let jy = (rng.unit() - 0.5) * 0.3
            let lx = cx + (u - 0.5 + jx) * halfW * 2.3
            let ly = baseY - bell * halfW * (0.34 + rng.unit() * 0.42) + jy * halfW * 0.3
            let lr = halfW * (0.22 + 0.46 * bell) * (0.7 + rng.unit() * 0.7)
            let la = alpha * (0.5 + bell * 0.5) * (0.7 + rng.unit() * 0.3)
            let g = Gradient(colors: [tint.opacity(la), tint.opacity(la * 0.4), tint.opacity(0)])
            let ww = lr * 2.6
            let hh = lr * 1.6
            let rect = CGRect(x: lx - ww / 2, y: ly - hh / 2, width: ww, height: hh)
            ctx.fill(Path(ellipseIn: rect),
                     with: .radialGradient(g, center: CGPoint(x: lx, y: ly),
                                           startRadius: 0, endRadius: CGFloat(max(ww, hh) / 2)))
        }
    }
}
