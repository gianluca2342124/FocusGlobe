import Foundation

/// A provider-independent geographic coordinate.
///
/// Google Maps is the temporary MVP provider. Keep all business logic
/// provider-independent so we can migrate to Apple Maps / MapKit later.
/// No view, model or service in the app should ever reference a
/// `GMSCoordinate`, `CLLocationCoordinate2D` or any SDK-specific type —
/// they all speak `GeoCoordinate`, and only the map layer translates.
struct GeoCoordinate: Equatable, Hashable, Codable {
    var latitude: Double
    var longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
