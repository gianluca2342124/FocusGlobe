import SwiftUI

/// A collectible balloon skin.
///
/// Each skin carries its own identity, accent, unlock rule and **image asset
/// name**. The renderer (`BalloonView` / `VehicleMarkerRenderer`) loads
/// `assetName` from the bundle; if a specific image is missing it falls back to
/// `BalloonSkin_Default` and finally to the crafted vector balloon, so the app
/// never crashes on a missing asset (see SKINS_SETUP.md).
///
/// Milestone unlocks are derived purely from on-device progress (completed
/// journeys / landings). Premium skins require an **active** Pro subscription —
/// they re-lock if Pro lapses (see `AppModel.isSkinUnlocked`). Nothing here
/// touches the network.
struct BalloonSkin: Identifiable, Hashable {

    /// How a skin is earned.
    enum Unlock: Hashable {
        case free
        /// Unlocked after this many completed journeys (landings).
        case journeys(Int)
        /// Unlocked after this many focus miles.
        case miles(Int)
        /// Requires an **active** Pro subscription (re-locks if Pro lapses).
        case pro

        var isPremium: Bool { if case .pro = self { return true } else { return false } }
    }

    let id: String
    let name: String
    let subtitle: String
    /// The bundled image asset name (see SKINS_SETUP.md). Resolved at render
    /// time; missing assets fall back to `BalloonSkin_Default` then the vector.
    let assetName: String
    /// SF Symbol used as the skin's small glyph / accent chip in the gallery.
    let systemImage: String
    /// Accent palette for the tile glow + selected ring (reuses route themes).
    let theme: RouteTheme
    let unlock: Unlock
    /// Display order in the gallery (ascending).
    let sortOrder: Int

    var isPremium: Bool { unlock.isPremium }

    /// A short human description of how the skin is earned.
    var requirementText: String {
        switch unlock {
        case .free:             return "Default"
        case .journeys(let n):  return "\(n) flight\(n == 1 ? "" : "s")"
        case .miles(let n):     return "\(n) focus mile\(n == 1 ? "" : "s")"
        case .pro:              return "PRO"
        }
    }

    /// The ONE reusable "current/required unit" progress label — numerator from
    /// REAL user progress, denominator + unit from the item's actual rule (never
    /// substituting one metric for another), with correct singular/plural and an
    /// Owned/Free/PRO terminal state. Every milestone skin unlocks by completed
    /// flights (`.journeys`); `.miles` stays unit-correct should a skin use it.
    /// Used by both the Store card and the preview status row.
    func progressLabel(landings: Int, focusMiles: Int) -> String {
        switch unlock {
        case .free:            return "Free"
        case .pro:             return "FocusGlobe PRO"
        case .journeys(let n):
            return landings >= n ? "Owned" : "\(min(landings, n))/\(n) flights"
        case .miles(let n):
            return focusMiles >= n ? "Owned" : "\(min(focusMiles, n))/\(n) focus miles"
        }
    }

    // MARK: Catalog

    /// The full skin roadmap, in display order. Premium skins (Moon, Galaxy,
    /// Cloudy, King) require an active subscription; the rest are free milestone
    /// unlocks based on completed journeys.
    static let all: [BalloonSkin] = [
        BalloonSkin(id: "default", name: "Default",
                    subtitle: "The calm default", assetName: "BalloonSkin_Default",
                    systemImage: "balloon.fill", theme: .teal, unlock: .free, sortOrder: 0),
        BalloonSkin(id: "balloon", name: "Balloon",
                    subtitle: "Bright and bold", assetName: "BalloonSkin_Balloon1",
                    systemImage: "balloon.2.fill", theme: .indigo, unlock: .journeys(10), sortOrder: 1),
        BalloonSkin(id: "marshmallow", name: "Marshmallow",
                    subtitle: "Soft and sweet", assetName: "BalloonSkin_Marshmallow1",
                    systemImage: "cloud.fill", theme: .coral, unlock: .journeys(25), sortOrder: 2),
        BalloonSkin(id: "emoji", name: "Emoji",
                    subtitle: "Say hello", assetName: "BalloonSkin_Emoji1",
                    systemImage: "face.smiling.fill", theme: .gold, unlock: .journeys(50), sortOrder: 3),
        BalloonSkin(id: "hohoho", name: "Ho Ho Ho",
                    subtitle: "Festive cheer", assetName: "BalloonSkin_HoHoHo1",
                    systemImage: "gift.fill", theme: .coral, unlock: .journeys(75), sortOrder: 4),
        BalloonSkin(id: "sky-pilot", name: "Sky Pilot",
                    subtitle: "Ready for the skies", assetName: "BalloonSkin_Sky-Pilot1",
                    systemImage: "airplane", theme: .mint, unlock: .journeys(100), sortOrder: 5),
        BalloonSkin(id: "moon", name: "Moon",
                    subtitle: "Lunar glow", assetName: "BalloonSkin_Moon1",
                    systemImage: "moon.stars.fill", theme: .indigo, unlock: .pro, sortOrder: 6),
        BalloonSkin(id: "galaxy", name: "Galaxy",
                    subtitle: "Cosmic drift", assetName: "BalloonSkin_Galaxy1",
                    systemImage: "sparkles", theme: .aurora, unlock: .pro, sortOrder: 7),
        BalloonSkin(id: "cloudy", name: "Cloudy",
                    subtitle: "Head in the clouds", assetName: "BalloonSkin_Cloudy",
                    systemImage: "cloud.sun.fill", theme: .mint, unlock: .pro, sortOrder: 8),
        BalloonSkin(id: "king", name: "King",
                    subtitle: "Rule the skies", assetName: "BalloonSkin_King1",
                    systemImage: "crown.fill", theme: .gold, unlock: .pro, sortOrder: 9),
    ]

    static let `default` = all[0]

    static func skin(id: String?) -> BalloonSkin {
        guard let id else { return `default` }
        return all.first { $0.id == id } ?? `default`
    }
}
