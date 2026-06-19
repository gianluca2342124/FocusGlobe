import SwiftUI
import UIKit

// MARK: - Brand assets

/// Resolves bundled brand art (see SETUP.md):
///   • `BalloonFront` imageset → ships a generated front-view balloon so the
///     hero is a real raster asset. Replace `BalloonFront.png` with the
///     official render (same filename) anytime.
///   • `BrandLogo` → optional. The wordmark renders crisply in code by default;
///     add an image named "BrandLogo" to the asset catalog to override it.
///
/// Anything missing falls back to crafted vector art, so the app always looks
/// premium with zero external files.
enum BrandAssets {
    static let balloonFrontName = "BalloonFront"
    static let brandLogoName = "BrandLogo"

    static var hasBalloonFront: Bool { UIImage(named: balloonFrontName) != nil }
    static var hasBrandLogo: Bool { UIImage(named: brandLogoName) != nil }
}

// MARK: - Burner glow (premium micro-detail)

/// A tiny, elegant "burner active" glow that sits under the balloon's mouth.
/// Soft, warm and gently pulsing — it makes the balloon feel quietly *on*.
/// No cartoon flame, smoke or sparks. Reusable across balloon skins.
struct BurnerGlow: View {
    var diameter: CGFloat
    var animated: Bool = true
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0xFFC861).opacity(0.85),
                                 Color(hex: 0xFF8A2A).opacity(0.45),
                                 .clear],
                        center: .center, startRadius: 0, endRadius: diameter * 0.5
                    )
                )
                .blur(radius: diameter * 0.10)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0xFFE9B8).opacity(0.95), .clear],
                        center: .center, startRadius: 0, endRadius: diameter * 0.26
                    )
                )
                .frame(width: diameter * 0.5, height: diameter * 0.5)
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(pulse ? 1.07 : 0.9)
        .opacity(pulse ? 1.0 : 0.78)
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Envelope shape

/// The balloon envelope — a full, rounded teardrop that tapers to a small flat
/// mouth (not a sharp point), matching the front-view brand balloon.
struct BalloonEnvelope: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let cx = rect.midX
        let mouth = w * 0.13 // half-width of the bottom opening

        p.move(to: CGPoint(x: cx - mouth, y: rect.maxY))
        p.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + h * 0.44),
            control1: CGPoint(x: cx - mouth - w * 0.06, y: rect.maxY - h * 0.05),
            control2: CGPoint(x: rect.minX, y: rect.minY + h * 0.80)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.minY + h * 0.12),
            control2: CGPoint(x: cx - w * 0.36, y: rect.minY)
        )
        p.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.44),
            control1: CGPoint(x: cx + w * 0.36, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.minY + h * 0.12)
        )
        p.addCurve(
            to: CGPoint(x: cx + mouth, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.minY + h * 0.80),
            control2: CGPoint(x: cx + mouth + w * 0.06, y: rect.maxY - h * 0.05)
        )
        p.closeSubpath()
        return p
    }
}

/// Subtle vertical panel seams (gores) that read as premium fabric, not noise.
private struct BalloonSeams: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let cx = rect.midX
        let top = rect.minY + h * 0.04
        let bottom = rect.maxY - h * 0.02
        for frac in [-0.62, -0.32, 0.0, 0.32, 0.62] {
            let topX = cx + CGFloat(frac) * w * 0.16
            let midX = cx + CGFloat(frac) * w * 0.5
            p.move(to: CGPoint(x: topX, y: top))
            p.addQuadCurve(to: CGPoint(x: cx + CGFloat(frac) * w * 0.13, y: bottom),
                           control: CGPoint(x: midX, y: rect.minY + h * 0.5))
        }
        return p
    }
}

private struct BalloonCords: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.30, y: r.maxY))
        p.move(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.70, y: r.maxY))
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.42, y: r.maxY))
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.58, y: r.maxY))
        return p
    }
}

// MARK: - Vector balloon

/// The default FocusGlobe vehicle, drawn entirely in code: a premium, minimal,
/// soft-white paneled balloon with a small skirt, ropes, a tan basket and an
/// optional warm burner glow. Original art that scales crisply and themes via
/// `glow`. Used as-is in the UI and rasterised for the map marker.
///
/// `size` is the envelope **width**; the full mark (incl. basket) is taller.
struct BalloonMark: View {
    var size: CGFloat = 64
    var glow: Color = .white
    var showGlow: Bool = false
    /// Shows the warm burner glow at the mouth.
    var showBurner: Bool = false
    /// Animate the burner (off when rasterised for a static map marker).
    var burnerAnimated: Bool = true

    private var envW: CGFloat { size }
    private var envH: CGFloat { size * 1.12 }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                envelope
                    .frame(width: envW, height: envH)

                BalloonCords()
                    .stroke(Color(hex: 0x9AA3B5).opacity(0.9),
                            style: StrokeStyle(lineWidth: max(0.8, size * 0.016), lineCap: .round))
                    .frame(width: envW * 0.5, height: size * 0.16)

                basket
            }

            if showBurner {
                BurnerGlow(diameter: size * 0.6, animated: burnerAnimated)
                    .offset(y: envH - size * 0.16)
            }
        }
        .shadow(color: .black.opacity(0.16), radius: size * 0.07, x: 0, y: size * 0.05)
        .background(ambientGlow)
    }

    // The envelope + seams + highlight + skirt.
    private var envelope: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                BalloonEnvelope()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0xFFFFFF), Color(hex: 0xF1F3F8), Color(hex: 0xDCE2EC)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                // Soft upper-left highlight.
                Ellipse()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: envW * 0.4, height: envH * 0.3)
                    .offset(x: -envW * 0.14, y: -envH * 0.18)
                    .blur(radius: envW * 0.08)
                // Gentle right-edge shading for volume.
                BalloonEnvelope()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color(hex: 0xC4CCDA).opacity(0.35)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                // Subtle panel seams.
                BalloonSeams()
                    .stroke(Color(hex: 0xB7C0D0).opacity(0.5), lineWidth: max(0.4, size * 0.006))
            }
            .compositingGroup()
            .clipShape(BalloonEnvelope())
            .overlay(
                BalloonEnvelope()
                    .stroke(Color.black.opacity(0.05), lineWidth: max(0.5, size * 0.006))
            )

            // Skirt / mouth band.
            RoundedRectangle(cornerRadius: size * 0.03, style: .continuous)
                .fill(
                    LinearGradient(colors: [Color(hex: 0xEDEFF4), Color(hex: 0xD8DDE6)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(width: envW * 0.3, height: size * 0.06)
                .offset(y: size * 0.03)
        }
    }

    private var basket: some View {
        RoundedRectangle(cornerRadius: size * 0.045, style: .continuous)
            .fill(
                LinearGradient(colors: [Color(hex: 0xC79A6A), Color(hex: 0x8A6038)],
                               startPoint: .top, endPoint: .bottom)
            )
            .frame(width: envW * 0.30, height: size * 0.17)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.045, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
            )
    }

    @ViewBuilder private var ambientGlow: some View {
        if showGlow {
            Circle()
                .fill(
                    RadialGradient(colors: [glow.opacity(0.5), glow.opacity(0)],
                                   center: .center, startRadius: 0, endRadius: size * 0.8)
                )
                .frame(width: size * 1.8, height: size * 1.8)
                .blur(radius: size * 0.12)
                .offset(y: -size * 0.12)
        }
    }
}

// MARK: - Brand balloon view (asset-preferring)

/// The balloon for hero moments. Prefers the bundled `BalloonFront` PNG when
/// present; otherwise renders the crafted `BalloonMark`. An optional animated
/// burner glow adds life on top of either.
struct BalloonView: View {
    /// Overall visual height of the balloon.
    var height: CGFloat = 160
    var showBurner: Bool = true
    var showGlow: Bool = false
    var glow: Color = Color(hex: 0xFFB23E)
    var burnerAnimated: Bool = true

    var body: some View {
        if BrandAssets.hasBalloonFront {
            Image(BrandAssets.balloonFrontName)
                .resizable()
                .scaledToFit()
                .frame(height: height)
                .overlay(alignment: .bottom) {
                    if showBurner {
                        // A gentle live pulse aligned to the PNG's burner mouth.
                        BurnerGlow(diameter: height * 0.26, animated: burnerAnimated)
                            .offset(y: -height * 0.30)
                            .blendMode(.plusLighter)
                    }
                }
                .background(ambientGlow)
        } else {
            BalloonMark(size: height * 0.62, glow: glow, showGlow: showGlow,
                        showBurner: showBurner, burnerAnimated: burnerAnimated)
        }
    }

    @ViewBuilder private var ambientGlow: some View {
        if showGlow {
            Circle()
                .fill(RadialGradient(colors: [glow.opacity(0.35), .clear],
                                     center: .center, startRadius: 0, endRadius: height * 0.7))
                .frame(width: height * 1.4, height: height * 1.4)
                .blur(radius: height * 0.1)
        }
    }
}

#Preview {
    ZStack {
        Color(hex: 0x0A0E1A).ignoresSafeArea()
        HStack(spacing: 50) {
            BalloonMark(size: 96, glow: RouteTheme.aurora.soft, showGlow: true, showBurner: true)
            BalloonView(height: 200, showBurner: true, showGlow: true)
        }
    }
}
