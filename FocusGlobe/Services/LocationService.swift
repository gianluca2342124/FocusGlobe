import Combine
import CoreLocation
import Foundation

/// Resolves the user's **real current location** into a `JourneyOrigin`
/// (city + country + coordinate + code). Real location is the normal path; the
/// app never silently substitutes a fake city. When location is denied or
/// unavailable, the state reflects that so the UI can ask the user to choose a
/// starting city instead.
///
/// Reliability: we fire a fast one-shot request *and* continuous updates so a
/// fix arrives as soon as possible. A timeout flips the state to `.unavailable`
/// (so the UI can offer manual city selection cleanly instead of spinning
/// forever) while updates keep running — so if a real fix arrives later it still
/// wins and is preferred.
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
    private var isResolvingFix = false
    private var timeoutTask: Task<Void, Never>?
    /// How long to wait for a real fix before offering manual city selection.
    /// Updates keep running, so a real fix that arrives later still wins.
    private let fixTimeout: TimeInterval = 10

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Begins the location flow: prompt if needed, otherwise take a fix.
    /// Safe to call repeatedly (idempotent).
    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            state = .resolving
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            if case .resolved = state { return }
            state = .resolving
            beginFix()
        case .denied, .restricted:
            state = .denied
        @unknown default:
            state = .unavailable
        }
    }

    // MARK: - Private

    /// Try hard for a real fix: a fast one-shot plus continuous updates until we
    /// resolve. A timeout offers manual selection if it's slow, while updates
    /// keep running so a later real fix is still preferred.
    private func beginFix() {
        guard !isResolvingFix else { return }
        isResolvingFix = true
        startTimeout()
        manager.requestLocation()
        manager.startUpdatingLocation()
    }

    private func startTimeout() {
        timeoutTask?.cancel()
        let seconds = fixTimeout
        timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            // Still waiting? Offer manual selection — but keep updates running so a
            // real fix that arrives later still resolves and is preferred.
            if case .resolving = self.state { self.state = .unavailable }
        }
    }

    private func stopFix() {
        isResolvingFix = false
        timeoutTask?.cancel()
        timeoutTask = nil
        manager.stopUpdatingLocation()
    }

    private func resolve(_ location: CLLocation) {
        guard isResolvingFix else { return }   // ignore stray updates after we resolve
        stopFix()
        let coordinate = GeoCoordinate(latitude: location.coordinate.latitude,
                                       longitude: location.coordinate.longitude)
        // `preferredLocale` is what stops the DEVICE language deciding this.
        // Without it the geocoder answers in the phone's language, so a pilot
        // running FocusGlobe in Spanish on an English phone lands in "Munich,
        // Germany" while every label around it is Spanish. City names have no
        // other locale-aware source, so this is where they have to be asked
        // for correctly. (The resolved fix is in-memory only.)
        //
        // The country is taken TWICE, and the difference matters. `country` is
        // the placemark's display text, already in the language we asked for.
        // `isoCountryCode` is the identity, and it is what survives a language
        // change: switch to German after the fix resolves and the label can be
        // re-rendered as "Deutschland" because the origin remembers DE, not
        // because anyone tried to recognise the word "Alemania".
        geocoder.reverseGeocodeLocation(
            location, preferredLocale: FocusLocalization.currentLocale
        ) { [weak self] placemarks, _ in
            let place = placemarks?.first
            let city = place?.locality ?? place?.subAdministrativeArea ?? place?.administrativeArea
            let country = place?.country
            let regionCode = place?.isoCountryCode
            Task { @MainActor [weak self] in
                guard let self else { return }
                let name = (city?.isEmpty == false) ? city!
                    : FocusLocalization.localized("Current Location")
                self.state = .resolved(JourneyOrigin(city: name,
                                                     country: country ?? "",
                                                     coordinate: coordinate,
                                                     countryCode: regionCode))
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
                self.beginFix()
            case .denied, .restricted:
                self.stopFix()
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
        let isDenied = (error as? CLError)?.code == .denied
        Task { @MainActor [weak self] in
            guard let self else { return }
            if isDenied {
                self.stopFix()
                self.state = .denied
                return
            }
            // Transient failure: keep updates running; the timeout offers manual
            // selection if no fix ever arrives. Never override a real resolve.
        }
    }
}
