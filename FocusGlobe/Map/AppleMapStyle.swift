import MapKit
import UIKit

/// Applies a `MapDisplayStyle` to an `MKMapView` using **only MapKit-supported
/// configurations** (no Google-style JSON — MapKit can't do that).
///
/// The four user-facing styles are made deliberately distinct:
///  • Monochrome — forced **dark** + **muted** emphasis, flat (desaturated
///    graphite: grey land, near-black sea). The premium default for backdrops.
///  • Terra — forced **dark** + **default** emphasis + **realistic elevation**
///    (richer, terrain/earth relief; planetary at wide zooms). Distinct from
///    Monochrome (saturated + 3D vs muted + flat).
///  • Standard — forced **light** + default emphasis (green/yellow land, blue
///    sea). Forcing light is what makes it clearly different from the dark styles
///    (the app runs in dark appearance, so an unforced map would also be dark).
///  • Satellite — Apple imagery; Hybrid (with labels) or Imagery (labels off).
///
/// Labels: ON shows the default labels/POIs; OFF hides POIs via
/// `pointOfInterestFilter = .excludingAll` (the most MapKit allows on the vector
/// styles — base place/road/country labels can't be fully hidden; see
/// APPLE_MAPS_MIGRATION.md) and, for Satellite, drops the label layer.
enum AppleMapStyle {

    static func apply(_ style: MapDisplayStyle, to map: MKMapView, labelsOn: Bool = true) {
        let poi: MKPointOfInterestFilter? = labelsOn ? nil : .excludingAll

        switch style {
        case .monochrome, .graphite, .night:
            map.overrideUserInterfaceStyle = .dark
            map.preferredConfiguration = standard(elevation: .flat, emphasis: .muted, poi: poi)

        case .terra, .terrain:
            map.overrideUserInterfaceStyle = .dark
            map.preferredConfiguration = standard(elevation: .realistic, emphasis: .default, poi: poi)

        case .standard:
            map.overrideUserInterfaceStyle = .light   // force the bright Apple look
            map.preferredConfiguration = standard(elevation: .flat, emphasis: .default, poi: poi)

        case .satellite, .hybrid:
            map.overrideUserInterfaceStyle = .unspecified
            map.preferredConfiguration = labelsOn
                ? MKHybridMapConfiguration(elevationStyle: .realistic)   // imagery + labels
                : MKImageryMapConfiguration(elevationStyle: .realistic)  // pure imagery
        }
    }

    private static func standard(elevation: MKMapConfiguration.ElevationStyle,
                                 emphasis: MKStandardMapConfiguration.EmphasisStyle,
                                 poi: MKPointOfInterestFilter?) -> MKStandardMapConfiguration {
        let cfg = MKStandardMapConfiguration(elevationStyle: elevation, emphasisStyle: emphasis)
        cfg.pointOfInterestFilter = poi
        cfg.showsTraffic = false
        return cfg
    }
}
