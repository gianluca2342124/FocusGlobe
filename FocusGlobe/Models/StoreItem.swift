import Foundation
import SwiftUI

/// A cosmetic Store item purchasable with **Focus Coins** (the coins earned by
/// landing flights — lifetime earnings minus what's been spent).
///
/// A semantic, responsive Cabin placement. The normalized coordinates live in
/// `CabinView`; items never persist arbitrary screen points. The main window is
/// deliberately absent from this list and therefore remains an exclusion zone.
enum CabinSlot: String, CaseIterable, Codable, Hashable, Identifiable {
    case tableCenter
    case tableLeft
    case tableRight
    case leftBench
    case rightFloor
    case leftWall
    case rightWall
    case leftHanging
    case rightHanging
    case sideHook

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tableCenter: return "Table · Center"
        case .tableLeft: return "Table · Left"
        case .tableRight: return "Table · Right"
        case .leftBench: return "Left Bench"
        case .rightFloor: return "Right Floor"
        case .leftWall: return "Left Wall"
        case .rightWall: return "Right Wall"
        case .leftHanging: return "Left Hanging"
        case .rightHanging: return "Right Hanging"
        case .sideHook: return "Side Hook"
        }
    }

    var systemImage: String {
        switch self {
        case .tableCenter, .tableLeft, .tableRight: return "table.furniture"
        case .leftBench: return "sofa.fill"
        case .rightFloor: return "square.bottomthird.inset.filled"
        case .leftWall, .rightWall: return "photo.artframe"
        case .leftHanging, .rightHanging: return "sparkles"
        case .sideHook: return "headphones"
        }
    }

    /// Order matters: wall and hanging pieces sit behind surface objects.
    var depth: Int {
        switch self {
        case .leftWall, .rightWall: return 0
        case .leftHanging, .rightHanging: return 1
        case .sideHook: return 2
        case .tableCenter, .tableLeft, .tableRight: return 3
        case .leftBench, .rightFloor: return 4
        }
    }

    /// Responsive position within the Cabin artwork. These intentionally avoid
    /// the protected central window rectangle.
    var normalizedPosition: CabinItemAnchor {
        switch self {
        case .tableLeft: return .init(x: 0.38, y: 0.55)
        case .tableCenter: return .init(x: 0.50, y: 0.57)
        case .tableRight: return .init(x: 0.63, y: 0.55)
        case .leftBench: return .init(x: 0.23, y: 0.71)
        case .rightFloor: return .init(x: 0.74, y: 0.80)
        case .leftWall: return .init(x: 0.13, y: 0.34)
        case .rightWall: return .init(x: 0.87, y: 0.34)
        case .leftHanging: return .init(x: 0.25, y: 0.18)
        case .rightHanging: return .init(x: 0.76, y: 0.18)
        case .sideHook: return .init(x: 0.12, y: 0.48)
        }
    }

    var normalizedBaseSize: Double {
        switch self {
        case .tableLeft, .tableRight: return 0.15
        case .tableCenter: return 0.17
        case .leftBench: return 0.24
        case .rightFloor: return 0.23
        case .leftWall, .rightWall: return 0.17
        case .leftHanging, .rightHanging: return 0.16
        case .sideHook: return 0.14
        }
    }
}

enum CabinItemFootprint: String, Hashable {
    case compact, medium, wide, tall, soft
}

struct CabinItemAnchor: Hashable {
    let x: Double
    let y: Double
    static let center = CabinItemAnchor(x: 0.5, y: 0.5)
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
    /// Optional bundled art — never required to compile or run.
    var imageName: String? = nil
    /// The only valid placement choices for this item.
    var allowedSlots: [CabinSlot] = []
    /// The first suggested slot in the placement sheet.
    var preferredSlot: CabinSlot? = nil
    var footprint: CabinItemFootprint = .medium
    /// Scale relative to the semantic slot's responsive base size.
    var normalizedScale: Double = 1
    /// Asset anchor metadata (kept normalized and independent of screen size).
    var anchorPoint: CabinItemAnchor = .center
    var zIndex: Double = 0
    var rotationDegrees: Double = 0
    var allowsSharedSurface = false

    init(id: String, name: String, subtitle: String, kind: Kind, price: Int,
         isPremium: Bool, systemImage: String, tintHex: UInt,
         imageName: String? = nil, allowedSlots: [CabinSlot] = [],
         preferredSlot: CabinSlot? = nil, footprint: CabinItemFootprint = .medium,
         normalizedScale: Double = 1, anchorPoint: CabinItemAnchor = .center,
         zIndex: Double = 0, rotationDegrees: Double = 0,
         allowsSharedSurface: Bool = false) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.kind = kind
        self.price = price
        self.isPremium = isPremium
        self.systemImage = systemImage
        self.tintHex = tintHex
        self.imageName = imageName
        self.allowedSlots = allowedSlots
        self.preferredSlot = preferredSlot
        self.footprint = footprint
        self.normalizedScale = normalizedScale
        self.anchorPoint = anchorPoint
        self.zIndex = zIndex
        self.rotationDegrees = rotationDegrees
        self.allowsSharedSurface = allowsSharedSurface
    }

    func supports(_ slot: CabinSlot) -> Bool { allowedSlots.contains(slot) }

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
        // Existing cabin collection — corrected semantic placement rules.
        StoreItem(id: "iced-latte", name: "Iced Latte", subtitle: "A cool companion for long flights",
                  kind: .cabinDecoration, price: 60, isPremium: false, systemImage: "cup.and.saucer.fill",
                  tintHex: 0xC9A27A, imageName: "iced-latte",
                  allowedSlots: [.tableLeft, .tableCenter, .tableRight], preferredSlot: .tableLeft,
                  footprint: .compact, normalizedScale: 0.86),
        StoreItem(id: "notebook", name: "Notebook", subtitle: "For your best ideas",
                  kind: .cabinDecoration, price: 40, isPremium: false, systemImage: "book.closed.fill",
                  tintHex: 0xB0783E, imageName: "notebook",
                  allowedSlots: [.tableLeft, .tableCenter, .tableRight, .leftBench],
                  preferredSlot: .tableCenter, footprint: .wide, normalizedScale: 0.88,
                  rotationDegrees: -4),
        StoreItem(id: "headphones", name: "Headphones", subtitle: "Sink into deep focus",
                  kind: .cabinDecoration, price: 200, isPremium: false, systemImage: "headphones",
                  tintHex: 0x8FA6D8, imageName: "headphones",
                  allowedSlots: [.sideHook, .tableLeft, .tableRight, .leftBench],
                  preferredSlot: .sideHook, footprint: .medium, normalizedScale: 0.78),
        StoreItem(id: "framed-poster", name: "Framed Poster", subtitle: "A view for the wall",
                  kind: .cabinDecoration, price: 340, isPremium: false, systemImage: "photo.fill",
                  tintHex: 0xE0A46A, imageName: "framed-poster",
                  allowedSlots: [.leftWall, .rightWall], preferredSlot: .leftWall,
                  footprint: .tall, normalizedScale: 0.82),
        StoreItem(id: "christmas-ornament", name: "Festive Ornament", subtitle: "A little seasonal cheer",
                  kind: .cabinDecoration, price: 280, isPremium: false, systemImage: "sparkles",
                  tintHex: 0xE8654B, imageName: "christmas-ornament",
                  allowedSlots: [.leftHanging, .rightHanging], preferredSlot: .rightHanging,
                  footprint: .tall, normalizedScale: 0.72),
        StoreItem(id: "closed-laptop", name: "Closed Laptop", subtitle: "Work set aside for the climb",
                  kind: .cabinDecoration, price: 460, isPremium: false, systemImage: "laptopcomputer",
                  tintHex: 0x9AA7B4, imageName: "closed-laptop",
                  allowedSlots: [.tableCenter, .tableLeft, .tableRight, .leftBench],
                  preferredSlot: .tableCenter, footprint: .wide, normalizedScale: 1.02,
                  rotationDegrees: -3),
        StoreItem(id: "sleeping-cat", name: "Sleeping Cat", subtitle: "A calm co-pilot",
                  kind: .cabinDecoration, price: 560, isPremium: false, systemImage: "cat.fill",
                  tintHex: 0xD8C0A0, imageName: "sleeping-cat",
                  allowedSlots: [.leftBench, .rightFloor], preferredSlot: .leftBench,
                  footprint: .soft, normalizedScale: 1.02),
        StoreItem(id: "cabin-plant", name: "Tiny Fern", subtitle: "A cabin companion",
                  kind: .cabinDecoration, price: 90, isPremium: false, systemImage: "leaf.fill",
                  tintHex: 0x6FD8B8, allowedSlots: [.tableLeft, .tableRight],
                  preferredSlot: .tableRight, footprint: .compact, normalizedScale: 0.80),
        StoreItem(id: "cabin-teapot", name: "Ceramic Teapot", subtitle: "For longer flights",
                  kind: .cabinDecoration, price: 130, isPremium: false, systemImage: "mug.fill",
                  tintHex: 0xE9C07A, allowedSlots: [.tableLeft, .tableCenter, .tableRight],
                  preferredSlot: .tableRight, footprint: .compact, normalizedScale: 0.82),

        // Curated first Cabin drop — premium stylized transparent artwork.
        StoreItem(id: "strawberry-matcha-latte", name: "Strawberry Matcha Latte",
                  subtitle: "A layered little lift", kind: .cabinDecoration, price: 180,
                  isPremium: false, systemImage: "cup.and.saucer.fill", tintHex: 0xE89AA8,
                  imageName: "Cabin_StrawberryMatcha",
                  allowedSlots: [.tableLeft, .tableCenter, .tableRight], preferredSlot: .tableLeft,
                  footprint: .compact, normalizedScale: 0.84),
        StoreItem(id: "heart-straw-boba", name: "Heart Straw Boba Tea",
                  subtitle: "Sweet focus energy", kind: .cabinDecoration, price: 210,
                  isPremium: false, systemImage: "heart.fill", tintHex: 0xE8A5B5,
                  imageName: "Cabin_HeartBoba",
                  allowedSlots: [.tableLeft, .tableCenter, .tableRight], preferredSlot: .tableRight,
                  footprint: .compact, normalizedScale: 0.84),
        StoreItem(id: "pastel-tumbler", name: "Pastel Insulated Tumbler",
                  subtitle: "Hydration for the long route", kind: .cabinDecoration, price: 250,
                  isPremium: false, systemImage: "waterbottle.fill", tintHex: 0xC9A6DA,
                  imageName: "Cabin_PastelTumbler",
                  allowedSlots: [.tableLeft, .tableCenter, .tableRight], preferredSlot: .tableRight,
                  footprint: .tall, normalizedScale: 0.78),
        StoreItem(id: "candle-warmer", name: "Candle Warmer Lamp",
                  subtitle: "Amber calm without a flame", kind: .cabinDecoration, price: 0,
                  isPremium: true, systemImage: "lamp.table.fill", tintHex: 0xE7B66D,
                  imageName: "Cabin_CandleWarmer",
                  allowedSlots: [.tableLeft, .tableCenter, .tableRight], preferredSlot: .tableRight,
                  footprint: .tall, normalizedScale: 0.90),
        StoreItem(id: "mushroom-lamp", name: "Mushroom Lamp",
                  subtitle: "A cozy pool of light", kind: .cabinDecoration, price: 320,
                  isPremium: false, systemImage: "lamp.table.fill", tintHex: 0xD9793F,
                  imageName: "Cabin_MushroomLamp",
                  allowedSlots: [.tableLeft, .tableCenter, .tableRight], preferredSlot: .tableLeft,
                  footprint: .medium, normalizedScale: 0.88),
        StoreItem(id: "sunset-projector", name: "Mini Sunset Projector",
                  subtitle: "Warm atmosphere on demand", kind: .cabinDecoration, price: 390,
                  isPremium: false, systemImage: "sun.max.fill", tintHex: 0xEF8D53,
                  imageName: "Cabin_SunsetProjector",
                  allowedSlots: [.tableLeft, .tableRight, .rightFloor], preferredSlot: .rightFloor,
                  footprint: .medium, normalizedScale: 0.84),
        StoreItem(id: "flip-clock", name: "Digital Flip Clock",
                  subtitle: "Time, quietly kept", kind: .cabinDecoration, price: 280,
                  isPremium: false, systemImage: "clock.fill", tintHex: 0x8B6348,
                  imageName: "Cabin_FlipClock",
                  allowedSlots: [.tableLeft, .tableCenter, .tableRight], preferredSlot: .tableCenter,
                  footprint: .wide, normalizedScale: 0.88),
        StoreItem(id: "vinyl-player", name: "Mini Vinyl Record Player",
                  subtitle: "Slow grooves for deep focus", kind: .cabinDecoration, price: 0,
                  isPremium: true, systemImage: "record.circle.fill", tintHex: 0x9B6D4A,
                  imageName: "Cabin_VinylPlayer",
                  allowedSlots: [.tableCenter, .tableLeft, .tableRight], preferredSlot: .tableCenter,
                  footprint: .wide, normalizedScale: 0.96),
        StoreItem(id: "capybara-plush", name: "Sleepy Capybara Plush",
                  subtitle: "The calmest co-pilot", kind: .cabinDecoration, price: 430,
                  isPremium: false, systemImage: "pawprint.fill", tintHex: 0xC78C52,
                  imageName: "Cabin_CapybaraPlush",
                  allowedSlots: [.leftBench, .rightFloor], preferredSlot: .leftBench,
                  footprint: .soft, normalizedScale: 1.06),
        StoreItem(id: "cloud-pillow", name: "Cloud Pillow",
                  subtitle: "A softer place to land", kind: .cabinDecoration, price: 260,
                  isPremium: false, systemImage: "cloud.fill", tintHex: 0xEFE7D7,
                  imageName: "Cabin_CloudPillow",
                  allowedSlots: [.leftBench], preferredSlot: .leftBench,
                  footprint: .soft, normalizedScale: 1.02),
        StoreItem(id: "mini-disco-ball", name: "Mini Disco Ball",
                  subtitle: "A restrained glint overhead", kind: .cabinDecoration, price: 0,
                  isPremium: true, systemImage: "circle.hexagongrid.fill", tintHex: 0xB5B5C8,
                  imageName: "Cabin_DiscoBall",
                  allowedSlots: [.leftHanging, .rightHanging], preferredSlot: .leftHanging,
                  footprint: .tall, normalizedScale: 0.76),
        StoreItem(id: "moon-stars-mobile", name: "Moon and Stars Mobile",
                  subtitle: "Celestial calm above you", kind: .cabinDecoration, price: 0,
                  isPremium: true, systemImage: "moon.stars.fill", tintHex: 0xD7B46A,
                  imageName: "Cabin_MoonStarsMobile",
                  allowedSlots: [.leftHanging, .rightHanging], preferredSlot: .rightHanging,
                  footprint: .tall, normalizedScale: 0.82),
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
