import Foundation
import SwiftUI

// MARK: - World library

/// The library of sky worlds a flight can travel through. Each world owns a
/// distinct palette and set-dressing; chapters are composed into seeded,
/// curated sequences so every session feels coherent yet not identical.
enum WorldKind: CaseIterable {
    case nightValley, cloudOcean, moonSky, auroraField, violetTwilight, snowSky
    case goldenHorizon, roseDawn, starfield, deepSpace, nebulaDream, quietReturn

    var displayName: String {
        switch self {
        case .nightValley:    return "Night Valley"
        case .cloudOcean:     return "Cloud Ocean"
        case .moonSky:        return "Moon Sky"
        case .auroraField:    return "Aurora Field"
        case .violetTwilight: return "Violet Twilight"
        case .snowSky:        return "Snow Sky"
        case .goldenHorizon:  return "Golden Horizon"
        case .roseDawn:       return "Rose Dawn"
        case .starfield:      return "Starfield"
        case .deepSpace:      return "Deep Space"
        case .nebulaDream:    return "Nebula Dream"
        case .quietReturn:    return "Quiet Night"
        }
    }

    /// The colour at this world's TOP edge — the chapter stacked above it ends
    /// on this exact colour, so any curated adjacency is seamless.
    var topColor: Color {
        switch self {
        case .nightValley:    return Color(hex: 0x1C2B4D)
        case .cloudOcean:     return Color(hex: 0x2E4468)
        case .moonSky:        return Color(hex: 0x16233E)
        case .auroraField:    return Color(hex: 0x0C1730)
        case .violetTwilight: return Color(hex: 0x241E44)
        case .snowSky:        return Color(hex: 0x27374F)
        case .goldenHorizon:  return Color(hex: 0x243052)
        case .roseDawn:       return Color(hex: 0x3A3658)
        case .starfield:      return Color(hex: 0x05081A)
        case .deepSpace:      return Color(hex: 0x020308)
        case .nebulaDream:    return Color(hex: 0x120E2E)
        case .quietReturn:    return Color(hex: 0x0E1424)
        }
    }

    var midColor: Color {
        switch self {
        case .nightValley:    return Color(hex: 0x24365C)
        case .cloudOcean:     return Color(hex: 0x4A6288)
        case .moonSky:        return Color(hex: 0x1E3050)
        case .auroraField:    return Color(hex: 0x11203A)
        case .violetTwilight: return Color(hex: 0x3A2F5E)
        case .snowSky:        return Color(hex: 0x3E5470)
        case .goldenHorizon:  return Color(hex: 0x4E4866)
        case .roseDawn:       return Color(hex: 0x7A5C72)
        case .starfield:      return Color(hex: 0x0A1128)
        case .deepSpace:      return Color(hex: 0x060B18)
        case .nebulaDream:    return Color(hex: 0x1E1846)
        case .quietReturn:    return Color(hex: 0x131B30)
        }
    }
}

/// One chapter of a flight: a world plus the seed that varies its dressing
/// (star density, cloud arrangement, moon side, aurora phase…).
struct ChapterSpec {
    let kind: WorldKind
    let seed: UInt64
}

/// Builds the seeded journey for a session: a curated opening sequence, then a
/// gently shuffled loop pool that keeps long and endless flights evolving
/// without obvious repetition. Precomputed once — ~15 hours of chapters.
enum FlightWorldSequence {
    /// Seconds each world stays on screen. The cinematic pace: constant and
    /// calm regardless of the chosen focus duration.
    static let chapterDuration: Double = 55

    static let openings: [[WorldKind]] = [
        [.nightValley, .cloudOcean, .moonSky, .starfield, .deepSpace],
        [.goldenHorizon, .roseDawn, .cloudOcean, .auroraField, .starfield],
        [.nightValley, .violetTwilight, .snowSky, .auroraField, .nebulaDream],
        [.moonSky, .cloudOcean, .starfield, .deepSpace, .quietReturn],
    ]

    static let loopPool: [WorldKind] = [
        .violetTwilight, .snowSky, .auroraField, .moonSky, .starfield,
        .nebulaDream, .quietReturn, .deepSpace, .cloudOcean, .roseDawn,
    ]

    /// One-entry memo: the same session seed always yields the same sequence,
    /// so rebuilding on every body evaluation would be pure waste.
    @MainActor private static var cached: (seed: UInt64, specs: [ChapterSpec])?

    @MainActor static func sequence(seed: UInt64) -> [ChapterSpec] {
        if let cached, cached.seed == seed { return cached.specs }
        let specs = build(seed: seed)
        cached = (seed, specs)
        return specs
    }

    private static func build(seed: UInt64) -> [ChapterSpec] {
        var rng = SeededRNG(seed: seed == 0 ? 0xF0C0_5155 : seed)
        let opening = openings[Int(rng.unit() * Double(openings.count)) % openings.count]
        var specs: [ChapterSpec] = opening.enumerated().map { i, kind in
            ChapterSpec(kind: kind, seed: seed &+ UInt64(i) &* 0x9E37_79B9)
        }
        // Loop chapters: rotate through the pool with a seeded offset and fresh
        // per-instance seeds; avoid the same world twice in a row at the join.
        let offset = Int(rng.unit() * Double(loopPool.count)) % loopPool.count
        var k = offset
        while specs.count < 940 {   // 940 × 55 s ≈ 14 h — beyond the 12 h cap
            let kind = loopPool[k % loopPool.count]
            if kind != specs[specs.count - 1].kind {
                specs.append(ChapterSpec(kind: kind,
                                         seed: seed &+ UInt64(specs.count) &* 0x9E37_79B9))
            }
            k += 1
        }
        return specs
    }
}

// MARK: - The journey view

/// The active-flight world: a continuous vertical journey through the world
/// library at a **constant cinematic pace**, fully decoupled from the chosen
/// focus duration. Only a sliding pair of static chapters is ever alive — the
/// current one and the one entering from above — moved by pure offset, so the
/// scene stays smooth on any device. A light overlay adds twinkle, drifting
/// foreground wisps and rare celestial events.
struct ActiveFlightJourneyWorldView: View {
    /// Live elapsed focus seconds (pause-aware), read every frame.
    let elapsed: () -> Double
    /// Stable per-session seed: world order and dressing vary between flights.
    var seed: UInt64 = 1
    var animated: Bool = true

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = max(1, geo.size.height)
            let seq = FlightWorldSequence.sequence(seed: seed)
            ZStack {
                Color(hex: 0x0D1322)

                TimelineView(.animation(minimumInterval: animated ? 1.0 / 30.0 : 5.0)) { _ in
                    let scroll = max(0, elapsed()) / FlightWorldSequence.chapterDuration
                    let last = seq.count - 2
                    let i = min(last, Int(scroll))
                    let frac = CGFloat(min(1, max(0, scroll - Double(i))))
                    // Two stacked chapters: the next world above the current one.
                    // Both are static; only this offset animates (GPU translate).
                    VStack(spacing: 0) {
                        ChapterSectionView(spec: seq[i + 1], bottomEdge: seq[i].kind.topColor,
                                           width: W, height: H)
                            .id(i + 1)
                        ChapterSectionView(spec: seq[i],
                                           bottomEdge: i > 0 ? seq[i - 1].kind.topColor
                                                             : Color(hex: 0x0D1322),
                                           width: W, height: H)
                            .id(i)
                    }
                    .frame(width: W, height: H * 2)
                    .offset(y: -H * (1 - frac))
                    .frame(width: W, height: H, alignment: .top)
                    .clipped()
                }

                if animated {
                    AmbientLifeOverlay(seed: seed)
                }
            }
            .frame(width: W, height: H)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Chapter renderer (static per chapter; rebuilt once a minute)

private struct ChapterSectionView: View {
    let spec: ChapterSpec
    let bottomEdge: Color
    let width: CGFloat
    let height: CGFloat

    /// Element sizes key off the shorter side so iPad/Mac stay elegant, never
    /// blown up; positions stay fractional so nothing crops oddly.
    private var ref: CGFloat { min(width, height) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [spec.kind.topColor, spec.kind.midColor, bottomEdge],
                           startPoint: .top, endPoint: .bottom)
            dressing
        }
        .frame(width: width, height: height)
        .clipped()
    }

    @ViewBuilder private var dressing: some View {
        switch spec.kind {
        case .nightValley:    nightValley
        case .cloudOcean:     cloudOcean
        case .moonSky:        moonSky
        case .auroraField:    auroraField
        case .violetTwilight: violetTwilight
        case .snowSky:        snowSky
        case .goldenHorizon:  goldenHorizon
        case .roseDawn:       roseDawn
        case .starfield:      starfield
        case .deepSpace:      deepSpace
        case .nebulaDream:    nebulaDream
        case .quietReturn:    quietReturn
        }
    }

    // MARK: Worlds

    private var nightValley: some View {
        ZStack {
            starsCanvas(count: 40 + seededInt(0, 20, salt: 1), brightness: 0.55, heightFraction: 0.55)
            glow(Color(hex: 0xE8C48A), alpha: 0.10, radius: ref * 0.55,
                 x: 0.5, y: 0.62)
            fogBand(y: 0.68, tint: Color(hex: 0xAAB8D0), alpha: 0.12)
            RollingHillsShape(amplitude: 0.05, phase: seededCG(0, 6, salt: 2), waves: 1.35)
                .fill(Color(hex: 0x1B2A45))
                .frame(width: width, height: height)
                .offset(y: height * 0.02)
            RollingHillsShape(amplitude: 0.065, phase: seededCG(0, 6, salt: 3), waves: 1.8)
                .fill(Color(hex: 0x0B101E))
                .frame(width: width, height: height)
                .offset(y: height * 0.12)
        }
    }

    private var cloudOcean: some View {
        ZStack {
            glow(Color(hex: 0xF2DFC0), alpha: 0.18, radius: ref * 0.62, x: 0.5, y: 0.58)
            puffRowsCanvas(rows: [
                PuffRow(y: 0.42, count: 6, radius: 0.17, tint: Color(hex: 0xDCE8F6), alpha: 0.22),
                PuffRow(y: 0.60, count: 5, radius: 0.23, tint: Color(hex: 0xE9F0FA), alpha: 0.30),
                PuffRow(y: 0.80, count: 6, radius: 0.27, tint: Color(hex: 0xF2EFE6), alpha: 0.38),
            ])
        }
    }

    private var moonSky: some View {
        let side: CGFloat = seededBool(salt: 4) ? 0.72 : 0.28
        let d = min(ref * 0.20, 170)
        return ZStack {
            starsCanvas(count: 75 + seededInt(0, 25, salt: 5), brightness: 0.75, heightFraction: 1)
            glow(Color(hex: 0xEDF2FB), alpha: 0.22, radius: d * 2.2, x: side, y: 0.32)
            moonDisc(diameter: d)
                .position(x: width * side, y: height * 0.32)
            wisp(y: 0.56, w: 0.72, alpha: 0.12)
            wisp(y: 0.70, w: 0.5, alpha: 0.10)
        }
    }

    private var auroraField: some View {
        ZStack {
            starsCanvas(count: 65, brightness: 0.7, heightFraction: 1)
            auroraCanvas(phaseSalt: 6)
            speckCanvas(count: 24, alpha: 0.30, salt: 7)
        }
    }

    private var violetTwilight: some View {
        ZStack {
            glow(Color(hex: 0xB9A8E8), alpha: 0.16, radius: ref * 0.6, x: 0.62, y: 0.34)
            starsCanvas(count: 55 + seededInt(0, 20, salt: 8), brightness: 0.6, heightFraction: 1)
            // Quiet cloud silhouettes low in the frame.
            puffRowsCanvas(rows: [
                PuffRow(y: 0.74, count: 5, radius: 0.24, tint: Color(hex: 0x1E1838), alpha: 0.5),
                PuffRow(y: 0.88, count: 4, radius: 0.3, tint: Color(hex: 0x161230), alpha: 0.6),
            ])
        }
    }

    private var snowSky: some View {
        ZStack {
            glow(Color(hex: 0xCFE2F2), alpha: 0.18, radius: ref * 0.55, x: 0.34, y: 0.30)
            starsCanvas(count: 30, brightness: 0.4, heightFraction: 0.6)
            speckCanvas(count: 40 + seededInt(0, 14, salt: 9), alpha: 0.4, salt: 10)
            fogBand(y: 0.78, tint: Color(hex: 0xD8E6F2), alpha: 0.10)
        }
    }

    private var goldenHorizon: some View {
        ZStack {
            // Restrained sunrise: one warm pool low in the frame, never orange-loud.
            glow(Color(hex: 0xEFD9A8), alpha: 0.34, radius: ref * 0.7, x: 0.5, y: 0.72)
            glow(Color(hex: 0xF6E9C8), alpha: 0.16, radius: ref * 0.4, x: 0.5, y: 0.78)
            // Backlit cloud silhouettes across the light.
            puffRowsCanvas(rows: [
                PuffRow(y: 0.66, count: 5, radius: 0.22, tint: Color(hex: 0x3A3450), alpha: 0.45),
                PuffRow(y: 0.82, count: 6, radius: 0.26, tint: Color(hex: 0x2C2842), alpha: 0.55),
            ])
            starsCanvas(count: 24, brightness: 0.4, heightFraction: 0.35)
        }
    }

    private var roseDawn: some View {
        ZStack {
            glow(Color(hex: 0xE8B4B8), alpha: 0.22, radius: ref * 0.62, x: 0.42, y: 0.6)
            puffRowsCanvas(rows: [
                PuffRow(y: 0.5, count: 6, radius: 0.19, tint: Color(hex: 0xF4E6DC), alpha: 0.26),
                PuffRow(y: 0.68, count: 5, radius: 0.24, tint: Color(hex: 0xF6EAE2), alpha: 0.32),
                PuffRow(y: 0.85, count: 6, radius: 0.27, tint: Color(hex: 0xEFE0DC), alpha: 0.36),
            ])
            starsCanvas(count: 16, brightness: 0.35, heightFraction: 0.3)
        }
    }

    private var starfield: some View {
        ZStack {
            glow(Color(hex: 0x6E4AE8), alpha: 0.10, radius: ref * 0.5, x: 0.28, y: 0.35)
            starsCanvas(count: 180 + seededInt(0, 40, salt: 11), brightness: 1.0, heightFraction: 1)
            heroStarsAndCometCanvas
        }
    }

    private var deepSpace: some View {
        let side: CGFloat = seededBool(salt: 12) ? 0.30 : 0.70
        let d = min(ref * 0.26, 210)
        return ZStack {
            glow(Color(hex: 0x6E4AE8), alpha: 0.16, radius: ref * 0.55, x: 1 - side, y: 0.28)
            glow(Color(hex: 0x2AC8B0), alpha: 0.10, radius: ref * 0.5, x: side * 0.6, y: 0.72)
            starsCanvas(count: 120, brightness: 0.9, heightFraction: 1)
            planetDisc(diameter: d)
                .position(x: width * side, y: height * 0.42)
            Circle().fill(Color(hex: 0xC9D2E4))
                .frame(width: d * 0.10, height: d * 0.10)
                .position(x: width * side + d * 0.85, y: height * 0.42 - d * 0.55)
        }
    }

    private var nebulaDream: some View {
        ZStack {
            glow(Color(hex: 0x8A6CE8), alpha: 0.20, radius: ref * 0.6, x: 0.3, y: 0.36)
            glow(Color(hex: 0x4C6CE8), alpha: 0.14, radius: ref * 0.55, x: 0.74, y: 0.6)
            glow(Color(hex: 0x3CC8C0), alpha: 0.10, radius: ref * 0.4, x: 0.5, y: 0.82)
            starsCanvas(count: 90, brightness: 0.65, heightFraction: 1)
            speckCanvas(count: 30, alpha: 0.22, salt: 13)
        }
    }

    private var quietReturn: some View {
        ZStack {
            starsCanvas(count: 50, brightness: 0.5, heightFraction: 0.7)
            fogBand(y: 0.72, tint: Color(hex: 0x9AA8C4), alpha: 0.08)
            RollingHillsShape(amplitude: 0.04, phase: seededCG(0, 6, salt: 14), waves: 1.2)
                .fill(Color(hex: 0x0A0F1E))
                .frame(width: width, height: height)
                .offset(y: height * 0.16)
        }
    }

    // MARK: Shared building blocks

    private func starsCanvas(count: Int, brightness: Double, heightFraction: CGFloat) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: spec.seed &+ 0x57A2)
            for _ in 0..<count {
                let u1 = rng.unit()
                let u2 = rng.unit()
                let u3 = rng.unit()
                let x = CGFloat(u1) * s.width
                let y = CGFloat(u2) * s.height * heightFraction
                let r = CGFloat(0.6 + u3 * 1.6)
                let a = (0.25 + u3 * 0.65) * brightness
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(a)))
            }
        }
    }

    private struct PuffRow {
        let y: CGFloat
        let count: Int
        let radius: CGFloat   // × ref
        let tint: Color
        let alpha: Double
    }

    private func puffRowsCanvas(rows: [PuffRow]) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: spec.seed &+ 0x5EAC)
            for row in rows {
                let n = row.count
                for i in 0..<n {
                    let u = rng.unit()
                    let jitterX = CGFloat(u - 0.5) * 44
                    let jitterY = CGFloat(rng.unit() - 0.5) * s.height * 0.03
                    let cx = s.width * (CGFloat(i) / CGFloat(max(1, n - 1))) + jitterX
                    let cy = s.height * row.y + jitterY
                    let radius = min(s.width, s.height) * row.radius
                    let g = Gradient(colors: [row.tint.opacity(row.alpha),
                                              row.tint.opacity(row.alpha * 0.55),
                                              row.tint.opacity(0)])
                    let rect = CGRect(x: cx - radius, y: cy - radius * 0.5,
                                      width: radius * 2, height: radius)
                    ctx.fill(Path(ellipseIn: rect),
                             with: .radialGradient(g, center: CGPoint(x: cx, y: cy),
                                                   startRadius: 0, endRadius: radius))
                }
            }
        }
    }

    private func speckCanvas(count: Int, alpha: Double, salt: UInt64) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: spec.seed &+ salt)
            for _ in 0..<count {
                let u1 = rng.unit()
                let u2 = rng.unit()
                let u3 = rng.unit()
                let x = CGFloat(u1) * s.width
                let y = CGFloat(u2) * s.height
                let r = CGFloat(0.9 + u3 * 1.3)
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(alpha)))
            }
        }
    }

    private func auroraCanvas(phaseSalt: UInt64) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: spec.seed &+ phaseSalt)
            let colors = [Color(hex: 0x54E0A8), Color(hex: 0x4FC9DD), Color(hex: 0x8F7BE8)]
            for band in 0..<3 {
                let basePhase = rng.unit() * 6.28
                let baseY = s.height * (0.26 + CGFloat(band) * 0.15)
                let amp = s.height * 0.05
                let thick = s.height * 0.15
                let path = auroraRibbonPath(width: s.width, baseY: baseY,
                                            amp: amp, thickness: thick, phase: basePhase)
                let c = colors[band]
                let g = Gradient(colors: [c.opacity(0), c.opacity(0.4), c.opacity(0)])
                ctx.fill(path, with: .linearGradient(
                    g,
                    startPoint: CGPoint(x: 0, y: baseY - amp),
                    endPoint: CGPoint(x: 0, y: baseY + thick + amp)))
            }
        }
    }

    private var heroStarsAndCometCanvas: some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: spec.seed &+ 0xB16)
            for _ in 0..<6 {
                let u1 = rng.unit()
                let u2 = rng.unit()
                let x = CGFloat(u1) * s.width
                let y = CGFloat(u2) * s.height
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 3, height: 3)),
                         with: .color(.white.opacity(0.95)))
            }
            let hx = s.width * CGFloat(0.4 + rng.unit() * 0.35)
            let hy = s.height * CGFloat(0.2 + rng.unit() * 0.25)
            let head = CGPoint(x: hx, y: hy)
            let tail = CGPoint(x: hx + 90, y: hy - 42)
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

    private func moonDisc(diameter d: CGFloat) -> some View {
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
    }

    private func planetDisc(diameter d: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0x9DB2DE), Color(hex: 0x4A5A84)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle()
                .fill(RadialGradient(colors: [Color.clear, Color(hex: 0x0A0F1E).opacity(0.6)],
                                     center: UnitPoint(x: 0.32, y: 0.36),
                                     startRadius: d * 0.2, endRadius: d * 0.62))
            Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        }
        .frame(width: d, height: d)
    }

    private func glow(_ color: Color, alpha: Double, radius: CGFloat,
                      x: CGFloat, y: CGFloat) -> some View {
        RadialGradient(colors: [color.opacity(alpha), .clear],
                       center: .center, startRadius: 2, endRadius: radius)
            .frame(width: radius * 2.2, height: radius * 2.2)
            .position(x: width * x, y: height * y)
    }

    private func fogBand(y: CGFloat, tint: Color, alpha: Double) -> some View {
        LinearGradient(colors: [tint.opacity(0), tint.opacity(alpha)],
                       startPoint: .top, endPoint: .bottom)
            .frame(height: height * 0.2)
            .position(x: width / 2, y: height * y)
    }

    private func wisp(y: CGFloat, w: CGFloat, alpha: Double) -> some View {
        Capsule()
            .fill(LinearGradient(colors: [.clear, Color(hex: 0xC9D6EC).opacity(alpha), .clear],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(width: width * w, height: 10)
            .position(x: width * (0.3 + w * 0.3), y: height * y)
    }

    // MARK: Seeded variation helpers

    private func seededInt(_ lo: Int, _ hi: Int, salt: UInt64) -> Int {
        var rng = SeededRNG(seed: spec.seed &+ salt)
        return lo + Int(rng.unit() * Double(hi - lo))
    }
    private func seededCG(_ lo: Double, _ hi: Double, salt: UInt64) -> CGFloat {
        var rng = SeededRNG(seed: spec.seed &+ salt)
        return CGFloat(lo + rng.unit() * (hi - lo))
    }
    private func seededBool(salt: UInt64) -> Bool {
        var rng = SeededRNG(seed: spec.seed &+ salt)
        return rng.unit() < 0.5
    }
}

/// An organic aurora ribbon: both edges wave independently. All maths in small
/// typed steps so the type-checker stays fast.
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

// MARK: - Ambient life + rare events (the only animated layer)

/// Twinkling stars, two slow foreground wisps, and a rare celestial event
/// roughly every 70 seconds — a shooting star, a small cluster of golden
/// sparks, or a faint cosmic shimmer. All parametric from the clock; nothing
/// allocated per frame beyond paths.
private struct AmbientLifeOverlay: View {
    let seed: UInt64

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
                drawRareEvent(&c, size: s, time: t, seed: seed)
            }
        }
        .allowsHitTesting(false)
    }

    /// One quiet event per ~70 s cycle; the kind and placement come from the
    /// cycle index + session seed, so events are deterministic per session.
    private func drawRareEvent(_ c: inout GraphicsContext, size s: CGSize,
                               time t: Double, seed: UInt64) {
        let period = 70.0
        let cycle = (t / period).rounded(.down)
        let phase = t / period - cycle
        guard phase < 0.09 else { return }   // ~6 s window per cycle
        let local = phase / 0.09
        var rng = SeededRNG(seed: seed &+ UInt64(bitPattern: Int64(cycle)) &* 97)
        let kindRoll = rng.unit()

        if kindRoll < 0.4 {
            // Shooting star.
            let x0 = s.width * CGFloat(0.25 + rng.unit() * 0.6)
            let y0 = s.height * CGFloat(0.08 + rng.unit() * 0.3)
            let travel = s.width * 0.45 * CGFloat(local)
            let head = CGPoint(x: x0 - travel, y: y0 + travel * 0.5)
            let tail = CGPoint(x: head.x + 85, y: head.y - 42)
            var p = Path()
            p.move(to: tail)
            p.addLine(to: head)
            let a = Foundation.sin(.pi * local) * 0.85
            let g = Gradient(colors: [Color.white.opacity(0), Color.white.opacity(a)])
            c.stroke(p, with: .linearGradient(g, startPoint: tail, endPoint: head), lineWidth: 1.5)
        } else if kindRoll < 0.7 {
            // A small cluster of golden sparks blooming and fading.
            let cx = s.width * CGFloat(0.3 + rng.unit() * 0.4)
            let cy = s.height * CGFloat(0.2 + rng.unit() * 0.3)
            let bloom = Foundation.sin(.pi * local)
            for i in 0..<7 {
                let ang = Double(i) / 7.0 * 6.28 + rng.unit()
                let dist = CGFloat(10.0 + 26.0 * local)
                let px = cx + CGFloat(Foundation.cos(ang)) * dist
                let py = cy + CGFloat(Foundation.sin(ang)) * dist
                let a = 0.5 * bloom
                c.fill(Path(ellipseIn: CGRect(x: px - 1.4, y: py - 1.4, width: 2.8, height: 2.8)),
                       with: .color(Color(hex: 0xE8CE9A).opacity(a)))
            }
        } else {
            // A faint cosmic shimmer — one slow soft pulse of light.
            let cx = s.width * CGFloat(0.3 + rng.unit() * 0.4)
            let cy = s.height * CGFloat(0.25 + rng.unit() * 0.3)
            let a = 0.06 * Foundation.sin(.pi * local)
            let radius = s.width * CGFloat(0.25 + 0.15 * local)
            let g = Gradient(colors: [Color.white.opacity(a), Color.white.opacity(0)])
            let rect = CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)
            c.fill(Path(ellipseIn: rect),
                   with: .radialGradient(g, center: CGPoint(x: cx, y: cy),
                                         startRadius: 0, endRadius: radius))
        }
    }
}
