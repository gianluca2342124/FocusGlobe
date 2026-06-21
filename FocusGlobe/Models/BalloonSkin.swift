import SwiftUI

/// A collectible balloon skin. The MVP renders every skin with the same
/// `BalloonFront` artwork (see `BalloonView`), but each skin carries its own
/// identity, accent and unlock rule so the gallery, progression and (later) per
/// skin artwork all work without further model changes.
///
/// Unlocks are derived purely from on-device progress — landings and miles — or
/// from Pro membership. Nothing here touches the network.
struct BalloonSkin: Identifiable, Hashable {

    /// How a skin is earned.
    enum Unlock: Hashable {
        case free
        case journeys(Int)
        case miles(Int)
        case pro

        var isPremium: Bool { if case .pro = self { return true } else { return false } }
    }

    let id: String
    let name: String
    let subtitle: String
    /// SF Symbol used as the skin's small glyph / accent chip in the gallery.
    let systemImage: String
    /// Accent palette for the tile glow + selected ring (reuses route themes).
    let theme: RouteTheme
    let unlock: Unlock

    var isPremium: Bool { unlock.isPremium }

    /// A short human description of how the skin is earned.
    var requirementText: String {
        switch unlock {
        case .free:             return "Default"
        case .journeys(let n):  return "\(n) journeys"
        case .miles(let n):     return "\(n) miles"
        case .pro:              return "Pro"
        }
    }

    // MARK: Catalog

    /// The full skin roadmap. Order = display order in the gallery.
    static let all: [BalloonSkin] = [
        BalloonSkin(id: "sky-balloon", name: "Sky Balloon",
                    subtitle: "The calm default", systemImage: "balloon.fill",
                    theme: .teal, unlock: .free),
        BalloonSkin(id: "sunrise-drifter", name: "Sunrise Drifter",
                    subtitle: "First light", systemImage: "sun.haze.fill",
                    theme: .gold, unlock: .journeys(10)),
        BalloonSkin(id: "ocean-voyager", name: "Ocean Voyager",
                    subtitle: "Sea breeze", systemImage: "water.waves",
                    theme: .teal, unlock: .journeys(25)),
        BalloonSkin(id: "forest-wanderer", name: "Forest Wanderer",
                    subtitle: "Quiet canopy", systemImage: "leaf.fill",
                    theme: .mint, unlock: .journeys(50)),
        BalloonSkin(id: "golden-centurion", name: "Golden Centurion",
                    subtitle: "100 landings", systemImage: "crown.fill",
                    theme: .gold, unlock: .journeys(100)),
        BalloonSkin(id: "trailblazer", name: "Trailblazer",
                    subtitle: "Long-haul spirit", systemImage: "flame.fill",
                    theme: .coral, unlock: .miles(500)),
        BalloonSkin(id: "globetrotter", name: "Globetrotter",
                    subtitle: "A thousand miles", systemImage: "globe.europe.africa.fill",
                    theme: .indigo, unlock: .miles(1000)),
        BalloonSkin(id: "midnight-aurora", name: "Midnight Aurora",
                    subtitle: "Shimmering hull", systemImage: "sparkles",
                    theme: .aurora, unlock: .pro),
        BalloonSkin(id: "royal-lavender", name: "Royal Lavender",
                    subtitle: "Members only", systemImage: "moon.stars.fill",
                    theme: .lavender, unlock: .pro),
    ]

    static let `default` = all[0]

    static func skin(id: String?) -> BalloonSkin {
        guard let id else { return `default` }
        return all.first { $0.id == id } ?? `default`
    }
}
