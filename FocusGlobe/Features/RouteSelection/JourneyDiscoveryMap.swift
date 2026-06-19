import SwiftUI

/// The route-selection canvas: a real Google night map (when the SDK is linked)
/// showing the journey from the user's current location to the selected
/// destination, with airport-style code tags, an origin halo, a route line and
/// the balloon. Mirrors the FocusFlight discovery look. Falls back to the
/// stylised aurora map only when Google Maps isn't available.
struct JourneyDiscoveryMap: View {
    let origin: JourneyOrigin
    let route: Route

    var body: some View {
        JourneyBackdropMap(origin: origin, destination: route, mode: .route,
                           progress: 0.5, showsCodeTags: true)
    }
}
