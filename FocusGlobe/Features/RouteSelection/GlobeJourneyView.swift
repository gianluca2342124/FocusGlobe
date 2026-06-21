import Foundation
import SwiftUI

/// An app-level **Globe View**: the journey seen at Earth scale as a geodesic arc
/// on a stylised dark planet, over deep space.
///
/// The Google Maps iOS SDK has no true globe projection, so this is a polished
/// SwiftUI approximation kept fully isolated from the live map renderers — it
/// never touches the Google layer, so it cannot affect normal map rendering.
struct GlobeJourneyView: View {
    let origin: JourneyOrigin
    let route: Route
    @Environment(\.dismiss) private var dismiss

    private var theme: RouteTheme { route.colorTheme }
    private var center: GeoCoordinate {
        GeoMath.interpolate(from: origin.coordinate, to: route.destination, fraction: 0.5)
    }
    private var distanceKm: Double {
        GeoMath.distanceKm(from: origin.coordinate, to: route.destination)
    }

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: 0x0C1226), Color(hex: 0x05070E)],
                           center: .center, startRadius: 10, endRadius: 540)
                .ignoresSafeArea()
            StarField().ignoresSafeArea().opacity(0.55)

            GeometryReader { geo in
                let R = min(geo.size.width, geo.size.height) * 0.40
                let mid = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                ZStack {
                    planet(R: R, mid: mid)
                    GlobeGraticule(center: center, radius: R, mid: mid).opacity(0.6)
                    GlobeArc(origin: origin.coordinate, destination: route.destination,
                             center: center, radius: R, mid: mid,
                             accent: theme.accent, soft: theme.soft)
                    endpoint(origin.coordinate, code: origin.code, color: .white, R: R, mid: mid)
                    endpoint(route.destination, code: route.destinationCode, color: theme.accent, R: R, mid: mid)
                }
            }

            VStack {
                header
                Spacer()
                footer
            }
            .padding(AppSpacing.screen)
        }
        .focusScreenChrome()
    }

    private func planet(R: CGFloat, mid: CGPoint) -> some View {
        Circle()
            .fill(RadialGradient(colors: [Color(hex: 0x20303F), Color(hex: 0x0D1622)],
                                 center: UnitPoint(x: 0.4, y: 0.34), startRadius: 4, endRadius: R * 1.25))
            .frame(width: R * 2, height: R * 2)
            .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            .overlay(Circle().strokeBorder(theme.soft.opacity(0.4), lineWidth: 2).blur(radius: 6))
            .shadow(color: theme.soft.opacity(0.35), radius: 34)
            .position(mid)
    }

    private func endpoint(_ coord: GeoCoordinate, code: String, color: Color,
                          R: CGFloat, mid: CGPoint) -> some View {
        let pr = projectGlobe(coord, center: center, radius: R, mid: mid)
        return Group {
            if pr.visible {
                ZStack {
                    Text(code)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(.black.opacity(0.55)))
                        .overlay(Capsule().strokeBorder(color.opacity(0.6), lineWidth: 1))
                        .offset(y: -18)
                    Circle().fill(color).frame(width: 10, height: 10)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                }
                .position(pr.point)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Globe View").font(AppTypography.headline).foregroundStyle(.white)
                Text("Earth scale").font(AppTypography.caption).foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            AppIconButton(systemImage: "xmark", size: 40, tint: .white,
                          accessibilityLabel: "Close") { dismiss() }
        }
    }

    private var footer: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(origin.code)  →  \(route.destinationCode)")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(origin.city)  →  \(route.destinationName)")
                    .font(AppTypography.caption).foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatters.distance(km: distanceKm))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(route.durationLabel)
                    .font(AppTypography.caption).foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(AppSpacing.md)
        .glassBackground(cornerRadius: AppSpacing.cardRadius, tintOpacity: 0.2, shadowRadius: 12, shadowY: 6)
    }
}

// MARK: - Orthographic projection (near hemisphere → unit disc)

/// Projects a coordinate onto the visible face of the globe centred at `center`.
/// `visible` is false for points on the far hemisphere.
private func projectGlobe(_ coord: GeoCoordinate, center c: GeoCoordinate,
                          radius R: CGFloat, mid: CGPoint) -> (point: CGPoint, visible: Bool) {
    let lat = coord.latitude * .pi / 180
    let lon = coord.longitude * .pi / 180
    let lat0 = c.latitude * .pi / 180
    let lon0 = c.longitude * .pi / 180
    let cosc = sin(lat0) * sin(lat) + cos(lat0) * cos(lat) * cos(lon - lon0)
    let x = cos(lat) * sin(lon - lon0)
    let y = cos(lat0) * sin(lat) - sin(lat0) * cos(lat) * cos(lon - lon0)
    return (CGPoint(x: mid.x + CGFloat(x) * R, y: mid.y - CGFloat(y) * R), cosc >= -0.04)
}

private struct GlobeArc: View {
    let origin: GeoCoordinate
    let destination: GeoCoordinate
    let center: GeoCoordinate
    let radius: CGFloat
    let mid: CGPoint
    let accent: Color
    let soft: Color

    var body: some View {
        Canvas { ctx, _ in
            var path = Path()
            var started = false
            let steps = 90
            for i in 0...steps {
                let t = Double(i) / Double(steps)
                let c = GeoMath.interpolate(from: origin, to: destination, fraction: t)
                let pr = projectGlobe(c, center: center, radius: radius, mid: mid)
                if pr.visible {
                    if started { path.addLine(to: pr.point) }
                    else { path.move(to: pr.point); started = true }
                } else {
                    started = false
                }
            }
            ctx.stroke(path, with: .color(soft.opacity(0.35)), lineWidth: 6)
            ctx.stroke(path, with: .color(accent), lineWidth: 2.5)
        }
        .allowsHitTesting(false)
    }
}

private struct GlobeGraticule: View {
    let center: GeoCoordinate
    let radius: CGFloat
    let mid: CGPoint

    var body: some View {
        Canvas { ctx, _ in
            func draw(_ pts: [GeoCoordinate]) {
                var p = Path()
                var started = false
                for c in pts {
                    let pr = projectGlobe(c, center: center, radius: radius, mid: mid)
                    if pr.visible {
                        if started { p.addLine(to: pr.point) }
                        else { p.move(to: pr.point); started = true }
                    } else {
                        started = false
                    }
                }
                ctx.stroke(p, with: .color(.white.opacity(0.12)), lineWidth: 0.8)
            }
            for lat in stride(from: -60.0, through: 60.0, by: 30.0) {
                draw(stride(from: -180.0, through: 180.0, by: 6.0).map {
                    GeoCoordinate(latitude: lat, longitude: $0)
                })
            }
            for lon in stride(from: -180.0, through: 150.0, by: 30.0) {
                draw(stride(from: -85.0, through: 85.0, by: 5.0).map {
                    GeoCoordinate(latitude: $0, longitude: lon)
                })
            }
        }
        .allowsHitTesting(false)
    }
}

private struct StarField: View {
    var body: some View {
        Canvas { ctx, size in
            var seed: UInt64 = 88_572
            func rnd() -> Double {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Double((seed >> 33) & 0xFFFF) / Double(0xFFFF)
            }
            for _ in 0..<90 {
                let x = rnd() * size.width
                let y = rnd() * size.height
                let r = 0.4 + rnd() * 1.3
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(0.25 + rnd() * 0.5)))
            }
        }
        .allowsHitTesting(false)
    }
}
