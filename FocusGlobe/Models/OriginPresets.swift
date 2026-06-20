import Foundation

/// Starting cities for the "Choose starting city" picker (the clean fallback
/// when location is unavailable) and the DEBUG override. Derived from the
/// supported hubs so every preset always has real journeys.
enum OriginPresets {
    static let all: [JourneyOrigin] = HubCatalog.all.map(\.origin)
}
