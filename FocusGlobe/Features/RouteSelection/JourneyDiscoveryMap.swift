import SwiftUI

/// The route-selection canvas: a real Google night map (when the SDK is linked)
/// showing the journey from the user's current location to the selected
/// destination, with airport-style code tags, an origin halo, a route line and
/// the balloon. Mirrors the FocusFlight discovery look. Falls back to the
/// stylised aurora map only when Google Maps isn't available.
struct JourneyDiscoveryMap: View {
    let origin: JourneyOrigin
    let route: Route
    /// Nearby destinations rendered as a subtle radar of small tags.
    var nearby: [MapPin] = []

    var body: some View {
        // No balloon here — the user is choosing a destination, not yet flying.
        JourneyBackdropMap(origin: origin, destination: route, mode: .route,
                           progress: 0.5, showsCodeTags: true, showsBalloon: false,
                           nearby: nearby)
    }
}
