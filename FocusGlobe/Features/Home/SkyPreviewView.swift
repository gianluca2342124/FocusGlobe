import Foundation
import SwiftUI
import UIKit

/// A full-screen, procedural preview of one **Sky** — the paging background of
/// the Home Sky selector. Fully vector (palette gradient, glow, stars, an
/// optional signature accent, a landmark silhouette far below, and one or two
/// tiny distant balloons), so no Sky depends on a bundled image. If a preview
/// asset (`sky.previewImageName`) is ever added it is drawn underneath the
/// accents automatically.
struct SkyPreviewView: View {
    let sky: FocusSky
    var animated: Bool = true

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            ZStack {
                background(W: W, H: H)
                if sky.stars > 0.01 { starField(W: W, H: H) }
                accent(W: W, H: H)
                glowPool(W: W, H: H)
                landmarkLayer(W: W, H: H)
                distantBalloons(W: W, H: H)
            }
            .frame(width: W, height: H)
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: Layers

    @ViewBuilder private func background(W: CGFloat, H: CGFloat) -> some View {
        LinearGradient(colors: sky.paletteColors, startPoint: .top, endPoint: .bottom)
        if let asset = sky.previewImageName, UIImage(named: asset) != nil {
            Image(asset).resizable().scaledToFill()
                .frame(width: W, height: H).clipped()
        }
    }

    /// Deterministic star sprinkle, denser for cosmic skies. Static (the Home
    /// mood is a calm postcard; the flight is where the sky truly lives).
    private func starField(W: CGFloat, H: CGFloat) -> some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: skySeed &+ 0x57AB)
            let count = Int(30 + sky.stars * 120)
            for _ in 0..<count {
                let x = CGFloat(rng.unit()) * size.width
                let y = CGFloat(rng.unit()) * size.height * 0.72
                let r = CGFloat(0.5 + rng.unit() * 1.6)
                let a = (0.18 + rng.unit() * 0.6) * sky.stars
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(a)))
            }
        }
    }

    /// The Sky's signature accent — one tasteful hero element, never clutter.
    @ViewBuilder private func accent(W: CGFloat, H: CGFloat) -> some View {
        switch sky.accent {
        case .none:
            EmptyView()
        case .moon:
            ZStack {
                Circle().fill(RadialGradient(colors: [Color(hex: 0xF5F7FB).opacity(0.5), .clear],
                                             center: .center, startRadius: 2, endRadius: W * 0.42))
                    .frame(width: W * 0.84, height: W * 0.84)
                Circle().fill(LinearGradient(colors: [Color(hex: 0xFCFDFF), Color(hex: 0xC2CCE2)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: W * 0.42, height: W * 0.42)
                    .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
            }
            .position(x: W * 0.68, y: H * 0.24)
        case .aurora:
            AuroraBandShape()
                .fill(LinearGradient(colors: [Color(hex: 0x54E0A8).opacity(0),
                                              Color(hex: 0x54E0A8).opacity(0.4),
                                              Color(hex: 0x8F7BE8).opacity(0.24),
                                              Color(hex: 0x54E0A8).opacity(0)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: W * 1.2, height: H * 0.3)
                .position(x: W * 0.5, y: H * 0.26)
                .blur(radius: 8)
        case .planet:
            ZStack {
                Circle().fill(RadialGradient(colors: [sky.glowColor.opacity(0.4), .clear],
                                             center: .center, startRadius: 1, endRadius: W * 0.3))
                    .frame(width: W * 0.6, height: W * 0.6)
                Circle().fill(LinearGradient(colors: [Color(hex: 0xAABDE6), Color(hex: 0x3A4A72)],
                                             startPoint: .top, endPoint: .bottom))
                    .frame(width: W * 0.22, height: W * 0.22)
            }
            .position(x: W * 0.26, y: H * 0.2)
        case .lanterns:
            Canvas { ctx, size in
                var rng = SeededRNG(seed: skySeed &+ 0x1A17)
                for _ in 0..<9 {
                    let x = CGFloat(0.1 + rng.unit() * 0.8) * size.width
                    let y = CGFloat(0.16 + rng.unit() * 0.42) * size.height
                    let r = CGFloat(2.5 + rng.unit() * 3.5)
                    let warm = Color(hex: 0xFFC873)
                    let g = Gradient(colors: [warm.opacity(0.85), warm.opacity(0)])
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r * 3, y: y - r * 3, width: r * 6, height: r * 6)),
                             with: .radialGradient(g, center: CGPoint(x: x, y: y),
                                                   startRadius: 0, endRadius: r * 3))
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r / 2, y: y - r / 2, width: r, height: r)),
                             with: .color(warm.opacity(0.95)))
                }
            }
        case .rain:
            Canvas { ctx, size in
                var rng = SeededRNG(seed: skySeed &+ 0x0A1D)
                for _ in 0..<34 {
                    let x = CGFloat(rng.unit()) * size.width
                    let y = CGFloat(rng.unit()) * size.height * 0.8
                    let len = CGFloat(7 + rng.unit() * 9)
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x - len * 0.18, y: y + len))
                    ctx.stroke(p, with: .color(Color(hex: 0xBFD0EC).opacity(0.16 + rng.unit() * 0.14)),
                               lineWidth: 1)
                }
            }
        case .bigStars:
            Canvas { ctx, size in
                var rng = SeededRNG(seed: skySeed &+ 0xB165)
                for _ in 0..<7 {
                    let x = CGFloat(0.08 + rng.unit() * 0.84) * size.width
                    let y = CGFloat(0.05 + rng.unit() * 0.4) * size.height
                    let r = CGFloat(1.8 + rng.unit() * 2.2)
                    let g = Gradient(colors: [Color.white.opacity(0.9), Color.white.opacity(0)])
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r * 3, y: y - r * 3, width: r * 6, height: r * 6)),
                             with: .radialGradient(g, center: CGPoint(x: x, y: y),
                                                   startRadius: 0, endRadius: r * 3))
                }
            }
        }
    }

    private func glowPool(W: CGFloat, H: CGFloat) -> some View {
        RadialGradient(colors: [sky.glowColor.opacity(0.34), .clear],
                       center: .center, startRadius: 4, endRadius: W * 0.62)
            .frame(width: W * 1.3, height: W * 1.3)
            .position(x: W * 0.5, y: H * 0.64)
    }

    /// The place far below — the Sky's landmark silhouette, layered twice for
    /// depth (reuses the Passport postcard silhouette art).
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
    private func distantBalloons(W: CGFloat, H: CGFloat) -> some View {
        ZStack {
            MiniBalloonView(size: 20, showGlow: false)
                .opacity(0.5)
                .position(x: W * 0.2, y: H * 0.36)
            MiniBalloonView(size: 13, showGlow: false)
                .opacity(0.34)
                .position(x: W * 0.79, y: H * 0.48)
        }
    }

    private var skySeed: UInt64 {
        var h: UInt64 = 0x5EED
        for u in sky.id.unicodeScalars { h = (h &* 31) &+ UInt64(u.value) }
        return h
    }
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
