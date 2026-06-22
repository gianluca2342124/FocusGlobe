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
        AppleMapStyle.apply(data.style, to: map)

        // Detect manual panning so the session can pause following.
        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = context.coordinator
        map.addGestureRecognizer(pan)

        // Start centred on the balloon (pulled back) so the first frame is the
        // take-off pose, not the default world map.
        map.setCamera(MKMapCamera(lookingAtCenter: data.vehicle.cl,
                                  fromDistance: AppleMapCameraController.takeoffStartDistance(forRouteKm: data.routeDistanceKm),
                                  pitch: 0, heading: 0), animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.onUserPan = onUserPan
        context.coordinator.apply(style: data.style, to: map)
        context.coordinator.configureIfNeeded(map: map, data: data)
        context.coordinator.update(map: map, data: data)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var onUserPan: () -> Void = {}

        private var didConfigure = false
        private var lastStyle: MapDisplayStyle?
        private var following = false
        private var takeoffDone = false
        private var lastCameraMode: JourneyCameraMode = .follow
        private var lastCameraToken = Int.min
        private var lastTilted = false
        private var theme: RouteTheme = .teal

        private var balloon: MapImageAnnotation?
        private var routeOverlay: MKGeodesicPolyline?
        private var trailOverlay: MKPolyline?

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

        func apply(style: MapDisplayStyle, to map: MKMapView) {
            guard lastStyle != style else { return }
            lastStyle = style
            AppleMapStyle.apply(style, to: map)
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
            map.addOverlay(route, level: .aboveRoads)
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

            // Take-off camera: centre on the balloon (start) at a pulled-back
            // distance FIRST, then a quick smooth zoom IN. Same centre → fast for
            // Short…Ultra (no lateral fly).
            let start = MKMapCamera(lookingAtCenter: data.vehicle.cl,
                                    fromDistance: AppleMapCameraController.takeoffStartDistance(forRouteKm: data.routeDistanceKm),
                                    pitch: 0, heading: 0)
            map.setCamera(start, animated: false)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self, weak map] in
                guard let self, let map else { return }
                UIView.animate(withDuration: 1.0, delay: 0, options: .curveEaseInOut) {
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

            // Air trail: just the short wisp of route right behind the balloon.
            let tailStartFrac = max(0, data.progress - 0.06)
            let tailStart = GeoMath.interpolate(from: data.origin, to: data.destination, fraction: tailStartFrac)
            let points = MapRouteRenderer.traveledPoints(from: tailStart, to: data.vehicle, samples: 14)
            if let old = trailOverlay { map.removeOverlay(old) }
            let trail = AppleMapRouteRenderer.trail(points: points)
            map.addOverlay(trail, level: .aboveRoads)
            trailOverlay = trail

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
            MKMapCamera(lookingAtCenter: vehicle.cl,
                        fromDistance: AppleMapCameraController.followDistance(forRouteKm: data.routeDistanceKm),
                        pitch: data.tilted ? 55 : 0,
                        heading: 0)
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
