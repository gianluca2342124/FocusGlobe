import SwiftUI

/// The reusable **signature scene** for a destination: a premium, abstract
/// "destination memory" rendered entirely in SwiftUI (no images, no cartoons).
/// Soft mood gradient, atmospheric light, a landmark silhouette, faint map
/// contour lines, and stars/aurora where the mood calls for it. Shared by the
/// boarding pass backdrop and the landing/passport postcard.
struct DestinationScene: View {
    let mood: RouteMood
    let theme: RouteTheme
    var landmark: Landmark = .generic
    var compact: Bool = false

    private var fg: Color { mood.preferredForeground }

    var body: some View {
        ZStack {
            mood.gradient

            RadialGradient(colors: [theme.soft.opacity(0.55), .clear],
                           center: .init(x: 0.7, y: 0.92), startRadius: 2, endRadius: compact ? 150 : 300)

            if mood == .night || mood == .aurora || mood == .sunset {
                StarSpecks(count: compact ? 10 : 24).opacity(0.8)
            }
            if mood == .aurora {
                AuroraRibbons(color: theme.soft)
            }

            ContourLines(color: fg.opacity(0.10))

            LandmarkSilhouette(landmark: landmark)
                .fill(LinearGradient(colors: [Color.black.opacity(0.42), Color.black.opacity(0.16)],
                                     startPoint: .bottom, endPoint: .top))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}

/// A premium destination postcard (signature scene + stamp + titles). Used
/// full-size on Landing and compact in the Passport.
struct DestinationPostcard: View {
    let title: String
    let place: String
    let mood: RouteMood
    let theme: RouteTheme
    var landmark: Landmark = .generic
    var compact: Bool = false
    var isNew: Bool = false

    private var fg: Color { mood.preferredForeground }
    private var radius: CGFloat { compact ? AppSpacing.pillRadius : AppSpacing.cardRadius }

    var body: some View {
        ZStack(alignment: .topLeading) {
            DestinationScene(mood: mood, theme: theme, landmark: landmark, compact: compact)

            // Stamp ring.
            Circle()
                .strokeBorder(fg.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .frame(width: compact ? 30 : 44, height: compact ? 30 : 44)
                .overlay(Image(systemName: mood.systemImage)
                    .font(.system(size: compact ? 12 : 16, weight: .semibold))
                    .foregroundStyle(fg.opacity(0.9)))
                .padding(compact ? AppSpacing.xs : AppSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .topTrailing)

            VStack(alignment: .leading, spacing: compact ? 2 : 6) {
                if !compact {
                    Text("Postcard unlocked")
                        .font(AppTypography.micro).tracking(0.6)
                        .foregroundStyle(fg.opacity(0.8))
                }
                Spacer()
                Text(LocalizedStringKey(title))
                    .font(compact ? AppTypography.callout : AppTypography.title2)
                    .foregroundStyle(fg).lineLimit(1)
                Text(place)
                    .font(AppTypography.caption)
                    .foregroundStyle(fg.opacity(0.85)).lineLimit(1)
            }
            .padding(compact ? AppSpacing.sm : AppSpacing.md)

            if isNew {
                Text("NEW")
                    .font(AppTypography.micro).foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.xs).padding(.vertical, 4)
                    .background(Capsule().fill(AppColors.success))
                    .padding(AppSpacing.sm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .frame(height: compact ? 116 : 172)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
        .shadow(color: AppColors.shadow, radius: 12, x: 0, y: 6)
    }
}

// MARK: - Procedural landmark silhouettes

/// A soft landmark silhouette anchored to the bottom edge of the rect.
struct LandmarkSilhouette: Shape {
    let landmark: Landmark

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let base = rect.maxY
        var p = Path()

        func hill(_ cx: CGFloat, _ peakY: CGFloat, _ halfW: CGFloat) {
            p.move(to: CGPoint(x: cx - halfW, y: base))
            p.addQuadCurve(to: CGPoint(x: cx + halfW, y: base),
                           control: CGPoint(x: cx, y: peakY))
        }
        func peak(_ x0: CGFloat, _ x1: CGFloat, _ topY: CGFloat) {
            let mid = (x0 + x1) / 2
            p.move(to: CGPoint(x: x0, y: base))
            p.addLine(to: CGPoint(x: mid, y: topY))
            p.addLine(to: CGPoint(x: x1, y: base))
        }
        func rectBldg(_ x: CGFloat, _ width: CGFloat, _ topY: CGFloat) {
            p.addRect(CGRect(x: x, y: topY, width: width, height: base - topY))
        }

        switch landmark {
        case .mountain:
            peak(w * 0.02, w * 0.5, h * 0.30)
            peak(w * 0.34, w * 0.86, h * 0.18)
            peak(w * 0.66, w * 1.02, h * 0.40)
        case .pagoda:
            // Stacked roofs.
            for (i, y) in [0.30, 0.50, 0.70].enumerated() {
                let inset = w * (0.30 - CGFloat(i) * 0.07)
                let topY = h * y
                p.move(to: CGPoint(x: inset, y: topY + h * 0.10))
                p.addLine(to: CGPoint(x: w * 0.5, y: topY))
                p.addLine(to: CGPoint(x: w - inset, y: topY + h * 0.10))
                p.addLine(to: CGPoint(x: w - inset - w * 0.05, y: topY + h * 0.10))
                p.closeSubpath()
            }
            rectBldg(w * 0.42, w * 0.16, h * 0.78)
        case .dome:
            hill(w * 0.30, h * 0.42, w * 0.18) // dome 1
            hill(w * 0.62, h * 0.32, w * 0.16) // dome 2
            rectBldg(w * 0.10, w * 0.80, h * 0.74) // wall base
        case .tower:
            p.move(to: CGPoint(x: w * 0.34, y: base))
            p.addLine(to: CGPoint(x: w * 0.47, y: h * 0.12))
            p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.04))
            p.addLine(to: CGPoint(x: w * 0.53, y: h * 0.12))
            p.addLine(to: CGPoint(x: w * 0.66, y: base))
            p.closeSubpath()
        case .skyline:
            let xs: [(CGFloat, CGFloat, CGFloat)] = [
                (0.04, 0.12, 0.55), (0.18, 0.10, 0.34), (0.30, 0.14, 0.62),
                (0.46, 0.10, 0.22), (0.58, 0.13, 0.50), (0.73, 0.11, 0.36), (0.86, 0.12, 0.58)]
            for (x, ww, top) in xs { rectBldg(w * x, w * ww, h * top) }
        case .coastline:
            p.move(to: CGPoint(x: 0, y: h * 0.55))
            p.addQuadCurve(to: CGPoint(x: w * 0.55, y: h * 0.72),
                           control: CGPoint(x: w * 0.28, y: h * 0.40))
            p.addQuadCurve(to: CGPoint(x: w, y: h * 0.60),
                           control: CGPoint(x: w * 0.8, y: h * 0.86))
            p.addLine(to: CGPoint(x: w, y: base))
            p.addLine(to: CGPoint(x: 0, y: base))
            p.closeSubpath()
        case .island:
            hill(w * 0.5, h * 0.5, w * 0.28)
            rectBldg(w * 0.46, w * 0.03, h * 0.30) // palm trunk
        case .desert:
            p.move(to: CGPoint(x: 0, y: base))
            p.addQuadCurve(to: CGPoint(x: w * 0.5, y: base),
                           control: CGPoint(x: w * 0.25, y: h * 0.55))
            p.addQuadCurve(to: CGPoint(x: w, y: base),
                           control: CGPoint(x: w * 0.78, y: h * 0.42))
            p.closeSubpath()
        case .forest:
            for i in 0..<6 {
                let x = w * (0.08 + CGFloat(i) * 0.16)
                peak(x - w * 0.07, x + w * 0.07, h * (0.45 + (CGFloat(i % 3) * 0.08)))
            }
        case .canyon:
            rectBldg(w * 0.05, w * 0.32, h * 0.45)
            rectBldg(w * 0.42, w * 0.22, h * 0.62)
            rectBldg(w * 0.68, w * 0.28, h * 0.38)
        case .bridge:
            p.move(to: CGPoint(x: 0, y: h * 0.62))
            p.addQuadCurve(to: CGPoint(x: w, y: h * 0.62), control: CGPoint(x: w * 0.5, y: h * 0.30))
            p.addLine(to: CGPoint(x: w, y: base)); p.addLine(to: CGPoint(x: 0, y: base)); p.closeSubpath()
            rectBldg(w * 0.18, w * 0.04, h * 0.20)
            rectBldg(w * 0.78, w * 0.04, h * 0.20)
        case .aurora, .generic:
            hill(w * 0.32, h * 0.5, w * 0.34)
            hill(w * 0.72, h * 0.42, w * 0.30)
        }
        return p
    }
}

private struct StarSpecks: View {
    let count: Int
    var body: some View {
        Canvas { ctx, size in
            var seed: UInt64 = 0x9E3779B9
            func rnd() -> CGFloat {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return CGFloat((seed >> 33) % 10000) / 10000
            }
            for _ in 0..<count {
                let x = rnd() * size.width
                let y = rnd() * size.height * 0.6
                let r = 0.6 + rnd() * 1.4
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(0.5 + rnd() * 0.4)))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct AuroraRibbons: View {
    let color: Color
    var body: some View {
        Canvas { ctx, size in
            for i in 0..<3 {
                var path = Path()
                let y = size.height * (0.18 + CGFloat(i) * 0.12)
                path.move(to: CGPoint(x: 0, y: y))
                path.addCurve(to: CGPoint(x: size.width, y: y - 10),
                              control1: CGPoint(x: size.width * 0.33, y: y - 26),
                              control2: CGPoint(x: size.width * 0.66, y: y + 20))
                ctx.stroke(path, with: .color(color.opacity(0.35 - Double(i) * 0.08)),
                           style: StrokeStyle(lineWidth: 10 - CGFloat(i) * 2, lineCap: .round))
            }
        }
        .blur(radius: 8)
        .allowsHitTesting(false)
    }
}

private struct ContourLines: View {
    let color: Color
    var body: some View {
        Canvas { ctx, size in
            for i in 0..<4 {
                var path = Path()
                let y = size.height * (0.5 + CGFloat(i) * 0.12)
                path.move(to: CGPoint(x: 0, y: y))
                path.addCurve(to: CGPoint(x: size.width, y: y),
                              control1: CGPoint(x: size.width * 0.3, y: y - 12),
                              control2: CGPoint(x: size.width * 0.7, y: y + 12))
                ctx.stroke(path, with: .color(color), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}
