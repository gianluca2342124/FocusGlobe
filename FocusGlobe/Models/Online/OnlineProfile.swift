import Foundation

/// The user's public face: anonymous by default, never containing personal
/// onboarding data, email, phone, or precise location.
struct OnlineProfile: Codable, Equatable, Sendable {
    let publicID: String
    var displayName: String
    var balloonSkinID: String
    var countryCode: String?
    var isDiscoverable: Bool
    var allowsFriendRequests: Bool
    var createdAt: Date
    var updatedAt: Date
}
