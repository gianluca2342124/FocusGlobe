import SwiftUI

/// Provider-independent SwiftUI entry point for the journey map.
///
/// Google Maps is the temporary MVP provider. The provider is chosen at compile
/// time: if the Google Maps SDK is linked we render with it; otherwise we use a
/// fully native SwiftUI fallback so the app is always beautiful and runnable
/// with zero dependencies. A future `AppleJourneyMapView` (MapKit) slots in the
/// exact same way — every renderer consumes the same `JourneyMapData`, so no
/// business logic changes. See MAP_PROVIDER_MIGRATION.md.
struct JourneyMapView: View {
    let data: JourneyMapData
    /// Called when the user pans the live map by hand (Google provider only).
    var onUserPan: () -> Void = {}

    var body: some View {
        #if canImport(GoogleMaps)
        GoogleJourneyMapView(data: data, onUserPan: onUserPan)
        #else
        FallbackJourneyMapView(data: data)
        #endif
    }
}
