import Foundation
import SwiftUI

/// A cosmetic Store item purchasable with **Focus Coins** (the coins earned by
/// landing flights — lifetime earnings minus what's been spent).
///
/// Data-only and asset-optional: every item renders procedurally (SF Symbol +
/// tint) until real art ships via `imageName`. Balloon skins keep living in
/// `BalloonSkin` (with its milestone/Pro unlocks); the Store lists both.
struct StoreItem: Identifiable, Hashable {
    enum Kind: String { case charm, trail, cabinDecoration }

    let id: String
    let name: String
    let subtitle: String
    let kind: Kind
    /// Focus Coins price (0 = premium-only item).
    let price: Int
    /// Premium-gated instead of coin-priced.
    let isPremium: Bool
    let systemImage: String
    let tintHex: UInt
    /// Optional bundled art — never required to compile or run.
    var imageName: String? = nil

    var tint: Color { Color(hex: tintHex) }

    /// Optional bundled cover art — `StoreItem_<id>` (e.g. `StoreItem_trail-comet`).
    /// The card renders this if present, else a tinted procedural icon.
    var imageAssetName: String { "StoreItem_\(id)" }

    // MARK: Rarity (derived from price / premium — labels the card)

    enum Rarity: String {
        case common = "Common", rare = "Rare", ultra = "Ultra", premium = "Premium"
        var tint: Color {
            switch self {
            case .common:  return Color(hex: 0x9AA7B4)
            case .rare:    return Color(hex: 0x5AA9E6)
            case .ultra:   return Color(hex: 0xB07BE8)
            case .premium: return Color(hex: 0xE7B94E)
            }
        }
    }

    var rarity: Rarity {
        if isPremium { return .premium }
        if price >= 220 { return .ultra }
        if price >= 130 { return .rare }
        return .common
    }

    // MARK: Catalog (cosmetic foundation — grows freely later)

    // Trails were retired; `Kind.trail` remains only so any previously-persisted
    // `equippedTrailID` still decodes harmlessly. Prices are tuned for the small
    // per-session coin economy (see `FocusEconomy`).
    static let all: [StoreItem] = [
        StoreItem(id: "charm-compass", name: "Brass Compass", subtitle: "A charm for the basket",
                  kind: .charm, price: 60, isPremium: false, systemImage: "location.north.circle.fill", tintHex: 0xD9A94F),
        StoreItem(id: "charm-pennant", name: "Cream Pennant", subtitle: "A little flag in the wind",
                  kind: .charm, price: 40, isPremium: false, systemImage: "flag.fill", tintHex: 0xF4EFE4),
        StoreItem(id: "charm-lantern", name: "Paper Lantern", subtitle: "Warm light for night skies",
                  kind: .charm, price: 75, isPremium: false, systemImage: "lightbulb.fill", tintHex: 0xFFC873),
        StoreItem(id: "cabin-plant", name: "Tiny Fern", subtitle: "A cabin companion",
                  kind: .cabinDecoration, price: 50, isPremium: false, systemImage: "leaf.fill", tintHex: 0x6FD8B8),
        StoreItem(id: "cabin-teapot", name: "Ceramic Teapot", subtitle: "For longer flights",
                  kind: .cabinDecoration, price: 70, isPremium: false, systemImage: "mug.fill", tintHex: 0xE9C07A),
        StoreItem(id: "cabin-quilt", name: "Aurora Quilt", subtitle: "Woven from cold skies",
                  kind: .cabinDecoration, price: 0, isPremium: true, systemImage: "square.grid.3x3.topleft.filled", tintHex: 0x54E0A8),
    ]

    static func byID(_ id: String) -> StoreItem? { all.first { $0.id == id } }

    /// Today's rotating featured items — deterministic from the calendar day,
    /// so everyone (and every relaunch) sees the same three until midnight.
    static func dailyItems(for date: Date = Date()) -> [StoreItem] {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        guard all.count > 3 else { return all }
        var picks: [StoreItem] = []
        var i = 0
        while picks.count < 3 && i < all.count {
            let index = (day &* 7 &+ i &* 5) % all.count
            let item = all[index]
            if !picks.contains(item) { picks.append(item) }
            i += 1
        }
        // Fill from the front on the rare collision-heavy day.
        for item in all where picks.count < 3 && !picks.contains(item) { picks.append(item) }
        return picks
    }

    /// Seconds until the daily rotation refreshes (local midnight).
    static func secondsUntilRefresh(from date: Date = Date()) -> Int {
        let cal = Calendar.current
        let startOfTomorrow = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: date) ?? date)
        return max(0, Int(startOfTomorrow.timeIntervalSince(date)))
    }
}
