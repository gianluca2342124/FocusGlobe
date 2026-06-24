import CoreLocation
import MapKit
import SwiftUI
import UIKit

/// The live in-flight Apple Maps (MapKit) renderer. Consumes the exact same
/// provider-independent `JourneyMapData` as the Google renderer, so journey,
/// timer, progress and reward logic are untouched. Selected via
/// `FocusGlobeMapProvider` from `JourneyMapView`.
///
/// Preserves the working experience: centre-on-balloon → quick zoom-in takeoff,
/// gentle follow, Full Route / Recenter / Tilt controls, the selected balloon
/// skin, a faint full route + a subtle white air trail (no coloured completed
/// line), and a dark/terrain default.
struct AppleActiveJourneyMapView: UIViewRepresentable {
    let data: JourneyMapData
    /// Called when the user pans the map by hand (so following pauses until Recenter).
    var onUserPan: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.isRotateEnabled = false
        map.isPitchEnabled = false          // tilt is a deliberate control, not a gesture
        map.isZoomEnabled = true
        map.isScrollEnabled = true
        map.showsUserLocation = false
        map.isAccessibilityElement = false
        map.accessibilityElementsHidden = true
        // iPad/Mac: flat elevation so the live map appears immediately instead of
        // streaming in heavy 3D buildings. iPhone keeps the realistic 3D look.
        AppleMapStyle.apply(data.style, to: map, labelsOn: data.labelsOn,
                            preferFlatElevation: Layout.isPadIdiom)

        // Detect manual panning so the session can pause following.
        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = context.coordinator
        map.addGestureRecognizer(pan)

        // Start framed on the whole route (overview) so the first frame is the
        // cinematic overview, not the default world map.
        let mid = GeoMath.interpolate(from: data.origin, to: data.destination, fraction: 0.5)
        map.setCamera(MKMapCamera(lookingAtCenter: mid.cl,
                                  fromDistance: AppleMapCameraController.overviewDistance(forRouteKm: data.routeDistanceKm),
                                  pitch: 0, heading: 0), animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.onUserPan = onUserPan
        context.coordinator.apply(style: data.style, labelsOn: data.labelsOn, to: map)
        context.coordinator.configureIfNeeded(map: map, data: data)
        context.coordinator.update(map: map, data: data)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var onUserPan: () -> Void = {}

        private var didConfigure = false
        private var lastStyle: MapDisplayStyle?
        private var lastLabelsOn: Bool?
        private var following = false
        private var takeoffDone = false
        private var lastCameraMode: JourneyCameraMode = .follow
        private var lastCameraToken = Int.min
        private var lastTilted = false
        private var theme: RouteTheme = .teal

        private var balloon: MapImageAnnotation?
        private var routeOverlay: MKGeodesicPolyline?

        // MARK: Gestures — detect manual panning

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            if gesture.state == .began {
                following = false
                onUserPan()
            }
        }

        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        // MARK: Style

        func apply(style: MapDisplayStyle, labelsOn: Bool, to map: MKMapView) {
            guard lastStyle != style || lastLabelsOn != labelsOn else { return }
            lastStyle = style
            lastLabelsOn = labelsOn
            AppleMapStyle.apply(style, to: map, labelsOn: labelsOn,
                                preferFlatElevation: Layout.isPadIdiom)
        }

        // MARK: Configure (once)

        func configureIfNeeded(map: MKMapView, data: JourneyMapData) {
            guard !didConfigure else { return }
            didConfigure = true
            theme = data.theme
            lastCameraMode = data.cameraMode
            lastCameraToken = data.cameraToken
            lastTilted = data.tilted

            // Faint full route only (no coloured "completed" line — just this plus
            // the white air trail).
            let route = AppleMapRouteRenderer.geodesicRoute(from: data.origin, to: data.destination,
                                                            tag: AppleMapRouteRenderer.Tag.routeSoft)
            map.addOverlay(route, level: .aboveLabels)   // sit as high as MapKit allows (cleaner in 3D)
            routeOverlay = route

            // Origin & destination dots.
            map.addAnnotation(AppleMapAnnotationRenderer.dot(at: data.origin.cl, fill: .white,
                                                             ring: UIColor(theme.accent), diameter: 12))
            map.addAnnotation(AppleMapAnnotationRenderer.dot(at: data.destination.cl, fill: UIColor(theme.accent),
                                                             ring: .white, diameter: 13))

            // The balloon (selected skin) — the protagonist.
            let b = AppleMapAnnotationRenderer.balloon(at: data.vehicle.cl, skinAssetName: data.skinAssetName,
                                                       theme: theme, height: 72)
            map.addAnnotation(b)
            balloon = b

            // Take-off camera: show the WHOLE route first (overview), hold briefly,
            // then quickly zoom in to the balloon and hand over to follow mode.
            // Fast and intentional — and equally fast for Short…Ultra.
            let routeRect = AppleMapCameraController.boundingRect(data.origin, data.destination)
            let overviewPadding = UIEdgeInsets(top: 90, left: 70, bottom: 90, right: 70)
            DispatchQueue.main.async { [weak map] in
                guard let map else { return }
                map.setVisibleMapRect(routeRect, edgePadding: overviewPadding, animated: false)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self, weak map] in
                guard let self, let map else { return }
                UIView.animate(withDuration: 0.85, delay: 0, options: .curveEaseInOut) {
                    map.camera = self.followCamera(for: data, at: data.vehicle)
                }
                self.following = true
                self.takeoffDone = true
            }
        }

        // MARK: Per-tick update

        func update(map: MKMapView, data: JourneyMapData) {
            theme = data.theme
            let vehicle = data.vehicle.cl

            // Glide the balloon — and the follow camera with it (same duration so
            // the balloon stays centred, FocusFlight-style).
            let shouldFollow = following && data.cameraMode == .follow && data.isMoving
            UIView.animate(withDuration: data.isMoving ? 1.0 : 0, delay: 0,
                           options: [.curveLinear, .allowUserInteraction]) {
                self.balloon?.coordinate = vehicle
                if shouldFollow {
                    map.camera = self.followCamera(for: data, at: data.vehicle)
                }
            }

            // (No per-tick "air trail" overlay: re-adding an overlay every tick
            // flickered in 3D and conflicted with building z-order. The single
            // faint full-route line — added once above — is cleaner and stable.)

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
        }

        // MARK: Camera helpers

        private func applyCamera(map: MKMapView, data: JourneyMapData) {
            switch data.cameraMode {
            case .overview:
                following = false
                let rect = AppleMapCameraController.boundingRect(data.origin, data.destination)
                map.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 90, left: 70, bottom: 90, right: 70),
                                      animated: true)
            case .follow:
                following = true
                map.setCamera(followCamera(for: data, at: data.vehicle), animated: true)
            }
        }

        private func followCamera(for data: JourneyMapData, at vehicle: GeoCoordinate) -> MKMapCamera {
            // Orient the camera along the bearing from the balloon to the
            // destination, so the route reads vertically (forward = up) and the
            // balloon flies upward/ahead — not sideways. The bearing drifts only
            // gradually on a geodesic, so the follow re-orients smoothly.
            let heading = GeoMath.bearingDegrees(from: vehicle, to: data.destination)
            return MKMapCamera(lookingAtCenter: vehicle.cl,
                               fromDistance: AppleMapCameraController.followDistance(forRouteKm: data.routeDistanceKm),
                               pitch: data.tilted ? 55 : 0,
                               heading: heading)
        }

        // MARK: MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            AppleMapRouteRenderer.renderer(for: overlay, accent: UIColor(theme.accent), soft: UIColor(theme.soft))
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            AppleMapAnnotationRenderer.view(for: annotation, on: mapView)
        }
    }
}
