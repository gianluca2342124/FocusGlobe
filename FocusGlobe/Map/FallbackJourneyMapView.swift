import SwiftUI

/// A fully native, dependency-free **stylised map** used when the Google Maps
/// SDK isn't linked (and for lightweight previews).
///
/// It deliberately reads as a flat, calm cartographic map (à la FocusFlight) —
/// land + water + faint roads — rather than a sky gradient, so the experience
/// feels map-native everywhere. The real Google map renders in the live session
/// once the SDK package is added.
struct FallbackJourneyMapView: View {
    let data: JourneyMapData
    @Environment(\.colorScheme) private var scheme
    @State private var bob: CGFloat = 0

    // Adaptive flat-map palette.
    private var land: Color { scheme == .dark ? Color(hex: 0x0F1A2E) : Color(hex: 0xE7ECF4) }
    private var water: Color { scheme == .dark ? Color(hex: 0x0A1322) : Color(hex: 0xC7D6E8) }
    private var road: Color { scheme == .dark ? Color(hex: 0x223252) : Color(hex: 0xD2DCEA) }

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
                land

                // Soft water bodies.
                MapBlobs(water: water)

                // Faint road network.
                RoadsLayer(tint: road)

                // Subtle atmospheric mood tint, kept low so it reads as map light.
                RadialGradient(colors: [data.theme.soft.opacity(scheme == .dark ? 0.16 : 0.12), .clear],
                               center: .topTrailing, startRadius: 10, endRadius: size.height * 0.7)
                    .allowsHitTesting(false)

                routeCanvas(full: full, traveled: traveled, origin: originPt, destination: destPt)

                BalloonView(height: 72, showBurner: true, showGlow: true,
                            glow: data.theme.soft, burnerAnimated: data.isMoving)
                    .position(x: vehiclePt.x, y: vehiclePt.y - 22 + bob)
                    .animation(.easeInOut(duration: 1.0), value: vehiclePt)
            }
        }
        .clipped()
        .onAppear {
            guard data.isMoving else { return }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { bob = -6 }
        }
    }

    private func routeCanvas(full: [CGPoint], traveled: [CGPoint],
                             origin: CGPoint, destination: CGPoint) -> some View {
        Canvas { ctx, _ in
            var remaining = Path()
            remaining.addLines(full)
            ctx.stroke(remaining, with: .color(data.theme.soft.opacity(0.55)),
                       style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [1, 9]))

            if traveled.count > 1 {
                var tp = Path()
                tp.addLines(traveled)
                ctx.stroke(tp, with: .color(data.theme.accent.opacity(0.35)),
                           style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
                ctx.stroke(tp, with: .color(data.theme.accent),
                           style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }

            let oRect = CGRect(x: origin.x - 5, y: origin.y - 5, width: 10, height: 10)
            ctx.fill(Path(ellipseIn: oRect), with: .color(.white))
            ctx.stroke(Path(ellipseIn: oRect), with: .color(data.theme.accent), lineWidth: 2.5)

            let dRect = CGRect(x: destination.x - 6, y: destination.y - 6, width: 12, height: 12)
            ctx.fill(Path(ellipseIn: dRect.insetBy(dx: -3, dy: -3)),
                     with: .color(data.theme.accent.opacity(0.25)))
            ctx.fill(Path(ellipseIn: dRect), with: .color(data.theme.accent))
            ctx.stroke(Path(ellipseIn: dRect), with: .color(.white), lineWidth: 2.5)
        }
        .allowsHitTesting(false)
    }
}

/// A few soft water bodies for cartographic depth.
private struct MapBlobs: View {
    let water: Color
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Ellipse().fill(water)
                    .frame(width: w * 0.9, height: h * 0.5)
                    .blur(radius: 26)
                    .position(x: w * 0.85, y: h * 0.82)
                Ellipse().fill(water)
                    .frame(width: w * 0.55, height: h * 0.34)
                    .blur(radius: 24)
                    .position(x: w * 0.1, y: h * 0.12)
                Capsule().fill(water)
                    .frame(width: w * 0.22, height: h * 0.5)
                    .blur(radius: 22)
                    .rotationEffect(.degrees(28))
                    .position(x: w * 0.32, y: h * 0.62)
            }
        }
        .allowsHitTesting(false)
    }
}

/// A faint, organic road network.
private struct RoadsLayer: View {
    let tint: Color
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            func road(_ pts: [CGPoint], width: CGFloat, op: Double) {
                var p = Path()
                p.addLines(pts)
                ctx.stroke(p, with: .color(tint.opacity(op)),
                           style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            }
            road([CGPoint(x: -20, y: h * 0.3), CGPoint(x: w * 0.4, y: h * 0.42),
                  CGPoint(x: w * 0.7, y: h * 0.3), CGPoint(x: w + 20, y: h * 0.38)], width: 3, op: 0.7)
            road([CGPoint(x: w * 0.2, y: -20), CGPoint(x: w * 0.34, y: h * 0.5),
                  CGPoint(x: w * 0.26, y: h + 20)], width: 2.4, op: 0.6)
            road([CGPoint(x: w + 20, y: h * 0.62), CGPoint(x: w * 0.55, y: h * 0.7),
                  CGPoint(x: w * 0.2, y: h * 0.92)], width: 2.4, op: 0.55)
            road([CGPoint(x: -20, y: h * 0.75), CGPoint(x: w * 0.5, y: h * 0.82),
                  CGPoint(x: w + 20, y: h * 0.74)], width: 1.8, op: 0.4)
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
        mood: .night, theme: .indigo, followsVehicle: true, isMoving: true
    ))
    .ignoresSafeArea()
}
