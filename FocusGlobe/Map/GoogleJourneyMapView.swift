// Google Maps is the temporary MVP provider. Keep all business logic
// provider-independent so we can migrate to Apple Maps / MapKit later.
//
// This file is the ONLY place that touches the Google Maps SDK for the live
// journey. It is fully guarded by `#if canImport(GoogleMaps)` so the project
// compiles and runs even before the SDK package is added (the native fallback
// map is used until then). When migrating to Apple Maps, this file is replaced
// by AppleJourneyMapView — nothing else changes.

#if canImport(GoogleMaps)
import CoreLocation
import GoogleMaps
import SwiftUI
import UIKit

struct GoogleJourneyMapView: UIViewRepresentable {
    let data: JourneyMapData
    /// Called when the user pans the map by hand (so the session can pause
    /// following until they tap Recenter).
    var onUserPan: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> GMSMapView {
        let zoom = CameraController.zoom(forDistanceKm: data.routeDistanceKm)
        let camera = GMSCameraPosition.camera(
            withLatitude: data.vehicle.latitude,
            longitude: data.vehicle.longitude,
            zoom: Float(zoom)
        )
        let map = GMSMapView(frame: .zero, camera: camera)
        map.delegate = context.coordinator
        map.isMyLocationEnabled = false
        map.settings.compassButton = false
        map.settings.myLocationButton = false
        map.settings.indoorPicker = false
        // Calm, focus-oriented: the user can pan/zoom to explore, but we never
        // rotate or tilt by hand (tilt is a deliberate control instead).
        map.settings.scrollGestures = true
        map.settings.zoomGestures = true
        map.settings.tiltGestures = false
        map.settings.rotateGestures = false
        map.isBuildingsEnabled = false
        map.accessibilityElementsHidden = true
        return map
    }

    func updateUIView(_ map: GMSMapView, context: Context) {
        context.coordinator.onUserPan = onUserPan
        context.coordinator.apply(displayStyle: data.style, to: map)
        context.coordinator.configureIfNeeded(map: map, data: data)
        context.coordinator.update(map: map, data: data)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var onUserPan: () -> Void = {}

        private var didConfigure = false
        private var lastStyle: MapDisplayStyle?

        private var originMarker: GMSMarker?
        private var destinationMarker: GMSMarker?
        private var vehicleMarker: GMSMarker?
        private var fullPolyline: GMSPolyline?
        private var glowPolyline: GMSPolyline?
        private var traveledPolyline: GMSPolyline?

        /// Becomes true once the take-off camera has zoomed to the balloon;
        /// thereafter the camera gently follows it (unless the user pans).
        private var following = false
        private var takeoffDone = false

        private var lastCameraMode: JourneyCameraMode = .follow
        private var lastCameraToken = Int.min
        private var lastTilted = false

        // MARK: Delegate — detect manual panning

        func mapView(_ mapView: GMSMapView, willMove gesture: Bool) {
            guard gesture else { return } // ignore our own programmatic moves
            following = false
            onUserPan()
        }

        // MARK: Style

        /// Applies the chosen presentation: map type + custom style JSON.
        func apply(displayStyle: MapDisplayStyle, to map: GMSMapView) {
            guard lastStyle != displayStyle else { return }
            lastStyle = displayStyle
            switch displayStyle {
            case .graphite:
                map.mapType = .normal
                map.mapStyle = try? GMSMapStyle(jsonString: MapStyles.graphite)
            case .standard:
                map.mapType = .normal
                map.mapStyle = try? GMSMapStyle(jsonString: MapStyles.light)
            case .terrain:
                map.mapType = .terrain
                map.mapStyle = nil
            case .satellite:
                map.mapType = .satellite
                map.mapStyle = nil
            case .hybrid:
                map.mapType = .hybrid
                map.mapStyle = nil
            case .night:
                map.mapType = .normal
                map.mapStyle = try? GMSMapStyle(jsonString: MapStyles.dark)
            case .monochrome:
                map.mapType = .normal
                map.mapStyle = try? GMSMapStyle(jsonString: MapStyles.monochrome)
            }
        }

        func configureIfNeeded(map: GMSMapView, data: JourneyMapData) {
            guard !didConfigure else { return }
            didConfigure = true
            lastCameraMode = data.cameraMode
            lastCameraToken = data.cameraToken
            lastTilted = data.tilted

            let fullPath = GMSMutablePath()
            MapRouteRenderer.routePoints(from: data.origin, to: data.destination)
                .forEach { fullPath.add(CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)) }

            // Soft halo beneath the whole route for a premium, glowing line.
            let glow = GMSPolyline(path: fullPath)
            glow.strokeWidth = 13
            glow.strokeColor = UIColor(data.theme.soft).withAlphaComponent(0.20)
            glow.zIndex = 1
            glow.map = map
            glowPolyline = glow

            // Full route (faint, the "remaining" track).
            let full = GMSPolyline(path: fullPath)
            full.strokeWidth = 5
            full.strokeColor = UIColor(data.theme.soft).withAlphaComponent(0.55)
            full.zIndex = 2
            full.map = map
            fullPolyline = full

            // A subtle white air trail behind the balloon (NOT a coloured
            // completed-route line — there is a single route line only). It fades
            // from invisible at the tail to soft white near the basket (set as a
            // gradient span each frame in `update`).
            let trail = GMSPolyline()
            trail.strokeWidth = 6
            trail.strokeColor = UIColor.white.withAlphaComponent(0.28)
            trail.zIndex = 5
            trail.map = map
            traveledPolyline = trail

            // Origin & destination dots.
            let origin = GMSMarker(position: CLLocationCoordinate2D(latitude: data.origin.latitude, longitude: data.origin.longitude))
            origin.icon = VehicleMarkerRenderer.dotImage(diameter: 12, fill: .white,
                                                         ring: UIColor(data.theme.accent), ringWidth: 3)
            origin.groundAnchor = CGPoint(x: 0.5, y: 0.5)
            origin.isTappable = false
            origin.zIndex = 4
            origin.map = map
            originMarker = origin

            let destination = GMSMarker(position: CLLocationCoordinate2D(latitude: data.destination.latitude, longitude: data.destination.longitude))
            destination.icon = VehicleMarkerRenderer.dotImage(diameter: 13, fill: UIColor(data.theme.accent),
                                                             ring: .white, ringWidth: 3)
            destination.groundAnchor = CGPoint(x: 0.5, y: 0.5)
            destination.isTappable = false
            destination.zIndex = 4
            destination.map = map
            destinationMarker = destination

            // Vehicle (the balloon) — large, premium presence (the protagonist).
            // Rendered with the user's selected skin (falls back to the default art).
            let vehicle = GMSMarker(position: CLLocationCoordinate2D(latitude: data.vehicle.latitude, longitude: data.vehicle.longitude))
            vehicle.icon = VehicleMarkerRenderer.balloonImage(targetHeight: 72, glow: data.theme.soft,
                                                              assetName: data.skinAssetName)
            vehicle.groundAnchor = CGPoint(x: 0.5, y: 0.86) // basket sits near the point; envelope above
            vehicle.isTappable = false
            vehicle.zIndex = 6
            vehicle.map = map
            vehicleMarker = vehicle

            // --- Take-off camera: centre on the balloon (the start) FIRST, then a
            // quick, smooth zoom IN toward it. Both the start and end poses are
            // centred on the balloon (we never fly out to the route midpoint), so
            // the motion is fast and identical for Short…Ultra — never sluggish on
            // long routes.
            let startTarget = CLLocationCoordinate2D(latitude: data.vehicle.latitude,
                                                     longitude: data.vehicle.longitude)
            let zoom = CameraController.followZoom(forDistanceKm: data.routeDistanceKm)
            map.moveCamera(GMSCameraUpdate.setTarget(startTarget, zoom: Float(max(3, zoom - 2.4))))

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self, weak map] in
                guard let self, let map else { return }
                CATransaction.begin()
                CATransaction.setAnimationDuration(1.1)
                CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
                map.animate(to: self.followCamera(for: data, vehicle: data.vehicle))
                CATransaction.commit()
                self.following = true
                self.takeoffDone = true
            }
        }

        func update(map: GMSMapView, data: JourneyMapData) {
            let vehicleCoord = CLLocationCoordinate2D(latitude: data.vehicle.latitude, longitude: data.vehicle.longitude)

            // Glide the balloon to its new position.
            CATransaction.begin()
            CATransaction.setAnimationDuration(data.isMoving ? 1.0 : 0)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .linear))
            vehicleMarker?.position = vehicleCoord
            CATransaction.commit()

            // Air trail: just the short wisp of route immediately behind the
            // balloon (fades back into the single route line).
            let tailStartFrac = max(0, data.progress - 0.06)
            let tailStart = GeoMath.interpolate(from: data.origin, to: data.destination, fraction: tailStartFrac)
            let trailPath = GMSMutablePath()
            MapRouteRenderer.traveledPoints(from: tailStart, to: data.vehicle, samples: 14)
                .forEach { trailPath.add(CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)) }
            traveledPolyline?.path = trailPath
            // Fade the wisp from invisible at the tail to a soft translucent white
            // right behind the basket — reads as moving air (not smoke) and never
            // competes with the single coloured route line.
            if trailPath.count() > 1 {
                let air = GMSStrokeStyle.gradient(from: UIColor.white.withAlphaComponent(0.0),
                                                  to: UIColor.white.withAlphaComponent(0.34))
                traveledPolyline?.spans = [GMSStyleSpan(style: air)]
            }

            // Respond to explicit camera commands (Recenter / Full Route / Tilt).
            let commandChanged = data.cameraToken != lastCameraToken
                || data.cameraMode != lastCameraMode
                || data.tilted != lastTilted
            if commandChanged && takeoffDone {
                lastCameraToken = data.cameraToken
                lastCameraMode = data.cameraMode
                lastTilted = data.tilted
                applyCamera(map: map, data: data)
            }

            // Gently follow once the take-off sequence has finished and the user
            // hasn't taken manual control. A slower glide keeps the motion calm.
            if following && data.cameraMode == .follow && data.isMoving {
                CATransaction.begin()
                CATransaction.setAnimationDuration(1.9)
                CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .linear))
                map.animate(to: followCamera(for: data, vehicle: data.vehicle))
                CATransaction.commit()
            }
        }

        // MARK: Camera helpers

        private func applyCamera(map: GMSMapView, data: JourneyMapData) {
            switch data.cameraMode {
            case .overview:
                following = false
                let bounds = GMSCoordinateBounds(
                    coordinate: CLLocationCoordinate2D(latitude: data.origin.latitude, longitude: data.origin.longitude),
                    coordinate: CLLocationCoordinate2D(latitude: data.destination.latitude, longitude: data.destination.longitude))
                CATransaction.begin()
                CATransaction.setAnimationDuration(1.0)
                CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
                map.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 70))
                CATransaction.commit()
            case .follow:
                following = true
                CATransaction.begin()
                CATransaction.setAnimationDuration(1.0)
                CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
                map.animate(to: followCamera(for: data, vehicle: data.vehicle))
                CATransaction.commit()
            }
        }

        private func followCamera(for data: JourneyMapData, vehicle: GeoCoordinate) -> GMSCameraPosition {
            // Close zoom so the balloon drifts over real neighbourhoods/roads.
            GMSCameraPosition(
                target: CLLocationCoordinate2D(latitude: vehicle.latitude, longitude: vehicle.longitude),
                zoom: Float(CameraController.followZoom(forDistanceKm: data.routeDistanceKm)),
                bearing: 0,
                viewingAngle: data.tilted ? 55 : 0
            )
        }
    }
}
#endif
