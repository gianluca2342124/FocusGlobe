import Foundation

/// How a focus flight participates online. Chosen before departure and fixed
/// for the whole session — never silently converted mid-flight.
enum OnlineFlightMode: String, Codable, Sendable {
    case solo
    case publicSky
    case privateRoom

    var isOnline: Bool { self != .solo }
}
