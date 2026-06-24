import MapKit
import UIKit

/// Applies a `MapDisplayStyle` to an `MKMapView` using **only MapKit-supported
/// configurations** (no Google-style JSON — MapKit can't do that).
///
/// User-facing styles:
///  • Dark Earth — forced **dark** + **default** emphasis + **realistic
///    elevation**: Apple Standard, but dark/premium. The default backdrop and
///    session style; reads as a planet at wide zooms.
///  • Standard — forced **light** + default emphasis (the bright native Apple look).
///  • Satellite — Apple imagery; Hybrid (with geographic labels) or Imagery
///    (labels off).
/// (`monochrome`/`graphite`/`night`/`terrain`/`hybrid` are decode-only legacy
/// values mapped to the closest current style.)
///
/// **POIs/businesses are never shown.** Every configuration sets
/// `pointOfInterestFilter = .excludingAll`, so shops, supermarkets, restaurants
/// and business pins never appear — regardless of the Labels toggle.
///
/// Labels toggle: MapKit exposes no API to hide the base geographic labels
/// (street/city/country names) on the vector styles, so on Dark Earth/Standard
/// the toggle effectively governs only POIs (which we always hide) and the base
/// labels remain. On Satellite it is meaningful: Hybrid (labels) vs Imagery
/// (no labels). See APPLE_MAPS_MIGRATION.md.
enum AppleMapStyle {

    static func apply(_ style: MapDisplayStyle, to map: MKMapView, labelsOn: Bool = true,
                      preferFlatElevation: Bool = false) {
        // Flat elevation skips 3D terrain/building extrusion, which is far lighter
        // to render. Requested on iPad/Mac for the *live journey* so the map shows
        // immediately instead of progressively streaming in 3D buildings. iPhone
        // and the (far) Home globe keep realistic elevation (default = false).
        let elevation: MKMapConfiguration.ElevationStyle = preferFlatElevation ? .flat : .realistic
        switch style {
        case .monochrome, .graphite, .night:
            map.overrideUserInterfaceStyle = .dark
            map.preferredConfiguration = standard(elevation: .flat, emphasis: .muted)

        case .terra, .terrain:
            map.overrideUserInterfaceStyle = .dark
            map.preferredConfiguration = standard(elevation: elevation, emphasis: .default)

        case .standard:
            map.overrideUserInterfaceStyle = .light   // force the bright Apple look
            map.preferredConfiguration = standard(elevation: .flat, emphasis: .default)

        case .satellite, .hybrid:
            map.overrideUserInterfaceStyle = .unspecified
            map.preferredConfiguration = labelsOn ? hybrid(elevation: elevation) : imagery(elevation: elevation)
        }
    }

    /// Standard vector config — POIs and traffic always off.
    private static func standard(elevation: MKMapConfiguration.ElevationStyle,
                                 emphasis: MKStandardMapConfiguration.EmphasisStyle) -> MKStandardMapConfiguration {
        let cfg = MKStandardMapConfiguration(elevationStyle: elevation, emphasisStyle: emphasis)
        cfg.pointOfInterestFilter = .excludingAll   // never show businesses/POIs
        cfg.showsTraffic = false
        return cfg
    }

    /// Satellite imagery + geographic labels — POIs and traffic always off.
    private static func hybrid(elevation: MKMapConfiguration.ElevationStyle = .realistic) -> MKHybridMapConfiguration {
        let cfg = MKHybridMapConfiguration(elevationStyle: elevation)
        cfg.pointOfInterestFilter = .excludingAll   // never show businesses/POIs
        cfg.showsTraffic = false
        return cfg
    }

    /// Pure satellite imagery — no labels of any kind (and so no POIs).
    private static func imagery(elevation: MKMapConfiguration.ElevationStyle = .realistic) -> MKImageryMapConfiguration {
        MKImageryMapConfiguration(elevationStyle: elevation)
    }
}
