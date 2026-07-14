import Foundation

/// The user's private cross-device online identity (one fixed record in the
/// private CloudKit database). Contains no personal data — only a random
/// public ID and an anonymous handle.
struct FocusIdentity: Codable, Equatable, Sendable {
    let publicID: String
    var anonymousHandle: String
    let createdAt: Date
    var updatedAt: Date
    var schemaVersion: Int

    static func makeNew() -> FocusIdentity {
        FocusIdentity(publicID: UUID().uuidString,
                      anonymousHandle: "SkyPilot\(Int.random(in: 1000...9999))",
                      createdAt: Date(), updatedAt: Date(), schemaVersion: 1)
    }
}
