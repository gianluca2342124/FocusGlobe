import Foundation
import SwiftUI

/// A cosmetic Store item purchasable with **Focus Coins** (the coins earned by
/// landing flights — lifetime earnings minus what's been spent).
///
/// Data-only and asset-optional: every item renders procedurally (SF Symbol +
/// tint) until real art ships via `imageName`. Balloon skins keep living in
/// `BalloonSkin` (with its milestone/Pro unlocks); the Store lists both.
/// A real surface inside the balloon's basket.
///
/// Slots are the whole placement system: the Cabin owns one layout table keyed
/// by slot (height, size and a set of seats along that surface), and every
/// object is arranged from it. Nothing in the Cabin positions an object by its
/// `id`, so a new decoration only has to declare which surface it lives on.
enum CabinSlot: String, CaseIterable {
    /// The window ledge — small objects you'd set down beside you.
    case shelf
    /// The seat itself — larger things that rest, at the pilot's side.
    case bench
    /// Hung flat against the interior wall.
    case wall
    /// Dangling from the basket rim.
    case hook

    /// Order matters: a fuller slot is drawn behind a nearer one.
    var depth: Int {
        switch self {
        case .wall:  return 0
        case .hook:  return 1
        case .shelf: return 2
        case .bench: return 3
        }
    }
}

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
    /// The surface a cabin object rests on. Semantic, not positional: an item
    /// says *what kind of place it belongs to* and the Cabin decides where that
    /// is, so adding an object never means editing a coordinate. Declared per
    /// item in the catalog rather than derived from `id` in a switch — one
    /// source of truth that cannot drift. `nil` for anything not a decoration.
    var slot: CabinSlot? = nil
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

    /// How many objects may be shown in the Cabin at once. The basket is small
    /// and the window, timer and pet all have to stay readable; past four the
    /// interior stops reading as a calm place you'd want to sit in.
    static let maxEquipped = 4

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
                  kind: .cabinDecoration, price: 60, isPremium: false, systemImage: "cup.and.saucer.fill", tintHex: 0xC9A27A, slot: .shelf, imageName: "iced-latte"),
        StoreItem(id: "notebook", name: "Notebook", subtitle: "For your best ideas",
                  kind: .cabinDecoration, price: 40, isPremium: false, systemImage: "book.closed.fill", tintHex: 0xB0783E, slot: .shelf, imageName: "notebook"),
        StoreItem(id: "headphones", name: "Headphones", subtitle: "Sink into deep focus",
                  kind: .cabinDecoration, price: 200, isPremium: false, systemImage: "headphones", tintHex: 0x8FA6D8, slot: .shelf, imageName: "headphones"),
        StoreItem(id: "framed-poster", name: "Framed Poster", subtitle: "A view for the wall",
                  kind: .cabinDecoration, price: 340, isPremium: false, systemImage: "photo.fill", tintHex: 0xE0A46A, slot: .wall, imageName: "framed-poster"),
        StoreItem(id: "christmas-ornament", name: "Festive Ornament", subtitle: "A little seasonal cheer",
                  kind: .cabinDecoration, price: 280, isPremium: false, systemImage: "sparkles", tintHex: 0xE8654B, slot: .hook, imageName: "christmas-ornament"),
        StoreItem(id: "closed-laptop", name: "Closed Laptop", subtitle: "Work set aside for the climb",
                  kind: .cabinDecoration, price: 460, isPremium: false, systemImage: "laptopcomputer", tintHex: 0x9AA7B4, slot: .bench, imageName: "closed-laptop"),
        StoreItem(id: "sleeping-cat", name: "Sleeping Cat", subtitle: "A calm co-pilot",
                  kind: .cabinDecoration, price: 560, isPremium: false, systemImage: "cat.fill", tintHex: 0xD8C0A0, slot: .bench, imageName: "sleeping-cat"),
        // Cabin companions. `imageName` is intentionally nil so `bestAssetName`
        // resolves their REAL shipped art (`StoreItem_cabin-plant` /
        // `StoreItem_cabin-teapot`). Pointing these at not-yet-shipped names
        // orphaned that artwork and silently dropped both items to the procedural
        // fallback — never name an asset here before it exists in the catalog.
        StoreItem(id: "cabin-plant", name: "Tiny Fern", subtitle: "A cabin companion",
                  kind: .cabinDecoration, price: 90, isPremium: false, systemImage: "leaf.fill", tintHex: 0x6FD8B8, slot: .shelf),
        StoreItem(id: "cabin-teapot", name: "Ceramic Teapot", subtitle: "For longer flights",
                  kind: .cabinDecoration, price: 130, isPremium: false, systemImage: "mug.fill", tintHex: 0xE9C07A, slot: .shelf),
    ]

    /// Every cabin object, in catalog order. The Cabin arranges from THIS order,
    /// so a pilot's interior looks the same on every launch — `equippedCabinItemIDs`
    /// is a `Set` and must never be the thing that decides who sits where.
    static var cabinDecorations: [StoreItem] { all.filter { $0.kind == .cabinDecoration } }

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
