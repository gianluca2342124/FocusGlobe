import MapKit
import UIKit

/// Applies a `MapDisplayStyle` to an `MKMapView` using **only MapKit-supported
/// configurations** (no Google-style JSON — MapKit can't do that).
///
/// User-facing styles:
///  • Monochrome — dark, muted standard map (grey land, near-black sea). Default.
///  • Terra — dark + muted with realistic elevation for a planet/terrain feel.
///  • Standard — native Apple standard (green/yellow land, blue sea).
///  • Satellite — Apple imagery; with labels = hybrid, without = pure imagery.
///
/// Labels: ON shows place labels (and POIs); OFF hides POIs via
/// `pointOfInterestFilter` and, for Satellite, drops the label layer (imagery).
/// MapKit cannot fully hide base place-name labels on the standard map, so for
/// Monochrome/Terra/Standard the toggle suppresses POIs as the best supported
/// approximation (documented in APPLE_MAPS_MIGRATION.md).
enum AppleMapStyle {

    static func apply(_ style: MapDisplayStyle, to map: MKMapView, labelsOn: Bool = true) {
        // ON → default POIs + labels; OFF → hide POIs (place labels may remain).
        let poi: MKPointOfInterestFilter? = labelsOn ? nil : .excludingAll

        switch style {
        case .monochrome, .graphite, .night:
            map.overrideUserInterfaceStyle = .dark
            map.preferredConfiguration = standard(emphasis: .muted, poi: poi)

        case .terra, .terrain:
            map.overrideUserInterfaceStyle = .dark
            let cfg = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .muted)
            cfg.pointOfInterestFilter = poi
            cfg.showsTraffic = false
            map.preferredConfiguration = cfg

        case .standard:
            map.overrideUserInterfaceStyle = .unspecified
            map.preferredConfiguration = standard(emphasis: .default, poi: poi)

        case .satellite, .hybrid:
            map.overrideUserInterfaceStyle = .unspecified
            map.preferredConfiguration = labelsOn
                ? MKHybridMapConfiguration(elevationStyle: .realistic)   // imagery + labels
                : MKImageryMapConfiguration(elevationStyle: .realistic)  // pure imagery
        }
    }

    private static func standard(emphasis: MKStandardMapConfiguration.EmphasisStyle,
                                 poi: MKPointOfInterestFilter?) -> MKStandardMapConfiguration {
        let cfg = MKStandardMapConfiguration(emphasisStyle: emphasis)
        cfg.pointOfInterestFilter = poi
        cfg.showsTraffic = false
        return cfg
    }
}
