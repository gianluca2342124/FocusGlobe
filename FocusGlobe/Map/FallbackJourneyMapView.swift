import SwiftUI

/// A premium, dependency-free **aurora / deep-space** journey surface.
///
/// Used for the ambient Home backdrop, route previews, and as the development
/// fallback when the Google Maps SDK isn't linked. (The live session uses the
/// real Google map.) Deep navy base, soft aurora light, subtle stars, luminous
/// route glow and atmospheric halos — cinematic, calm and magical.
struct FallbackJourneyMapView: View {
    let data: JourneyMapData
    @State private var drift: CGFloat = 0
    @State private var bob: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let projection = GeoProjection(coords: [data.origin, data.destination],
                                           size: size, inset: 64)
            let full = MapRouteRenderer.routePoints(from: data.origin, to: data.destination, samples: 90)
                .map { projection.point(for: $0) }
            let traveled = MapRouteRenderer.traveledPoints(from: data.origin, to: data.vehicle, samples: 50)
                .map { projection.point(for: $0) }
            let originPt = projection.point(for: data.origin)
            let destPt = projection.point(for: data.destination)
            let vehiclePt = projection.point(for: data.vehicle)

            ZStack {
                AuroraBackdrop(theme: data.theme, drift: drift)

                routeCanvas(full: full, traveled: traveled, origin: originPt, destination: destPt)

                // Glowing destination halo (drawn as a soft SwiftUI blur).
                Circle()
                    .fill(data.theme.accent.opacity(0.5))
                    .frame(width: 60, height: 60)
                    .blur(radius: 22)
                    .position(destPt)

                BalloonView(height: 74, showBurner: true, showGlow: true,
                            glow: data.theme.soft, burnerAnimated: data.isMoving)
                    .position(x: vehiclePt.x, y: vehiclePt.y - 22 + bob)
                    .animation(.easeInOut(duration: 1.0), value: vehiclePt)

                // Depth vignette.
                RadialGradient(colors: [.clear, .black.opacity(0.45)],
                               center: .center, startRadius: size.height * 0.28,
                               endRadius: size.height * 0.85)
                    .allowsHitTesting(false)
            }
        }
        .clipped()
        .onAppear {
            withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) { drift = 1 }
            if data.isMoving {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { bob = -6 }
            }
        }
    }

    private func routeCanvas(full: [CGPoint], traveled: [CGPoint],
                             origin: CGPoint, destination: CGPoint) -> some View {
        Canvas { ctx, _ in
            // Remaining route — faint luminous dots.
            var remaining = Path()
            remaining.addLines(full)
            ctx.stroke(remaining, with: .color(data.theme.soft.opacity(0.45)),
                       style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [1, 10]))

            // Travelled route — soft outer glow + bright luminous core.
            if traveled.count > 1 {
                var tp = Path()
                tp.addLines(traveled)
                ctx.stroke(tp, with: .color(data.theme.accent.opacity(0.30)),
                           style: StrokeStyle(lineWidth: 13, lineCap: .round, lineJoin: .round))
                ctx.stroke(tp, with: .color(data.theme.accent.opacity(0.55)),
                           style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                ctx.stroke(tp, with: .color(.white.opacity(0.9)),
                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }

            // Origin — soft glow + crisp dot.
            ctx.fill(Path(ellipseIn: CGRect(x: origin.x - 14, y: origin.y - 14, width: 28, height: 28)),
                     with: .color(.white.opacity(0.12)))
            let oRect = CGRect(x: origin.x - 5, y: origin.y - 5, width: 10, height: 10)
            ctx.fill(Path(ellipseIn: oRect), with: .color(.white))

            // Destination — accent dot over its blur halo.
            let dRect = CGRect(x: destination.x - 6, y: destination.y - 6, width: 12, height: 12)
            ctx.fill(Path(ellipseIn: dRect), with: .color(.white))
            ctx.stroke(Path(ellipseIn: dRect), with: .color(data.theme.accent), lineWidth: 3)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Aurora backdrop

private struct AuroraBackdrop: View {
    let theme: RouteTheme
    let drift: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                // Deep-space base.
                LinearGradient(colors: [Color(hex: 0x241A10), Color(hex: 0x1C140C), Color(hex: 0x150F09)],
                               startPoint: .top, endPoint: .bottom)

                // Soft nebula glows (themed + aurora hues), gently drifting.
                nebula(color: theme.soft, w: w, h: h, x: 0.2, y: 0.18, size: 1.1, op: 0.16,
                       dx: 18 * drift, dy: 8 * drift)
                nebula(color: Color(hex: 0x3FD9A8), w: w, h: h, x: 0.78, y: 0.26, size: 0.9, op: 0.12,
                       dx: -16 * drift, dy: 10 * drift)
                nebula(color: Color(hex: 0xE0A050), w: w, h: h, x: 0.5, y: 0.7, size: 1.2, op: 0.12,
                       dx: 12 * drift, dy: -10 * drift)

                StarField()
            }
        }
        .allowsHitTesting(false)
    }

    private func nebula(color: Color, w: CGFloat, h: CGFloat,
                        x: CGFloat, y: CGFloat, size: CGFloat, op: Double,
                        dx: CGFloat, dy: CGFloat) -> some View {
        Ellipse()
            .fill(color.opacity(op))
            .frame(width: w * size, height: h * 0.5 * size)
            .blur(radius: 70)
            .position(x: w * x + dx, y: h * y + dy)
    }
}

/// A subtle, deterministic star field.
private struct StarField: View {
    private let stars: [(CGFloat, CGFloat, CGFloat, Double)] = [
        (0.08, 0.10, 1.6, 0.7), (0.18, 0.24, 1.1, 0.4), (0.27, 0.07, 2.0, 0.85),
        (0.36, 0.18, 1.2, 0.5), (0.45, 0.06, 1.5, 0.6), (0.54, 0.15, 1.1, 0.45),
        (0.63, 0.09, 2.0, 0.8), (0.72, 0.20, 1.3, 0.5), (0.81, 0.07, 1.6, 0.65),
        (0.90, 0.17, 1.2, 0.5), (0.12, 0.40, 1.3, 0.5), (0.30, 0.46, 1.0, 0.35),
        (0.50, 0.38, 1.7, 0.6), (0.68, 0.44, 1.1, 0.4), (0.86, 0.40, 1.4, 0.5),
        (0.22, 0.62, 1.2, 0.45), (0.42, 0.70, 1.5, 0.55), (0.60, 0.64, 1.0, 0.35),
        (0.78, 0.72, 1.3, 0.5), (0.93, 0.60, 1.1, 0.4), (0.15, 0.82, 1.4, 0.5),
        (0.34, 0.88, 1.0, 0.3), (0.55, 0.84, 1.6, 0.55), (0.74, 0.90, 1.1, 0.4),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(Array(stars.enumerated()), id: \.offset) { _, s in
                Circle()
                    .fill(Color.white.opacity(s.3))
                    .frame(width: s.2, height: s.2)
                    .position(x: geo.size.width * s.0, y: geo.size.height * s.1)
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    FallbackJourneyMapView(data: JourneyMapData(
        origin: GeoCoordinate(latitude: 35.0116, longitude: 135.7681),
        destination: GeoCoordinate(latitude: 34.6851, longitude: 135.8048),
        vehicle: GeoCoordinate(latitude: 34.86, longitude: 135.78),
        progress: 0.45, bearingDegrees: 170,
        mood: .aurora, theme: .aurora, followsVehicle: true, isMoving: true
    ))
    .ignoresSafeArea()
}
