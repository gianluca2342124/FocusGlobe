import SwiftUI

/// The balloon envelope silhouette — a soft teardrop, rounded on top and
/// gently tapered to the basket below.
struct BalloonEnvelope: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let cx = rect.midX

        p.move(to: CGPoint(x: cx, y: rect.maxY)) // bottom tip
        p.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + h * 0.42),
            control1: CGPoint(x: cx - w * 0.16, y: rect.maxY - h * 0.06),
            control2: CGPoint(x: rect.minX, y: rect.minY + h * 0.74)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.minY + h * 0.12),
            control2: CGPoint(x: cx - w * 0.34, y: rect.minY)
        )
        p.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.42),
            control1: CGPoint(x: cx + w * 0.34, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.minY + h * 0.12)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.minY + h * 0.74),
            control2: CGPoint(x: cx + w * 0.16, y: rect.maxY - h * 0.06)
        )
        p.closeSubpath()
        return p
    }
}

private struct BalloonCords: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.32, y: r.maxY))
        p.move(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.68, y: r.maxY))
        return p
    }
}

/// The default FocusGlobe vehicle: a premium, minimal, soft cream balloon with
/// a gentle highlight, a small basket and an optional glow. Original artwork,
/// drawn entirely in code so it scales crisply and themes via `glow`.
///
/// `size` is the envelope **width**; the full mark (incl. basket) is a little
/// taller. Reused as-is in the UI and rendered to a `UIImage` for the map
/// marker — see `VehicleMarkerRenderer`.
struct BalloonMark: View {
    var size: CGFloat = 64
    var glow: Color = .white
    var showGlow: Bool = true

    private var envW: CGFloat { size }
    private var envH: CGFloat { size * 1.12 }

    var body: some View {
        VStack(spacing: 0) {
            envelope
                .frame(width: envW, height: envH)

            BalloonCords()
                .stroke(Color(hex: 0x9AA3B5), style: StrokeStyle(lineWidth: max(1, size * 0.02), lineCap: .round))
                .frame(width: envW * 0.42, height: size * 0.14)

            RoundedRectangle(cornerRadius: size * 0.04, style: .continuous)
                .fill(
                    LinearGradient(colors: [Color(hex: 0xC79A6A), Color(hex: 0x8A6038)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(width: envW * 0.30, height: size * 0.16)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.04, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
                )
        }
        .shadow(color: .black.opacity(0.18), radius: size * 0.07, x: 0, y: size * 0.05)
        .background(glowLayer)
    }

    private var envelope: some View {
        ZStack {
            BalloonEnvelope()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xFFFDF8), Color(hex: 0xEFF1F7), Color(hex: 0xDCE2EE)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            // Soft upper-left highlight.
            Ellipse()
                .fill(Color.white.opacity(0.55))
                .frame(width: envW * 0.42, height: envH * 0.30)
                .offset(x: -envW * 0.15, y: -envH * 0.17)
                .blur(radius: envW * 0.07)
        }
        .compositingGroup()
        .clipShape(BalloonEnvelope())
        .overlay(
            BalloonEnvelope()
                .stroke(Color.black.opacity(0.06), lineWidth: max(0.5, size * 0.008))
        )
    }

    @ViewBuilder private var glowLayer: some View {
        if showGlow {
            Circle()
                .fill(
                    RadialGradient(colors: [glow.opacity(0.55), glow.opacity(0)],
                                   center: .center, startRadius: 0, endRadius: size * 0.75)
                )
                .frame(width: size * 1.7, height: size * 1.7)
                .blur(radius: size * 0.12)
                .offset(y: -size * 0.15)
        }
    }
}

#Preview {
    ZStack {
        AppColors.backgroundBottom
        HStack(spacing: 40) {
            BalloonMark(size: 80, glow: RouteTheme.aurora.soft)
            BalloonMark(size: 56, glow: RouteTheme.coral.soft)
        }
    }
    .ignoresSafeArea()
}
