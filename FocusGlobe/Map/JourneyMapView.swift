import SwiftUI

/// Provider-independent SwiftUI entry point for the live journey map.
///
/// The provider is chosen at runtime by `FocusGlobeMapProvider` (default
/// **Apple Maps / MapKit**). Google Maps remains as a fallback for this
/// migration phase (selected only via the DEBUG override, and only when the SDK
/// is linked); a fully native SwiftUI fallback covers the no-SDK case. Every
/// renderer consumes the same `JourneyMapData`, so no business logic changes.
/// See APPLE_MAPS_MIGRATION.md.
struct JourneyMapView: View {
    let data: JourneyMapData
    /// Called when the user pans the live map by hand.
    var onUserPan: () -> Void = {}

    var body: some View {
        switch FocusGlobeMapProvider.current {
        case .apple:
            AppleActiveJourneyMapView(data: data, onUserPan: onUserPan)
        case .google:
            googleOrFallback
        case .fallback:
            FallbackJourneyMapView(data: data)
        }
    }

    @ViewBuilder private var googleOrFallback: some View {
        #if canImport(GoogleMaps)
        GoogleJourneyMapView(data: data, onUserPan: onUserPan)
        #else
        FallbackJourneyMapView(data: data)
        #endif
    }
}
