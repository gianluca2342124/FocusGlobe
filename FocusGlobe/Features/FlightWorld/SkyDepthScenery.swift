import Foundation
import SwiftUI

// MARK: - Layered atmospheric depth scenery

/// The shared **depth engine** behind every Sky: two or three silhouette
/// planes stacked toward the horizon with atmospheric-perspective haze between
/// them, plus a soft horizon light. Each plane drifts sideways at a glacial,
/// plane-specific rate, so the world gains true parallax depth without any
/// scrolling scenery. Everything is authored per Sky — ridge character, haze
/// colour and light all come from the Sky's identity, never from generic
/// decoration. Cosmic Skies deliberately render nothing here: their depth
/// comes from nebulae and star parallax, not terrain.
///
/// Used by BOTH the Home Sky previews and the living flight renderer, so the
/// world a pilot chooses is the world they fly.
struct SkyDepthScenery: View {
    let sky: FocusSky
    /// Pause-aware seconds; 0 renders a still frame (Reduce Motion / previews).
    var t: Double = 0
    /// Fraction of height where the NEAREST plane's base line sits.
    var horizon: CGFloat = 0.86
    /// Global strength multiplier (lets the flight sit scenery back a touch).
    var intensity: Double = 1.0

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            if let config = SkySceneryConfig.config(for: sky.id) {
                ZStack {
                    // Horizon light: the soft luminous air where sky meets land.
                    if let glow = config.horizonGlow {
                        let breathe = t == 0 ? 1.0 : 0.85 + 0.15 * Foundation.sin(t * 0.05)
                        RadialGradient(colors: [glow.opacity(0.20 * intensity * breathe), .clear],
                                       center: UnitPoint(x: 0.5, y: Double(horizon) - 0.02),
                                       startRadius: 2, endRadius: W * 0.75)
                    }
                    ForEach(Array(config.planes.enumerated()), id: \.offset) { index, plane in
                        planeView(plane, index: index, W: W, H: H)
                    }
                    // A whisper of haze lying over the far planes — the air
                    // between the viewer and the distance.
                    LinearGradient(colors: [config.haze.opacity(0),
                                            config.haze.opacity(0.10 * intensity),
                                            config.haze.opacity(0)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: H * 0.16)
                        .position(x: W / 2, y: H * (horizon - 0.10))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func planeView(_ plane: SkySceneryConfig.Plane, index: Int,
                           W: CGFloat, H: CGFloat) -> some View {
        // Far planes drift the least — genuine parallax, glacially slow.
        let drift: CGFloat = t == 0 ? 0
            : CGFloat(Foundation.sin(t * plane.driftSpeed + Double(index) * 2.1)) * plane.driftPoints
        let planeH = H * plane.height
        // A solid skirt continues the silhouette from its base line down to the
        // PHYSICAL bottom of the view, so a plane based above 1.0 can never end
        // in an exposed horizontal cut (the ground plate / tab bar can't be
        // relied on to cover it on every surface).
        let skirtH = max(0, 1 - plane.base) * H
        let fill = LinearGradient(
            colors: [plane.tint.opacity(plane.topOpacity * intensity),
                     plane.tint.opacity(plane.bottomOpacity * intensity)],
            startPoint: .top, endPoint: .bottom)
        let skirtFill = plane.tint.opacity(plane.bottomOpacity * intensity)
        switch plane.form {
        case .ridge(let waves, let phase, let sharpness):
            VStack(spacing: 0) {
                SkyRidgeShape(waves: waves, phase: phase,
                              sharpness: sharpness, parallax: drift)
                    .fill(fill)
                    .frame(height: planeH)
                if skirtH > 0.25 {
                    Rectangle().fill(skirtFill).frame(height: skirtH)
                }
            }
            .frame(width: W)
            .position(x: W / 2, y: H - (planeH + skirtH) / 2)
        case .landmark(let landmark, let widthFactor, let xCenter):
            VStack(spacing: 0) {
                LandmarkSilhouette(landmark: landmark)
                    .fill(fill)
                    .frame(height: planeH)
                if skirtH > 0.25 {
                    Rectangle().fill(skirtFill).frame(height: skirtH)
                }
            }
            .frame(width: W * widthFactor)
            .position(x: W * xCenter + drift * 0.4, y: H - (planeH + skirtH) / 2)
        }
    }
}

// MARK: - The ridge silhouette

/// A parametric mountain/dune/hill silhouette. Two blended wave families:
/// a rounded low-frequency sum (soft highlands, dunes) and a crisp-peaked sum
/// (alpine ridges); `sharpness` mixes between them. `parallax` shifts the wave
/// field horizontally so a plane can drift without ever revealing an edge.
struct SkyRidgeShape: Shape {
    var waves: CGFloat
    var phase: CGFloat
    /// 0 = fully rounded shoulders … 1 = crisp alpine peaks.
    var sharpness: CGFloat = 0
    /// Horizontal wave-field shift in points (the parallax drift).
    var parallax: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let steps = 56
        let baseY = rect.maxY
        p.move(to: CGPoint(x: rect.minX, y: baseY))
        for i in 0...steps {
            let fx = CGFloat(i) / CGFloat(steps)
            let x = rect.minX + fx * rect.width
            let u = Double((fx * rect.width + parallax) / max(1, rect.width))
                * Double(waves) * .pi * 2 + Double(phase)
            // Rounded family: soft shoulders, gentle valleys.
            let rounded = (Foundation.sin(u) + 0.45 * Foundation.sin(u * 2.17 + 1.3)) / 1.45
            // Crisp family: sharp summits, still-smooth valleys.
            let s1 = (0.5 - abs(Foundation.sin(u * 0.5 + 0.4))) * 2
            let s2 = (0.5 - abs(Foundation.sin(u * 1.27 + 1.9))) * 0.9
            let crisp = (s1 + s2) / 1.45
            let v = rounded * (1 - Double(sharpness)) + crisp * Double(sharpness)
            let elevation = 0.55 + 0.45 * max(-1, min(1, v))
            p.addLine(to: CGPoint(x: x, y: baseY - rect.height * CGFloat(elevation)))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: baseY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Per-Sky scenery authoring

/// The authored scenery per Sky — silhouette planes far → near, the haze that
/// lies between them, and the horizon light. Values are hand-tuned so every
/// Sky keeps its own identity: highlands roll, the Alps bite, dunes breathe,
/// skylines glow through rain. Cosmic Skies return nil (no terrain in space).
enum SkySceneryConfig {

    struct Plane {
        enum Form {
            case ridge(waves: CGFloat, phase: CGFloat, sharpness: CGFloat)
            case landmark(Landmark, widthFactor: CGFloat, xCenter: CGFloat)
        }
        let form: Form
        let tint: Color
        /// Opacity at the silhouette's crest (lighter = more air in front).
        let topOpacity: Double
        let bottomOpacity: Double
        /// Plane height as a fraction of view height.
        let height: CGFloat
        /// Fraction of view height where this plane's base sits.
        let base: CGFloat
        /// Parallax: how far (points) and how fast this plane drifts.
        let driftPoints: CGFloat
        let driftSpeed: Double
    }

    struct Config {
        let planes: [Plane]
        let haze: Color
        let horizonGlow: Color?
    }

    static func config(for skyID: String) -> Config? {
        switch skyID {
        case "golden-hour":
            // Amber Highlands — three rolling ridge lines sinking into warm
            // rose haze; the horizon holds the amber light of the low sun.
            return Config(planes: [
                Plane(form: .ridge(waves: 1.5, phase: 0.7, sharpness: 0.22),
                      tint: Color(hex: 0x8A4A5E), topOpacity: 0.30, bottomOpacity: 0.55,
                      height: 0.20, base: 0.965, driftPoints: 10, driftSpeed: 0.010),
                Plane(form: .ridge(waves: 1.9, phase: 3.6, sharpness: 0.30),
                      tint: Color(hex: 0x5A3050), topOpacity: 0.50, bottomOpacity: 0.78,
                      height: 0.16, base: 0.985, driftPoints: 17, driftSpeed: 0.014),
                Plane(form: .ridge(waves: 2.4, phase: 1.9, sharpness: 0.18),
                      tint: Color(hex: 0x33203E), topOpacity: 0.80, bottomOpacity: 0.95,
                      height: 0.115, base: 1.0, driftPoints: 24, driftSpeed: 0.018),
            ], haze: Color(hex: 0xF2A96A), horizonGlow: Color(hex: 0xFFC873))
        case "fiji-lagoon":
            // Low island mounds resting on a luminous sea-air band.
            return Config(planes: [
                Plane(form: .ridge(waves: 1.1, phase: 2.4, sharpness: 0.05),
                      tint: Color(hex: 0x14606C), topOpacity: 0.26, bottomOpacity: 0.5,
                      height: 0.10, base: 0.97, driftPoints: 8, driftSpeed: 0.009),
                Plane(form: .ridge(waves: 1.7, phase: 5.1, sharpness: 0.05),
                      tint: Color(hex: 0x0B3E4C), topOpacity: 0.55, bottomOpacity: 0.85,
                      height: 0.075, base: 1.0, driftPoints: 14, driftSpeed: 0.013),
            ], haze: Color(hex: 0xBFF2E0), horizonGlow: Color(hex: 0xA8F0DC))
        case "kyoto-lanterns":
            // Soft temple hills, with a distant pagoda resting in the plum dusk.
            return Config(planes: [
                Plane(form: .ridge(waves: 1.4, phase: 1.2, sharpness: 0.1),
                      tint: Color(hex: 0x6E3A58), topOpacity: 0.30, bottomOpacity: 0.55,
                      height: 0.16, base: 0.97, driftPoints: 9, driftSpeed: 0.010),
                Plane(form: .landmark(.pagoda, widthFactor: 0.34, xCenter: 0.72),
                      tint: Color(hex: 0x2E1A38), topOpacity: 0.62, bottomOpacity: 0.8,
                      height: 0.135, base: 0.995, driftPoints: 5, driftSpeed: 0.008),
                Plane(form: .ridge(waves: 2.1, phase: 4.4, sharpness: 0.08),
                      tint: Color(hex: 0x241332), topOpacity: 0.78, bottomOpacity: 0.94,
                      height: 0.10, base: 1.0, driftPoints: 18, driftSpeed: 0.015),
            ], haze: Color(hex: 0xE09A6E), horizonGlow: Color(hex: 0xF2AA6A))
        case "aurora-snowfield":
            // Silent snow ridges under the cold green light.
            return Config(planes: [
                Plane(form: .ridge(waves: 1.3, phase: 0.4, sharpness: 0.34),
                      tint: Color(hex: 0x16404A), topOpacity: 0.34, bottomOpacity: 0.6,
                      height: 0.15, base: 0.97, driftPoints: 8, driftSpeed: 0.009),
                Plane(form: .ridge(waves: 1.8, phase: 2.9, sharpness: 0.26),
                      tint: Color(hex: 0x081E2C), topOpacity: 0.66, bottomOpacity: 0.9,
                      height: 0.11, base: 1.0, driftPoints: 15, driftSpeed: 0.014),
            ], haze: Color(hex: 0x7EDCB4), horizonGlow: Color(hex: 0x54E0A8))
        case "rainy-tokyo":
            // Two skyline strata dissolving into the rain haze.
            return Config(planes: [
                Plane(form: .landmark(.skyline, widthFactor: 1.35, xCenter: 0.46),
                      tint: Color(hex: 0x27335A), topOpacity: 0.34, bottomOpacity: 0.55,
                      height: 0.17, base: 0.975, driftPoints: 6, driftSpeed: 0.008),
                Plane(form: .landmark(.skyline, widthFactor: 1.15, xCenter: 0.56),
                      tint: Color(hex: 0x131B36), topOpacity: 0.68, bottomOpacity: 0.9,
                      height: 0.13, base: 1.0, driftPoints: 11, driftSpeed: 0.012),
            ], haze: Color(hex: 0x8FA6D8), horizonGlow: Color(hex: 0x6E7EA8))
        case "swiss-alps":
            // Crisp alpine ridge lines in cold blue air, snowlight on the horizon.
            return Config(planes: [
                Plane(form: .ridge(waves: 1.6, phase: 0.9, sharpness: 0.85),
                      tint: Color(hex: 0x7C9CB8), topOpacity: 0.30, bottomOpacity: 0.5,
                      height: 0.235, base: 0.96, driftPoints: 8, driftSpeed: 0.009),
                Plane(form: .ridge(waves: 2.0, phase: 3.2, sharpness: 0.8),
                      tint: Color(hex: 0x3E607E), topOpacity: 0.52, bottomOpacity: 0.75,
                      height: 0.17, base: 0.985, driftPoints: 14, driftSpeed: 0.013),
                Plane(form: .ridge(waves: 2.5, phase: 5.4, sharpness: 0.6),
                      tint: Color(hex: 0x1A2E44), topOpacity: 0.8, bottomOpacity: 0.95,
                      height: 0.115, base: 1.0, driftPoints: 22, driftSpeed: 0.017),
            ], haze: Color(hex: 0xE0EEF2), horizonGlow: Color(hex: 0xF6D9B4))
        case "sahara-night":
            // Two breathing dune curves under the desert stars.
            return Config(planes: [
                Plane(form: .ridge(waves: 0.9, phase: 1.6, sharpness: 0.0),
                      tint: Color(hex: 0x6E4448), topOpacity: 0.30, bottomOpacity: 0.55,
                      height: 0.15, base: 0.97, driftPoints: 9, driftSpeed: 0.008),
                Plane(form: .ridge(waves: 1.3, phase: 4.7, sharpness: 0.0),
                      tint: Color(hex: 0x2E1C2E), topOpacity: 0.68, bottomOpacity: 0.92,
                      height: 0.11, base: 1.0, driftPoints: 16, driftSpeed: 0.012),
            ], haze: Color(hex: 0xD08A5E), horizonGlow: Color(hex: 0xE8B080))
        case "galaxy-drift", "deep-space":
            // Space has no terrain: depth belongs to the nebulae and stars.
            return nil
        default:
            return nil
        }
    }
}
