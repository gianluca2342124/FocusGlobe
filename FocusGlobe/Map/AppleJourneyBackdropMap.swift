import CoreLocation
import MapKit
import SwiftUI
import UIKit

/// The Apple Maps (MapKit) backdrop for the primary screens (Home, Choose
/// Journey, Boarding, Onboarding). A calm, dark, non-interactive map that mirrors
/// `GoogleBackdropMapView` exactly — same modes, halo, route line, balloon,
/// nearby radar tags and origin-point projection — but native to iOS with no API
/// key. Selected via `FocusGlobeMapProvider` from `JourneyBackdropMap`.
struct AppleBackdropMapView: UIViewRepresentable {
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
    var style: MapDisplayStyle = .monochrome

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.isZoomEnabled = false
        map.isScrollEnabled = false
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.showsUserLocation = false
        map.isAccessibilityElement = false
        map.accessibilityElementsHidden = true
        AppleMapStyle.apply(style, to: map, labelsOn: true)   // dark premium backdrop
        // Start near the origin so the first frame isn't the default world map;
        // precise framing is applied in updateUIView once laid out.
        map.setRegion(MKCoordinateRegion(center: origin.coordinate.cl,
                                         span: MKCoordinateSpan(latitudeDelta: 12, longitudeDelta: 12)),
                      animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.configure(map: map, view: self)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var theme: RouteTheme = .teal
        private var lastKey = ""

        func configure(map: MKMapView, view: AppleBackdropMapView) {
            theme = view.theme
            let dest = view.destination
            let key = [
                view.mode == .origin ? "origin" : "route",
                String(format: "%.3f,%.3f", view.origin.coordinate.latitude, view.origin.coordinate.longitude),
                dest?.id ?? "-",
                view.showsCodeTags ? "t" : "_", view.showsBalloon ? "b" : "_", view.showsOrigin ? "o" : "_",
                String(format: "%.0f", view.bottomInset),
                "n\(view.nearby.count)",
                view.skinAssetName,
                view.style.rawValue
            ].joined(separator: "|")

            if key != lastKey {
                lastKey = key
                rebuild(map: map, view: view)
            }
            // Apply the camera + report the origin point after layout so the
            // projection (radar) is exact even on the first pass (bounds valid).
            DispatchQueue.main.async { [weak map] in
                guard let map else { return }
                self.applyCamera(map: map, view: view)
                self.reportOrigin(map: map, view: view)
            }
        }

        private func rebuild(map: MKMapView, view: AppleBackdropMapView) {
            map.removeAnnotations(map.annotations)
            map.removeOverlays(map.overlays)

            let accent = UIColor(view.theme.accent)
            let originCoord = view.origin.coordinate.cl

            if view.showsOrigin {
                map.addOverlay(AppleMapRouteRenderer.circle(center: view.origin.coordinate,
                                                            radiusMeters: view.mode == .origin ? 2600 : 1400,
                                                            tag: AppleMapRouteRenderer.Tag.halo),
                               level: .aboveRoads)
                // Skip the white origin dot when the balloon sits on the origin
                // (Home): the balloon is the marker there. Choose Journey (no
                // balloon) keeps its origin dot.
                let homeBalloon = (view.mode == .origin && view.showsBalloon)
                if !homeBalloon {
                    map.addAnnotation(AppleMapAnnotationRenderer.dot(at: originCoord, fill: .white,
                                                                     ring: accent, diameter: 12))
                }
            }

            guard view.mode == .route, let dest = view.destination else {
                // Origin-only (Home): optional small balloon over "you are here".
                if view.showsBalloon {
                    map.addAnnotation(AppleMapAnnotationRenderer.balloon(at: originCoord,
                                                                         skinAssetName: view.skinAssetName,
                                                                         theme: view.theme, height: 58))
                }
                if view.showsCodeTags && view.showsOrigin {
                    map.addAnnotation(AppleMapAnnotationRenderer.tag(at: originCoord, code: view.origin.code,
                                                                     highlighted: false, accent: accent))
                }
                return
            }

            // Route line: soft halo + bright accent core (selection is dominant).
            map.addOverlay(AppleMapRouteRenderer.geodesicRoute(from: view.origin.coordinate, to: dest.destination,
                                                               tag: AppleMapRouteRenderer.Tag.routeGlow), level: .aboveRoads)
            map.addOverlay(AppleMapRouteRenderer.geodesicRoute(from: view.origin.coordinate, to: dest.destination,
                                                               tag: AppleMapRouteRenderer.Tag.routeCore), level: .aboveRoads)

            map.addAnnotation(AppleMapAnnotationRenderer.dot(at: dest.destination.cl, fill: accent,
                                                             ring: .white, diameter: 13))

            if view.showsBalloon {
                let vehicle = GeoMath.interpolate(from: view.origin.coordinate, to: dest.destination, fraction: view.progress)
                map.addAnnotation(AppleMapAnnotationRenderer.balloon(at: vehicle.cl, skinAssetName: view.skinAssetName,
                                                                     theme: view.theme, height: 84))
            }

            // Radar of nearby destinations around the origin (Choose Journey only).
            if !view.nearby.isEmpty {
                for km in [45.0, 95.0, 165.0] {
                    map.addOverlay(AppleMapRouteRenderer.circle(center: view.origin.coordinate, radiusMeters: km * 1000,
                                                                tag: AppleMapRouteRenderer.Tag.ring), level: .aboveRoads)
                }
                for pin in view.nearby.prefix(10) where pin.code != dest.destinationCode {
                    map.addAnnotation(AppleMapAnnotationRenderer.tag(at: pin.coordinate.cl, code: pin.code,
                                                                     highlighted: false, accent: UIColor(AppColors.textPrimary)))
                }
            }

            if view.showsCodeTags {
                if view.showsOrigin {
                    map.addAnnotation(AppleMapAnnotationRenderer.tag(at: originCoord, code: view.origin.code,
                                                                     highlighted: false, accent: accent))
                }
                map.addAnnotation(AppleMapAnnotationRenderer.tag(at: dest.destination.cl, code: dest.destinationCode,
                                                                 highlighted: true, accent: UIColor(AppColors.gold)))
            }
        }

        // MARK: Camera

        private func applyCamera(map: MKMapView, view: AppleBackdropMapView) {
            if view.mode == .route, let dest = view.destination {
                let rect = AppleMapCameraController.boundingRect(view.origin.coordinate, dest.destination)
                map.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 80, left: 60, bottom: 80, right: 60),
                                      animated: false)
            } else {
                let zoom = Double(view.showsOrigin ? view.originZoom : 4.0)
                let w = Double(map.bounds.width)
                let h = Double(map.bounds.height)
                guard w > 0, h > 0 else {
                    let span = MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
                    map.setRegion(MKCoordinateRegion(center: view.origin.coordinate.cl, span: span), animated: false)
                    return
                }
                // Match Google's tile zoom: longitude from zoom + width, latitude
                // from the view aspect (so the framing — and "not too close" feel —
                // matches the old map).
                let lonDelta = AppleMapCameraController.longitudeDelta(forZoom: zoom, viewWidthPoints: w)
                let latDelta = min(120.0, lonDelta * (h / w))
                var centerLat = view.origin.coordinate.latitude
                // Push the origin into the upper half (above the Home text block).
                if view.bottomInset > 0 {
                    centerLat -= (Double(view.bottomInset) / 2.0 / h) * latDelta
                }
                let region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: centerLat, longitude: view.origin.coordinate.longitude),
                    span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta))
                map.setRegion(region, animated: false)
            }
        }

        private func reportOrigin(map: MKMapView, view: AppleBackdropMapView) {
            guard map.bounds.width > 0 else { view.onOriginPoint(nil); return }
            guard view.showsOrigin else { view.onOriginPoint(nil); return }
            view.onOriginPoint(map.convert(view.origin.coordinate.cl, toPointTo: map))
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
