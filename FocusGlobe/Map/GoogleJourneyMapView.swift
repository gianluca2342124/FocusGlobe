// Google Maps is the temporary MVP provider. Keep all business logic
// provider-independent so we can migrate to Apple Maps / MapKit later.
//
// This file is the ONLY place that touches the Google Maps SDK for journeys.
// It is fully guarded by `#if canImport(GoogleMaps)` so the project compiles
// and runs even before the SDK package is added (the native fallback map is
// used until then). When migrating to Apple Maps, this file is replaced by
// AppleJourneyMapView — nothing else changes.

#if canImport(GoogleMaps)
import CoreLocation
import GoogleMaps
import SwiftUI
import UIKit

struct GoogleJourneyMapView: UIViewRepresentable {
    let data: JourneyMapData
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> GMSMapView {
        let zoom = CameraController.zoom(forDistanceKm: data.routeDistanceKm)
        let camera = GMSCameraPosition.camera(
            withLatitude: data.vehicle.latitude,
            longitude: data.vehicle.longitude,
            zoom: Float(zoom)
        )
        let map = GMSMapView(frame: .zero, camera: camera)
        map.isMyLocationEnabled = false
        map.settings.compassButton = false
        map.settings.myLocationButton = false
        map.settings.indoorPicker = false
        // Calm, distraction-free: the user focuses, not pans.
        map.settings.scrollGestures = false
        map.settings.zoomGestures = false
        map.settings.tiltGestures = false
        map.settings.rotateGestures = false
        map.isBuildingsEnabled = false
        map.accessibilityElementsHidden = true
        return map
    }

    func updateUIView(_ map: GMSMapView, context: Context) {
        context.coordinator.apply(style: colorScheme, to: map)
        context.coordinator.configureIfNeeded(map: map, data: data)
        context.coordinator.update(map: map, data: data)
    }

    // MARK: - Coordinator

    final class Coordinator {
        private var didConfigure = false
        private var isDarkApplied: Bool?

        private var originMarker: GMSMarker?
        private var destinationMarker: GMSMarker?
        private var vehicleMarker: GMSMarker?
        private var fullPolyline: GMSPolyline?
        private var glowPolyline: GMSPolyline?
        private var traveledPolyline: GMSPolyline?

        private var movedCameraOnce = false

        func apply(style colorScheme: ColorScheme, to map: GMSMapView) {
            let dark = (colorScheme == .dark)
            guard isDarkApplied != dark else { return }
            isDarkApplied = dark
            map.mapStyle = try? GMSMapStyle(jsonString: dark ? MapStyles.dark : MapStyles.light)
        }

        func configureIfNeeded(map: GMSMapView, data: JourneyMapData) {
            guard !didConfigure else { return }
            didConfigure = true

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

            // Travelled portion (bright accent).
            let traveled = GMSPolyline()
            traveled.strokeWidth = 7
            traveled.strokeColor = UIColor(data.theme.accent)
            traveled.zIndex = 3
            traveled.map = map
            traveledPolyline = traveled

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

            // Vehicle (the balloon).
            let vehicle = GMSMarker(position: CLLocationCoordinate2D(latitude: data.vehicle.latitude, longitude: data.vehicle.longitude))
            vehicle.icon = VehicleMarkerRenderer.balloonImage(targetHeight: 72, glow: data.theme.soft)
            vehicle.groundAnchor = CGPoint(x: 0.5, y: 0.84) // basket sits on the point
            vehicle.isTappable = false
            vehicle.zIndex = 6
            vehicle.map = map
            vehicleMarker = vehicle
        }

        func update(map: GMSMapView, data: JourneyMapData) {
            let vehicleCoord = CLLocationCoordinate2D(latitude: data.vehicle.latitude, longitude: data.vehicle.longitude)

            // Glide the balloon to its new position.
            CATransaction.begin()
            CATransaction.setAnimationDuration(data.isMoving ? 1.0 : 0)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .linear))
            vehicleMarker?.position = vehicleCoord
            CATransaction.commit()

            // Update the travelled polyline.
            let traveledPath = GMSMutablePath()
            MapRouteRenderer.traveledPoints(from: data.origin, to: data.vehicle)
                .forEach { traveledPath.add(CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)) }
            traveledPolyline?.path = traveledPath

            // Gently follow.
            if data.followsVehicle && (data.isMoving || !movedCameraOnce) {
                movedCameraOnce = true
                let zoom = Float(CameraController.zoom(forDistanceKm: data.routeDistanceKm))
                CATransaction.begin()
                CATransaction.setAnimationDuration(1.2)
                CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .linear))
                map.animate(to: GMSCameraPosition.camera(withTarget: vehicleCoord, zoom: zoom))
                CATransaction.commit()
            }
        }
    }
}
#endif
