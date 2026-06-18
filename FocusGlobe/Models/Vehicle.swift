import Foundation

/// A balloon / airship skin. The MVP ships exactly one fully-implemented
/// vehicle — the `skyBalloon`. The remaining skins are declared as locked,
/// "coming soon" data so the Passport and Settings can preview the roadmap
/// without any half-built art.
struct Vehicle: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let systemImage: String
    let isPremium: Bool
    let isAvailable: Bool

    static let skyBalloon = Vehicle(
        id: "sky-balloon",
        name: "Sky Balloon",
        subtitle: "Soft cream • the calm default",
        systemImage: "balloon",
        isPremium: false,
        isAvailable: true
    )

    /// Future skins (locked in the MVP).
    static let comingSoon: [Vehicle] = [
        Vehicle(id: "classic-balloon", name: "Classic Balloon",
                subtitle: "Warm stripes", systemImage: "balloon.fill",
                isPremium: true, isAvailable: false),
        Vehicle(id: "night-balloon", name: "Night Balloon",
                subtitle: "Moonlit glow", systemImage: "moon.stars.fill",
                isPremium: true, isAvailable: false),
        Vehicle(id: "aurora-airship", name: "Aurora Airship",
                subtitle: "Shimmering hull", systemImage: "sparkles",
                isPremium: true, isAvailable: false),
        Vehicle(id: "cloudship", name: "Cloudship",
                subtitle: "Drifts on mist", systemImage: "cloud.fill",
                isPremium: true, isAvailable: false),
        Vehicle(id: "paper-balloon", name: "Paper Balloon",
                subtitle: "Folded & light", systemImage: "doc.fill",
                isPremium: true, isAvailable: false),
    ]

    static let `default` = skyBalloon
}
