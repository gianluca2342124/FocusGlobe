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

    /// The asset to render for this item: an explicit `imageName` (the new Cabin
    /// art whose Image Set name IS the raw item id), else the legacy
    /// `StoreItem_<id>` name. Store and Cabin both use this so it's one PNG.
    var bestAssetName: String { imageName ?? imageAssetName }

    /// Where a cabin decoration rests inside the basket (drives placement anchors).
    enum CabinPlacement { case tabletop, bench, wall, hook, none }
    var cabinPlacement: CabinPlacement {
        switch id {
        case "iced-latte", "potted-plant", "scented-candle", "alarm-clock", "notebook",
             "headphones", "cabin-plant", "cabin-teapot": return .tabletop
        case "sleeping-cat", "closed-laptop":              return .bench
        case "framed-poster":                              return .wall
        case "christmas-ornament":                         return .hook
        default:                                           return .none
        }
    }

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
        // Basket charms.
        StoreItem(id: "charm-compass", name: "Brass Compass", subtitle: "A charm for the basket",
                  kind: .charm, price: 350, isPremium: false, systemImage: "location.north.circle.fill", tintHex: 0xD9A94F),
        StoreItem(id: "charm-pennant", name: "Cream Pennant", subtitle: "A little flag in the wind",
                  kind: .charm, price: 250, isPremium: false, systemImage: "flag.fill", tintHex: 0xF4EFE4),
        StoreItem(id: "charm-lantern", name: "Paper Lantern", subtitle: "Warm light for night skies",
                  kind: .charm, price: 400, isPremium: false, systemImage: "lightbulb.fill", tintHex: 0xFFC873),
        // Cabin objects — new art (Image Set name IS the item id).
        StoreItem(id: "iced-latte", name: "Iced Latte", subtitle: "A cool companion for long flights",
                  kind: .cabinDecoration, price: 280, isPremium: false, systemImage: "cup.and.saucer.fill", tintHex: 0xC9A27A, imageName: "iced-latte"),
        StoreItem(id: "potted-plant", name: "Potted Plant", subtitle: "A little green on the sill",
                  kind: .cabinDecoration, price: 320, isPremium: false, systemImage: "leaf.fill", tintHex: 0x6FD8B8, imageName: "potted-plant"),
        StoreItem(id: "scented-candle", name: "Scented Candle", subtitle: "Warm light and calm",
                  kind: .cabinDecoration, price: 300, isPremium: false, systemImage: "flame.fill", tintHex: 0xF2A65A, imageName: "scented-candle"),
        StoreItem(id: "alarm-clock", name: "Alarm Clock", subtitle: "Keep gentle time",
                  kind: .cabinDecoration, price: 260, isPremium: false, systemImage: "alarm.fill", tintHex: 0xE86A6A, imageName: "alarm-clock"),
        StoreItem(id: "notebook", name: "Notebook", subtitle: "For your best ideas",
                  kind: .cabinDecoration, price: 250, isPremium: false, systemImage: "book.closed.fill", tintHex: 0xB0783E, imageName: "notebook"),
        StoreItem(id: "headphones", name: "Headphones", subtitle: "Sink into deep focus",
                  kind: .cabinDecoration, price: 420, isPremium: false, systemImage: "headphones", tintHex: 0x8FA6D8, imageName: "headphones"),
        StoreItem(id: "framed-poster", name: "Framed Poster", subtitle: "A view for the wall",
                  kind: .cabinDecoration, price: 520, isPremium: false, systemImage: "photo.fill", tintHex: 0xE0A46A, imageName: "framed-poster"),
        StoreItem(id: "christmas-ornament", name: "Festive Ornament", subtitle: "A little seasonal cheer",
                  kind: .cabinDecoration, price: 480, isPremium: false, systemImage: "sparkles", tintHex: 0xE8654B, imageName: "christmas-ornament"),
        StoreItem(id: "closed-laptop", name: "Closed Laptop", subtitle: "Work set aside for the climb",
                  kind: .cabinDecoration, price: 600, isPremium: false, systemImage: "laptopcomputer", tintHex: 0x9AA7B4, imageName: "closed-laptop"),
        StoreItem(id: "sleeping-cat", name: "Sleeping Cat", subtitle: "A calm co-pilot",
                  kind: .cabinDecoration, price: 650, isPremium: false, systemImage: "cat.fill", tintHex: 0xD8C0A0, imageName: "sleeping-cat"),
        // Existing cabin items (kept; prices lifted into the new economy).
        StoreItem(id: "cabin-plant", name: "Tiny Fern", subtitle: "A cabin companion",
                  kind: .cabinDecoration, price: 300, isPremium: false, systemImage: "leaf.fill", tintHex: 0x6FD8B8),
        StoreItem(id: "cabin-teapot", name: "Ceramic Teapot", subtitle: "For longer flights",
                  kind: .cabinDecoration, price: 380, isPremium: false, systemImage: "mug.fill", tintHex: 0xE9C07A),
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
