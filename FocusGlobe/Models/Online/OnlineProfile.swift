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

extension OnlineProfile {
    /// THE generated public alias.
    ///
    /// This shape already existed, written out twice — once in
    /// `FocusOnlineModel.ensureIdentityAndProfile` and once in
    /// `ProfileService.legacyEnsureProfile`. It is the same string either way,
    /// so this is a consolidation, not a new generator: short, neutral, not
    /// derived from anything on the device, and nothing like a UUID.
    ///
    /// Generated ONCE per profile. `AppModel` writes it to `profile.name` at
    /// first load and never regenerates, so it is stable for the life of the
    /// install.
    static func generatedAlias() -> String { "SkyPilot\(Int.random(in: 1000...9999))" }
}
