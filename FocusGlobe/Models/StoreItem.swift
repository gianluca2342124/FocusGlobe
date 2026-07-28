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
        case "iced-latte", "notebook", "headphones", "cabin-plant", "cabin-teapot":
            return .tabletop
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
        if price >= 400 { return .ultra }   // exceptional band
        if price >= 150 { return .rare }    // rare band
        return .common                       // common / uncommon bands
    }

    // MARK: Catalog (cosmetic foundation — grows freely later)

    // Trails were retired; `Kind.trail` remains only so any previously-persisted
    // `equippedTrailID` still decodes harmlessly. Prices are tuned for the small
    // per-session coin economy (see `FocusEconomy`).
    static let all: [StoreItem] = [
        // Cabin objects — real art (Image Set name IS the item id). Prices are
        // tuned for the small per-session coin economy (see `FocusEconomy`).
        StoreItem(id: "iced-latte", name: "Iced Latte", subtitle: "A cool companion for long flights",
                  kind: .cabinDecoration, price: 60, isPremium: false, systemImage: "cup.and.saucer.fill", tintHex: 0xC9A27A, imageName: "iced-latte"),
        StoreItem(id: "notebook", name: "Notebook", subtitle: "For your best ideas",
                  kind: .cabinDecoration, price: 40, isPremium: false, systemImage: "book.closed.fill", tintHex: 0xB0783E, imageName: "notebook"),
        StoreItem(id: "headphones", name: "Headphones", subtitle: "Sink into deep focus",
                  kind: .cabinDecoration, price: 200, isPremium: false, systemImage: "headphones", tintHex: 0x8FA6D8, imageName: "headphones"),
        StoreItem(id: "framed-poster", name: "Framed Poster", subtitle: "A view for the wall",
                  kind: .cabinDecoration, price: 340, isPremium: false, systemImage: "photo.fill", tintHex: 0xE0A46A, imageName: "framed-poster"),
        StoreItem(id: "christmas-ornament", name: "Festive Ornament", subtitle: "A little seasonal cheer",
                  kind: .cabinDecoration, price: 280, isPremium: false, systemImage: "sparkles", tintHex: 0xE8654B, imageName: "christmas-ornament"),
        StoreItem(id: "closed-laptop", name: "Closed Laptop", subtitle: "Work set aside for the climb",
                  kind: .cabinDecoration, price: 460, isPremium: false, systemImage: "laptopcomputer", tintHex: 0x9AA7B4, imageName: "closed-laptop"),
        StoreItem(id: "sleeping-cat", name: "Sleeping Cat", subtitle: "A calm co-pilot",
                  kind: .cabinDecoration, price: 560, isPremium: false, systemImage: "cat.fill", tintHex: 0xD8C0A0, imageName: "sleeping-cat"),
        // Cabin companions. `imageName` is intentionally nil so `bestAssetName`
        // resolves their REAL shipped art (`StoreItem_cabin-plant` /
        // `StoreItem_cabin-teapot`). Pointing these at not-yet-shipped names
        // orphaned that artwork and silently dropped both items to the procedural
        // fallback — never name an asset here before it exists in the catalog.
        StoreItem(id: "cabin-plant", name: "Tiny Fern", subtitle: "A cabin companion",
                  kind: .cabinDecoration, price: 90, isPremium: false, systemImage: "leaf.fill", tintHex: 0x6FD8B8),
        StoreItem(id: "cabin-teapot", name: "Ceramic Teapot", subtitle: "For longer flights",
                  kind: .cabinDecoration, price: 130, isPremium: false, systemImage: "mug.fill", tintHex: 0xE9C07A),
    ]

    static func byID(_ id: String) -> StoreItem? { all.first { $0.id == id } }

    /// The set of live item ids — used to migrate any persisted equipped/owned id
    /// that pointed at a now-removed item (Brass Compass, Cream Pennant, Paper
    /// Lantern, Potted Plant, Scented Candle, Alarm Clock, Aurora Quilt).
    static var validIDs: Set<String> { Set(all.map(\.id)) }

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
