import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if DEBUG
/// Code-only switch for the DEBUG sky inspector (sky · seed · palette segment ·
/// elapsed). Never compiled into release builds.
private let livingSkyInspectorEnabled = false
#endif

/// Where the authoritative Sky is being shown. Presentation mode deliberately
/// does not select different artwork: Home, ritual, preview, Cabin and the
/// active journey always enter the same world.
enum SkyPresentationMode {
    case activeJourney
    case homeSelector
    case ritual
    case lockedPreview
    case cabin
    case completion
    case socialPreview
    case paywall
}

/// Rendering cadence for multiple simultaneous Sky surfaces. Reduced keeps the
/// complete composition and all real effects, but refreshes less often; still
/// renders the same settled frame without maintaining an animation timeline.
enum SkyRenderQuality {
    case full
    case reduced
    case still

    var minimumInterval: TimeInterval {
        switch self {
        case .full: return 1.0 / 30.0
        case .reduced: return 1.0 / 15.0
        case .still: return 600
        }
    }
}

/// **The living animated sky** — FocusGlobe's authoritative flight renderer,
/// shared by real flights, Cabin View and locked-Sky previews.
///
/// Direction: premium digital sky art, not a scrolling world and not a
/// procedural collage. The composition is:
///
///   1. Orientation-aware, full-screen environment artwork defines terrain,
///      architecture, water, lighting and depth. A continuously evolving
///      authored gradient remains behind it as a safe missing-art fallback.
///   2. Soft breathing haze and a slowly wandering highlight — organic light,
///      never a hard-edged disc.
///   3. Per-Sky atmospheric moments that fade in, live briefly in place
///      (drift a little, breathe, twinkle) and fade out — birds, lanterns,
///      aurora, rain, petals, shimmer. Nothing travels top-to-bottom as
///      scenery; there are no rings, no vector geometry, no procedural mini
///      balloons, at most ONE restrained celestial body.
///
/// All motion derives from the pause-aware flight clock: pause freezes the
/// world; Cabin/preview share the same seed + clock, so they show the same sky.
struct SkyFlightSceneView: View {
    let sky: FocusSky
    /// Pause-aware elapsed seconds — the single source of motion.
    let elapsed: () -> Double
    var animated: Bool = true
    /// Stable per-session seed (shared with Cabin) — varies effect placement
    /// between flights while staying fixed across pause/resume.
    var seed: UInt64 = 1
    var presentationMode: SkyPresentationMode = .activeJourney
    var renderQuality: SkyRenderQuality = .full

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = max(1, geo.size.height)
            let artwork = SkyArtworkResolver.image(for: sky, landscape: W > H)
            let isLive = animated && renderQuality != .still
            TimelineView(.animation(minimumInterval: isLive ? renderQuality.minimumInterval : 600)) { _ in
                // Static frame: a fixed, SETTLED moment (celestial faded in,
                // scenery composed) — a constant, so Reduce Motion and off-
                // screen previews show no movement at all, never the bare t=0
                // frame that hides the celestial bodies.
                let t = isLive ? max(0, elapsed()) : 24
                ZStack {
                    gradientField(W: W, H: H, t: t)
                    if let artwork {
                        SkyArtworkFoundation(image: artwork)
                        artworkGrade(W: W, H: H, t: t)
                    }
                    atmosphere(W: W, H: H, t: t)
                        .opacity(artwork == nil ? 1 : artworkAtmosphereOpacity)
                    // Finished artwork already owns the moon/planets. The
                    // procedural celestial layer remains only for missing art.
                    if artwork == nil {
                        celestial(W: W, H: H, t: t)
                    }
                    effects(W: W, H: H, t: t)
                        .opacity(artwork == nil ? 1 : artworkEffectsOpacity)
                    if artwork == nil {
                        // A future/missing artwork pair still gets the complete
                        // legacy world rather than a blank background.
                        SkyDepthScenery(sky: sky, t: t, horizon: 0.82, intensity: 0.95)
                    }
                    weather(W: W, H: H, t: t)
                        .opacity(artwork == nil ? 1 : artworkWeatherOpacity)
                    #if DEBUG
                    if livingSkyInspectorEnabled { inspector(t: t) }
                    #endif
                }
                .frame(width: W, height: H)
                .clipped()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// A subtle moving light wash keeps the static foundation connected to the
    /// live atmosphere without redrawing or distorting authored scenery.
    private func artworkGrade(W: CGFloat, H: CGFloat, t: Double) -> some View {
        let breathe = 0.86 + 0.14 * Foundation.sin(t * 0.035)
        return ZStack {
            LinearGradient(stops: [
                .init(color: .black.opacity(sky.isCosmicSky ? 0.04 : 0.08), location: 0),
                .init(color: .clear, location: 0.36),
                .init(color: .clear, location: 0.74),
                .init(color: .black.opacity(0.055), location: 1),
            ], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [sky.glowColor.opacity(0.045 * breathe), .clear],
                           center: UnitPoint(x: 0.5 + 0.05 * Foundation.sin(t * 0.009), y: 0.72),
                           startRadius: 2, endRadius: W * 0.76)
        }
    }

    /// Weather remains legible over detailed art without becoming visual noise.
    private var artworkWeatherOpacity: Double {
        switch sky.flightParticles {
        case .rain: return 0.98
        case .snow: return sky.id == "aurora-snowfield" ? 0.92 : 0.76
        case .none, .lanterns: return 1
        }
    }

    /// Authored art is the visual foundation, but it must not mute the living
    /// sky into a still poster. Each value is tuned for the contrast of that
    /// specific painting; these layers are light/particles only and never
    /// redraw terrain, water or architecture.
    private var artworkAtmosphereOpacity: Double {
        switch sky.id {
        case "sahara-night":     return 0.82
        case "fiji-lagoon":      return 0.70
        case "kyoto-lanterns":   return 0.68
        case "aurora-snowfield": return 0.76
        case "rainy-tokyo":      return 0.72
        case "swiss-alps":       return 0.70
        case "galaxy-drift":     return 0.84
        case "deep-space":       return 0.88
        default:                 return 0.58
        }
    }

    private var artworkEffectsOpacity: Double {
        switch sky.id {
        case "fiji-lagoon":      return 0.86
        case "kyoto-lanterns":   return 0.94
        case "aurora-snowfield": return 0.78
        case "rainy-tokyo":      return 0.90
        case "sahara-night":     return 0.82
        case "swiss-alps":       return 0.72
        case "galaxy-drift":     return 0.86
        case "deep-space":       return 0.88
        default:                 return 0.62
        }
    }

    /// Per-Sky live star density. This deliberately does not alter the catalog
    /// model (unlocking, persistence and product IDs stay untouched).
    private var liveStarDensity: Double {
        switch sky.id {
        case "sahara-night":     return 1.00
        case "fiji-lagoon":      return 0.08
        case "kyoto-lanterns":   return 0.42
        case "aurora-snowfield": return 0.88
        case "rainy-tokyo":      return 0.18
        case "swiss-alps":       return 0.46
        case "galaxy-drift", "deep-space": return 1.00
        default:                 return sky.stars
        }
    }

    private var skySeed: UInt64 {
        var h: UInt64 = seed == 0 ? 0xF0C0 : seed
        for u in sky.id.unicodeScalars { h = (h &* 31) &+ UInt64(u.value) }
        return h
    }

    // MARK: 1 — The evolving gradient field

    private func gradientField(W: CGFloat, H: CGFloat, t: Double) -> some View {
        let stops = SkyGradientTimeline.stops(skyID: sky.id, at: t)
        // The highlight wanders extremely slowly and stays soft-edged.
        let hx = 0.5 + 0.22 * Foundation.sin(t * 0.011)
        let hy = 0.30 + 0.08 * Foundation.sin(t * 0.007 + 1.7)
        let breathe = 0.8 + 0.2 * Foundation.sin(t * 0.05)
        return ZStack {
            LinearGradient(colors: stops, startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [sky.glowColor.opacity(0.16 * breathe), .clear],
                           center: UnitPoint(x: hx, y: hy),
                           startRadius: 2, endRadius: W * 1.05)
            // Two vast, ultra-soft haze masses breathing out of phase — organic
            // depth with no identifiable boundary.
            RadialGradient(colors: [stops[3].opacity(0.10 + 0.04 * Foundation.sin(t * 0.03)), .clear],
                           center: UnitPoint(x: 0.24 + 0.06 * Foundation.sin(t * 0.013 + 2.2), y: 0.62),
                           startRadius: 2, endRadius: W * 0.9)
            RadialGradient(colors: [stops[1].opacity(0.10 + 0.04 * Foundation.sin(t * 0.026 + 3.1)), .clear],
                           center: UnitPoint(x: 0.78 - 0.06 * Foundation.sin(t * 0.017), y: 0.4),
                           startRadius: 2, endRadius: W * 0.85)
            // Zenith depth: the top of the sky deepens gently, so looking up
            // reads as looking into vastness rather than at a flat wall.
            LinearGradient(stops: [
                .init(color: stops[0].opacity(0.55), location: 0),
                .init(color: stops[0].opacity(0), location: 0.30),
                .init(color: .clear, location: 1),
            ], startPoint: .top, endPoint: .bottom)
            // Horizon bloom: light accumulating in the thick air low in the
            // frame — the classic "big world" cue, breathing very slowly.
            RadialGradient(colors: [sky.glowColor.opacity(0.11 + 0.04 * breathe), .clear],
                           center: UnitPoint(x: 0.5, y: 0.82),
                           startRadius: 4, endRadius: W * 0.95)
        }
    }

    // MARK: 2 — Ambient atmosphere (stars, near-ground shimmer)

    @ViewBuilder private func atmosphere(W: CGFloat, H: CGFloat, t: Double) -> some View {
        if liveStarDensity > 0.01 { starField(W: W, H: H, t: t) }
        switch sky.id {
        case "fiji-lagoon":
            groundShimmer(W: W, H: H, t: t, tint: Color(hex: 0xBFF2E0))
            seaGlow(W: W, H: H, t: t)
        case "rainy-tokyo":
            neonShimmer(W: W, H: H, t: t)
        case "paris-sunset":
            groundShimmer(W: W, H: H, t: t, tint: Color(hex: 0xF6C88A))
        case "sahara-night":
            milkyWay(W: W, H: H, t: t)
        case "galaxy-drift", "deep-space":
            // The great diagonal star-river gives the cosmos its sense of
            // immense, structured depth — the emptiest Skies feel the largest.
            milkyWay(W: W, H: H, t: t)
        default:
            EmptyView()
        }
    }

    /// Fiji — a luminous aqua band where sea light saturates the low air,
    /// breathing on a long period. Pure light, no boundary.
    private func seaGlow(W: CGFloat, H: CGFloat, t: Double) -> some View {
        let breathe = 0.8 + 0.2 * Foundation.sin(t * 0.045)
        return LinearGradient(colors: [Color(hex: 0x8DE8D0).opacity(0),
                                       Color(hex: 0x8DE8D0).opacity(0.12 * breathe),
                                       Color(hex: 0x8DE8D0).opacity(0)],
                              startPoint: .top, endPoint: .bottom)
            .frame(height: H * 0.22)
            .position(x: W / 2, y: H * 0.76)
    }

    /// Stars twinkle **in place** — the world does not scroll. Star-heavy Skies
    /// gain a second plane of fine background dust (depth through density) and
    /// a handful of hero stars with soft cross glints (depth through hierarchy).
    private func starField(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0x57A2)
            let density = liveStarDensity
            let count = Int(56 + density * 178)
            for i in 0..<count {
                let x = CGFloat(rng.unit()) * s.width
                let depth = rng.unit()
                let desertCeiling: CGFloat = s.width > s.height ? 0.64 : 0.67
                let maxY: CGFloat = sky.id == "sahara-night"
                    ? desertCeiling
                    : (depth < 0.28 ? 0.96 : 0.82)
                let y = CGFloat(rng.unit()) * s.height * maxY
                let u = rng.unit()
                let pulse = 0.5 + 0.5 * Foundation.sin(t * (0.30 + u * 1.26) + Double(i) * 1.31)
                let tw = 0.32 + 0.68 * pow(pulse, u > 0.86 ? 2.2 : 1.0)
                let a = (0.13 + u * 0.58) * density * tw
                let r = CGFloat(0.45 + u * (depth < 0.28 ? 0.9 : 1.65))
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(a)))
                if u > 0.91 && density > 0.4 {
                    softGlow(&ctx, x: x, y: y, r: r * 3.4, color: .white.opacity(a * 0.4))
                }
                // Hero stars: rare, brighter, with a delicate 4-point glint that
                // swells and fades with the twinkle — never a hard sparkle.
                if u > 0.958 && density > 0.4 {
                    let glint = CGFloat(6 + u * 5) * CGFloat(0.6 + 0.4 * tw)
                    var cross = Path()
                    cross.move(to: CGPoint(x: x - glint, y: y)); cross.addLine(to: CGPoint(x: x + glint, y: y))
                    cross.move(to: CGPoint(x: x, y: y - glint)); cross.addLine(to: CGPoint(x: x, y: y + glint))
                    ctx.stroke(cross, with: .color(.white.opacity(a * 0.35)), lineWidth: 0.7)
                }
            }
            // The dust plane: dense micro-stars for the deep cosmic Skies only.
            if density > 0.72 {
                var dustRNG = SeededRNG(seed: skySeed &+ 0xD0_57A2)
                for i in 0..<150 {
                    let x = CGFloat(dustRNG.unit()) * s.width
                    let y = CGFloat(dustRNG.unit()) * s.height
                    let tw = 0.65 + 0.35 * Foundation.sin(t * 0.16 + Double(i) * 0.73)
                    let a = (0.045 + dustRNG.unit() * 0.13) * tw
                    let r = 0.55 + dustRNG.unit() * 0.35
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                             with: .color(.white.opacity(a)))
                }
            }
        }
    }

    /// Soft glints twinkling just above the ground line (ocean / city lights).
    private func groundShimmer(W: CGFloat, H: CGFloat, t: Double, tint: Color) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0x0CEA)
            for _ in 0..<20 {
                let fx = rng.unit()
                let fy = 0.84 + rng.unit() * 0.1
                let tw = 0.5 + 0.5 * Foundation.sin(t * (0.4 + rng.unit() * 1.2) + fx * 6.0)
                let a = 0.06 + tw * 0.18
                let x = CGFloat(fx) * s.width
                let y = CGFloat(fy) * s.height
                softGlow(&ctx, x: x, y: y, r: CGFloat(3 + rng.unit() * 5), color: tint.opacity(a))
            }
        }
    }

    /// Blurred neon reflections breathing low in the rain haze.
    private func neonShimmer(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0x0C17)
            let neon = [Color(hex: 0xE86A9E), Color(hex: 0x6AC8E8), Color(hex: 0x8F7BE8)]
            for i in 0..<14 {
                let fx = rng.unit()
                let fy = 0.72 + rng.unit() * 0.2
                let pulse = 0.5 + 0.5 * Foundation.sin(t * (0.5 + rng.unit()) + Double(i))
                let a = 0.05 + pulse * 0.16
                softGlow(&ctx, x: CGFloat(fx) * s.width, y: CGFloat(fy) * s.height,
                         r: CGFloat(9 + rng.unit() * 12), color: neon[i % neon.count].opacity(a))
            }
        }
    }

    /// A faint diagonal Milky-Way glow: a tilted band of dense micro-stars
    /// inside a very soft luminous haze — no edges, no geometry.
    private func milkyWay(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0x3117)
            let cx = Double(s.width) * 0.5
            let cy = Double(s.height) * 0.34
            let tilt = -0.5
            ctx.drawLayer { l in
                l.translateBy(x: CGFloat(cx), y: CGFloat(cy))
                l.rotate(by: .radians(tilt))
                let len = Double(s.width) * 1.3
                let g = Gradient(colors: [Color(hex: 0xD8CCF0).opacity(0.10),
                                          Color(hex: 0x9A88C8).opacity(0.04), .clear])
                // Desert Night's authored foundation already contains its
                // luminous Milky Way. Drawing this broad elliptical haze over
                // it read as a giant translucent spotlight on wide layouts.
                // Keep the fine star river below, but reserve the additional
                // glow plate for the two fully cosmic Skies.
                if sky.id != "sahara-night" {
                    l.fill(Path(ellipseIn: CGRect(x: -len / 2, y: -len * 0.09,
                                                  width: len, height: len * 0.18)),
                           with: .radialGradient(g, center: .zero, startRadius: 0,
                                                 endRadius: CGFloat(len / 2)))
                }
                for _ in 0..<70 {
                    let x = (rng.unit() - 0.5) * len
                    let y = (rng.unit() - 0.5) * len * 0.13
                    let a = 0.1 + rng.unit() * 0.35
                    let r = 0.5 + rng.unit() * 1.1
                    l.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                           with: .color(.white.opacity(a)))
                }
            }
        }
    }

    // MARK: 3 — One restrained celestial body (never more)

    @ViewBuilder private func celestial(W: CGFloat, H: CGFloat, t: Double) -> some View {
        // Placed in an upper corner, small, fading in over ~20 s, then nearly
        // stationary — never behind the balloon, headline or controls.
        let fadeIn = min(1.0, t / 20.0)
        let drift = CGFloat(Foundation.sin(t * 0.004)) * W * 0.01
        switch sky.id {
        case "moon-garden":
            softMoon(d: W * 0.24)
                .position(x: W * 0.74 + drift, y: H * 0.20)
                .opacity(fadeIn)
        case "sahara-night":
            // Nudged in from the far-left corner (0.26 → 0.40) so the moon reads
            // meaningfully THROUGH the Cabin window (its arched top-left corner was
            // clipping the disc), while staying balanced in the full-screen flight.
            // The Home preview draws its own accent, so it is unaffected.
            softMoon(d: W * 0.12, dim: true)
                .position(x: W * 0.40 + drift, y: H * 0.17)
                .opacity(fadeIn * 0.8)
        case "galaxy-drift":
            ZStack {
                softPlanet(d: W * 0.14)
                    .position(x: W * 0.24 + drift, y: H * 0.18)
                // A tiny distant second world for depth, far to the other side.
                softPlanet(d: W * 0.05)
                    .position(x: W * 0.82 - drift, y: H * 0.30)
                    .opacity(0.7)
            }
            .opacity(fadeIn * 0.9)
        case "deep-space":
            ZStack {
                galaxySmudge(W: W, H: H)
                // The hero: a Saturn-like ringed planet, high and to the side so
                // it never sits behind the timer or balloon. Slow parallax.
                SkyCosmic.ringedPlanet(d: W * 0.22)
                    .position(x: W * 0.72 + drift * 1.6, y: H * 0.24)
                // A small moon at a different depth.
                softMoon(d: W * 0.07, dim: true)
                    .position(x: W * 0.2 - drift, y: H * 0.32)
                // A very rare, very distant UFO — an easter egg, not a fixture.
                SkyCosmic.rareUFO(W: W, H: H, t: t, k: 1.0, seed: skySeed)
            }
            .opacity(fadeIn * 0.9)
        default:
            EmptyView()
        }
    }

    /// A moon with a fully diffused limb — sphere shading, soft maria, a wide
    /// glow. No rim strokes, no rings, no hard boundary.
    private func softMoon(d: CGFloat, dim: Bool = false) -> some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [Color(hex: 0xEDF2FB).opacity(dim ? 0.16 : 0.28), .clear],
                                         center: .center, startRadius: 2, endRadius: d))
                .frame(width: d * 2, height: d * 2)
            Circle().fill(RadialGradient(
                colors: [Color(hex: 0xF6F8FE).opacity(dim ? 0.7 : 0.95),
                         Color(hex: 0xD5DCEC).opacity(dim ? 0.55 : 0.85),
                         Color(hex: 0xAEB9D2).opacity(0)],
                center: UnitPoint(x: 0.38, y: 0.34), startRadius: 0, endRadius: d * 0.66))
                .frame(width: d, height: d)
            Circle().fill(Color(hex: 0x93A0BC).opacity(0.22))
                .frame(width: d * 0.18, height: d * 0.18).offset(x: -d * 0.12, y: -d * 0.04)
            Circle().fill(Color(hex: 0x93A0BC).opacity(0.16))
                .frame(width: d * 0.1, height: d * 0.1).offset(x: d * 0.12, y: d * 0.14)
        }
        .frame(width: d, height: d)
    }

    /// A small distant world with soft limb shading — no rings, no strokes.
    private func softPlanet(d: CGFloat) -> some View {
        Circle().fill(RadialGradient(
            colors: [Color(hex: 0xB4C4E8).opacity(0.85), Color(hex: 0x7E92C2).opacity(0.6),
                     Color(hex: 0x3A4A72).opacity(0)],
            center: UnitPoint(x: 0.36, y: 0.32), startRadius: 0, endRadius: d * 0.68))
            .frame(width: d, height: d)
    }

    /// A faint tilted galaxy smudge — soft elliptical haze with a brighter core.
    private func galaxySmudge(W: CGFloat, H: CGFloat) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0x6A1A)
            let gx = Double(s.width) * (0.24 + rng.unit() * 0.16)
            let gy = Double(s.height) * (0.14 + rng.unit() * 0.1)
            let r = Double(min(s.width, s.height)) * 0.16
            ctx.drawLayer { l in
                l.translateBy(x: CGFloat(gx), y: CGFloat(gy))
                l.rotate(by: .radians(rng.unit() * 0.8 - 0.4))
                let g = Gradient(colors: [Color(hex: 0xB49CE8).opacity(0.12),
                                          Color(hex: 0x6E7EC8).opacity(0.05), .clear])
                l.fill(Path(ellipseIn: CGRect(x: -r, y: -r * 0.4, width: r * 2, height: r * 0.8)),
                       with: .radialGradient(g, center: .zero, startRadius: 0, endRadius: CGFloat(r)))
                let cg = Gradient(colors: [Color.white.opacity(0.12), .clear])
                l.fill(Path(ellipseIn: CGRect(x: -r * 0.14, y: -r * 0.07, width: r * 0.28, height: r * 0.14)),
                       with: .radialGradient(cg, center: .zero, startRadius: 0, endRadius: CGFloat(r * 0.2)))
            }
        }
    }

    // MARK: 4 — Per-Sky atmospheric moments (fade in · live · fade out)

    @ViewBuilder private func effects(W: CGFloat, H: CGFloat, t: Double) -> some View {
        switch sky.id {
        case "golden-hour":
            ZStack {
                sunBloom(W: W, H: H, t: t)
                cirrus(W: W, H: H, t: t, tint: Color(hex: 0xF6D8A8))
                flockCrossing(W: W, H: H, t: t)
                dustMotes(W: W, H: H, t: t, tint: Color(hex: 0xF6C88A), count: 14)
            }
        case "paris-sunset":
            ZStack {
                sunBloom(W: W, H: H, t: t)
                cirrus(W: W, H: H, t: t, tint: Color(hex: 0xEEB0A0))
                flockCrossing(W: W, H: H, t: t)
                dustMotes(W: W, H: H, t: t, tint: Color(hex: 0xF6C88A), count: 10)
            }
        case "fiji-lagoon":
            ZStack {
                sunBloom(W: W, H: H, t: t)
                cirrus(W: W, H: H, t: t, tint: Color(hex: 0xEAFBF4))
                flockCrossing(W: W, H: H, t: t)
                lagoonLight(W: W, H: H, t: t)
                horizonHaze(W: W, H: H, t: t, tint: Color(hex: 0x9BE8DA), y: 0.64)
                dustMotes(W: W, H: H, t: t, tint: Color(hex: 0xD9FFF0), count: 18)
            }
        case "kyoto-lanterns":
            ZStack {
                horizonHaze(W: W, H: H, t: t, tint: Color(hex: 0xF2AA6A), y: 0.68)
                anchoredLanternGlow(W: W, H: H, t: t)
                lanternMoments(W: W, H: H, t: t)
                petals(W: W, H: H, t: t, tint: Color(hex: 0xF2C4C8))
                dustMotes(W: W, H: H, t: t, tint: Color(hex: 0xFFD08A), count: 18)
                mistBreath(W: W, H: H, t: t, tint: Color(hex: 0xCFA4B8))
                moonGlow(W: W, H: H, t: t)
            }
        case "aurora-snowfield":
            ZStack {
                auroraCurtains(W: W, H: H, t: t)
                moonGlow(W: W, H: H, t: t)
                lightPillar(W: W, H: H, t: t)
                horizonHaze(W: W, H: H, t: t, tint: Color(hex: 0x8FE8D0), y: 0.70)
                icyAir(W: W, H: H, t: t)
            }
        case "rainy-tokyo":
            ZStack {
                cloudGlow(W: W, H: H, t: t)
                cityLightPulse(W: W, H: H, t: t)
                horizonHaze(W: W, H: H, t: t, tint: Color(hex: 0x6A8ED8), y: 0.64)
                mistBreath(W: W, H: H, t: t, tint: Color(hex: 0xB5C7E8))
                distantBeacon(W: W, H: H, t: t, period: 112, salt: 0x701)
            }
        case "moon-garden":
            ZStack {
                mistBreath(W: W, H: H, t: t, tint: Color(hex: 0xB4C4D8))
                petals(W: W, H: H, t: t, tint: Color(hex: 0xD8DEEE))
            }
        case "swiss-alps":
            ZStack {
                sunBloom(W: W, H: H, t: t)
                cirrus(W: W, H: H, t: t, tint: Color(hex: 0xEEF6F8))
                flockCrossing(W: W, H: H, t: t)
                horizonHaze(W: W, H: H, t: t, tint: Color(hex: 0xD9EDF4), y: 0.68)
                mistBreath(W: W, H: H, t: t, tint: Color(hex: 0xE7F1F4))
                distantBeacon(W: W, H: H, t: t, period: 98, salt: 0xA17)
            }
        case "sahara-night":
            ZStack {
                moonGlow(W: W, H: H, t: t)
                shootingStar(W: W, H: H, t: t, period: 15, phaseOffset: 0.08, salt: 0x11)
                shootingStar(W: W, H: H, t: t, period: 23, phaseOffset: 0.56, salt: 0x29)
                dustMotes(W: W, H: H, t: t, tint: Color(hex: 0xE8B080), count: 20)
                horizonHaze(W: W, H: H, t: t, tint: Color(hex: 0xE8A06A), y: 0.72)
                distantBeacon(W: W, H: H, t: t, period: 126, salt: 0xD35)
            }
        case "galaxy-drift":
            ZStack {
                nebulaBreath(W: W, H: H, t: t,
                             tints: [Color(hex: 0x8A6CE8), Color(hex: 0x4C6CE8), Color(hex: 0xE870B4)])
                cosmicDust(W: W, H: H, t: t, tint: Color(hex: 0xC9B7FF), count: 54)
                shootingStar(W: W, H: H, t: t, period: 12, phaseOffset: 0.10, salt: 0x41)
                shootingStar(W: W, H: H, t: t, period: 19, phaseOffset: 0.62, salt: 0x53)
                rareCelestialFragment(W: W, H: H, t: t, period: 74, salt: 0x6B)
            }
        case "deep-space":
            ZStack {
                nebulaBreath(W: W, H: H, t: t,
                             tints: [Color(hex: 0x2E3E64), Color(hex: 0x46567E), Color(hex: 0x6E7EC8)])
                cosmicDust(W: W, H: H, t: t, tint: Color(hex: 0xAFC7FF), count: 62)
                shootingStar(W: W, H: H, t: t, period: 16, phaseOffset: 0.18, salt: 0x71)
                shootingStar(W: W, H: H, t: t, period: 27, phaseOffset: 0.70, salt: 0x89)
                rareCelestialFragment(W: W, H: H, t: t, period: 92, salt: 0xA3)
            }
        default:
            EmptyView()
        }
    }

    /// A big diffused sun bloom high in the frame, breathing very slowly —
    /// pure light, no disc edge, no rings.
    private func sunBloom(W: CGFloat, H: CGFloat, t: Double) -> some View {
        var rng = SeededRNG(seed: skySeed &+ 0x50B1)
        let x = 0.3 + rng.unit() * 0.4
        let breathe = 0.75 + 0.25 * Foundation.sin(t * 0.04)
        return ZStack {
            RadialGradient(colors: [Color(hex: 0xFFF4DC).opacity(0.34 * breathe),
                                    Color(hex: 0xF6D89A).opacity(0.14 * breathe), .clear],
                           center: UnitPoint(x: x, y: 0.22), startRadius: 2, endRadius: W * 0.5)
            RadialGradient(colors: [Color.white.opacity(0.18 * breathe), .clear],
                           center: UnitPoint(x: x, y: 0.22), startRadius: 1, endRadius: W * 0.14)
        }
    }

    /// Thin illuminated cirrus streaks: each moment fades in at a seeded height,
    /// drifts a few points sideways, and fades away (~46 s cycle). Drawn as a
    /// chain of overlapping ultra-soft glows — organic, no visible ellipse.
    private func cirrus(W: CGFloat, H: CGFloat, t: Double, tint: Color) -> some View {
        Canvas { ctx, s in
            for slot in 0..<3 {
                let period = 58.0
                let shifted = t / period + Double(slot) / 3.0
                let cycle = shifted.rounded(.down)
                let local = shifted - cycle
                let env = Foundation.sin(.pi * local)                // fade in → out
                guard env > 0.02 else { continue }
                var rng = SeededRNG(seed: skySeed &+ UInt64(bitPattern: Int64(cycle)) &* 73 &+ UInt64(slot) &* 7)
                let y = Double(s.height) * (0.14 + rng.unit() * 0.3)
                let cx = Double(s.width) * (0.2 + rng.unit() * 0.6) + local * 14 - 7
                let len = Double(s.width) * (0.3 + rng.unit() * 0.25)
                let n = 7
                for k in 0..<n {
                    let f = Double(k) / Double(n - 1) - 0.5
                    let px = cx + f * len
                    let py = y + Foundation.sin(f * 3.0 + rng.unit() * 6) * Double(s.height) * 0.008
                    let bell = Foundation.cos(f * .pi) * 0.5 + 0.5
                    softGlow(&ctx, x: CGFloat(px), y: CGFloat(py),
                             r: CGFloat(Double(s.width) * 0.055 * (0.6 + bell * 0.6)),
                             color: tint.opacity(0.10 * env * bell))
                }
            }
        }
    }

    /// A small flock crossing horizontally (~every 44 s) — the only travelling
    /// element, because birds genuinely fly.
    private func flockCrossing(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            let period = 44.0
            let cycle = (t / period).rounded(.down)
            let phase = t / period - cycle
            guard phase < 0.22 else { return }
            let local = phase / 0.22
            var rng = SeededRNG(seed: skySeed &+ UInt64(bitPattern: Int64(cycle)) &* 97 &+ 3)
            let dir: Double = rng.unit() < 0.5 ? -1 : 1
            let baseY = 0.16 + rng.unit() * 0.26
            let x = (dir > 0 ? -0.12 : 1.12) + dir * 1.24 * local
            let a = Foundation.sin(.pi * min(1, local)) * 0.4 + 0.12
            for i in 0..<6 {
                let di = Double(i)
                let row = (di + 1) / 2
                let side: Double = i % 2 == 0 ? 1 : -1
                let bx = (x - dir * row * 0.032) * Double(s.width)
                let by = (baseY + side * row * 0.02) * Double(s.height)
                let flap = 0.5 + 0.5 * Foundation.sin(t * 3.4 + di * 1.4)
                let wing = 2.8 + flap * 3.2
                var p = Path()
                p.move(to: CGPoint(x: bx - wing, y: by + wing * 0.5))
                p.addLine(to: CGPoint(x: bx, y: by))
                p.addLine(to: CGPoint(x: bx + wing, y: by + wing * 0.5))
                ctx.stroke(p, with: .color(Color(hex: 0x2A2438).opacity(a)), lineWidth: 1.5)
            }
        }
    }

    /// Warm floating motes catching the light: stable seeded homes, tiny local
    /// sway, twinkling alpha — nothing streams anywhere.
    private func dustMotes(W: CGFloat, H: CGFloat, t: Double, tint: Color, count: Int) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0xD057)
            for i in 0..<count {
                let di = Double(i)
                let fx = rng.unit()
                let fy = 0.1 + rng.unit() * 0.7
                let sway = Foundation.sin(t * (0.1 + rng.unit() * 0.14) + di) * 8
                let bob = Foundation.sin(t * (0.08 + rng.unit() * 0.1) + di * 1.7) * 6
                let tw = 0.5 + 0.5 * Foundation.sin(t * (0.4 + rng.unit()) + di * 2.1)
                let a = (0.05 + 0.2 * tw)
                let x = fx * Double(s.width) + sway
                let y = fy * Double(s.height) + bob
                softGlow(&ctx, x: CGFloat(x), y: CGFloat(y),
                         r: CGFloat(1.6 + rng.unit() * 2.2), color: tint.opacity(a))
            }
        }
    }

    /// Fiji's water is already authored in the painting. These are only fine
    /// reflected highlights: short, soft strokes that breathe in place at
    /// different depths, plus a few humid glints near the island line.
    private func lagoonLight(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0xF1_711)
            for i in 0..<34 {
                let fx = rng.unit()
                let fy = 0.66 + rng.unit() * 0.29
                let depth = (fy - 0.66) / 0.29
                let rate = 0.24 + rng.unit() * 0.72
                let pulse = pow(0.5 + 0.5 * Foundation.sin(t * rate + Double(i) * 1.37), 2.1)
                let drift = Foundation.sin(t * 0.045 + Double(i)) * (2 + depth * 5)
                let x = fx * Double(s.width) + drift
                let y = fy * Double(s.height)
                let width = 3.0 + depth * 12.0 + rng.unit() * 7.0
                var line = Path()
                line.move(to: CGPoint(x: x - width / 2, y: y))
                line.addLine(to: CGPoint(x: x + width / 2, y: y))
                ctx.stroke(line, with: .linearGradient(
                    Gradient(colors: [.clear,
                                      Color(hex: 0xD8FFF3).opacity(0.10 + pulse * 0.34),
                                      .clear]),
                    startPoint: CGPoint(x: x - width / 2, y: y),
                    endPoint: CGPoint(x: x + width / 2, y: y)),
                    lineWidth: CGFloat(0.6 + depth * 1.2))
            }
            for i in 0..<10 {
                let x = CGFloat(0.08 + rng.unit() * 0.84) * s.width
                let y = CGFloat(0.56 + rng.unit() * 0.18) * s.height
                let pulse = pow(0.5 + 0.5 * Foundation.sin(t * (0.28 + rng.unit() * 0.5) + Double(i)), 2.8)
                softGlow(&ctx, x: x, y: y, r: CGFloat(2.5 + rng.unit() * 3),
                         color: Color(hex: 0xD8FFF3).opacity(0.24 * pulse))
            }
        }
    }

    /// Low, wide haze masses support the painted horizon without producing a
    /// visible band. Each mass has a different long drift and breathing rhythm.
    private func horizonHaze(W: CGFloat, H: CGFloat, t: Double,
                             tint: Color, y: Double) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0xA2_113)
            for i in 0..<4 {
                let baseX = 0.08 + rng.unit() * 0.84
                let drift = Foundation.sin(t * (0.010 + rng.unit() * 0.012) + Double(i) * 1.8)
                    * Double(s.width) * 0.055
                let breathe = 0.64 + 0.36 * Foundation.sin(t * (0.025 + rng.unit() * 0.018) + Double(i))
                softGlow(&ctx, x: CGFloat(baseX * Double(s.width) + drift),
                         y: CGFloat(y + (rng.unit() - 0.5) * 0.08) * s.height,
                         r: s.width * CGFloat(0.19 + rng.unit() * 0.12),
                         color: tint.opacity(0.055 * breathe))
            }
        }
    }

    /// Warm fixed lanterns near the architecture/path. They never travel; only
    /// their illustrated paper and the pool of light breathe independently.
    private func anchoredLanternGlow(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            let sprites = [
                ctx.resolve(Image("SkyOverlay_KyotoLantern_Ivory")),
                ctx.resolve(Image("SkyOverlay_KyotoLantern_Vermilion")),
                ctx.resolve(Image("SkyOverlay_KyotoLantern_Coral")),
            ]
            var rng = SeededRNG(seed: skySeed &+ 0xA11C)
            for i in 0..<8 {
                let x = CGFloat(0.08 + rng.unit() * 0.84) * s.width
                let y = CGFloat(0.68 + rng.unit() * 0.18) * s.height
                let side = CGFloat(8 + rng.unit() * 8)
                let pulse = 0.72 + 0.28 * Foundation.sin(t * (0.55 + rng.unit() * 0.7) + Double(i) * 1.7)
                softGlow(&ctx, x: x, y: y, r: side * 1.8,
                         color: Color(hex: 0xFFB95E).opacity(0.32 * pulse))
                let rect = CGRect(x: x - side / 2, y: y - side / 2, width: side, height: side)
                ctx.drawLayer { layer in
                    layer.opacity = 0.42 + 0.46 * pulse
                    layer.draw(sprites[i % sprites.count], in: rect)
                }
            }
        }
    }

    /// Kyoto's signature lantern river. Real illustrated lantern sprites emerge
    /// below the horizon, cross the whole sky on long staggered paths, flicker
    /// independently and disappear beyond the top. A new seeded layout is chosen
    /// only while a lantern is fully invisible, so nothing pops or teleports.
    private func lanternMoments(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            let sprites = [
                ctx.resolve(Image("SkyOverlay_KyotoLantern_Ivory")),
                ctx.resolve(Image("SkyOverlay_KyotoLantern_Vermilion")),
                ctx.resolve(Image("SkyOverlay_KyotoLantern_Coral")),
            ]
            let warm = Color(hex: 0xFFC873)
            for slot in 0..<18 {
                let period = 52.0
                let shifted = t / period + Double(slot) / 18.0
                let cycle = shifted.rounded(.down)
                let local = shifted - cycle
                let fadeIn = smoothStep(0.03, 0.16, local)
                let fadeOut = 1 - smoothStep(0.78, 0.98, local)
                let env = fadeIn * fadeOut
                guard env > 0.01 else { continue }
                var rng = SeededRNG(seed: skySeed &+ UInt64(bitPattern: Int64(cycle)) &* 53 &+ UInt64(slot) &* 11)
                let depth = rng.unit()
                let startX = 0.06 + rng.unit() * 0.88
                let endDrift = (rng.unit() - 0.5) * (0.10 + depth * 0.08)
                let startY = 1.06 + rng.unit() * 0.12
                let endY = -0.18 + (1 - depth) * 0.24
                let progress = local * local * (3 - 2 * local)
                let sway = Foundation.sin(t * (0.09 + rng.unit() * 0.10) + Double(slot) * 1.27)
                    * (3 + depth * 8)
                let x = (startX + endDrift * progress) * Double(s.width) + sway
                let y = (startY + (endY - startY) * progress) * Double(s.height)
                let side = CGFloat(10 + depth * 21)
                let flicker = 0.82 + 0.18 * Foundation.sin(t * (1.0 + rng.unit() * 1.2) + Double(slot) * 1.9)
                let alpha = env * flicker * (0.38 + depth * 0.58)
                softGlow(&ctx, x: CGFloat(x), y: CGFloat(y), r: side * 1.15,
                         color: warm.opacity(0.28 * alpha))
                let rect = CGRect(x: CGFloat(x) - side / 2, y: CGFloat(y) - side / 2,
                                  width: side, height: side)
                ctx.drawLayer { layer in
                    layer.opacity = alpha
                    layer.translateBy(x: CGFloat(x), y: CGFloat(y))
                    layer.rotate(by: .degrees(Foundation.sin(t * 0.12 + Double(slot)) * (1.2 + depth)))
                    layer.translateBy(x: -CGFloat(x), y: -CGFloat(y))
                    layer.draw(sprites[slot % sprites.count], in: rect)
                }
            }
        }
    }

    /// Delicate petals: short diagonal flutters that fade in and out locally.
    private func petals(W: CGFloat, H: CGFloat, t: Double, tint: Color) -> some View {
        Canvas { ctx, s in
            for slot in 0..<6 {
                let period = 17.0
                let shifted = t / period + Double(slot) / 6.0
                let cycle = shifted.rounded(.down)
                let local = shifted - cycle
                let env = Foundation.sin(.pi * local)
                guard env > 0.04 else { continue }
                var rng = SeededRNG(seed: skySeed &+ UInt64(bitPattern: Int64(cycle)) &* 41 &+ UInt64(slot) &* 13)
                let fx = rng.unit()
                let fy = 0.12 + rng.unit() * 0.6
                let dx = local * 40 * (rng.unit() < 0.5 ? 1 : -1)
                let dy = local * 26
                let flutter = Foundation.sin(t * 2.2 + rng.unit() * 6) * 3
                let x = fx * Double(s.width) + dx + flutter
                let y = fy * Double(s.height) + dy
                let r = 1.4 + rng.unit() * 1.4
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r * 0.6, width: r * 2, height: r * 1.2)),
                         with: .color(tint.opacity(0.4 * env)))
            }
        }
    }

    /// A soft distant moon glow — light only, no disc.
    private func moonGlow(W: CGFloat, H: CGFloat, t: Double) -> some View {
        let breathe = 0.7 + 0.3 * Foundation.sin(t * 0.03)
        return RadialGradient(colors: [Color(hex: 0xEDF2FB).opacity(0.14 * breathe), .clear],
                              center: UnitPoint(x: 0.76, y: 0.16),
                              startRadius: 2, endRadius: W * 0.4)
    }

    /// Full-width organic aurora curtains, deforming slowly. Pure gradient fill
    /// inside a hand-wavy path — no geometric edge. Each ribbon carries faint
    /// vertical curtain rays that breathe independently, so the light reads as
    /// a true hanging curtain rather than a coloured band.
    private func auroraCurtains(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            let colors = [Color(hex: 0x54E0A8), Color(hex: 0x78F0C2),
                          Color(hex: 0x4FC9DD), Color(hex: 0xA58AEC)]
            for band in 0..<4 {
                let depth = Double(band) / 3.0
                let baseY = s.height * (0.09 + CGFloat(band) * 0.105)
                let amp = s.height * CGFloat(0.035 + depth * 0.018)
                let thick = s.height * CGFloat(0.13 + depth * 0.035)
                let phase = t * (0.055 + depth * 0.045) + Double(band) * 1.73
                let path = flightAuroraRibbon(width: s.width, baseY: baseY,
                                              amp: amp, thickness: thick, phase: phase)
                let c = colors[band]
                let breathe = 0.76 + 0.24 * Foundation.sin(t * (0.035 + depth * 0.02) + Double(band))
                let g = Gradient(colors: [c.opacity(0), c.opacity((0.28 + depth * 0.14) * breathe),
                                          c.opacity(0.12 * breathe), c.opacity(0)])
                ctx.fill(path, with: .linearGradient(
                    g, startPoint: CGPoint(x: 0, y: baseY - amp),
                    endPoint: CGPoint(x: 0, y: baseY + thick + amp)))
                // Curtain rays: soft luminous columns hanging inside the ribbon,
                // each swelling on its own slow rhythm.
                for k in 0..<7 {
                    let fx = (Double(k) + 0.5) / 7.0
                    let sway = Foundation.sin(t * 0.05 + Double(k) * 1.7 + Double(band)) * 0.03
                    let x = CGFloat(fx + sway) * s.width
                    let wave = Foundation.sin(Double(x) / 120.0 + phase)
                        + 0.4 * Foundation.sin(Double(x) / 51.0 + phase * 1.6)
                    let topY = baseY + CGFloat(wave) * amp
                    let pulse = 0.5 + 0.5 * Foundation.sin(t * (0.16 + Double(k) * 0.04) + Double(k) * 2.3 + Double(band) * 1.1)
                    let rayA = (0.075 + depth * 0.045) * pulse
                    guard rayA > 0.015 else { continue }
                    var ray = Path()
                    ray.move(to: CGPoint(x: x, y: topY))
                    ray.addLine(to: CGPoint(x: x, y: topY + thick * CGFloat(0.7 + 0.3 * pulse)))
                    ctx.stroke(ray, with: .linearGradient(
                        Gradient(colors: [c.opacity(rayA), c.opacity(0)]),
                        startPoint: CGPoint(x: x, y: topY),
                        endPoint: CGPoint(x: x, y: topY + thick)),
                        lineWidth: s.width * 0.02)
                }
            }
        }
        .blur(radius: 3)
    }

    /// A rare, restrained vertical light pillar (~every 70 s), fully diffused.
    private func lightPillar(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            let period = 70.0
            let cycle = (t / period).rounded(.down)
            let phase = t / period - cycle
            guard phase < 0.2 else { return }
            let env = Foundation.sin(.pi * (phase / 0.2))
            var rng = SeededRNG(seed: skySeed &+ UInt64(bitPattern: Int64(cycle)) &* 29 &+ 5)
            let x = Double(s.width) * (0.2 + rng.unit() * 0.6)
            let n = 6
            for k in 0..<n {
                let f = Double(k) / Double(n - 1)
                let y = Double(s.height) * (0.1 + f * 0.5)
                softGlow(&ctx, x: CGFloat(x), y: CGFloat(y),
                         r: CGFloat(Double(s.width) * 0.05),
                         color: Color(hex: 0x9AE8CE).opacity(0.06 * env))
            }
        }
    }

    /// A soft glow pulsing inside the rain ceiling (never a lightning bolt).
    private func cloudGlow(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            let period = 47.0
            let cycle = (t / period).rounded(.down)
            let phase = t / period - cycle
            guard phase < 0.1 else { return }
            let env = Foundation.sin(.pi * (phase / 0.1))
            var rng = SeededRNG(seed: skySeed &+ UInt64(bitPattern: Int64(cycle)) &* 89 &+ 7)
            let x = CGFloat(0.2 + rng.unit() * 0.6) * s.width
            let y = CGFloat(0.1 + rng.unit() * 0.16) * s.height
            softGlow(&ctx, x: x, y: y, r: s.width * 0.24,
                     color: Color(hex: 0xC8D4F2).opacity(0.16 * env))
        }
    }

    /// Silver mist masses breathing and drifting a few points — never crossing.
    private func mistBreath(W: CGFloat, H: CGFloat, t: Double, tint: Color) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0x315B)
            for i in 0..<3 {
                let di = Double(i)
                let fx = 0.16 + rng.unit() * 0.68
                let fy = 0.3 + rng.unit() * 0.42
                let drift = Foundation.sin(t * 0.02 + di * 2.0) * Double(s.width) * 0.015
                let breathe = 0.7 + 0.3 * Foundation.sin(t * 0.04 + di * 1.4)
                softGlow(&ctx, x: CGFloat(fx * Double(s.width) + drift),
                         y: CGFloat(fy) * s.height,
                         r: s.width * CGFloat(0.2 + rng.unit() * 0.1),
                         color: tint.opacity(0.07 * breathe))
            }
        }
    }

    /// Slow-breathing nebula haze masses — organic colour, no boundaries.
    private func nebulaBreath(W: CGFloat, H: CGFloat, t: Double, tints: [Color]) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0x4EB0)
            for i in 0..<3 {
                let di = Double(i)
                let fx = 0.14 + rng.unit() * 0.72
                let fy = 0.12 + rng.unit() * 0.5
                let drift = Foundation.sin(t * 0.015 + di * 2.4) * Double(s.width) * 0.02
                let breathe = 0.65 + 0.35 * Foundation.sin(t * 0.03 + di * 1.9)
                softGlow(&ctx, x: CGFloat(fx * Double(s.width) + drift),
                         y: CGFloat(fy) * s.height,
                         r: s.width * CGFloat(0.24 + rng.unit() * 0.14),
                         color: tints[i % tints.count].opacity(0.11 * breathe))
            }
        }
    }

    /// Fine cosmic dust sits on a nearer visual plane than the starfield. Every
    /// speck keeps a permanent home and only orbits it by a few points.
    private func cosmicDust(W: CGFloat, H: CGFloat, t: Double,
                            tint: Color, count: Int) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0xC05D)
            for i in 0..<count {
                let baseX = rng.unit() * Double(s.width)
                let baseY = rng.unit() * Double(s.height) * 0.9
                let depth = rng.unit()
                let orbit = 2.0 + depth * 9.0
                let rate = 0.025 + rng.unit() * 0.055
                let angle = t * rate + Double(i) * 2.17
                let x = baseX + Foundation.sin(angle) * orbit
                let y = baseY + Foundation.cos(angle * 0.83) * orbit * 0.6
                let pulse = 0.45 + 0.55 * Foundation.sin(t * (0.18 + rng.unit() * 0.34) + Double(i))
                let r = CGFloat(0.55 + depth * 1.45)
                softGlow(&ctx, x: CGFloat(x), y: CGFloat(y), r: r * 2.2,
                         color: tint.opacity((0.06 + depth * 0.15) * max(0.12, pulse)))
            }
        }
    }

    /// Aurora-only suspended ice crystals. The falling weather is a separate,
    /// nearer layer; these particles drift locally in the luminous cold air.
    private func icyAir(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0x1CE)
            for i in 0..<28 {
                let fx = rng.unit()
                let fy = 0.06 + rng.unit() * 0.70
                let depth = rng.unit()
                let sway = Foundation.sin(t * (0.08 + rng.unit() * 0.09) + Double(i)) * (3 + depth * 8)
                let bob = Foundation.cos(t * (0.06 + rng.unit() * 0.08) + Double(i) * 1.5) * 4
                let tw = pow(0.5 + 0.5 * Foundation.sin(t * (0.30 + rng.unit()) + Double(i)), 2.2)
                softGlow(&ctx, x: CGFloat(fx * Double(s.width) + sway),
                         y: CGFloat(fy * Double(s.height) + bob),
                         r: CGFloat(0.9 + depth * 2.2),
                         color: Color(hex: 0xD8FFF4).opacity(0.10 + tw * 0.30))
            }
        }
    }

    /// Tokyo's windows and neon pools do not switch abruptly. Small seeded
    /// groups wax and wane on unrelated long rhythms, reflected softly below.
    private func cityLightPulse(W: CGFloat, H: CGFloat, t: Double) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: skySeed &+ 0xC17A)
            let colors = [Color(hex: 0xF48DB8), Color(hex: 0x77D6EE),
                          Color(hex: 0xB39AF4), Color(hex: 0xFFD089)]
            for i in 0..<24 {
                let x = CGFloat(0.04 + rng.unit() * 0.92) * s.width
                let y = CGFloat(0.48 + rng.unit() * 0.36) * s.height
                let rate = 0.10 + rng.unit() * 0.28
                let pulse = 0.35 + 0.65 * pow(0.5 + 0.5 * Foundation.sin(t * rate + Double(i) * 1.7), 2.0)
                let color = colors[i % colors.count]
                softGlow(&ctx, x: x, y: y, r: CGFloat(3 + rng.unit() * 8),
                         color: color.opacity(0.08 + pulse * 0.18))
                if i % 3 == 0 {
                    var reflection = Path()
                    reflection.move(to: CGPoint(x: x, y: y + 2))
                    reflection.addLine(to: CGPoint(x: x, y: min(s.height, y + CGFloat(12 + rng.unit() * 22))))
                    ctx.stroke(reflection, with: .linearGradient(
                        Gradient(colors: [color.opacity(0.16 * pulse), .clear]),
                        startPoint: CGPoint(x: x, y: y),
                        endPoint: CGPoint(x: x, y: y + 34)), lineWidth: 1)
                }
            }
        }
    }

    /// A tiny far-away navigation light. It is visible only for part of a long
    /// cycle and fades at both ends; no aircraft silhouette is imposed on art.
    private func distantBeacon(W: CGFloat, H: CGFloat, t: Double,
                               period: Double, salt: UInt64) -> some View {
        Canvas { ctx, s in
            let cycle = (t / period).rounded(.down)
            let phase = t / period - cycle
            guard phase < 0.52 else { return }
            let local = phase / 0.52
            let env = Foundation.sin(.pi * local)
            var rng = SeededRNG(seed: skySeed &+ UInt64(bitPattern: Int64(cycle)) &* 107 &+ salt)
            let leftToRight = rng.unit() > 0.5
            let x = (leftToRight ? -0.04 + local * 1.08 : 1.04 - local * 1.08) * Double(s.width)
            let y = (0.14 + rng.unit() * 0.22) * Double(s.height)
            let blink = pow(max(0, Foundation.sin(t * 2.7)), 10)
            softGlow(&ctx, x: CGFloat(x), y: CGFloat(y), r: 4,
                     color: Color(hex: 0xFF745F).opacity(0.5 * env * blink))
            softGlow(&ctx, x: CGFloat(x + (leftToRight ? -4 : 4)), y: CGFloat(y), r: 2.5,
                     color: Color.white.opacity(0.34 * env))
        }
    }

    /// A rare distant cosmic fragment: small, slow and softly lit. It crosses a
    /// short arc, never the whole frame, and is completely invisible at reset.
    private func rareCelestialFragment(W: CGFloat, H: CGFloat, t: Double,
                                       period: Double, salt: UInt64) -> some View {
        Canvas { ctx, s in
            let cycle = (t / period).rounded(.down)
            let phase = t / period - cycle
            guard phase > 0.18, phase < 0.62 else { return }
            let local = (phase - 0.18) / 0.44
            let env = Foundation.sin(.pi * local)
            var rng = SeededRNG(seed: skySeed &+ UInt64(bitPattern: Int64(cycle)) &* 157 &+ salt)
            let x0 = 0.14 + rng.unit() * 0.58
            let y0 = 0.12 + rng.unit() * 0.42
            let x = (x0 + local * 0.12) * Double(s.width)
            let y = (y0 + local * 0.05) * Double(s.height)
            let r = CGFloat(1.8 + rng.unit() * 2.4)
            var shard = Path()
            shard.move(to: CGPoint(x: x - Double(r), y: y))
            shard.addLine(to: CGPoint(x: x, y: y - Double(r) * 0.55))
            shard.addLine(to: CGPoint(x: x + Double(r) * 1.35, y: y + Double(r) * 0.35))
            shard.addLine(to: CGPoint(x: x - Double(r) * 0.25, y: y + Double(r) * 0.72))
            shard.closeSubpath()
            ctx.fill(shard, with: .color(Color(hex: 0xBFD0EC).opacity(0.26 * env)))
            softGlow(&ctx, x: CGFloat(x), y: CGFloat(y), r: r * 3,
                     color: Color(hex: 0x8AA6E8).opacity(0.10 * env))
        }
    }

    /// An occasional shooting star — a natural streak with a gradient tail.
    private func shootingStar(W: CGFloat, H: CGFloat, t: Double, period: Double,
                              phaseOffset: Double = 0, salt: UInt64 = 0) -> some View {
        Canvas { ctx, s in
            let shifted = t / period + phaseOffset
            let cycle = shifted.rounded(.down)
            let phase = shifted - cycle
            guard phase < 0.16 else { return }
            let local = phase / 0.16
            var rng = SeededRNG(seed: skySeed &+ UInt64(bitPattern: Int64(cycle)) &* 131 &+ 7 &+ salt)
            let x0 = s.width * CGFloat(0.12 + rng.unit() * 0.76)
            let y0 = s.height * CGFloat(0.05 + rng.unit() * 0.4)
            let dir: CGFloat = rng.unit() < 0.5 ? -1 : 1
            let travel = s.width * 0.4 * CGFloat(local)
            let head = CGPoint(x: x0 - dir * travel, y: y0 + travel * 0.4)
            let tail = CGPoint(x: head.x + dir * 80, y: head.y - 34)
            let a = Foundation.sin(.pi * local) * 0.8
            var p = Path()
            p.move(to: tail)
            p.addLine(to: head)
            let g = Gradient(colors: [Color.white.opacity(0), Color(hex: 0xE6F2FF).opacity(a)])
            ctx.stroke(p, with: .linearGradient(g, startPoint: tail, endPoint: head), lineWidth: 1.5)
            ctx.fill(Path(ellipseIn: CGRect(x: head.x - 1.6, y: head.y - 1.6, width: 3.2, height: 3.2)),
                     with: .color(.white.opacity(a)))
        }
    }

    // MARK: 5 — Weather (rain / snow fall naturally; they are weather, not scenery)

    @ViewBuilder private func weather(W: CGFloat, H: CGFloat, t: Double) -> some View {
        switch sky.flightParticles {
        case .none, .lanterns:
            EmptyView()   // lanterns are an effect moment, not falling weather
        case .snow:
            Canvas { ctx, s in
                var rng = SeededRNG(seed: skySeed &+ 0x5A0F)
                let span = Double(s.height) + 40
                let count = sky.id == "aurora-snowfield" ? 68 : 42
                for i in 0..<count {
                    let di = Double(i)
                    let fx = rng.unit(); let fy = rng.unit()
                    let depth = rng.unit()
                    let speed = 10.0 + depth * 25.0
                    let y = (fy * span + t * speed).truncatingRemainder(dividingBy: span) - 20
                    let sway = Foundation.sin(t * (0.30 + rng.unit() * 0.75) + di) * (3 + depth * 11)
                    let x = fx * Double(s.width) + sway
                    let r = 0.65 + depth * 2.25
                    softGlow(&ctx, x: CGFloat(x), y: CGFloat(y), r: CGFloat(r),
                             color: .white.opacity(0.20 + depth * 0.48))
                }
            }
        case .rain:
            Canvas { ctx, s in
                var rng = SeededRNG(seed: skySeed &+ 0x0A17)
                let span = Double(s.height) + 40
                for _ in 0..<92 {
                    let fx = rng.unit(); let fy = rng.unit()
                    let depth = rng.unit()
                    let speed = 150.0 + depth * 175.0
                    let y = (fy * span + t * speed).truncatingRemainder(dividingBy: span) - 20
                    let x = fx * Double(s.width) - y * (0.035 + depth * 0.035)
                    let len = 7.0 + depth * 17.0
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x - len * (0.10 + depth * 0.06), y: y + len))
                    ctx.stroke(p, with: .color(Color(hex: 0xC9DCF6).opacity(0.08 + depth * 0.23)),
                               lineWidth: CGFloat(0.65 + depth * 0.75))
                }
            }
        }
    }

    // MARK: 6 — (The old static Ground plate has been removed.)
    //
    // The bottom of the world is now the integrated SkyDepthScenery, whose
    // authored per-Sky planes skirt to the physical bottom of the frame. There
    // is no separate Ground image/silhouette layer any more — it read as a
    // frozen foreground card sitting in front of the living parallax scenery.

    #if DEBUG
    private func inspector(t: Double) -> some View {
        let seg = SkyGradientTimeline.segmentInfo(skyID: sky.id, at: t)
        return VStack(alignment: .leading, spacing: 2) {
            Text("sky \(sky.id) · seed \(seed)")
            Text("palette segment \(seg.index) · blend \(Int(seg.blend * 100))%")
            Text(String(format: "elapsed %.1fs · clock %@", t, animated ? "live" : "static"))
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white)
        .padding(6)
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 60)
        .padding(.leading, 10)
    }
    #endif
}

// MARK: - The per-Sky gradient timeline

/// Authored palette keyframes per Sky (5 stops, top → bottom). The sky blends
/// between neighbouring keyframes over ~70 s each, ping-pong looped so every
/// transition — including the turnaround — is perfectly smooth. Every keyframe
/// belongs to the Sky's colour family: Golden Hour never leaves warm light.
enum SkyGradientTimeline {
    static let segmentDuration: Double = 70

    static func stops(skyID: String, at t: Double) -> [Color] {
        let frames = timelines[skyID] ?? timelines["golden-hour"]!
        let info = segmentInfo(skyID: skyID, at: t)
        let a = frames[info.index]
        let b = frames[info.nextIndex]
        let e = smooth(info.blend)
        var out: [Color] = []
        for i in 0..<min(a.count, b.count) {
            out.append(lerpHex(a[i], b[i], e))
        }
        return out
    }

    /// Ping-pong indexing: 0,1,…,n-1,n-2,…,0,1,… — no wrap seam ever.
    static func segmentInfo(skyID: String, at t: Double) -> (index: Int, nextIndex: Int, blend: Double) {
        let frames = timelines[skyID] ?? timelines["golden-hour"]!
        let n = frames.count
        guard n > 1 else { return (0, 0, 0) }
        let pos = max(0, t) / segmentDuration
        let seg = Int(pos)
        let blend = pos - Double(seg)
        let cycle = 2 * (n - 1)
        let m = seg % cycle
        let i = m < n - 1 ? m : cycle - m
        let j = m < n - 1 ? i + 1 : i - 1
        return (i, max(0, min(n - 1, j)), blend)
    }

    private static func smooth(_ x: Double) -> Double { x * x * (3 - 2 * x) }

    private static func lerpHex(_ a: UInt, _ b: UInt, _ f: Double) -> Color {
        let ar = Double((a >> 16) & 0xFF), ag = Double((a >> 8) & 0xFF), ab = Double(a & 0xFF)
        let br = Double((b >> 16) & 0xFF), bg = Double((b >> 8) & 0xFF), bb = Double(b & 0xFF)
        return Color(red: (ar + (br - ar) * f) / 255,
                     green: (ag + (bg - ag) * f) / 255,
                     blue: (ab + (bb - ab) * f) / 255)
    }

    /// The authored timelines. Each row is one keyframe: 5 stops top → bottom.
    static let timelines: [String: [[UInt]]] = [
        // Warm from first light to dusk: gold → honey → coral → rose → warm plum.
        "golden-hour": [
            [0x3A2338, 0x8E4A46, 0xD9814E, 0xF2A96A, 0xF6C48C],
            [0x46283C, 0x9E5648, 0xE0925A, 0xF6BE7E, 0xFAD9A8],
            [0x48223E, 0xA04A50, 0xE0745A, 0xF29B6A, 0xF6B88C],
            [0x3A1F40, 0x8A4058, 0xC96058, 0xE8906E, 0xEEB08A],
            [0x2A1838, 0x5E3450, 0x94505E, 0xBE7060, 0xD08E6A],
        ],
        "fiji-lagoon": [
            [0x0C3644, 0x156274, 0x2E96A0, 0x6CC8C4, 0xC8F0E0],
            [0x0E3E4E, 0x1A7080, 0x3AA8AC, 0x86D8CC, 0xE2FAEE],
            [0x0A3240, 0x14586C, 0x2A8C9C, 0x62C0BE, 0xBCEADC],
            [0x0E4452, 0x1E7C88, 0x46B0B0, 0x92DCD0, 0xE8FBF2],
            [0x082C3A, 0x125064, 0x268494, 0x58B8B8, 0xACE2D6],
        ],
        "kyoto-lanterns": [
            [0x241534, 0x4A2A4E, 0x7E4260, 0xB86A6E, 0xE8A882],
            [0x2A1838, 0x543054, 0x8E4A66, 0xC87878, 0xF2BE94],
            [0x1E1230, 0x422648, 0x743E5C, 0xAA6068, 0xD89678],
            [0x281640, 0x502C5C, 0x86466C, 0xBE7080, 0xECAC90],
            [0x1A0F2C, 0x381F42, 0x643654, 0x985462, 0xC48470],
        ],
        "aurora-snowfield": [
            [0x04101E, 0x0A2434, 0x104C48, 0x2E9678, 0x7EDCB4],
            [0x061424, 0x0E2C40, 0x166058, 0x3CB08C, 0x96E8C4],
            [0x040E1C, 0x0A2030, 0x0E4450, 0x2A8880, 0x6ED0BE],
            [0x081828, 0x123448, 0x1C6862, 0x48BC9A, 0xA6ECCE],
            [0x030B18, 0x081C2C, 0x0C3A44, 0x227670, 0x5EC4AE],
        ],
        "rainy-tokyo": [
            [0x0A0F20, 0x141E38, 0x243354, 0x3E4E78, 0x5C6A9A],
            [0x0C1224, 0x18243E, 0x2A3A5E, 0x485A84, 0x6E7EA8],
            [0x080D1C, 0x121B34, 0x202E4E, 0x384870, 0x546294],
            [0x0E1428, 0x1C2842, 0x304264, 0x50628C, 0x7888B0],
            [0x070B18, 0x101830, 0x1C2A48, 0x324068, 0x4C5A8A],
        ],
        "moon-garden": [
            [0x0C1226, 0x1C2A46, 0x35486A, 0x6A80A0, 0xB4C4D8],
            [0x101830, 0x243452, 0x405476, 0x7C92B0, 0xC8D6E6],
            [0x0A0F22, 0x18243E, 0x2E4060, 0x5E7494, 0xA6B8CE],
            [0x121A34, 0x283A58, 0x485E80, 0x8AA0BC, 0xD4E0EC],
            [0x080C1E, 0x141E36, 0x283A58, 0x54688A, 0x9AACC4],
        ],
        "swiss-alps": [
            [0x14283E, 0x2A4A66, 0x4E7A96, 0x8CB4C8, 0xE0EEF2],
            [0x18304A, 0x325674, 0x5C88A4, 0x9EC2D2, 0xEEF6F8],
            [0x102236, 0x24425C, 0x446E8C, 0x7EA8C0, 0xD2E6EE],
            [0x1C3852, 0x3A6280, 0x6896B0, 0xACCCDA, 0xF4FAFA],
            [0x0E1E30, 0x1F3A54, 0x3C6284, 0x729CB6, 0xC4DCE8],
        ],
        "sahara-night": [
            [0x120C24, 0x2E1C3E, 0x583452, 0x94585A, 0xD08A5E],
            [0x160E2A, 0x362246, 0x643C58, 0xA46460, 0xDC9866],
            [0x0E0A20, 0x281838, 0x4E2E4C, 0x845052, 0xBE7C58],
            [0x1A1230, 0x3E284E, 0x704460, 0xB47066, 0xE8A66E],
            [0x0B081C, 0x221430, 0x442846, 0x74464C, 0xAA6E52],
        ],
        "galaxy-drift": [
            [0x0A0620, 0x1E1148, 0x3C2472, 0x6E44A8, 0xA878D0],
            [0x0C0826, 0x241554, 0x462C80, 0x7E52B8, 0xBC8ADC],
            [0x080518, 0x180D3C, 0x321E64, 0x5E3A98, 0x9468C4],
            [0x0E0A2C, 0x2A1960, 0x50338C, 0x8A5CC4, 0xC896E4],
            [0x060412, 0x120A30, 0x281852, 0x4E3084, 0x8058B4],
        ],
        "deep-space": [
            [0x020308, 0x060B18, 0x0E1630, 0x1E2A4E, 0x3A4A72],
            [0x030410, 0x080E20, 0x121C3A, 0x263458, 0x46567E],
            [0x010206, 0x050912, 0x0B1226, 0x182242, 0x303E64],
            [0x04051A, 0x0A1228, 0x162244, 0x2E3E62, 0x526288],
            [0x010204, 0x04070E, 0x090F1E, 0x141C38, 0x283454],
        ],
        "paris-sunset": [
            [0x32204A, 0x7A3E5E, 0xC06058, 0xEE9066, 0xF8BE8C],
            [0x3A2452, 0x8A4866, 0xD06A5E, 0xF6A070, 0xFCD0A0],
            [0x2C1C44, 0x6E3858, 0xB25654, 0xE08462, 0xF2B284],
            [0x241740, 0x5C3060, 0x9A4C64, 0xCC7470, 0xE8A488],
            [0x1C1236, 0x482852, 0x7E4260, 0xAE6468, 0xD08E7A],
        ],
    ]
}

// MARK: - Shared drawing helpers

/// A soft radial glow — the universal organic building block. Always fades
/// fully to clear, so nothing ever shows a boundary.
private func softGlow(_ ctx: inout GraphicsContext, x: CGFloat, y: CGFloat, r: CGFloat, color: Color) {
    let g = Gradient(colors: [color, color.opacity(0)])
    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
             with: .radialGradient(g, center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r))
}

private func smoothStep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
    guard edge1 > edge0 else { return x < edge0 ? 0 : 1 }
    let v = max(0, min(1, (x - edge0) / (edge1 - edge0)))
    return v * v * (3 - 2 * v)
}

/// An organic aurora ribbon: both edges wave independently, in small typed
/// steps so the type-checker stays fast.
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
