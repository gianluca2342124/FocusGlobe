import Foundation

/// The current user's own published presence state (mirrors the single
/// `SkyPresence` record in the public database).
struct OnlinePresence: Codable, Equatable, Sendable {
    var sessionID: String
    var skyID: String
    var mode: OnlineFlightMode
    var roomPublicID: String?
    var startedAt: Date
    var expectedEndAt: Date?
    var isPaused: Bool
    var focusCategory: String
    var balloonSkinID: String
    /// The journey-sound id from the app's fixed catalog (display label key);
    /// nil when nothing shareable is playing. PRO is intentionally NOT part of
    /// presence — no trusted server entitlement source exists, so a self-asserted
    /// flag would be spoofable.
    var soundID: String? = nil
}
