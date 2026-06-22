import MapKit
import UIKit

/// Applies a `MapDisplayStyle` to an `MKMapView` using **only MapKit-supported
/// configurations** (no Google-style JSON — MapKit can't do that).
///
/// FocusGlobe's default is a calm, dark, muted map: `MKStandardMapConfiguration`
/// with the *muted* emphasis, points-of-interest hidden, and the map forced into
/// dark cartography via `overrideUserInterfaceStyle`. Bright styles
/// (standard/satellite/hybrid) are opt-in; the active flight stays dark.
///
/// MapKit limitations vs Google are documented in APPLE_MAPS_MIGRATION.md.
enum AppleMapStyle {

    /// Apply the chosen style to the map.
    static func apply(_ style: MapDisplayStyle, to map: MKMapView) {
        switch style {
        case .graphite, .night, .monochrome:
            // Premium dark/muted — FocusGlobe's signature look.
            map.overrideUserInterfaceStyle = .dark
            map.preferredConfiguration = standard(emphasis: .muted)

        case .standard:
            map.overrideUserInterfaceStyle = .unspecified
            map.preferredConfiguration = standard(emphasis: .default)

        case .terrain:
            // MapKit has no Google-style terrain; use a realistic-elevation
            // standard map kept dark + muted for a subtle topographic feel.
            map.overrideUserInterfaceStyle = .dark
            let cfg = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .muted)
            cfg.pointOfInterestFilter = .excludingAll
            cfg.showsTraffic = false
            map.preferredConfiguration = cfg

        case .satellite:
            map.overrideUserInterfaceStyle = .unspecified
            map.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .realistic)

        case .hybrid:
            map.overrideUserInterfaceStyle = .unspecified
            map.preferredConfiguration = MKHybridMapConfiguration(elevationStyle: .realistic)
        }
    }

    private static func standard(emphasis: MKStandardMapConfiguration.EmphasisStyle) -> MKStandardMapConfiguration {
        let cfg = MKStandardMapConfiguration(emphasisStyle: emphasis)
        cfg.pointOfInterestFilter = .excludingAll   // calm — no business clutter
        cfg.showsTraffic = false
        return cfg
    }
}
