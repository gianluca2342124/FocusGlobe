import Foundation
import SwiftUI

// MARK: - World library

/// The library of sky worlds a flight can travel through. Each world owns a
/// distinct palette and set-dressing; chapters are composed into seeded,
/// curated sequences so every session feels coherent yet not identical.
enum WorldKind: CaseIterable {
    case nightValley, cloudOcean, moonSky, auroraField, violetTwilight, snowSky
    case goldenHorizon, roseDawn, starfield, deepSpace, nebulaDream, quietReturn
    // Per-Sky authored chapters (the journey rebuild): sunlight breaking through
    // clouds, turquoise lagoon air, lantern festivals, neon rain haze, evening
    // window-lights, a giant passing moon, meteor fields, crystalline ice air.
    case sunBreak, lagoonAir, lanternNight, cityRain, duskLights, moonHalo
    case cometField, iceCrystal

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
        case .sunBreak:       return "Sun Break"
        case .lagoonAir:      return "Lagoon Air"
        case .lanternNight:   return "Lantern Night"
        case .cityRain:       return "City Rain"
        case .duskLights:     return "Dusk Lights"
        case .moonHalo:       return "Moon Halo"
        case .cometField:     return "Comet Field"
        case .iceCrystal:     return "Ice Crystal"
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
        case .sunBreak:       return Color(hex: 0x33395C)
        case .lagoonAir:      return Color(hex: 0x14485A)
        case .lanternNight:   return Color(hex: 0x1A1434)
        case .cityRain:       return Color(hex: 0x0E1428)
        case .duskLights:     return Color(hex: 0x2E2148)
        case .moonHalo:       return Color(hex: 0x101A30)
        case .cometField:     return Color(hex: 0x060A1C)
        case .iceCrystal:     return Color(hex: 0x1E3448)
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
        case .sunBreak:       return Color(hex: 0x7A5F62)
        case .lagoonAir:      return Color(hex: 0x2E7C86)
        case .lanternNight:   return Color(hex: 0x3A2450)
        case .cityRain:       return Color(hex: 0x223052)
        case .duskLights:     return Color(hex: 0x5C3A5E)
        case .moonHalo:       return Color(hex: 0x24344E)
        case .cometField:     return Color(hex: 0x101A38)
        case .iceCrystal:     return Color(hex: 0x3E5C74)
        }
    }

    /// The dominant light this chapter casts on the atmosphere — drives the
    /// journey's environment-lighting veil so illumination evolves with the
    /// composition (see `SkyEnvironmentLighting`).
    var lightColor: Color {
        switch self {
        case .nightValley:    return Color(hex: 0xE8C48A)
        case .cloudOcean:     return Color(hex: 0xF2DFC0)
        case .moonSky:        return Color(hex: 0xEDF2FB)
        case .auroraField:    return Color(hex: 0x54E0A8)
        case .violetTwilight: return Color(hex: 0xB9A8E8)
        case .snowSky:        return Color(hex: 0xCFE2F2)
        case .goldenHorizon:  return Color(hex: 0xEFD9A8)
        case .roseDawn:       return Color(hex: 0xE8B4B8)
        case .starfield:      return Color(hex: 0x8F7BE8)
        case .deepSpace:      return Color(hex: 0x6E7EC8)
        case .nebulaDream:    return Color(hex: 0x8A6CE8)
        case .quietReturn:    return Color(hex: 0xE8B080)
        case .sunBreak:       return Color(hex: 0xF6E2B0)
        case .lagoonAir:      return Color(hex: 0xA8F0DC)
        case .lanternNight:   return Color(hex: 0xFFC873)
        case .cityRain:       return Color(hex: 0x8FA6D8)
        case .duskLights:     return Color(hex: 0xF6C88A)
        case .moonHalo:       return Color(hex: 0xEDF2FB)
        case .cometField:     return Color(hex: 0xD9F0FF)
        case .iceCrystal:     return Color(hex: 0xCFE2F2)
        }
    }
}

/// One chapter of a flight: a world plus the seed that varies its dressing
/// (star density, cloud arrangement, moon side, aurora phase…).
struct ChapterSpec {
    let kind: WorldKind
    let seed: UInt64
}

// MARK: - Per-Sky palette contract

/// The gradient + light colours one chapter renders with.
struct ChapterPalette {
    let top: Color
    let mid: Color
    let light: Color
}

/// **The per-Sky palette contract.** Chapters are shared *composition*
/// primitives (clouds, light shafts, lanterns…), but their colour field must
/// belong to the selected Sky's family — Golden Hour can never drift into
/// steel blue just because a shared chapter's default palette is cold. Any
/// (sky, chapter) pair listed here renders with the Sky's own warm/cold family;
/// unlisted pairs fall back to the chapter's default (used only where that
/// default already matches the Sky's contract).
enum SkyPaletteContract {
    static func palette(skyID: String, kind: WorldKind) -> ChapterPalette {
        if let c = overrides[skyID]?[kind] { return c }
        return ChapterPalette(top: kind.topColor, mid: kind.midColor, light: kind.lightColor)
    }

    static func lightColor(skyID: String, kind: WorldKind) -> Color {
        palette(skyID: skyID, kind: kind).light
    }

    private static func p(_ t: UInt, _ m: UInt, _ l: UInt) -> ChapterPalette {
        ChapterPalette(top: Color(hex: t), mid: Color(hex: m), light: Color(hex: l))
    }

    /// Sky → (chapter → palette). Only cross-family pairs need entries.
    private static let overrides: [String: [WorldKind: ChapterPalette]] = [
        // Golden Hour: cream · gold · amber · coral · terracotta · auburn — never cold blue.
        "golden-hour": [
            .goldenHorizon: p(0x52303E, 0x8E5240, 0xF2C488),   // takeoff / warm dusk reprise
            .cloudOcean:    p(0x8E4A42, 0xD08A52, 0xF2DFC0),   // amber cloud valleys
            .sunBreak:      p(0x6E3A3A, 0xC9744A, 0xF6E2B0),   // honey light breaking through
            .roseDawn:      p(0x5C3348, 0xA85862, 0xE8B4B8),   // intense coral-rose sunset
        ],
        // Fiji: turquoise · aqua · sea-green · white sunlight.
        "fiji-lagoon": [
            .cloudOcean:    p(0x186270, 0x46A0A8, 0xEAFBF4),
            .sunBreak:      p(0x0F4656, 0x2E8E92, 0xF2FFF8),
        ],
        // Kyoto: warm violet · plum · lantern gold (its moon chapter stays warm-violet).
        "kyoto-lanterns": [
            .moonSky:       p(0x241A3E, 0x402C56, 0xE8C8A0),
        ],
        // Paris: peach · rose · warm violet — its cloud fields are romantic rose.
        "paris-sunset": [
            .cloudOcean:    p(0x6E3A52, 0xB86A6E, 0xF2BE8C),
        ],
        // Swiss Alps: clean sky blue · icy white · sparing gold.
        "swiss-alps": [
            .sunBreak:      p(0x2E4E6E, 0x7FA0BE, 0xF6D9B4),
        ],
        // Sahara: warm dark indigo · sand gold — its moonlit chapter stays warm.
        "sahara-night": [
            .moonSky:       p(0x1E1834, 0x3A2C4E, 0xE8B080),
        ],
    ]
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

    /// One-entry memo: the same session seed (and Sky identity) always yields
    /// the same sequence, so rebuilding per body evaluation would be pure waste.
    @MainActor private static var cached: (seed: UInt64, opening: Int?, pool: [WorldKind]?, specs: [ChapterSpec])?

    /// `pool` pins the whole session inside one Sky's chapter family (its
    /// recognizable identity); otherwise `opening` biases just the first
    /// chapters, and `nil`/`nil` keeps the fully seeded journey.
    @MainActor static func sequence(seed: UInt64, opening: Int? = nil,
                                    pool: [WorldKind]? = nil) -> [ChapterSpec] {
        if let cached, cached.seed == seed, cached.opening == opening, cached.pool == pool {
            return cached.specs
        }
        let specs = build(seed: seed, opening: opening, pool: pool)
        cached = (seed, opening, pool, specs)
        return specs
    }

    private static func build(seed: UInt64, opening forcedOpening: Int?,
                              pool: [WorldKind]?) -> [ChapterSpec] {
        // A Sky-identity flight: open through the Sky's own chapters in order,
        // then keep drifting inside that family — evolving, never leaving.
        if let pool, !pool.isEmpty {
            var specs: [ChapterSpec] = pool.enumerated().map { i, kind in
                ChapterSpec(kind: kind, seed: seed &+ UInt64(i) &* 0x9E37_79B9)
            }
            var k = 0
            while specs.count < 940 {
                let kind = pool[k % pool.count]
                if kind != specs[specs.count - 1].kind || pool.count == 1 {
                    specs.append(ChapterSpec(kind: kind,
                                             seed: seed &+ UInt64(specs.count) &* 0x9E37_79B9))
                }
                k += 1
            }
            return specs
        }
        var rng = SeededRNG(seed: seed == 0 ? 0xF0C0_5155 : seed)
        let seededIndex = Int(rng.unit() * Double(openings.count)) % openings.count
        let openingIndex = forcedOpening.map { max(0, min(openings.count - 1, $0)) } ?? seededIndex
        let opening = openings[openingIndex]
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
    /// Biases the opening chapters toward the selected Sky (see
    /// `FlightWorldSequence.openings`); `nil` keeps the seeded opening.
    var openingBias: Int? = nil
    /// Pins the whole flight inside one Sky's chapter family (the Sky-identity
    /// flight). Takes precedence over `openingBias`.
    var skyPool: [WorldKind]? = nil
    /// The Sky's own weather riding inside the scrolling world.
    var skyParticles: FocusSky.FlightParticle = .none
    /// **The modern path.** When the flight's Sky is known, the whole session is
    /// rendered by the stable per-Sky scene (`SkyFlightSceneView`) — one place,
    /// one identity, no chapter cycling, no seams. The legacy chapter tape below
    /// remains only for sessions without a resolvable Sky (old resumes).
    var focusSky: FocusSky? = nil

    var body: some View {
        if let focusSky {
            // The authoritative journey renderer: the Sky's authored chapter tape
            // riding under the per-Sky overlays (weather / life / celestial /
            // ground). Exterior, Cabin and previews all pass through here.
            SkyFlightSceneView(sky: focusSky, elapsed: elapsed, animated: animated, seed: seed)
        } else {
            legacyTape
        }
    }

    private var legacyTape: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = max(1, geo.size.height)
            let seq = FlightWorldSequence.sequence(seed: seed, opening: openingBias, pool: skyPool)
            ZStack {
                Color(hex: 0x0D1322)

                TimelineView(.animation(minimumInterval: animated ? 1.0 / 30.0 : 5.0)) { ctx in
                    let t = animated ? ctx.date.timeIntervalSinceReferenceDate : 0
                    let scroll = max(0, elapsed()) / FlightWorldSequence.chapterDuration
                    let last = seq.count - 2
                    let i = min(last, Int(scroll))
                    let frac = CGFloat(min(1, max(0, scroll - Double(i))))
                    // Two stacked chapters slide as one tape. The scenery AND its
                    // living detail (twinkles, shooting stars, sparkles) both ride
                    // *inside* these cells, so everything scrolls downward together
                    // behind the fixed balloon — nothing sits in screen space.
                    VStack(spacing: 0) {
                        chapterCell(spec: seq[i + 1], bottomEdge: seq[i].kind.topColor,
                                    chapterID: i + 1, t: t, W: W, H: H)
                        chapterCell(spec: seq[i],
                                    bottomEdge: i > 0 ? seq[i - 1].kind.topColor
                                                      : Color(hex: 0x0D1322),
                                    chapterID: i, t: t, W: W, H: H)
                    }
                    .frame(width: W, height: H * 2)
                    .offset(y: -H * (1 - frac))
                    .frame(width: W, height: H, alignment: .top)
                    .clipped()
                }
            }
            .frame(width: W, height: H)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// One scrolling cell of the tape: the static scenery for a chapter with its
    /// animated life (twinkles, shooting stars, sparkles) layered on top **inside
    /// the same cell**, so both scroll together as the tape slides. Nothing here
    /// is pinned to the screen — only the balloon and UI are.
    @ViewBuilder
    private func chapterCell(spec: ChapterSpec, bottomEdge: Color, chapterID: Int,
                             t: Double, W: CGFloat, H: CGFloat) -> some View {
        ZStack {
            ChapterSectionView(spec: spec, bottomEdge: bottomEdge, width: W, height: H)
                .id(chapterID)
            ChapterLifeCanvas(seed: spec.seed, kind: spec.kind, particles: skyParticles,
                              t: t, width: W, height: H)
        }
        .frame(width: W, height: H)
    }
}

// MARK: - Chapter renderer (static per chapter; rebuilt once a minute)

private struct ChapterSectionView: View {
    let spec: ChapterSpec
    let bottomEdge: Color
    let width: CGFloat
    let height: CGFloat
    /// The Sky's palette for this chapter (see `SkyPaletteContract`); nil uses
    /// the chapter's default colours (legacy skyless tape).
    var palette: ChapterPalette? = nil

    /// Element sizes key off the shorter side so iPad/Mac stay elegant, never
    /// blown up; positions stay fractional so nothing crops oddly.
    private var ref: CGFloat { min(width, height) }

    var body: some View {
        let top = palette?.top ?? spec.kind.topColor
        let mid = palette?.mid ?? spec.kind.midColor
        ZStack {
            LinearGradient(colors: [top, mid, bottomEdge],
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
        case .sunBreak:       sunBreak
        case .lagoonAir:      lagoonAir
        case .lanternNight:   lanternNight
        case .cityRain:       cityRain
        case .duskLights:     duskLights
        case .moonHalo:       moonHalo
        case .cometField:     cometField
        case .iceCrystal:     iceCrystal
        }
    }

    // MARK: Worlds

    // Distant city glow inside night haze — NO terrain (mountains may never
    // appear mid-flight; the take-off ground plate is the only ground, ever).
    private var nightValley: some View {
        ZStack {
            starsCanvas(count: 40 + seededInt(0, 20, salt: 1), brightness: 0.55, heightFraction: 0.65)
            glow(Color(hex: 0xE8C48A), alpha: 0.12, radius: ref * 0.55,
                 x: 0.5, y: 0.66)
            fogBand(y: 0.6, tint: Color(hex: 0xAAB8D0), alpha: 0.12)
            windowLights
            fogBand(y: 0.86, tint: Color(hex: 0x1B2A45), alpha: 0.3)
        }
    }

    // A cloud *valley*, not a cloud wall: exactly two distinct banks with open
    // sky between them, a lit gap the eye travels through, and a thin ribbon.
    // Clouds never stack into a full-width mountain here.
    private var cloudOcean: some View {
        let leftLow = seededBool(salt: 30)
        return ZStack {
            glow(Color(hex: 0xF2DFC0), alpha: 0.22, radius: ref * 0.6,
                 x: leftLow ? 0.68 : 0.32, y: 0.42)
            cloudBank(salt: 31, xFrac: leftLow ? 0.24 : 0.76,
                      yFrac: 0.68, scale: 0.30, alpha: 0.36)
            cloudBank(salt: 32, xFrac: leftLow ? 0.78 : 0.22,
                      yFrac: 0.30, scale: 0.20, alpha: 0.24)
            wisp(y: 0.52, w: 0.55, alpha: 0.10)
        }
    }

    /// One self-contained billowing bank (a single organic mass with a lit
    /// crown) — used sparingly so the sky keeps open negative space.
    private func cloudBank(salt: UInt64, xFrac: CGFloat, yFrac: CGFloat,
                           scale: CGFloat, alpha: Double) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: spec.seed &+ salt)
            let ref = min(s.width, s.height)
            let cx = s.width * xFrac + CGFloat(rng.unit() - 0.5) * s.width * 0.08
            let cy = s.height * yFrac + CGFloat(rng.unit() - 0.5) * s.height * 0.04
            let halfW = ref * scale * CGFloat(0.9 + rng.unit() * 0.3)
            drawCloud(&ctx, cx: cx, cy: cy, halfWidth: halfW,
                      tint: Color(hex: 0xF4EFE2), alpha: alpha, highlight: true, rng: &rng)
        }
    }

    private var moonSky: some View {
        let side: CGFloat = seededBool(salt: 4) ? 0.72 : 0.28
        // Sometimes a vast moon rides high and part off-screen for scale; usually
        // a calm, mid-size one. Lit from whichever side it sits on.
        let giant = seededBool(salt: 15)
        let d = giant ? min(ref * 0.62, 460) : min(ref * 0.22, 190)
        let my: CGFloat = giant ? 0.16 : 0.30
        let litLeft = side < 0.5
        return ZStack {
            starsCanvas(count: 75 + seededInt(0, 25, salt: 5), brightness: 0.75, heightFraction: 1)
            glow(Color(hex: 0xEDF2FB), alpha: 0.22, radius: d * 1.5, x: side, y: my)
            moonDisc(diameter: d, litFromLeft: litLeft)
                .position(x: width * side, y: height * my)
            // A small companion moon further into the frame.
            moonDisc(diameter: d * 0.24, litFromLeft: litLeft)
                .position(x: width * (litLeft ? side + 0.34 : side - 0.34),
                          y: height * (my + 0.26))
            wisp(y: 0.58, w: 0.72, alpha: 0.12)
            wisp(y: 0.72, w: 0.5, alpha: 0.10)
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
                PuffRow(y: 0.74, count: 5, radius: 0.24, tint: Color(hex: 0x1E1838), alpha: 0.5, highlight: false),
                PuffRow(y: 0.88, count: 4, radius: 0.3, tint: Color(hex: 0x161230), alpha: 0.6, highlight: false),
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
                PuffRow(y: 0.66, count: 5, radius: 0.22, tint: Color(hex: 0x3A3450), alpha: 0.45, highlight: false),
                PuffRow(y: 0.82, count: 6, radius: 0.26, tint: Color(hex: 0x2C2842), alpha: 0.55, highlight: false),
            ])
            starsCanvas(count: 24, brightness: 0.4, heightFraction: 0.35)
        }
    }

    // Intense sunset: broad light veils and ONE soft cloud bank — mostly open
    // glowing sky, never stacked rows.
    private var roseDawn: some View {
        ZStack {
            glow(Color(hex: 0xE8B4B8), alpha: 0.26, radius: ref * 0.66, x: 0.42, y: 0.52)
            glow(Color(hex: 0xE8865A), alpha: 0.16, radius: ref * 0.5, x: 0.64, y: 0.74)
            cloudBank(salt: 34, xFrac: 0.3, yFrac: 0.78, scale: 0.26, alpha: 0.3)
            wisp(y: 0.4, w: 0.7, alpha: 0.12)
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
        // A commanding world: sometimes vast and partly off-screen, sometimes
        // ringed. Its companion moon rides just off the sunlit shoulder.
        let giant = seededBool(salt: 16)
        let d = giant ? min(ref * 0.7, 520) : min(ref * 0.30, 250)
        let py: CGFloat = giant ? 0.30 : 0.42
        let ringed = seededBool(salt: 17)
        let litLeft = side < 0.5
        return ZStack {
            glow(Color(hex: 0x6E4AE8), alpha: 0.16, radius: ref * 0.55, x: 1 - side, y: 0.28)
            glow(Color(hex: 0x2AC8B0), alpha: 0.10, radius: ref * 0.5, x: side * 0.6, y: 0.72)
            starsCanvas(count: 120, brightness: 0.9, heightFraction: 1)
            planetDisc(diameter: d, ringed: ringed, litFromLeft: litLeft)
                .position(x: width * side, y: height * py)
            moonDisc(diameter: d * 0.14, litFromLeft: litLeft)
                .position(x: width * side + d * (litLeft ? 0.8 : -0.8),
                          y: height * py - d * 0.5)
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

    // A calm desert-night atmosphere: heavy stars over a warm horizon glow —
    // no dunes/terrain (those live only in the take-off ground plate).
    private var quietReturn: some View {
        ZStack {
            starsCanvas(count: 70, brightness: 0.6, heightFraction: 0.85)
            glow(Color(hex: 0xE8B080), alpha: 0.14, radius: ref * 0.62, x: 0.5, y: 0.9)
            fogBand(y: 0.76, tint: Color(hex: 0x9AA8C4), alpha: 0.08)
            wisp(y: 0.6, w: 0.5, alpha: 0.08)
        }
    }

    // MARK: Per-Sky authored chapters (the journey rebuild)

    /// Sunlight breaking through: a large diffused sun with a faint halo, wide
    /// light shafts, one low backlit silhouette row — and open sky everywhere else.
    private var sunBreak: some View {
        let sx = seededCG(0.36, 0.64, salt: 35)
        return ZStack {
            glow(Color(hex: 0xF6E2B0), alpha: 0.3, radius: ref * 0.7, x: Double(sx), y: 0.36)
            sunDisc(x: sx, y: 0.34)
            lightShafts
            puffRowsCanvas(rows: [
                PuffRow(y: 0.88, count: 4, radius: 0.24, tint: Color(hex: 0x3A3450), alpha: 0.4, highlight: false),
            ])
        }
    }

    /// A big, softly-bounded sun with a faint halo ring — a recognisable hero.
    private func sunDisc(x: CGFloat, y: CGFloat) -> some View {
        let d = ref * 0.30
        return ZStack {
            Circle().fill(RadialGradient(
                colors: [Color(hex: 0xFFF4DC).opacity(0.9), Color(hex: 0xF6D89A).opacity(0.5),
                         Color(hex: 0xF2B46A).opacity(0.0)],
                center: .center, startRadius: 0, endRadius: d * 0.85))
                .frame(width: d * 1.7, height: d * 1.7)
            Circle().strokeBorder(Color(hex: 0xFFF0C8).opacity(0.14), lineWidth: 1.5)
                .frame(width: d * 1.35, height: d * 1.35)
        }
        .position(x: width * x, y: height * y)
    }

    /// Wide, soft light shafts spreading down from above the frame.
    private var lightShafts: some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: spec.seed &+ 0x5AFF)
            for _ in 0..<3 {
                let cx = s.width * CGFloat(0.3 + rng.unit() * 0.4)
                let topW = s.width * CGFloat(0.05 + rng.unit() * 0.04)
                let botW = topW * 3.2
                let tilt = CGFloat(rng.unit() - 0.5) * s.width * 0.35
                var p = Path()
                p.move(to: CGPoint(x: cx - topW, y: -10))
                p.addLine(to: CGPoint(x: cx + topW, y: -10))
                p.addLine(to: CGPoint(x: cx + botW + tilt, y: s.height * 0.85))
                p.addLine(to: CGPoint(x: cx - botW + tilt, y: s.height * 0.85))
                p.closeSubpath()
                let g = Gradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0)])
                ctx.fill(p, with: .linearGradient(g, startPoint: CGPoint(x: cx, y: 0),
                                                  endPoint: CGPoint(x: cx + tilt, y: s.height * 0.85)))
            }
        }
    }

    /// Turquoise tropical air: bright clouds, ocean shimmer, islands far below
    /// (distant scenery leaving beneath — explicitly part of Fiji's concept).
    private var lagoonAir: some View {
        ZStack {
            glow(Color(hex: 0xA8F0DC), alpha: 0.22, radius: ref * 0.6, x: 0.5, y: 0.42)
            cloudBank(salt: 36, xFrac: 0.3, yFrac: 0.34, scale: 0.18, alpha: 0.26)
            cloudBank(salt: 37, xFrac: 0.74, yFrac: 0.6, scale: 0.24, alpha: 0.3)
            shimmerBand
            islandSilhouettes
        }
    }

    private var shimmerBand: some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: spec.seed &+ 0x0CEA)
            for _ in 0..<24 {
                let x = CGFloat(rng.unit()) * s.width
                let y = s.height * CGFloat(0.80 + rng.unit() * 0.16)
                let w = CGFloat(8 + rng.unit() * 20)
                ctx.fill(Path(ellipseIn: CGRect(x: x - w / 2, y: y - 1, width: w, height: 2)),
                         with: .color(Color(hex: 0xBFF2E0).opacity(0.10 + rng.unit() * 0.2)))
            }
        }
    }

    private var islandSilhouettes: some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: spec.seed &+ 0x151A)
            for _ in 0..<3 {
                let x = CGFloat(0.12 + rng.unit() * 0.76) * s.width
                let y = s.height * CGFloat(0.88 + rng.unit() * 0.08)
                let w = min(s.width, s.height) * CGFloat(0.10 + rng.unit() * 0.10)
                ctx.fill(Path(ellipseIn: CGRect(x: x - w / 2, y: y - w * 0.16, width: w, height: w * 0.32)),
                         with: .color(Color(hex: 0x0E3A40).opacity(0.30 + rng.unit() * 0.12)))
            }
        }
    }

    /// A dense lantern-festival chapter — warm lights at every depth.
    private var lanternNight: some View {
        ZStack {
            glow(Color(hex: 0xB9A8E8), alpha: 0.12, radius: ref * 0.55, x: 0.4, y: 0.3)
            starsCanvas(count: 40, brightness: 0.5, heightFraction: 0.8)
            lanternField
            fogBand(y: 0.82, tint: Color(hex: 0x2A1E44), alpha: 0.2)
        }
    }

    private var lanternField: some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: spec.seed &+ 0x1AFE)
            let warm = Color(hex: 0xFFC873)
            for _ in 0..<16 {
                let x = CGFloat(rng.unit()) * s.width
                let y = CGFloat(0.1 + rng.unit() * 0.85) * s.height
                let r = CGFloat(1.6 + rng.unit() * 3.0)
                let a = 0.25 + rng.unit() * 0.5
                let g = Gradient(colors: [warm.opacity(a), warm.opacity(0)])
                ctx.fill(Path(ellipseIn: CGRect(x: x - r * 3, y: y - r * 3, width: r * 6, height: r * 6)),
                         with: .radialGradient(g, center: CGPoint(x: x, y: y),
                                               startRadius: 0, endRadius: r * 3))
                ctx.fill(Path(ellipseIn: CGRect(x: x - r / 2, y: y - r * 0.7, width: r, height: r * 1.4)),
                         with: .color(warm.opacity(a)))
            }
        }
    }

    /// Neon reflections inside rainy night haze — Tokyo's glow chapter.
    private var cityRain: some View {
        ZStack {
            fogBand(y: 0.3, tint: Color(hex: 0x8FA6D8), alpha: 0.08)
            neonHaze
            fogBand(y: 0.78, tint: Color(hex: 0x50548E), alpha: 0.16)
            starsCanvas(count: 16, brightness: 0.3, heightFraction: 0.4)
        }
    }

    private var neonHaze: some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: spec.seed &+ 0x0C1A)
            let cols = [Color(hex: 0xE86A9E), Color(hex: 0x6AC8E8), Color(hex: 0xE8C86A), Color(hex: 0x8F7BE8)]
            for i in 0..<22 {
                let x = CGFloat(rng.unit()) * s.width
                let y = s.height * CGFloat(0.55 + rng.unit() * 0.42)
                let r = CGFloat(2 + rng.unit() * 3)
                let c = cols[i % cols.count]
                let g = Gradient(colors: [c.opacity(0.28 + rng.unit() * 0.2), c.opacity(0)])
                ctx.fill(Path(ellipseIn: CGRect(x: x - r * 3.4, y: y - r * 3.4, width: r * 6.8, height: r * 6.8)),
                         with: .radialGradient(g, center: CGPoint(x: x, y: y),
                                               startRadius: 0, endRadius: r * 3.4))
            }
        }
    }

    /// Warm evening window-lights below a violet-rose dusk — Paris / late Kyoto.
    private var duskLights: some View {
        ZStack {
            glow(Color(hex: 0xE8A8B8), alpha: 0.2, radius: ref * 0.6, x: 0.42, y: 0.4)
            starsCanvas(count: 30, brightness: 0.45, heightFraction: 0.6)
            windowLights
            wisp(y: 0.7, w: 0.6, alpha: 0.1)
        }
    }

    private var windowLights: some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: spec.seed &+ 0xD05C)
            let warm = Color(hex: 0xF6C88A)
            for _ in 0..<14 {
                let x = CGFloat(rng.unit()) * s.width
                let y = s.height * CGFloat(0.6 + rng.unit() * 0.36)
                let r = CGFloat(1.2 + rng.unit() * 1.8)
                let a = 0.3 + rng.unit() * 0.4
                let g = Gradient(colors: [warm.opacity(a), warm.opacity(0)])
                ctx.fill(Path(ellipseIn: CGRect(x: x - r * 2.6, y: y - r * 2.6, width: r * 5.2, height: r * 5.2)),
                         with: .radialGradient(g, center: CGPoint(x: x, y: y),
                                               startRadius: 0, endRadius: r * 2.6))
            }
        }
    }

    /// An enormous moon with halo rings filling much of the frame — the Moon
    /// Garden's major visual event, travelling down with the chapter.
    private var moonHalo: some View {
        let side: CGFloat = seededBool(salt: 21) ? 0.64 : 0.36
        let d = min(ref * 0.74, 560)
        return ZStack {
            starsCanvas(count: 90, brightness: 0.8, heightFraction: 1)
            glow(Color(hex: 0xEDF2FB), alpha: 0.2, radius: d * 0.9, x: side, y: 0.34)
            Circle().strokeBorder(Color(hex: 0xEDF2FB).opacity(0.10), lineWidth: 1.5)
                .frame(width: d * 1.5, height: d * 1.5)
                .position(x: width * side, y: height * 0.34)
            Circle().strokeBorder(Color(hex: 0xEDF2FB).opacity(0.05), lineWidth: 1)
                .frame(width: d * 1.9, height: d * 1.9)
                .position(x: width * side, y: height * 0.34)
            moonDisc(diameter: d, litFromLeft: side < 0.5)
                .position(x: width * side, y: height * 0.34)
            wisp(y: 0.68, w: 0.7, alpha: 0.1)
        }
    }

    /// A meteor-rich cosmic chapter: dense stars and several baked streaks
    /// (the living overlay adds moving ones on top).
    private var cometField: some View {
        ZStack {
            glow(Color(hex: 0x8F7BE8), alpha: 0.1, radius: ref * 0.5, x: 0.3, y: 0.3)
            starsCanvas(count: 150, brightness: 0.95, heightFraction: 1)
            cometStreaks
        }
    }

    private var cometStreaks: some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: spec.seed &+ 0xC03E)
            for _ in 0..<3 {
                let x = CGFloat(rng.unit()) * s.width
                let y = CGFloat(0.1 + rng.unit() * 0.6) * s.height
                let len = CGFloat(60 + rng.unit() * 90)
                let dir: CGFloat = rng.unit() < 0.5 ? -1 : 1
                let head = CGPoint(x: x, y: y)
                let tail = CGPoint(x: x + dir * len, y: y - len * 0.45)
                var p = Path()
                p.move(to: tail)
                p.addLine(to: head)
                let a = 0.3 + rng.unit() * 0.35
                let g = Gradient(colors: [Color.white.opacity(0), Color(hex: 0xD9F0FF).opacity(a)])
                ctx.stroke(p, with: .linearGradient(g, startPoint: tail, endPoint: head), lineWidth: 1.6)
                ctx.fill(Path(ellipseIn: CGRect(x: head.x - 2, y: head.y - 2, width: 4, height: 4)),
                         with: .color(.white.opacity(a + 0.2)))
            }
        }
    }

    /// Crystalline high-altitude cold air: sparkle, an ice halo arc, cold glow.
    private var iceCrystal: some View {
        ZStack {
            glow(Color(hex: 0xCFE2F2), alpha: 0.2, radius: ref * 0.55, x: 0.62, y: 0.3)
            starsCanvas(count: 40, brightness: 0.5, heightFraction: 0.8)
            speckCanvas(count: 50, alpha: 0.4, salt: 0x1CE)
            haloArc
            fogBand(y: 0.8, tint: Color(hex: 0xD8E6F2), alpha: 0.1)
        }
    }

    private var haloArc: some View {
        Circle()
            .trim(from: 0.05, to: 0.45)
            .stroke(Color.white.opacity(0.10), lineWidth: 2)
            .frame(width: ref * 0.8, height: ref * 0.8)
            .position(x: width * 0.62, y: height * 0.3)
    }

    // MARK: Shared building blocks

    private func starsCanvas(count: Int, brightness: Double, heightFraction: CGFloat) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: spec.seed &+ 0x57A2)
            // Far layer — many tiny, dim stars sit deep behind the near field,
            // so the sky has real depth rather than a single flat sprinkle.
            let farCount = count + count / 2
            for _ in 0..<farCount {
                let u1 = rng.unit()
                let u2 = rng.unit()
                let u3 = rng.unit()
                let x = CGFloat(u1) * s.width
                let y = CGFloat(u2) * s.height * heightFraction
                let r = CGFloat(0.4 + u3 * 0.7)
                let a = (0.10 + u3 * 0.26) * brightness
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(a)))
            }
            // Near layer — fewer, larger, brighter; the brightest carry a soft
            // four-point glint so a few stars read as close and luminous.
            for _ in 0..<count {
                let u1 = rng.unit()
                let u2 = rng.unit()
                let u3 = rng.unit()
                let x = CGFloat(u1) * s.width
                let y = CGFloat(u2) * s.height * heightFraction
                let r = CGFloat(0.9 + u3 * 1.7)
                let a = (0.32 + u3 * 0.6) * brightness
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(a)))
                if u3 > 0.9 {
                    let gx = x + r * 0.5
                    let gy = y + r * 0.5
                    let len = r * 3.0
                    var glint = Path()
                    glint.move(to: CGPoint(x: gx - len, y: gy))
                    glint.addLine(to: CGPoint(x: gx + len, y: gy))
                    glint.move(to: CGPoint(x: gx, y: gy - len))
                    glint.addLine(to: CGPoint(x: gx, y: gy + len))
                    ctx.stroke(glint, with: .color(.white.opacity(a * 0.5)), lineWidth: 0.6)
                }
            }
        }
    }

    private struct PuffRow {
        let y: CGFloat
        let count: Int
        let radius: CGFloat   // cloud half-width × ref
        let tint: Color
        let alpha: Double
        /// A soft top-lit crown on the upper lobes — on for lit clouds, off for
        /// flat dark silhouettes (dusk / backlit).
        var highlight: Bool = true
    }

    /// Organic clouds: each cloud is a flat-based mass of several overlapping
    /// lobes — larger in the middle, smaller at the ends — so it billows rather
    /// than reading as a row of identical circles.
    private func puffRowsCanvas(rows: [PuffRow]) -> some View {
        Canvas { ctx, s in
            var rng = SeededRNG(seed: spec.seed &+ 0x5EAC)
            let ref = min(s.width, s.height)
            for row in rows {
                let n = row.count
                for i in 0..<n {
                    let slot = n <= 1 ? 0.5 : CGFloat(i) / CGFloat(n - 1)
                    let jitterX = CGFloat(rng.unit() - 0.5) * s.width * 0.12
                    let jitterY = CGFloat(rng.unit() - 0.5) * s.height * 0.025
                    let cx = s.width * slot + jitterX
                    let cy = s.height * row.y + jitterY
                    let halfW = ref * row.radius * CGFloat(0.85 + rng.unit() * 0.5)
                    drawCloud(&ctx, cx: cx, cy: cy, halfWidth: halfW, tint: row.tint,
                              alpha: row.alpha, highlight: row.highlight, rng: &rng)
                }
            }
        }
    }

    /// Paint one billowing cloud. All maths in small typed steps so the
    /// type-checker stays fast.
    private func drawCloud(_ ctx: inout GraphicsContext, cx: CGFloat, cy: CGFloat,
                           halfWidth: CGFloat, tint: Color, alpha: Double,
                           highlight: Bool, rng: inout SeededRNG) {
        let lobes = 4 + Int(rng.unit() * 3.0)      // 4…6 lobes
        let baseY = cy + halfWidth * 0.16          // the soft flat underside
        let crown = halfWidth * 0.62               // how tall the middle billows
        // A wide, low base mattress unifies the lobes into one grounded mass.
        let baseR = halfWidth
        let baseGrad = Gradient(colors: [tint.opacity(alpha * 0.7), tint.opacity(0)])
        let baseRect = CGRect(x: cx - baseR, y: baseY - baseR * 0.34,
                              width: baseR * 2, height: baseR * 0.68)
        ctx.fill(Path(ellipseIn: baseRect),
                 with: .radialGradient(baseGrad, center: CGPoint(x: cx, y: baseY),
                                       startRadius: 0, endRadius: baseR))
        for l in 0..<lobes {
            let t = lobes <= 1 ? 0.5 : Double(l) / Double(lobes - 1)   // 0…1 across
            let bell = Foundation.sin(t * Double.pi)                   // 0 ends, 1 middle
            let jitter = rng.unit()
            let lx = cx + CGFloat(t - 0.5) * halfWidth * 1.5
            let lr = halfWidth * CGFloat(0.34 + 0.34 * bell) * CGFloat(0.8 + jitter * 0.4)
            let ly = baseY - CGFloat(bell) * crown - lr * 0.25
            let g = Gradient(colors: [tint.opacity(alpha), tint.opacity(alpha * 0.5), tint.opacity(0)])
            let rect = CGRect(x: lx - lr, y: ly - lr, width: lr * 2, height: lr * 2)
            ctx.fill(Path(ellipseIn: rect),
                     with: .radialGradient(g, center: CGPoint(x: lx, y: ly),
                                           startRadius: 0, endRadius: lr))
            if highlight && bell > 0.55 {
                let hr = lr * 0.6
                let hy = ly - lr * 0.4
                let hg = Gradient(colors: [Color.white.opacity(alpha * 0.5), Color.white.opacity(0)])
                let hrect = CGRect(x: lx - hr, y: hy - hr, width: hr * 2, height: hr * 2)
                ctx.fill(Path(ellipseIn: hrect),
                         with: .radialGradient(hg, center: CGPoint(x: lx, y: hy),
                                               startRadius: 0, endRadius: hr))
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

    private func moonDisc(diameter d: CGFloat, litFromLeft: Bool = true) -> some View {
        let lx: CGFloat = litFromLeft ? 0.34 : 0.66
        return ZStack {
            // A lit sphere: brightest toward the light, falling toward the limb.
            Circle().fill(RadialGradient(
                colors: [Color(hex: 0xFCFDFF), Color(hex: 0xDBE2F0), Color(hex: 0xAEB9D2)],
                center: UnitPoint(x: lx, y: 0.36), startRadius: 0, endRadius: d * 0.62))
            // Maria — soft grey seas of varying size.
            Circle().fill(Color(hex: 0x93A0BC).opacity(0.32))
                .frame(width: d * 0.20, height: d * 0.20)
                .offset(x: -d * 0.15, y: -d * 0.06)
            Circle().fill(Color(hex: 0x93A0BC).opacity(0.26))
                .frame(width: d * 0.12, height: d * 0.12)
                .offset(x: d * 0.13, y: d * 0.16)
            Circle().fill(Color(hex: 0x93A0BC).opacity(0.22))
                .frame(width: d * 0.08, height: d * 0.08)
                .offset(x: -d * 0.02, y: d * 0.24)
            Circle().fill(Color(hex: 0x93A0BC).opacity(0.16))
                .frame(width: d * 0.05, height: d * 0.05)
                .offset(x: d * 0.22, y: -d * 0.18)
            // Terminator — the far limb falls into shadow for a gentle phase.
            Circle().fill(RadialGradient(
                colors: [Color.clear, Color(hex: 0x0A0F1E).opacity(0.5)],
                center: UnitPoint(x: lx, y: 0.34), startRadius: d * 0.16, endRadius: d * 0.72))
            // A crisp rim of light on the sunlit edge.
            Circle().strokeBorder(Color.white.opacity(0.26), lineWidth: max(0.6, d * 0.006))
        }
        .frame(width: d, height: d)
    }

    private func planetDisc(diameter d: CGFloat, ringed: Bool = false,
                            litFromLeft: Bool = true) -> some View {
        let lx: CGFloat = litFromLeft ? 0.34 : 0.66
        let ringGrad = LinearGradient(
            colors: [Color(hex: 0xE6D7B4).opacity(0), Color(hex: 0xEADFBC).opacity(0.6),
                     Color(hex: 0xC9B788).opacity(0.35), Color(hex: 0xEADFBC).opacity(0.6),
                     Color(hex: 0xE6D7B4).opacity(0)],
            startPoint: .leading, endPoint: .trailing)
        return ZStack {
            // Ring — BACK half: a full flat ellipse drawn behind the globe. Once
            // the globe covers the middle, only the far (upper) arc reads as
            // passing behind the sphere.
            if ringed {
                Ellipse().stroke(ringGrad, lineWidth: d * 0.06)
                    .frame(width: d * 2.0, height: d * 0.60)
            }
            // The globe — soft latitudinal banding, light to deep.
            Circle().fill(LinearGradient(
                colors: [Color(hex: 0xAABDE6), Color(hex: 0x7E92C2),
                         Color(hex: 0x53628E), Color(hex: 0x3A4A72)],
                startPoint: .top, endPoint: .bottom))
            // A gentle specular bloom toward the light.
            Circle().fill(RadialGradient(colors: [Color.white.opacity(0.16), Color.clear],
                                         center: UnitPoint(x: lx, y: 0.30),
                                         startRadius: 0, endRadius: d * 0.5))
            // Terminator shadow on the far limb.
            Circle().fill(RadialGradient(colors: [Color.clear, Color(hex: 0x05070F).opacity(0.6)],
                                         center: UnitPoint(x: lx, y: 0.34),
                                         startRadius: d * 0.18, endRadius: d * 0.66))
            Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            // Ring — FRONT half: the same ellipse, masked to its lower half so the
            // near arc convincingly crosses in front of the sphere. Back + front =
            // a ring that truly encircles the planet.
            if ringed {
                Ellipse().stroke(ringGrad, lineWidth: d * 0.06)
                    .frame(width: d * 2.0, height: d * 0.60)
                    .mask {
                        Rectangle()
                            .frame(width: d * 2.0, height: d * 0.30)
                            .frame(width: d * 2.0, height: d * 0.60, alignment: .bottom)
                    }
            }
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

// MARK: - Per-chapter life (twinkles + micro-events, riding inside the scroll)

/// The living detail for one chapter, drawn in that chapter's own coordinate
/// space so it scrolls with the scenery: twinkling accent stars plus frequent,
/// seeded shooting stars and sparkle blooms. Two of these are alive at once (one
/// per visible chapter), so the world almost always has something moving — and
/// because it lives inside the scrolling cell, none of it feels stuck to the
/// screen.
private struct ChapterLifeCanvas: View {
    let seed: UInt64
    let kind: WorldKind
    var particles: FocusSky.FlightParticle = .none
    let t: Double
    let width: CGFloat
    let height: CGFloat

    /// Cold worlds get a soft snow flurry; space worlds get a distant galaxy.
    private var isCold: Bool {
        switch kind { case .snowSky, .auroraField, .iceCrystal: return true; default: return false }
    }
    private var isSpace: Bool {
        switch kind { case .starfield, .deepSpace, .nebulaDream, .cometField: return true; default: return false }
    }

    var body: some View {
        Canvas { c, s in
            if isSpace { drawGalaxy(&c, s: s) }        // far behind everything
            drawTwinkles(&c, s: s)
            drawShootingStar(&c, s: s)
            drawMeteor(&c, s: s)
            drawSparkle(&c, s: s)
            drawDistantBalloon(&c, s: s)
            // The Sky's own weather (identity), plus snow for cold chapters.
            switch particles {
            case .snow:     drawSnow(&c, s: s)
            case .rain:     drawRain(&c, s: s)
            case .lanterns: drawLanterns(&c, s: s)
            case .none:     if isCold { drawSnow(&c, s: s) }
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }

    /// Soft rain streaks drifting down and slightly sideways — cozy, not stormy.
    private func drawRain(_ c: inout GraphicsContext, s: CGSize) {
        var rng = SeededRNG(seed: seed &+ 0x0A17)
        let H = Double(s.height) + 40
        for _ in 0..<38 {
            let fx = rng.unit()
            let fy = rng.unit()
            let speed = 120.0 + rng.unit() * 90.0
            let y = (fy * H + t * speed).truncatingRemainder(dividingBy: H) - 20
            let x = fx * Double(s.width) - (y * 0.06)
            let len = 8.0 + rng.unit() * 8.0
            var p = Path()
            p.move(to: CGPoint(x: x, y: y))
            p.addLine(to: CGPoint(x: x - len * 0.14, y: y + len))
            c.stroke(p, with: .color(Color(hex: 0xBFD0EC).opacity(0.10 + rng.unit() * 0.14)),
                     lineWidth: 1)
        }
    }

    /// Warm lantern lights drifting gently down with the world — Kyoto's glow.
    private func drawLanterns(_ c: inout GraphicsContext, s: CGSize) {
        var rng = SeededRNG(seed: seed &+ 0x1A27)
        let H = Double(s.height) + 60
        for i in 0..<9 {
            let di = Double(i)
            let fx = rng.unit()
            let fy = rng.unit()
            let speed = 9.0 + rng.unit() * 8.0
            let y = (fy * H + t * speed).truncatingRemainder(dividingBy: H) - 30
            let sway = Foundation.sin(t * (0.3 + rng.unit() * 0.3) + di) * (6 + rng.unit() * 8)
            let x = fx * Double(s.width) + sway
            let r = 2.2 + rng.unit() * 2.4
            let warm = Color(hex: 0xFFC873)
            let g = Gradient(colors: [warm.opacity(0.7), warm.opacity(0)])
            c.fill(Path(ellipseIn: CGRect(x: x - r * 3.2, y: y - r * 3.2, width: r * 6.4, height: r * 6.4)),
                   with: .radialGradient(g, center: CGPoint(x: x, y: y),
                                         startRadius: 0, endRadius: CGFloat(r * 3.2)))
            c.fill(Path(ellipseIn: CGRect(x: x - r / 2, y: y - r * 0.7, width: r, height: r * 1.4)),
                   with: .color(warm.opacity(0.9)))
        }
    }

    /// Once in a while, a tiny fellow traveller drifts far away inside the
    /// world — ambient life, one balloon at most, never a crowd.
    private func drawDistantBalloon(_ c: inout GraphicsContext, s: CGSize) {
        var rng = SeededRNG(seed: seed &+ 0xBA11)
        guard rng.unit() < 0.4 else { return }          // most chapters stay empty
        let baseX = 0.14 + rng.unit() * 0.72
        let baseY = 0.18 + rng.unit() * 0.5
        let drift = Foundation.sin(t * 0.05 + rng.unit() * 6) * 0.02
        let x = (baseX + drift) * Double(s.width)
        let y = baseY * Double(s.height) + Foundation.sin(t * 0.4) * 3
        let h = 9.0 + rng.unit() * 5.0                  // tiny — far away
        let alpha = 0.30 + rng.unit() * 0.18
        let envelope = CGRect(x: x - h * 0.36, y: y - h, width: h * 0.72, height: h * 0.8)
        c.fill(Path(ellipseIn: envelope), with: .color(Color(hex: 0xF4EFE4).opacity(alpha)))
        let basket = CGRect(x: x - h * 0.09, y: y - h * 0.08, width: h * 0.18, height: h * 0.14)
        c.fill(Path(basket), with: .color(Color(hex: 0x6B4A2C).opacity(alpha)))
    }

    /// A soft radial dot — the shared building block for meteor trails and snow.
    private func softDot(_ c: inout GraphicsContext, x: CGFloat, y: CGFloat, r: CGFloat, _ color: Color) {
        let g = Gradient(colors: [color, color.opacity(0)])
        c.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
               with: .radialGradient(g, center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r))
    }

    /// A faint, slowly-drifting distant galaxy — a tilted elliptical glow with a
    /// soft bright core. Part of the scenery, so it scrolls with the chapter.
    private func drawGalaxy(_ c: inout GraphicsContext, s: CGSize) {
        var rng = SeededRNG(seed: seed &+ 0x6A1A)
        let gx = Double(0.2 + rng.unit() * 0.6) * Double(s.width)
        let gy = Double(0.14 + rng.unit() * 0.5) * Double(s.height)
        let drift = Foundation.sin(t * 0.03) * Double(s.width) * 0.01
        let r = Double(min(s.width, s.height)) * (0.22 + rng.unit() * 0.12)
        let tilt = rng.unit() * 0.8 - 0.4
        c.drawLayer { l in
            l.translateBy(x: CGFloat(gx + drift), y: CGFloat(gy))
            l.rotate(by: .radians(tilt))
            let g = Gradient(colors: [Color(hex: 0xB49CE8).opacity(0.16),
                                      Color(hex: 0x6E7EC8).opacity(0.06), .clear])
            l.fill(Path(ellipseIn: CGRect(x: -r, y: -r * 0.45, width: r * 2, height: r * 0.9)),
                   with: .radialGradient(g, center: .zero, startRadius: 0, endRadius: CGFloat(r)))
            let cg = Gradient(colors: [Color.white.opacity(0.16), .clear])
            l.fill(Path(ellipseIn: CGRect(x: -r * 0.16, y: -r * 0.08, width: r * 0.32, height: r * 0.16)),
                   with: .radialGradient(cg, center: .zero, startRadius: 0, endRadius: CGFloat(r * 0.22)))
        }
    }

    /// A rarer, brighter meteor (~every 19 s) with a warm glowing trail.
    private func drawMeteor(_ c: inout GraphicsContext, s: CGSize) {
        let period = 19.0
        let cycle = (t / period).rounded(.down)
        let phase = t / period - cycle
        guard phase < 0.22 else { return }
        let local = phase / 0.22
        var rng = SeededRNG(seed: seed &+ UInt64(bitPattern: Int64(cycle)) &* 151 &+ 5)
        let x0 = Double(s.width) * (0.1 + rng.unit() * 0.8)
        let y0 = Double(s.height) * (0.02 + rng.unit() * 0.3)
        let dir: Double = rng.unit() < 0.5 ? -1 : 1
        let travel = Double(s.width) * 0.7 * local
        let hx = x0 - dir * travel
        let hy = y0 + travel * 0.7
        let a = Foundation.sin(.pi * local)
        var i = 0
        while i < 8 {
            let f = Double(i) / 7.0
            let tx = hx + dir * travel * f * 0.5
            let ty = hy - travel * f * 0.35
            softDot(&c, x: CGFloat(tx), y: CGFloat(ty), r: CGFloat(6 * (1 - f) + 1.5),
                    Color(hex: 0xFFE7C4).opacity(a * (1 - f) * 0.4))
            i += 1
        }
        softDot(&c, x: CGFloat(hx), y: CGFloat(hy), r: 9, Color(hex: 0xFFF0D8).opacity(a * 0.6))
        c.fill(Path(ellipseIn: CGRect(x: hx - 2.6, y: hy - 2.6, width: 5.2, height: 5.2)),
               with: .color(.white.opacity(a)))
    }

    /// A soft snow flurry drifting down and swaying — for cold / aurora skies.
    private func drawSnow(_ c: inout GraphicsContext, s: CGSize) {
        var rng = SeededRNG(seed: seed &+ 0x5A0F)
        let H = Double(s.height) + 40
        for i in 0..<46 {
            let di = Double(i)
            let fx = rng.unit()
            let fy = rng.unit()
            let speed = 18.0 + rng.unit() * 26.0
            let y = (fy * H + t * speed).truncatingRemainder(dividingBy: H) - 20
            let sway = Foundation.sin(t * (0.5 + rng.unit()) + di) * (4 + rng.unit() * 8)
            let x = fx * Double(s.width) + sway
            let r = 0.8 + rng.unit() * 1.8
            let a = 0.35 + rng.unit() * 0.4
            softDot(&c, x: CGFloat(x), y: CGFloat(y), r: CGFloat(r), Color.white.opacity(a))
        }
    }

    /// Soft twinkling accent stars, seeded to this chapter.
    private func drawTwinkles(_ c: inout GraphicsContext, s: CGSize) {
        var rng = SeededRNG(seed: seed &+ 0x7ADE)
        for i in 0..<24 {
            let u1 = rng.unit()
            let u2 = rng.unit()
            let u3 = rng.unit()
            let x = CGFloat(u1) * s.width
            let y = CGFloat(u2) * s.height
            let speed = 0.6 + u3 * 1.6
            let phase = t * speed + Double(i) * 1.3
            let a = 0.10 + 0.30 * (0.5 + 0.5 * Foundation.sin(phase))
            let r = CGFloat(0.7 + u3 * 1.7)
            c.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                   with: .color(.white.opacity(a)))
        }
    }

    /// A shooting star every ~9 s (seeded per chapter, so the two live chapters
    /// stagger) — a bright head with a fading tail, streaking through the world.
    private func drawShootingStar(_ c: inout GraphicsContext, s: CGSize) {
        let period = 9.0
        let cycle = (t / period).rounded(.down)
        let phase = t / period - cycle
        guard phase < 0.28 else { return }
        let local = phase / 0.28
        var rng = SeededRNG(seed: seed &+ UInt64(bitPattern: Int64(cycle)) &* 131 &+ 3)
        let x0 = s.width * CGFloat(0.12 + rng.unit() * 0.76)
        let y0 = s.height * CGFloat(0.05 + rng.unit() * 0.55)
        let dir: CGFloat = rng.unit() < 0.5 ? -1 : 1
        let travel = s.width * 0.5 * CGFloat(local)
        let head = CGPoint(x: x0 - dir * travel, y: y0 + travel * 0.5)
        let tail = CGPoint(x: head.x + dir * 92, y: head.y - 44)
        let a = Foundation.sin(.pi * local) * 0.9
        var p = Path()
        p.move(to: tail)
        p.addLine(to: head)
        let g = Gradient(colors: [Color.white.opacity(0), Color(hex: 0xE6F2FF).opacity(a)])
        c.stroke(p, with: .linearGradient(g, startPoint: tail, endPoint: head), lineWidth: 1.6)
        c.fill(Path(ellipseIn: CGRect(x: head.x - 1.9, y: head.y - 1.9, width: 3.8, height: 3.8)),
               with: .color(.white.opacity(a)))
    }

    /// A small elegant 4-point sparkle every ~5 s, phase-shifted from the streaks.
    private func drawSparkle(_ c: inout GraphicsContext, s: CGSize) {
        let period = 5.0
        let shifted = t / period + 0.5
        let cycle = shifted.rounded(.down)
        let phase = shifted - cycle
        guard phase < 0.4 else { return }
        let local = phase / 0.4
        var rng = SeededRNG(seed: seed &+ UInt64(bitPattern: Int64(cycle)) &* 197 &+ 11)
        let cx = s.width * CGFloat(0.15 + rng.unit() * 0.7)
        let cy = s.height * CGFloat(0.1 + rng.unit() * 0.75)
        let sz = min(s.width, s.height) * 0.03
        let a = Foundation.sin(.pi * local) * 0.8
        let r = sz * 1.5
        let g = Gradient(colors: [Color.white.opacity(a * 0.5), Color.white.opacity(0)])
        c.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
               with: .radialGradient(g, center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: r))
        for k in 0..<4 {
            let ang = Double(k) / 4.0 * Double.pi
            let dx = CGFloat(Foundation.cos(ang)) * sz * 2.3
            let dy = CGFloat(Foundation.sin(ang)) * sz * 2.3
            var p = Path()
            p.move(to: CGPoint(x: cx - dx, y: cy - dy))
            p.addLine(to: CGPoint(x: cx + dx, y: cy + dy))
            let lg = Gradient(colors: [Color.white.opacity(0), Color.white.opacity(a * 0.7), Color.white.opacity(0)])
            c.stroke(p, with: .linearGradient(lg, startPoint: CGPoint(x: cx - dx, y: cy - dy),
                                              endPoint: CGPoint(x: cx + dx, y: cy + dy)), lineWidth: 1.1)
        }
    }
}

// MARK: - The Sky journey tape (restored world-tape engine, per-Sky authored)

/// The lightweight environment-light state the journey exposes so the balloon
/// and nearby atmosphere can sit *inside* the changing world (subtle veils and
/// rim tints — never a destructive recolour of balloon skins).
struct SkyEnvironmentLighting {
    let ambientColor: Color
    let highlightColor: Color
    let intensity: Double
    let glowDirection: UnitPoint
}

/// **The journey engine** — the restored world tape (from the original
/// `ActiveFlightJourneyWorldView` chapter system), pinned to one Sky's authored
/// chapter sequence. Two full-screen chapters are stacked and slid downward by
/// the pause-aware flight clock, so entire compositions enter from above,
/// travel through the frame, and exit below — the background itself evolves,
/// chapter after chapter, with seamless colour-matched seams and seeded
/// variation on every loop. One instance serves exterior flight, Cabin View
/// and premium previews (same seed + same clock ⇒ identical world state).
struct SkyJourneyTape: View {
    let sky: FocusSky
    var seed: UInt64 = 1
    /// Pause-aware elapsed journey seconds — the only source of progression.
    let elapsed: () -> Double
    var animated: Bool = true

    /// The stable per-flight journey seed: session seed × Sky identity.
    static func journeySeed(sky: FocusSky, seed: UInt64) -> UInt64 {
        var h: UInt64 = seed == 0 ? 0xF0C0 : seed
        for u in sky.id.unicodeScalars { h = (h &* 31) &+ UInt64(u.value) }
        return h
    }

    /// The chapter kind at a sequence index — pure/deterministic, mirroring the
    /// tape builder's loop (pool order first, then cycling without adjacent
    /// repeats). Cheap enough to call per frame; no cached state required.
    static func chapterKind(at index: Int, pool: [WorldKind]) -> WorldKind {
        guard !pool.isEmpty else { return .goldenHorizon }
        guard index >= 0 else { return pool[0] }
        if index < pool.count { return pool[index] }
        var lastKind = pool[pool.count - 1]
        var count = pool.count
        var k = 0
        let bail = index * 2 + pool.count * 2 + 4
        while k < bail {
            let kind = pool[k % pool.count]
            if kind != lastKind || pool.count == 1 {
                if count == index { return kind }
                lastKind = kind
                count += 1
            }
            k += 1
        }
        return pool[index % pool.count]
    }

    /// Current chapter, the chapter entering from above, and the blend fraction
    /// between them — drives the lighting veil and the DEBUG inspector.
    static func chapterInfo(sky: FocusSky, elapsed: Double)
        -> (index: Int, kind: WorldKind, nextKind: WorldKind, progress: Double) {
        let pool = sky.flightPool
        let scroll = max(0, elapsed) / FlightWorldSequence.chapterDuration
        let i = Int(scroll)
        let frac = min(1, max(0, scroll - Double(i)))
        return (i, chapterKind(at: i, pool: pool), chapterKind(at: i + 1, pool: pool), frac)
    }

    /// The journey's current environment light (blends toward the entering
    /// chapter as it takes over the frame).
    static func lighting(sky: FocusSky, elapsed: Double) -> SkyEnvironmentLighting {
        let info = chapterInfo(sky: sky, elapsed: elapsed)
        let c = info.progress < 0.5
            ? SkyPaletteContract.lightColor(skyID: sky.id, kind: info.kind)
            : SkyPaletteContract.lightColor(skyID: sky.id, kind: info.nextKind)
        var h: UInt64 = 0x11
        for u in sky.id.unicodeScalars { h = (h &* 31) &+ UInt64(u.value) }
        let x = 0.3 + Double(h % 5) * 0.1
        return SkyEnvironmentLighting(ambientColor: sky.paletteColors.first ?? .black,
                                      highlightColor: c,
                                      intensity: 0.4 + 0.2 * Foundation.sin(info.progress * .pi),
                                      glowDirection: UnitPoint(x: x, y: 0.3))
    }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = max(1, geo.size.height)
            ZStack {
                Color(hex: 0x0D1322)
                TimelineView(.animation(minimumInterval: animated ? 1.0 / 30.0 : 5.0)) { _ in
                    // Progression derives ONLY from the pause-aware journey clock:
                    // pause freezes the tape mid-slide; resume continues exactly
                    // where it stopped; background/foreground never jump.
                    let t = animated ? max(0, elapsed()) : 0
                    let jSeed = Self.journeySeed(sky: sky, seed: seed)
                    let seq = FlightWorldSequence.sequence(seed: jSeed, pool: sky.flightPool)
                    let scroll = t / FlightWorldSequence.chapterDuration
                    let last = seq.count - 2
                    let i = min(last, Int(scroll))
                    let frac = CGFloat(min(1, max(0, scroll - Double(i))))
                    VStack(spacing: 0) {
                        cell(seq: seq, index: i + 1, t: t, W: W, H: H)
                        cell(seq: seq, index: i, t: t, W: W, H: H)
                    }
                    .frame(width: W, height: H * 2)
                    .offset(y: -H * (1 - frac))
                    .frame(width: W, height: H, alignment: .top)
                    .clipped()
                }
            }
            .frame(width: W, height: H)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// One scrolling chapter cell: the authored scenery plus its living detail
    /// (twinkles, streaks, weather), both riding inside the cell so everything
    /// scrolls together. Adjacent cells share edge colours ⇒ seamless seams.
    @ViewBuilder
    private func cell(seq: [ChapterSpec], index: Int, t: Double, W: CGFloat, H: CGFloat) -> some View {
        let spec = seq[index]
        // Colours come from the Sky's palette contract, so shared chapter
        // primitives can never pull a Sky outside its colour family; seams stay
        // seamless because both cells resolve through the same contract.
        let pal = SkyPaletteContract.palette(skyID: sky.id, kind: spec.kind)
        let below = index > 0
            ? SkyPaletteContract.palette(skyID: sky.id, kind: seq[index - 1].kind).top
            : pal.mid
        ZStack {
            ChapterSectionView(spec: spec, bottomEdge: below, width: W, height: H, palette: pal)
                .id(index)
            ChapterLifeCanvas(seed: spec.seed, kind: spec.kind,
                              particles: sky.flightParticles, t: t, width: W, height: H)
        }
        .frame(width: W, height: H)
    }
}
