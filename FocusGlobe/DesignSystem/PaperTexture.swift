import Foundation
import SwiftUI

/// Expedition **materials**: procedural paper grain, a wax seal, ink stamps and a
/// torn-paper divider. All are drawn in code (no bundled image assets), and all
/// are *deterministic* — seeded so the texture is identical on every render and
/// never shimmers. They are the reusable primitives the ritual/journal screens
/// (Phases 3–8) compose; Phase 1 only defines them and layers the grain into the
/// shared background.

// MARK: - Deterministic RNG

/// A tiny, fast, deterministic generator (xorshift64*). Given the same seed it
/// always produces the same sequence, so grain and deckle edges are stable — no
/// flicker between frames, unlike `Double.random`.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 0x2545_F491_4F6C_DD1D
    }
    /// A `Double` in `0..<1`.
    mutating func unit() -> Double { Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0) }
}

// MARK: - Paper grain

/// A faint, non-interactive speckle that gives a surface a tactile paper feel.
/// Dark specks (multiply) on light paper; light specks (screen) on night paper —
/// so it reads correctly in both modes. Density scales with area and is capped so
/// even a full screen stays cheap, and the `Canvas` closure only re-runs on a size
/// change (the content is static).
struct PaperGrain: View {
    var intensity: Double = 1
    var seed: UInt64 = 0x5EED_0001
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = scheme == .dark
        Canvas { context, size in
            var rng = SeededRNG(seed: seed)
            let count = min(Int(size.width * size.height / 900), 700)
            for _ in 0..<count {
                let x = rng.unit() * size.width
                let y = rng.unit() * size.height
                let d = 0.4 + rng.unit() * 0.9
                let a = (dark ? 0.05 : 0.032) * intensity * (0.5 + rng.unit() * 0.5)
                let color: Color = dark ? .white : .black
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d)),
                             with: .color(color.opacity(a)))
            }
        }
        .allowsHitTesting(false)
        .blendMode(dark ? .screen : .multiply)
    }
}

// MARK: - Wax seal

/// A scalloped wax-drop outline — gives the seal its unmistakable "poured wax"
/// silhouette instead of a plain button circle.
struct ScallopedCircle: Shape {
    var petals: Int = 16
    var depth: CGFloat = 0.055
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * (1 - depth)
        let total = max(petals, 4) * 2
        var p = Path()
        for i in 0...total {
            let angle = (Double(i) / Double(total)) * 2 * .pi - .pi / 2
            let r = (i % 2 == 0) ? outer : inner
            let pt = CGPoint(x: c.x + CGFloat(cos(angle)) * r, y: c.y + CGFloat(sin(angle)) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// The signature **wax seal** — an embossed, scalloped wax-red disc with a symbol.
/// Used sparingly (expedition-page confirmation, featured paywall plan) so it stays
/// memorable. Purely presentational; animate it at the call site with
/// `AppMotion.sealImpact`.
struct WaxSeal: View {
    var symbol: String = "seal.fill"
    var diameter: CGFloat = 84

    var body: some View {
        ZStack {
            ScallopedCircle()
                .fill(
                    RadialGradient(
                        colors: [AppColors.waxSeal.opacity(0.95), AppColors.waxSeal.opacity(0.78)],
                        center: .init(x: 0.4, y: 0.34),
                        startRadius: 2, endRadius: diameter * 0.72))
            // Emboss: a bright top-left kiss and a soft inner ring.
            ScallopedCircle()
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                .blur(radius: 0.5)
            Circle()
                .strokeBorder(Color.black.opacity(0.18), lineWidth: 1)
                .padding(diameter * 0.16)
            Image(systemName: symbol)
                .font(.system(size: diameter * 0.4, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.92))
                .shadow(color: .black.opacity(0.25), radius: 0.5, y: 0.5)
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: AppColors.waxSeal.opacity(0.35), radius: 8, y: 4)
        .compositingGroup()
        .accessibilityHidden(true)
    }
}

// MARK: - Ink stamp

/// A rubber-stamp label (date, focus type, "PACKED") — serif, tracked-out, boxed
/// and rotated a touch, so it reads as ink pressed onto the page. Visible in both
/// modes (opacity, not multiply, so it never vanishes on the night page).
struct InkStamp: View {
    var text: String
    var color: Color = AppColors.waxSeal
    var rotation: Double = -7

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12.5, weight: .heavy, design: .serif))
            .tracking(1.6)
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(color, lineWidth: 1.6))
            .rotationEffect(.degrees(rotation))
            .opacity(0.85)
            .compositingGroup()
            .accessibilityLabel(text)
    }
}

// MARK: - Torn-paper divider

/// A hand-torn deckle edge, for separating journal sections. A faint sepia jagged
/// line — deterministic per `seed`.
struct TornPaperDivider: View {
    var seed: UInt64 = 0xC0FF_EE01

    var body: some View {
        Canvas { context, size in
            var rng = SeededRNG(seed: seed)
            let midY = size.height / 2
            let amp = size.height * 0.34
            var path = Path()
            path.move(to: CGPoint(x: 0, y: midY))
            var x: CGFloat = 0
            let step: CGFloat = 5
            while x <= size.width {
                let y = midY + CGFloat(rng.unit() - 0.5) * 2 * amp
                path.addLine(to: CGPoint(x: x, y: y))
                x += step
            }
            context.stroke(path, with: .color(AppColors.sepia.opacity(0.4)), lineWidth: 1)
        }
        .frame(height: 8)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Paper surface modifier

/// Gives any container the full paper treatment: warm paper fill, soft aged
/// mottling and grain, clipped to a corner radius. Use on cards/pages that should
/// feel like a physical page (the expedition page, postcards, the paywall).
struct PaperSurface: ViewModifier {
    var cornerRadius: CGFloat = 0
    var grain: Double = 1

    func body(content: Content) -> some View {
        content.background {
            ZStack {
                AppColors.paper
                RadialGradient(colors: [AppColors.sepia.opacity(0.10), .clear],
                               center: .topLeading, startRadius: 4, endRadius: 260)
                RadialGradient(colors: [AppColors.lantern.opacity(0.08), .clear],
                               center: .bottomTrailing, startRadius: 4, endRadius: 300)
                PaperGrain(intensity: grain)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

extension View {
    /// Wrap a container in warm, grained expedition paper.
    func paperSurface(cornerRadius: CGFloat = 0, grain: Double = 1) -> some View {
        modifier(PaperSurface(cornerRadius: cornerRadius, grain: grain))
    }
}
