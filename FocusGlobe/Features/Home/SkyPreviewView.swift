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
/// Fully procedural; a bundled preview asset still wins when present. Motion
/// is calm and cheap (a single low-rate TimelineView), and Reduce Motion
/// renders a perfectly still frame.
struct SkyPreviewView: View {
    let sky: FocusSky
    var animated: Bool = true

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            if animated {
                TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { ctx in
                    content(W: W, H: H, t: ctx.date.timeIntervalSinceReferenceDate)
                }
            } else {
                content(W: W, H: H, t: 0)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func content(W: CGFloat, H: CGFloat, t: Double) -> some View {
        let art = Self.resolvedArt(for: sky, landscape: W > H)
        return ZStack {
            background(W: W, H: H, t: t, art: art)
            if sky.stars > 0.01 { starField(W: W, H: H, t: t) }
            accent(W: W, H: H, t: t)
            glowPool(W: W, H: H, t: t)
            // Procedural depth belongs to procedural skies only — bundled art
            // already carries its own scenery.
            if art == nil { SkyDepthScenery(sky: sky, t: t, horizon: 0.84) }
            landmarkLayer(W: W, H: H)
            distantBalloons(W: W, H: H, t: t)
        }
        .frame(width: W, height: H)
        .clipped()
    }

    /// One bundle lookup per asset name for the app's lifetime — WITH misses
    /// cached, so the 12 fps timeline never re-searches the bundle for art
    /// that isn't there (every Sky is procedural today).
    private static var artCache: [String: UIImage?] = [:]
    private static func cachedImage(named name: String) -> UIImage? {
        if let hit = artCache[name] { return hit }
        let ui = UIImage(named: name)
        artCache[name] = ui
        return ui
    }
    /// Bundled Sky art when present: the shared naming convention first
    /// (Sky_<ID>_Background_Portrait/_Landscape), then the legacy field.
    private static func resolvedArt(for sky: FocusSky, landscape: Bool) -> UIImage? {
        cachedImage(named: sky.backgroundAssetName(landscape: landscape))
            ?? sky.previewImageName.flatMap { cachedImage(named: $0) }
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
            Image(uiImage: ui).resizable().scaledToFill()
                .frame(width: W, height: H).clipped()
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

    /// Deterministic star sprinkle, denser for cosmic skies — twinkling gently
    /// in place, with soft glints on the brightest few.
    private func starField(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: skySeed &+ 0x57AB)
            let count = Int(30 + sky.stars * 120)
            for i in 0..<count {
                let x = CGFloat(rng.unit()) * size.width
                let y = CGFloat(rng.unit()) * size.height * 0.72
                let r = CGFloat(0.5 + rng.unit() * 1.6)
                let u = rng.unit()
                let tw = t == 0 ? 1.0
                    : 0.6 + 0.4 * Foundation.sin(t * (0.35 + u * 1.1) + Double(i) * 1.37)
                let a = (0.18 + u * 0.6) * sky.stars * tw
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(a)))
                if u > 0.94 && sky.stars > 0.4 {
                    softHalo(&ctx, x: x, y: y, r: r * 3.2, color: .white.opacity(a * 0.35))
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
            let breathe = t == 0 ? 1.0 : 0.8 + 0.2 * Foundation.sin(t * 0.05 + 1.1)
            ZStack {
                Circle().fill(RadialGradient(colors: [sky.glowColor.opacity(0.4 * breathe), .clear],
                                             center: .center, startRadius: 1, endRadius: W * 0.3))
                    .frame(width: W * 0.6, height: W * 0.6)
                Circle().fill(LinearGradient(colors: [Color(hex: 0xAABDE6), Color(hex: 0x3A4A72)],
                                             startPoint: .top, endPoint: .bottom))
                    .frame(width: W * 0.22, height: W * 0.22)
            }
            .position(x: W * 0.26, y: H * 0.2 + CGFloat(t == 0 ? 0 : Foundation.sin(t * 0.05) * 5))
        case .lanterns:
            lanternAccent(W: W, H: H, t: t)
        case .rain:
            rainAccent(W: W, H: H, t: t)
        case .bigStars:
            bigStarAccent(W: W, H: H, t: t)
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

    /// Warm lantern lights, each pulsing on its own slow rhythm.
    private func lanternAccent(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: skySeed &+ 0x1A17)
            for i in 0..<9 {
                let x = CGFloat(0.1 + rng.unit() * 0.8) * size.width
                let y = CGFloat(0.16 + rng.unit() * 0.42) * size.height
                let r = CGFloat(2.5 + rng.unit() * 3.5)
                // Consume the rate draw UNCONDITIONALLY so the seeded layout is
                // byte-identical between the still (t == 0) and live frames.
                let rate = 0.3 + rng.unit() * 0.4
                let pulse = t == 0 ? 1.0
                    : 0.7 + 0.3 * Foundation.sin(t * rate + Double(i) * 1.9)
                let bob = t == 0 ? 0.0 : Foundation.sin(t * 0.12 + Double(i) * 1.3) * 4
                let warm = Color(hex: 0xFFC873)
                softHalo(&ctx, x: x, y: y + CGFloat(bob), r: r * 3,
                         color: warm.opacity(0.85 * pulse))
                ctx.fill(Path(ellipseIn: CGRect(x: x - r / 2, y: y + CGFloat(bob) - r / 2,
                                                width: r, height: r)),
                         with: .color(warm.opacity(0.95 * pulse)))
            }
        }
    }

    /// Soft rain drifting down through the preview — quiet, cool, alive.
    private func rainAccent(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: skySeed &+ 0x0A1D)
            let span = size.height * 0.8 + 30
            for _ in 0..<34 {
                let fx = rng.unit()
                let fy = rng.unit()
                let speed = 26.0 + rng.unit() * 22.0
                let x = CGFloat(fx) * size.width
                let y = CGFloat((fy * Double(span) + t * speed)
                    .truncatingRemainder(dividingBy: Double(span))) - 15
                let len = CGFloat(7 + rng.unit() * 9)
                var p = Path()
                p.move(to: CGPoint(x: x, y: y))
                p.addLine(to: CGPoint(x: x - len * 0.18, y: y + len))
                ctx.stroke(p, with: .color(Color(hex: 0xBFD0EC).opacity(0.16 + rng.unit() * 0.14)),
                           lineWidth: 1)
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
    private func landmarkLayer(W: CGFloat, H: CGFloat) -> some View {
        ZStack {
            LandmarkSilhouette(landmark: sky.landmark)
                .fill(Color.black.opacity(0.30))
                .frame(width: W * 1.1, height: H * 0.20)
                .position(x: W * 0.52, y: H * 0.86)
            LandmarkSilhouette(landmark: sky.landmark)
                .fill(Color.black.opacity(0.5))
                .frame(width: W * 1.2, height: H * 0.17)
                .position(x: W * 0.48, y: H * 0.93)
        }
    }

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
