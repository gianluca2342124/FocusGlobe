import MapKit
import SwiftUI
import UIKit

/// A MapKit annotation backed by a pre-rendered image (the balloon skin, an
/// origin/destination dot, or a code tag). Backs every FocusGlobe marker on the
/// Apple maps. `coordinate` is KVO-compliant so the balloon can glide smoothly
/// inside a `UIView` animation block.
final class MapImageAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    let image: UIImage?
    /// Vertical anchor: 0.5 = centred on the coordinate, 1.0 = bottom sits on it
    /// (used for the balloon basket and the tag nub).
    let anchorY: CGFloat
    let reuseID: String

    init(coordinate: CLLocationCoordinate2D, image: UIImage?, anchorY: CGFloat, reuseID: String) {
        self.coordinate = coordinate
        self.image = image
        self.anchorY = anchorY
        self.reuseID = reuseID
    }
}

/// Builds FocusGlobe annotations + their views, reusing the provider-independent
/// `VehicleMarkerRenderer` images (so the balloon uses the selected skin with the
/// same fallback chain, and the marker crop/anchoring matches Google exactly).
enum AppleMapAnnotationRenderer {

    /// The moving balloon (vehicle) — rendered with the selected skin asset.
    static func balloon(at coord: CLLocationCoordinate2D, skinAssetName: String,
                        theme: RouteTheme, height: CGFloat) -> MapImageAnnotation {
        let image = VehicleMarkerRenderer.balloonImage(targetHeight: height, glow: theme.soft,
                                                       assetName: skinAssetName)
        return MapImageAnnotation(coordinate: coord, image: image, anchorY: 0.88, reuseID: "fg.balloon")
    }

    /// An origin / destination dot.
    static func dot(at coord: CLLocationCoordinate2D, fill: UIColor, ring: UIColor,
                    diameter: CGFloat) -> MapImageAnnotation {
        let image = VehicleMarkerRenderer.dotImage(diameter: diameter, fill: fill, ring: ring, ringWidth: 3)
        return MapImageAnnotation(coordinate: coord, image: image, anchorY: 0.5, reuseID: "fg.dot")
    }

    /// An airport-style code tag (nub points down at the coordinate).
    static func tag(at coord: CLLocationCoordinate2D, code: String, highlighted: Bool,
                    accent: UIColor) -> MapImageAnnotation {
        let image = VehicleMarkerRenderer.tagImage(code: code, highlighted: highlighted, accent: accent)
        return MapImageAnnotation(coordinate: coord, image: image, anchorY: 1.0, reuseID: "fg.tag")
    }

    /// The view for a FocusGlobe annotation. Non-interactive; anchored per
    /// `anchorY` so the image sits correctly on its coordinate (no jump/resize).
    static func view(for annotation: MKAnnotation, on map: MKMapView) -> MKAnnotationView? {
        guard let a = annotation as? MapImageAnnotation else { return nil }
        let view = map.dequeueReusableAnnotationView(withIdentifier: a.reuseID)
            ?? MKAnnotationView(annotation: a, reuseIdentifier: a.reuseID)
        view.annotation = a
        view.image = a.image
        view.canShowCallout = false
        view.isEnabled = false
        view.isUserInteractionEnabled = false
        if let size = a.image?.size {
            // Shift the view up so the desired anchor point lands on the coordinate.
            view.centerOffset = CGPoint(x: 0, y: -(a.anchorY - 0.5) * size.height)
        } else {
            view.centerOffset = .zero
        }
        return view
    }
}
