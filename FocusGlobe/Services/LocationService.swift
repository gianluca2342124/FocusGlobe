import Combine
import CoreLocation
import Foundation

/// Resolves the user's **real current location** into a `JourneyOrigin`
/// (city + country + coordinate + code). Real location is the normal path; the
/// app never silently substitutes a fake city. When location is denied or
/// unavailable, the state reflects that so the UI can ask the user to choose a
/// starting city instead.
///
/// CoreLocation is the source of truth and is provider-independent — this type
/// never touches the Google Maps SDK.
///
/// NOTE: `NSLocationWhenInUseUsageDescription` must be present for the system
/// prompt to appear (see LOCATION_SETUP.md). Without it the state simply stays
/// `.unavailable` and the user picks a starting city.
@MainActor
final class LocationService: NSObject, ObservableObject {

    enum State: Equatable {
        case idle
        case resolving
        case resolved(JourneyOrigin)
        case denied
        case unavailable
    }

    @Published private(set) var state: State = .idle

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var didRequestFix = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Begins the location flow: prompt if needed, otherwise take a single fix.
    /// Safe to call repeatedly (idempotent).
    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            state = .resolving
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            if case .resolved = state { return }
            state = .resolving
            requestFix()
        case .denied, .restricted:
            state = .denied
        @unknown default:
            state = .unavailable
        }
    }

    // MARK: - Private

    private func requestFix() {
        guard !didRequestFix else { return }
        didRequestFix = true
        manager.requestLocation()
    }

    private func resolve(_ location: CLLocation) {
        let coordinate = GeoCoordinate(latitude: location.coordinate.latitude,
                                       longitude: location.coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            let place = placemarks?.first
            let city = place?.locality ?? place?.subAdministrativeArea ?? place?.administrativeArea
            let country = place?.country
            Task { @MainActor [weak self] in
                guard let self else { return }
                let name = (city?.isEmpty == false) ? city! : "Current Location"
                self.state = .resolved(JourneyOrigin(city: name,
                                                     country: country ?? "",
                                                     coordinate: coordinate))
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
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                if case .resolved = self.state { return }
                self.state = .resolving
                self.requestFix()
            case .denied, .restricted:
                self.state = .denied
            case .notDetermined:
                break
            @unknown default:
                self.state = .unavailable
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
        Task { @MainActor [weak self] in
            guard let self else { return }
            if case .resolved = self.state { return }
            self.state = .unavailable
        }
    }
}
