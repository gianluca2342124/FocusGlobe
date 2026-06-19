import SwiftUI

/// The route-selection canvas: a flat cartographic map showing the selected
/// journey (origin → destination) with airport-style code tags and the balloon.
/// Mirrors the FocusFlight discovery look. It uses the controllable stylised
/// renderer so the on-map code tags stay perfectly aligned with the route.
struct JourneyDiscoveryMap: View {
    let route: Route

    private var data: JourneyMapData {
        JourneyMapData(
            origin: route.origin,
            destination: route.destination,
            vehicle: GeoMath.interpolate(from: route.origin, to: route.destination, fraction: 0.5),
            progress: 0.5,
            bearingDegrees: GeoMath.bearingDegrees(from: route.origin, to: route.destination),
            mood: route.mood,
            theme: route.colorTheme,
            followsVehicle: false,
            isMoving: false
        )
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            // Must match FallbackJourneyMapView's internal inset (64) so tags
            // align with the route's origin/destination dots.
            let proj = GeoProjection(coords: [route.origin, route.destination], size: size, inset: 64)
            let o = proj.point(for: route.origin)
            let d = proj.point(for: route.destination)

            ZStack {
                FallbackJourneyMapView(data: data)
                    .frame(width: size.width, height: size.height)

                CodeTag(code: route.originCode, highlighted: false)
                    .position(x: o.x, y: o.y - 20)
                CodeTag(code: route.destinationCode, highlighted: true)
                    .position(x: d.x, y: d.y - 20)
            }
        }
        .allowsHitTesting(false)
    }
}

/// An airport-style code tag (amber accent), à la FocusFlight.
private struct CodeTag: View {
    let code: String
    let highlighted: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: highlighted ? "mappin" : "circle.fill")
                .font(.system(size: highlighted ? 9 : 6, weight: .bold))
            Text(code)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(highlighted ? Color(hex: 0x14181F) : .white)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(highlighted ? AnyShapeStyle(AppColors.gold)
                                       : AnyShapeStyle(Color.black.opacity(0.55)))
        )
        .overlay(Capsule().strokeBorder(AppColors.gold, lineWidth: highlighted ? 0 : 1.5))
        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }
}
