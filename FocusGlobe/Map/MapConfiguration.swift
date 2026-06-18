import Foundation

// ============================================================================
//  Google Maps is the temporary MVP provider. Keep all business logic
//  provider-independent so we can migrate to Apple Maps / MapKit later.
// ============================================================================

/// Configuration for the map layer — the *only* place the Google Maps API key
/// lives, and the single switch that decides which provider renders the map.
enum MapConfiguration {

    /// Google Maps SDK for iOS API key.
    ///
    /// SECURITY: this is a client-side Maps SDK key (it ships inside the app
    /// binary regardless). Before release, restrict it in Google Cloud Console
    /// to this app's bundle identifier and to the "Maps SDK for iOS" API only.
    /// For CI / open-source, move this into an untracked `Secrets.xcconfig`
    /// (see SETUP.md). It is kept inline here purely for MVP convenience.
    static let googleMapsAPIKey = "AIzaSyBzfHc_v6qJclulViBp46tjPtfgtR7oD98"

    static var hasValidGoogleKey: Bool {
        !googleMapsAPIKey.isEmpty && !googleMapsAPIKey.contains("PASTE_")
    }
}

/// The available map providers. The active provider is chosen at compile time
/// by whether the Google Maps SDK is linked. The fallback is a fully native
/// SwiftUI map so the app is beautiful and runnable with zero dependencies;
/// adding the Google Maps package lights up the live map automatically.
enum MapProvider: String {
    case google
    case apple      // Future migration target (see AppleJourneyMapView).
    case fallback   // Native SwiftUI stylised map — no SDK required.

    static var active: MapProvider {
        #if canImport(GoogleMaps)
        return .google
        #else
        return .fallback
        #endif
    }
}
