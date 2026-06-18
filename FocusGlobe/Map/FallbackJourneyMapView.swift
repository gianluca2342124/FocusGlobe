import SwiftUI

/// A fully native, dependency-free stylised journey map.
///
/// This renders when the Google Maps SDK isn't linked, so the app is always
/// beautiful and runnable out of the box. It is a genuine `MapProvider`
/// implementation — it consumes the same `JourneyMapData` — and intentionally
/// styles itself with the route's mood gradient rather than real cartography:
/// a calm aerial canvas with a soft graticule, drifting clouds, the route line
/// and the balloon. Add the Google Maps package to switch to live maps.
struct FallbackJourneyMapView: View {
    let data: JourneyMapData
    @Environment(\.colorScheme) private var scheme
    @State private var bob: CGFloat = 0

    private var lineTint: Color {
        data.mood.isDarkScene ? .white : Color(hex: 0x2A3550)
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let projection = GeoProjection(coords: [data.origin, data.destination],
                                           size: size, inset: 64)
            let full = MapRouteRenderer.routePoints(from: data.origin, to: data.destination, samples: 80)
                .map { projection.point(for: $0) }
            let traveled = MapRouteRenderer.traveledPoints(from: data.origin, to: data.vehicle, samples: 44)
                .map { projection.point(for: $0) }
            let originPt = projection.point(for: data.origin)
            let destPt = projection.point(for: data.destination)
            let vehiclePt = projection.point(for: data.vehicle)

            ZStack {
                data.mood.gradient

                GraticuleLayer(tint: lineTint.opacity(scheme == .dark ? 0.10 : 0.16))

                if data.mood.isDarkScene {
                    StarsLayer()
                }

                CloudsLayer()

                routeCanvas(full: full, traveled: traveled, origin: originPt, destination: destPt)

                BalloonMark(size: 42, glow: data.theme.soft)
                    .position(x: vehiclePt.x, y: vehiclePt.y - 16 + bob)
                    .animation(.easeInOut(duration: 1.0), value: vehiclePt)

                // Gentle depth vignette.
                RadialGradient(colors: [.clear, Color.black.opacity(0.22)],
                               center: .center, startRadius: size.height * 0.32,
                               endRadius: size.height * 0.8)
                    .blendMode(.multiply)
                    .allowsHitTesting(false)
            }
        }
        .clipped()
        .onAppear {
            guard data.isMoving else { return }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                bob = -6
            }
        }
    }

    private func routeCanvas(full: [CGPoint], traveled: [CGPoint],
                             origin: CGPoint, destination: CGPoint) -> some View {
        Canvas { ctx, _ in
            // Remaining route — soft dotted line.
            var remaining = Path()
            remaining.addLines(full)
            ctx.stroke(remaining, with: .color(data.theme.soft.opacity(0.6)),
                       style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [1, 9]))

            // Travelled route — accent with a soft glow underneath.
            if traveled.count > 1 {
                var tp = Path()
                tp.addLines(traveled)
                ctx.stroke(tp, with: .color(data.theme.accent.opacity(0.35)),
                           style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
                ctx.stroke(tp, with: .color(data.theme.accent),
                           style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }

            // Origin dot.
            let oRect = CGRect(x: origin.x - 5, y: origin.y - 5, width: 10, height: 10)
            ctx.fill(Path(ellipseIn: oRect), with: .color(.white))
            ctx.stroke(Path(ellipseIn: oRect), with: .color(data.theme.accent), lineWidth: 2.5)

            // Destination dot.
            let dRect = CGRect(x: destination.x - 6, y: destination.y - 6, width: 12, height: 12)
            ctx.fill(Path(ellipseIn: dRect.insetBy(dx: -3, dy: -3)),
                     with: .color(data.theme.accent.opacity(0.25)))
            ctx.fill(Path(ellipseIn: dRect), with: .color(data.theme.accent))
            ctx.stroke(Path(ellipseIn: dRect), with: .color(.white), lineWidth: 2.5)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Decorative layers

private struct GraticuleLayer: View {
    let tint: Color
    var body: some View {
        Canvas { ctx, size in
            let cols = 6
            let rows = 10
            for i in 1..<cols {
                let x = size.width * CGFloat(i) / CGFloat(cols)
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(p, with: .color(tint), lineWidth: 0.6)
            }
            for j in 1..<rows {
                let y = size.height * CGFloat(j) / CGFloat(rows)
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(tint), lineWidth: 0.6)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct StarsLayer: View {
    // Deterministic positions (fraction of size) + size + opacity.
    private let stars: [(CGFloat, CGFloat, CGFloat, Double)] = [
        (0.12, 0.10, 2.0, 0.7), (0.22, 0.22, 1.5, 0.5), (0.34, 0.08, 2.4, 0.8),
        (0.46, 0.18, 1.6, 0.5), (0.58, 0.07, 1.8, 0.6), (0.70, 0.16, 2.2, 0.7),
        (0.82, 0.09, 1.5, 0.5), (0.90, 0.22, 2.0, 0.6), (0.16, 0.34, 1.6, 0.5),
        (0.64, 0.30, 1.7, 0.5), (0.78, 0.36, 2.1, 0.6), (0.30, 0.40, 1.4, 0.4),
        (0.50, 0.34, 1.8, 0.5), (0.88, 0.42, 1.5, 0.45),
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

private struct CloudsLayer: View {
    @State private var sway: CGFloat = 0

    private let clouds: [(CGFloat, CGFloat, CGFloat, Double)] = [
        (0.20, 0.30, 150, 0.16), (0.72, 0.22, 190, 0.13),
        (0.50, 0.58, 220, 0.10), (0.84, 0.64, 140, 0.12),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(Array(clouds.enumerated()), id: \.offset) { i, c in
                Ellipse()
                    .fill(Color.white.opacity(c.3))
                    .frame(width: c.2, height: c.2 * 0.42)
                    .blur(radius: 26)
                    .position(x: geo.size.width * c.0 + sway * (i.isMultiple(of: 2) ? 1 : -1),
                              y: geo.size.height * c.1)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 26).repeatForever(autoreverses: true)) {
                sway = 22
            }
        }
    }
}

#Preview {
    FallbackJourneyMapView(data: JourneyMapData(
        origin: GeoCoordinate(latitude: 35.0116, longitude: 135.7681),
        destination: GeoCoordinate(latitude: 34.6851, longitude: 135.8048),
        vehicle: GeoCoordinate(latitude: 34.86, longitude: 135.78),
        progress: 0.45, bearingDegrees: 170,
        mood: .sunset, theme: .coral, followsVehicle: true, isMoving: true
    ))
    .ignoresSafeArea()
}
