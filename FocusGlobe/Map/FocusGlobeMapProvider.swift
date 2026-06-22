import Foundation

/// The runtime map provider used by the journey map wrappers
/// (`JourneyMapView`, `JourneyBackdropMap`).
///
/// FocusGlobe is migrating from Google Maps to **Apple Maps (MapKit)**. Apple is
/// the default for the normal app path. Google Maps remains in the project as a
/// fallback for this migration phase (it is NOT removed yet — see
/// APPLE_MAPS_MIGRATION.md). MapKit needs no API key/token.
///
/// In DEBUG a hidden override lets us compare Apple vs Google; release builds
/// always resolve to `.apple`. There is no user-facing provider switch.
enum FocusGlobeMapProvider: String {
    case apple
    case google
    /// Native SwiftUI stylised map — no SDK required.
    case fallback

    #if DEBUG
    /// DEBUG-only override (not exposed to users). Set in the debugger or a dev
    /// affordance to compare providers; `nil` uses the default resolution.
    static var debugOverride: FocusGlobeMapProvider?
    #endif

    /// The provider the UI should render with right now. Apple Maps by default.
    static var current: FocusGlobeMapProvider {
        #if DEBUG
        if let debugOverride { return debugOverride }
        #endif
        return .apple
    }
}

/// Naming alias so map code can refer to a FocusGlobe map style without coupling
/// to the (Google-era) `MapDisplayStyle` name. Same cases, adapted to MapKit by
/// `AppleMapStyle`.
typealias FocusGlobeMapStyle = MapDisplayStyle
