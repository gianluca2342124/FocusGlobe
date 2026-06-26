import SwiftUI
import WidgetKit

// ============================================================================
//  Premium widget visual system — dark space identity, large iconic art.
//
//  Pure SwiftUI vector art (no bundled images, no MapKit) so the widget stays
//  lightweight, reliable and App Store-safe. Every component is deterministic
//  (fixed seeds) so nothing "jumps" between timeline renders.
// ============================================================================

// MARK: - Space background

/// A deterministic starfield (fixed positions, never twinkles between renders).
struct WStarfield: View {
    var count: Int = 34
    var body: some View {
        Canvas { ctx, size in
            var seed: UInt64 = 0x9E3779B97F4A7C15
            func r() -> Double {
                seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
                return Double(seed % 100_000) / 100_000.0
            }
            for _ in 0..<count {
                let x = r() * size.width
                let y = r() * size.height
                let rad = 0.5 + r() * 1.4
                let a = 0.12 + r() * 0.55
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: rad * 2, height: rad * 2)),
                         with: .color(.white.opacity(a)))
            }
        }
    }
}

/// The shared deep-space backdrop: navy→black, a faint starfield and two soft
/// glows (a coloured one + gold). Used by `fgWidgetBackground()`.
struct WSpace: View {
    var glow: Color = WTheme.indigo
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.06, green: 0.09, blue: 0.17),
                                    Color(red: 0.02, green: 0.03, blue: 0.07)],
                           startPoint: .top, endPoint: .bottom)
            WStarfield()
            RadialGradient(colors: [glow.opacity(0.26), .clear],
                           center: .topTrailing, startRadius: 2, endRadius: 250)
            RadialGradient(colors: [WTheme.gold.opacity(0.10), .clear],
                           center: .bottomLeading, startRadius: 2, endRadius: 200)
        }
    }
}

// MARK: - Glass card

/// A glassmorphism rounded card for grouping content on the space backdrop.
struct WGlassCard<Content: View>: View {
    var corner: CGFloat = 16
    var tint: Color = .white
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(Color.white.opacity(0.05)))
                    .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(tint.opacity(0.16), lineWidth: 1))
            )
    }
}

// MARK: - Flame (streak)

/// A large glowing flame with the streak count over it. Streak 0 → a calm dim
/// "ember" state (never guilt). Optional `atRisk` adds a subtle warm pulse-glow.
struct WFlame: View {
    var streak: Int
    var size: CGFloat = 64
    var showNumber: Bool = true
    var atRisk: Bool = false
    private var active: Bool { streak > 0 }

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: active ? [WTheme.coral.opacity(atRisk ? 0.65 : 0.5),
                                      WTheme.gold.opacity(0.20), .clear]
                                   : [Color.white.opacity(0.10), .clear],
                    center: .center, startRadius: 1, endRadius: size * 0.95))
                .frame(width: size * 2, height: size * 2)
            Image(systemName: "flame.fill")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(active
                    ? LinearGradient(colors: [WTheme.gold, WTheme.coral], startPoint: .top, endPoint: .bottom)
                    : LinearGradient(colors: [Color.white.opacity(0.34), Color.white.opacity(0.16)],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: active ? WTheme.coral.opacity(0.6) : .clear, radius: size * 0.18, y: 2)
            if showNumber {
                Text("\(streak)")
                    .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.55), radius: 2, y: 1)
                    .offset(y: size * 0.12)
            }
        }
        // Reserve only the nominal size in layout — the glow halo bleeds softly
        // beyond it (never clipped) so the flame stays predictable in any family.
        .frame(width: size, height: size)
    }
}

// MARK: - Earth (around-earth / passport globe)

/// A layered, illustrated globe that echoes the app's home planet — atmosphere
/// glow, ocean gradient, abstract green landmasses, a light terminator highlight
/// and a thin rim. Optionally wrapped by a progress ring + an orbiting balloon.
struct WEarth: View {
    var size: CGFloat = 70
    var ringFraction: Double? = nil
    var ringTint: Color = WTheme.teal
    var orbitBalloon: Bool = false

    private let ocean = Color(red: 0.12, green: 0.34, blue: 0.62)
    private let oceanDeep = Color(red: 0.03, green: 0.09, blue: 0.22)
    private let land = Color(red: 0.22, green: 0.56, blue: 0.42)

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [WTheme.sky.opacity(0.45), .clear],
                                     center: .center, startRadius: size * 0.42, endRadius: size * 0.8))
                .frame(width: size * 1.55, height: size * 1.55)
            globe
            if let f = ringFraction {
                Circle()
                    .trim(from: 0, to: max(0.001, min(1, f)))
                    .stroke(ringTint, style: StrokeStyle(lineWidth: max(3, size * 0.07), lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: size * 1.22, height: size * 1.22)
                    .shadow(color: ringTint.opacity(0.5), radius: 4)
            }
            if orbitBalloon {
                WBalloon(size: size * 0.34, tint: WTheme.gold)
                    .offset(x: size * 0.52, y: -size * 0.46)
            }
        }
        // Reserve the globe + ring in layout; the atmosphere glow and orbiting
        // balloon bleed beyond it softly (never clipped).
        .frame(width: size * 1.25, height: size * 1.25)
    }

    private var globe: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [ocean, oceanDeep],
                                         center: UnitPoint(x: 0.34, y: 0.30),
                                         startRadius: 1, endRadius: size * 0.72))
            ZStack {
                Capsule().fill(land).frame(width: size * 0.46, height: size * 0.26)
                    .rotationEffect(.degrees(-20)).offset(x: -size * 0.12, y: -size * 0.12)
                Ellipse().fill(land).frame(width: size * 0.30, height: size * 0.38)
                    .offset(x: size * 0.18, y: size * 0.05)
                Capsule().fill(land).frame(width: size * 0.24, height: size * 0.13)
                    .rotationEffect(.degrees(12)).offset(x: -size * 0.02, y: size * 0.24)
            }
            .blur(radius: size * 0.012)
            .clipShape(Circle())
            .frame(width: size, height: size)
            Circle().fill(RadialGradient(colors: [.white.opacity(0.34), .clear],
                                         center: UnitPoint(x: 0.32, y: 0.26),
                                         startRadius: 1, endRadius: size * 0.5))
            Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Balloon (vector hot-air balloon)

struct WBalloon: View {
    var size: CGFloat = 30
    var tint: Color = WTheme.gold
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [tint.opacity(0.45), .clear],
                                     center: .center, startRadius: 1, endRadius: size * 0.7))
                .frame(width: size * 1.7, height: size * 1.7)
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [tint, tint.opacity(0.62)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    Circle().fill(RadialGradient(colors: [.white.opacity(0.42), .clear],
                                                 center: UnitPoint(x: 0.32, y: 0.28),
                                                 startRadius: 1, endRadius: size * 0.45))
                    Circle().strokeBorder(.white.opacity(0.22), lineWidth: 0.7)
                }
                .frame(width: size, height: size)
                ZStack {
                    Rectangle().fill(.white.opacity(0.30)).frame(width: size * 0.48, height: 1).offset(y: -size * 0.03)
                    RoundedRectangle(cornerRadius: size * 0.06)
                        .fill(Color(red: 0.45, green: 0.30, blue: 0.18))
                        .frame(width: size * 0.30, height: size * 0.22).offset(y: size * 0.05)
                }
                .frame(height: size * 0.28)
            }
        }
        // Reserve the balloon's shape size in layout (the soft halo bleeds beyond).
        .frame(width: size, height: size * 1.3)
    }
}

// MARK: - Stylized map (Option B — no MapKit in widgets)

/// A dark, premium "route on the map" background: deep sea gradient, soft
/// coastline landmasses, a faint graticule, and a glowing dashed route arc with
/// origin/destination dots and the balloon at `progress` along the arc.
struct WStylizedMap: View {
    var progress: Double? = nil          // 0…1 balloon position; nil → at origin
    var showRoute: Bool = true
    var accent: Color = WTheme.gold

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let start = CGPoint(x: w * 0.16, y: h * 0.76)
            let end   = CGPoint(x: w * 0.84, y: h * 0.30)
            let ctrl  = CGPoint(x: w * 0.50, y: h * 0.02)
            ZStack {
                LinearGradient(colors: [Color(red: 0.06, green: 0.13, blue: 0.24),
                                        Color(red: 0.02, green: 0.05, blue: 0.11)],
                               startPoint: .top, endPoint: .bottom)
                WMapLand().fill(Color(red: 0.10, green: 0.21, blue: 0.21)).blur(radius: 2).opacity(0.95)
                WMapLand().stroke(WTheme.teal.opacity(0.28), lineWidth: 0.8)
                WGraticule().stroke(.white.opacity(0.05), lineWidth: 0.6)
                if showRoute {
                    let arc = Path { p in p.move(to: start); p.addQuadCurve(to: end, control: ctrl) }
                    arc.stroke(accent.opacity(0.35), style: StrokeStyle(lineWidth: 6, lineCap: .round)).blur(radius: 4)
                    arc.stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 6]))
                    Circle().fill(.white).frame(width: 8, height: 8).position(start)
                        .shadow(color: .white.opacity(0.7), radius: 4)
                    Circle().fill(accent).frame(width: 9, height: 9).position(end)
                        .shadow(color: accent.opacity(0.8), radius: 5)
                    WBalloon(size: 26, tint: accent)
                        .position(wQuadPoint(start, ctrl, end, progress ?? 0))
                }
            }
        }
    }
}

/// Quadratic-bezier point at parameter `t` (for placing the balloon on the arc).
func wQuadPoint(_ s: CGPoint, _ c: CGPoint, _ e: CGPoint, _ t: Double) -> CGPoint {
    let mt = 1 - t
    return CGPoint(x: mt * mt * s.x + 2 * mt * t * c.x + t * t * e.x,
                   y: mt * mt * s.y + 2 * mt * t * c.y + t * t * e.y)
}

/// Abstract, soft landmasses (blurred when filled → coastline-like) for the map.
struct WMapLand: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.addEllipse(in: CGRect(x: w * 0.00, y: h * 0.34, width: w * 0.34, height: h * 0.40))
        p.addEllipse(in: CGRect(x: w * 0.18, y: h * 0.58, width: w * 0.26, height: h * 0.30))
        p.addEllipse(in: CGRect(x: w * 0.56, y: h * 0.06, width: w * 0.42, height: h * 0.42))
        p.addEllipse(in: CGRect(x: w * 0.66, y: h * 0.56, width: w * 0.30, height: h * 0.34))
        return p
    }
}

/// A faint lat/long grid (a few gentle curves) hinting at a globe projection.
struct WGraticule: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        for f in [0.28, 0.5, 0.72] {
            p.move(to: CGPoint(x: 0, y: h * f))
            p.addQuadCurve(to: CGPoint(x: w, y: h * f), control: CGPoint(x: w / 2, y: h * (f - 0.06)))
        }
        for f in [0.3, 0.5, 0.7] {
            p.move(to: CGPoint(x: w * f, y: 0))
            p.addLine(to: CGPoint(x: w * f, y: h))
        }
        return p
    }
}

// MARK: - Day dots (streak week)

/// A row of 7 day dots — lit for active days, with today highlighted.
struct WDayDots: View {
    var streak: Int
    var tint: Color = WTheme.gold
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<7, id: \.self) { i in
                let lit = i >= (7 - min(7, streak))
                Circle()
                    .fill(lit
                          ? AnyShapeStyle(LinearGradient(colors: [WTheme.gold, WTheme.coral],
                                                         startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(WTheme.hair))
                    .frame(width: 8, height: 8)
                    .overlay(i == 6 ? Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1) : nil)
            }
        }
    }
}

/// A compact "CTA pill" used at the bottom of launcher widgets.
struct WPill: View {
    let icon: String
    let title: String
    var fill: Color = WTheme.ink
    var fg: Color = .black
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12, weight: .bold))
            Text(title).font(.system(size: 13, weight: .bold, design: .rounded)).lineLimit(1)
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Capsule().fill(fill))
    }
}
