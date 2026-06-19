import Combine
import CoreLocation
import Foundation

/// Resolves the user's **real current location** into a `JourneyOrigin`
/// (friendly city name + short code + coordinate). Every journey starts from
/// here, so real location is the normal path — a calm default city is used only
/// until permission is granted (or if it's denied/unavailable).
///
/// CoreLocation is treated as provider-independent map input: this type never
/// touches the Google Maps SDK. We request *When In Use* authorization, take a
/// single coarse fix, reverse-geocode it to a place name, and publish the
/// resulting `JourneyOrigin`. Every failure path degrades gracefully to
/// `JourneyOrigin.default`.
///
/// NOTE: The usage string `NSLocationWhenInUseUsageDescription` must be present
/// in the app's Info settings for the system prompt to appear. Because the
/// project generates its Info.plist from build settings (and the project file
/// is managed manually), add it once in Xcode — see LOCATION_SETUP.md. Without
/// it the app still runs and simply keeps the default origin.
@MainActor
final class LocationService: NSObject, ObservableObject {

    /// The resolved origin. Starts at the calm default and updates to the real,
    /// reverse-geocoded location once permission is granted and a fix arrives.
    @Published private(set) var origin: JourneyOrigin = .default
    /// `true` once a *real* location has been resolved (vs the default).
    @Published private(set) var hasResolvedRealLocation = false
    /// Current authorization, surfaced so the UI can reflect permission state.
    @Published private(set) var authorization: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var didRequestFix = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorization = manager.authorizationStatus
    }

    // MARK: - Intent

    /// Begins the calm location flow: ask for permission if needed, otherwise
    /// take a single fix. Safe to call repeatedly (idempotent).
    func requestLocation() {
        switch authorization {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            requestFix()
        default:
            // Denied / restricted → keep the graceful default origin.
            break
        }
    }

    // MARK: - Private

    private func requestFix() {
        guard !didRequestFix else { return }
        didRequestFix = true
        manager.requestLocation()
    }

    /// Applies a reverse-geocoded result on the main actor.
    private func apply(cityName: String?, coordinate: GeoCoordinate) {
        let name = (cityName?.isEmpty == false) ? cityName! : "Current Location"
        origin = JourneyOrigin(cityName: name,
                               code: JourneyOrigin.code(for: name),
                               coordinate: coordinate)
        hasResolvedRealLocation = true
    }

    /// Reverse-geocodes a fix to a friendly place name, then publishes it.
    private func resolve(_ location: CLLocation) {
        let coordinate = GeoCoordinate(latitude: location.coordinate.latitude,
                                       longitude: location.coordinate.longitude)
        // Publish the coordinate immediately so the map can centre while the
        // (slower) reverse-geocode resolves the name.
        if !hasResolvedRealLocation {
            origin = JourneyOrigin(cityName: origin.cityName, code: origin.code,
                                   coordinate: coordinate)
        }
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            // Extract only Sendable values inside the (non-isolated) callback.
            let place = placemarks?.first
            let name = place?.locality ?? place?.subAdministrativeArea
                ?? place?.administrativeArea ?? place?.country
            Task { @MainActor [weak self] in
                self?.apply(cityName: name, coordinate: coordinate)
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.authorization = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.requestFix()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in self?.resolve(location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        // Keep the graceful default origin; nothing to surface to the user.
    }
}
