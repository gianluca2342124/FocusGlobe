import SwiftUI
#if canImport(GoogleMaps)
import CoreLocation
import GoogleMaps
import UIKit
#endif

/// A calm, non-interactive **background map** for the primary screens (Home,
/// Journey Selection, Prepare/Boarding).
///
/// When the Google Maps SDK is linked it renders a real, premium night map —
/// the aurora/galaxy surface is reserved as an atmospheric *overlay/scrim* on
/// top (applied by the screens), never as a replacement here. Only when the SDK
/// is absent (no-dependency / preview builds) does it fall back to the stylised
/// aurora map.
///
/// Modes:
///  • `.origin` — frame the user's current location (soft halo, optionally a
///    small balloon "ready to depart"). Used on Home.
///  • `.route`  — frame the journey from the user's location to the destination
///    (route line, endpoints, optional code tags). Used on Selection & Boarding.
/// A nearby destination shown as a subtle "radar" marker on the Choose Journey
/// map (small code tag at a real coordinate). Display-only.
struct MapPin: Equatable {
    let code: String
    let coordinate: GeoCoordinate
}

struct JourneyBackdropMap: View {
    enum Mode: Equatable { case origin, route }

    let origin: JourneyOrigin
    var destination: Route?
    var mode: Mode = .origin
    /// Balloon position along the route preview (0…1). Ignored in `.origin`.
    var progress: Double = 0.5
    var showsCodeTags: Bool = false
    /// Show the balloon marker. Off on Choose Journey (the user is selecting a
    /// destination, not watching the balloon yet).
    var showsBalloon: Bool = true
    /// Show the origin halo/dot. Off when there's no real origin yet.
    var showsOrigin: Bool = true
    /// Bottom inset (points) so the origin sits in the upper half of the screen,
    /// above the text block. Used on Home; 0 elsewhere.
    var bottomInset: CGFloat = 0
    /// Camera zoom for origin-only framing (Home). Lower = more of the
    /// region/world. Only affects `.origin` mode with an origin shown.
    var originZoom: Float = 9.3
    /// Nearby destinations to surface as a subtle radar of small tags (Choose
    /// Journey only). Empty everywhere else.
    var nearby: [MapPin] = []
    /// The selected balloon skin asset name for the (optional) balloon marker.
    /// Defaults to the standard balloon; Home passes the user's selected skin.
    var skinAssetName: String = BalloonSkin.default.assetName
    /// Reports the origin's on-screen point (in the map's coordinate space) so a
    /// SwiftUI radar pulse can be overlaid there. `nil` when no origin is shown.
    var onOriginPoint: (CGPoint?) -> Void = { _ in }

    private var theme: RouteTheme { destination?.colorTheme ?? .teal }
    private var mood: RouteMood { destination?.mood ?? .calm }

    var body: some View {
        switch FocusGlobeMapProvider.current {
        case .apple:
            appleBackdrop
        case .google:
            googleBackdrop
        case .fallback:
            fallback.allowsHitTesting(false)
        }
    }

    /// Apple Maps (MapKit) backdrop — the default for the normal app path.
    private var appleBackdrop: some View {
        AppleBackdropMapView(origin: origin, destination: destination,
                             mode: mode, progress: progress,
                             showsCodeTags: showsCodeTags, showsBalloon: showsBalloon,
                             showsOrigin: showsOrigin, bottomInset: bottomInset,
                             nearby: nearby, onOriginPoint: onOriginPoint,
                             originZoom: originZoom, theme: theme,
                             skinAssetName: skinAssetName)
            .allowsHitTesting(false)
    }

    /// Google Maps backdrop — kept as a migration-phase fallback (DEBUG override).
    @ViewBuilder private var googleBackdrop: some View {
        #if canImport(GoogleMaps)
        GoogleBackdropMapView(origin: origin, destination: destination,
                              mode: mode, progress: progress,
                              showsCodeTags: showsCodeTags, showsBalloon: showsBalloon,
                              showsOrigin: showsOrigin, bottomInset: bottomInset,
                              nearby: nearby, onOriginPoint: onOriginPoint,
                              originZoom: originZoom, theme: theme,
                              skinAssetName: skinAssetName)
            .allowsHitTesting(false)
        #else
        fallback.allowsHitTesting(false)
        #endif
    }

    // MARK: - Aurora fallback (no SDK only)

    private var destinationCoordinate: GeoCoordinate {
        if let destination { return destination.destination }
        return GeoCoordinate(latitude: origin.coordinate.latitude + 6,
                             longitude: origin.coordinate.longitude + 8)
    }

    private var fallbackData: JourneyMapData {
        let frac = (mode == .origin) ? 0.0 : progress
        return JourneyMapData(
            origin: origin.coordinate,
            destination: destinationCoordinate,
            vehicle: GeoMath.interpolate(from: origin.coordinate, to: destinationCoordinate, fraction: frac),
            progress: frac,
            bearingDegrees: GeoMath.bearingDegrees(from: origin.coordinate, to: destinationCoordinate),
            mood: mood,
            theme: theme,
            followsVehicle: false,
            isMoving: false
        )
    }

    @ViewBuilder private var fallback: some View {
        if showsCodeTags, mode == .route {
            GeometryReader { geo in
                let size = geo.size
                let proj = GeoProjection(coords: [origin.coordinate, destinationCoordinate],
                                         size: size, inset: 64)
                let o = proj.point(for: origin.coordinate)
                let d = proj.point(for: destinationCoordinate)
                ZStack {
                    FallbackJourneyMapView(data: fallbackData)
                        .frame(width: size.width, height: size.height)
                    MapCodeTag(code: origin.code, highlighted: false)
                        .position(x: o.x, y: o.y - 22)
                    MapCodeTag(code: destination?.destinationCode ?? "FLY", highlighted: true)
                        .position(x: d.x, y: d.y - 22)
                }
            }
        } else {
            FallbackJourneyMapView(data: fallbackData)
        }
    }
}

/// An airport-style code tag (amber accent), à la FocusFlight. Used only by the
/// aurora fallback overlay; the Google backdrop renders tags as marker icons.
struct MapCodeTag: View {
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

#if canImport(GoogleMaps)
/// The real Google night map used as a backdrop on the primary screens.
/// Non-interactive and static (no take-off animation, no following).
struct GoogleBackdropMapView: UIViewRepresentable {
    let origin: JourneyOrigin
    let destination: Route?
    let mode: JourneyBackdropMap.Mode
    let progress: Double
    let showsCodeTags: Bool
    let showsBalloon: Bool
    let showsOrigin: Bool
    let bottomInset: CGFloat
    let nearby: [MapPin]
    let onOriginPoint: (CGPoint?) -> Void
    let originZoom: Float
    let theme: RouteTheme
    let skinAssetName: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(withLatitude: origin.coordinate.latitude,
                                              longitude: origin.coordinate.longitude,
                                              zoom: 10.5)
        let map = GMSMapView(frame: .zero, camera: camera)
        map.mapStyle = try? GMSMapStyle(jsonString: MapStyles.graphite)
        map.isMyLocationEnabled = false
        map.settings.setAllGesturesEnabled(false)
        map.settings.compassButton = false
        map.settings.myLocationButton = false
        map.isBuildingsEnabled = false
        map.accessibilityElementsHidden = true
        return map
    }

    func updateUIView(_ map: GMSMapView, context: Context) {
        // Bottom inset lifts the origin into the upper half (Home), clearing the
        // text block below.
        map.padding = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
        context.coordinator.configure(map: map, view: self)

        // Report the origin's screen point for the SwiftUI radar overlay.
        let report = onOriginPoint
        let showOrigin = showsOrigin
        let coord = CLLocationCoordinate2D(latitude: origin.coordinate.latitude,
                                           longitude: origin.coordinate.longitude)
        DispatchQueue.main.async {
            report(showOrigin ? map.projection.point(for: coord) : nil)
        }
    }

    final class Coordinator {
        private var markers: [GMSMarker] = []
        private var polylines: [GMSPolyline] = []
        private var circle: GMSCircle?
        private var rings: [GMSCircle] = []
        private var lastKey = ""

        func configure(map: GMSMapView, view: GoogleBackdropMapView) {
            let dest = view.destination
            let key = [
                view.mode == .origin ? "origin" : "route",
                String(format: "%.3f,%.3f", view.origin.coordinate.latitude, view.origin.coordinate.longitude),
                dest?.id ?? "-",
                view.showsCodeTags ? "t" : "_", view.showsBalloon ? "b" : "_", view.showsOrigin ? "o" : "_",
                String(format: "%.0f", view.bottomInset),
                "n\(view.nearby.count)",
                view.skinAssetName
            ].joined(separator: "|")
            guard key != lastKey else { return }
            lastKey = key

            markers.forEach { $0.map = nil }; markers.removeAll()
            polylines.forEach { $0.map = nil }; polylines.removeAll()
            rings.forEach { $0.map = nil }; rings.removeAll()
            circle?.map = nil; circle = nil

            let accent = UIColor(view.theme.accent)
            let soft = UIColor(view.theme.soft)
            let originCoord = CLLocationCoordinate2D(latitude: view.origin.coordinate.latitude,
                                                     longitude: view.origin.coordinate.longitude)

            if view.showsOrigin {
                let halo = GMSCircle(position: originCoord, radius: view.mode == .origin ? 2600 : 1400)
                halo.fillColor = soft.withAlphaComponent(0.18)
                halo.strokeColor = accent.withAlphaComponent(0.55)
                halo.strokeWidth = 2
                halo.map = map
                circle = halo

                let originDot = GMSMarker(position: originCoord)
                originDot.icon = VehicleMarkerRenderer.dotImage(diameter: 12, fill: .white, ring: accent, ringWidth: 3)
                originDot.groundAnchor = CGPoint(x: 0.5, y: 0.5)
                originDot.isTappable = false
                originDot.zIndex = 4
                originDot.map = map
                markers.append(originDot)
            }

            guard view.mode == .route, let dest else {
                // Origin-only (Home): optional small balloon over "you are here".
                if view.showsBalloon {
                    let balloon = GMSMarker(position: originCoord)
                    balloon.icon = VehicleMarkerRenderer.balloonImage(targetHeight: 58, glow: view.theme.soft,
                                                                      assetName: view.skinAssetName)
                    balloon.groundAnchor = CGPoint(x: 0.5, y: 0.9)
                    balloon.isTappable = false
                    balloon.zIndex = 6
                    balloon.map = map
                    markers.append(balloon)
                }
                if view.showsCodeTags && view.showsOrigin {
                    addTag(code: view.origin.code, highlighted: false, at: originCoord, accent: accent, on: map)
                }
                // Zoomed out so you see the city/region from above, not the street.
                let zoom: Float = view.showsOrigin ? view.originZoom : 4.0
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                map.moveCamera(GMSCameraUpdate.setCamera(
                    GMSCameraPosition.camera(withTarget: originCoord, zoom: zoom)))
                CATransaction.commit()
                return
            }

            let destCoord = CLLocationCoordinate2D(latitude: dest.destination.latitude,
                                                   longitude: dest.destination.longitude)

            // Route line: soft halo + bright core.
            let path = GMSMutablePath()
            MapRouteRenderer.routePoints(from: view.origin.coordinate, to: dest.destination)
                .forEach { path.add(CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)) }
            let glow = GMSPolyline(path: path)
            glow.strokeWidth = 12
            glow.strokeColor = soft.withAlphaComponent(0.20)
            glow.zIndex = 1
            glow.map = map
            polylines.append(glow)
            let line = GMSPolyline(path: path)
            line.strokeWidth = 4
            line.strokeColor = accent
            line.zIndex = 2
            line.map = map
            polylines.append(line)

            // Destination dot + soft glow.
            let destDot = GMSMarker(position: destCoord)
            destDot.icon = VehicleMarkerRenderer.dotImage(diameter: 13, fill: accent, ring: .white, ringWidth: 3)
            destDot.groundAnchor = CGPoint(x: 0.5, y: 0.5)
            destDot.isTappable = false
            destDot.zIndex = 4
            destDot.map = map
            markers.append(destDot)

            if view.showsBalloon {
                let vehicle = GeoMath.interpolate(from: view.origin.coordinate, to: dest.destination, fraction: view.progress)
                let balloon = GMSMarker(position: CLLocationCoordinate2D(latitude: vehicle.latitude, longitude: vehicle.longitude))
                balloon.icon = VehicleMarkerRenderer.balloonImage(targetHeight: 84, glow: view.theme.soft,
                                                                  assetName: view.skinAssetName)
                balloon.groundAnchor = CGPoint(x: 0.5, y: 0.88)
                balloon.isTappable = false
                balloon.zIndex = 6
                balloon.map = map
                markers.append(balloon)
            }

            // Radar of nearby destinations around the origin (Choose Journey only).
            if !view.nearby.isEmpty {
                for (i, km) in [45.0, 95.0, 165.0].enumerated() {
                    let ring = GMSCircle(position: originCoord, radius: km * 1000)
                    ring.fillColor = .clear
                    ring.strokeColor = accent.withAlphaComponent(CGFloat(0.45 - Double(i) * 0.12))
                    ring.strokeWidth = 1.4
                    ring.zIndex = 0
                    ring.map = map
                    rings.append(ring)
                }
                for pin in view.nearby.prefix(10) where pin.code != dest.destinationCode {
                    let c = CLLocationCoordinate2D(latitude: pin.coordinate.latitude,
                                                   longitude: pin.coordinate.longitude)
                    let tag = GMSMarker(position: c)
                    tag.icon = VehicleMarkerRenderer.tagImage(code: pin.code, highlighted: false,
                                                              accent: UIColor(AppColors.textPrimary))
                    tag.groundAnchor = CGPoint(x: 0.5, y: 1.0)
                    tag.isTappable = false
                    tag.zIndex = 5
                    tag.map = map
                    markers.append(tag)
                }
            }

            if view.showsCodeTags {
                if view.showsOrigin {
                    addTag(code: view.origin.code, highlighted: false, at: originCoord, accent: accent, on: map)
                }
                addTag(code: dest.destinationCode, highlighted: true, at: destCoord, accent: UIColor(AppColors.gold), on: map)
            }

            // Frame the whole route (camera by centre + zoom — frame-independent).
            let mid = GeoMath.interpolate(from: view.origin.coordinate, to: dest.destination, fraction: 0.5)
            let distance = GeoMath.distanceKm(from: view.origin.coordinate, to: dest.destination)
            let zoom = max(2.4, CameraController.zoom(forDistanceKm: distance) - 0.8)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            map.moveCamera(GMSCameraUpdate.setCamera(
                GMSCameraPosition.camera(withTarget: CLLocationCoordinate2D(latitude: mid.latitude, longitude: mid.longitude),
                                         zoom: Float(zoom))))
            CATransaction.commit()
        }

        private func addTag(code: String, highlighted: Bool, at coord: CLLocationCoordinate2D,
                            accent: UIColor, on map: GMSMapView) {
            let tag = GMSMarker(position: coord)
            tag.icon = VehicleMarkerRenderer.tagImage(code: code, highlighted: highlighted, accent: accent)
            tag.groundAnchor = CGPoint(x: 0.5, y: 1.0)
            tag.isTappable = false
            tag.zIndex = 7
            tag.map = map
            markers.append(tag)
        }
    }
}
#endif
