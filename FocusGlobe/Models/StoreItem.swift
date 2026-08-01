import Foundation
import SwiftUI

/// A cosmetic Store item purchasable with **Focus Coins** (the coins earned by
/// landing flights — lifetime earnings minus what's been spent).
///
/// A semantic, responsive Cabin placement. The normalized coordinates live in
/// `CabinView`; items never persist arbitrary screen points. The main window is
/// deliberately absent from this list and therefore remains an exclusion zone.
enum CabinSlot: String, CaseIterable, Codable, Hashable, Identifiable {
    case tableLeft
    case tableCenter
    case tableRight
    case benchLeft
    case benchCenter
    case wallLeft
    case wallRight
    case hookLeft
    case hookRight
    case hangingLeft
    case hangingRight
    case floorRight

    var id: String { rawValue }

    /// Profiles written by the first semantic-slot implementation used a few
    /// different raw names. Keep reading them while every new save uses the
    /// canonical physical names above.
    static func persisted(_ rawValue: String) -> CabinSlot? {
        if let slot = CabinSlot(rawValue: rawValue) { return slot }
        switch rawValue {
        case "leftBench": return .benchLeft
        case "rightFloor": return .floorRight
        case "leftWall": return .wallLeft
        case "rightWall": return .wallRight
        case "sideHook": return .hookLeft
        case "leftHanging": return .hangingLeft
        case "rightHanging": return .hangingRight
        default: return nil
        }
    }

    var displayName: String {
        switch self {
        case .tableLeft: return "Table · Left"
        case .tableCenter: return "Table · Center"
        case .tableRight: return "Table · Right"
        case .benchLeft: return "Bench · Left"
        case .benchCenter: return "Bench · Center"
        case .wallLeft: return "Wall · Left"
        case .wallRight: return "Wall · Right"
        case .hookLeft: return "Hook · Left"
        case .hookRight: return "Hook · Right"
        case .hangingLeft: return "Hanging · Left"
        case .hangingRight: return "Hanging · Right"
        case .floorRight: return "Floor · Right"
        }
    }

    /// Plain language for where the slot physically is. The placement sheet reads
    /// this instead of asking the pilot to interpret markers floating on a dark
    /// photo of the Cabin.
    var placementHint: String {
        switch self {
        case .tableLeft: return "On the table, left side"
        case .tableCenter: return "On the table, in the middle"
        case .tableRight: return "On the table, right side"
        case .benchLeft: return "On the bench, left side"
        case .benchCenter: return "On the bench, in the middle"
        case .wallLeft: return "On the left wall"
        case .wallRight: return "On the right wall"
        case .hookLeft: return "On the left hook"
        case .hookRight: return "On the right hook"
        case .hangingLeft: return "Hanging above, to the left"
        case .hangingRight: return "Hanging above, to the right"
        case .floorRight: return "On the floor, right side"
        }
    }

    var systemImage: String {
        switch self {
        case .tableCenter, .tableLeft, .tableRight: return "table.furniture"
        case .benchLeft, .benchCenter: return "sofa.fill"
        case .floorRight: return "square.bottomthird.inset.filled"
        case .wallLeft, .wallRight: return "photo.artframe"
        case .hangingLeft, .hangingRight: return "sparkles"
        case .hookLeft, .hookRight: return "headphones"
        }
    }

    /// Order matters: wall and hanging pieces sit behind surface objects.
    var depth: Int {
        switch self {
        case .wallLeft, .wallRight: return 0
        case .hangingLeft, .hangingRight: return 1
        case .hookLeft, .hookRight: return 2
        case .tableCenter, .tableLeft, .tableRight: return 3
        case .benchLeft, .benchCenter, .floorRight: return 4
        }
    }

    /// Where this slot physically is, per production Cabin artwork.
    ///
    /// Every number here is normalized inside the **rendered Cabin artwork**,
    /// not the device screen and not the container view. That distinction is the
    /// whole point: the artwork is drawn `.scaledToFill` and centre-cropped, so
    /// container-normalized coordinates drift by up to 0.054 of the height on an
    /// iPhone SE, 0.031 of the width on an iPad in landscape, and 0.100 of the
    /// height in a narrow Mac window — which is precisely why a plush that sat
    /// on the bench on one device floated in front of it on another.
    /// `CabinArtFrame` converts these into container points.
    ///
    /// The values were measured off the three artworks rather than guessed:
    ///
    ///   cabin_iphone  852x1846  tabletop y 0.44-0.47, span x 0.30-0.70
    ///                           bench seat y 0.55-0.64, span x 0.06-0.33
    ///   cabin_ipad   1086x1449  tabletop y 0.48-0.52, span x 0.27-0.75
    ///                           bench seat y 0.62-0.68, span x 0.05-0.30
    ///   cabin_mac    1586x992   tabletop y 0.50-0.54, span x 0.375-0.75
    ///                           bench seat y 0.72-0.76, span x 0.125-0.375
    ///
    /// The Mac artwork is deliberately NOT symmetric — its window sits right of
    /// centre — so x varies per artwork too, which the previous table could not
    /// express.
    func transform(for artwork: CabinArtworkLayout) -> CabinSlotTransform {
        let p = Self.placement(for: artwork)[self] ?? Self.placement(for: .portrait)[self]!
        return CabinSlotTransform(contact: .init(x: p.x, y: p.y),
                                  defaultScale: p.scale,
                                  anchor: p.anchor,
                                  zIndex: Double(depth),
                                  rotationDegrees: p.rotation,
                                  maximumFootprint: p.maxFootprint)
    }

    /// One artwork's complete slot map. Table sizes differ per artwork because
    /// the painted tabletop is a different FRACTION of each picture: three
    /// objects of 0.115/0.130/0.115 fit the iPhone's 0.40-wide tabletop with
    /// room to spare, and would hang over both ends of the Mac's 0.375-wide one.
    private static func placement(for artwork: CabinArtworkLayout) -> [CabinSlot: SlotPlacement] {
        switch artwork {
        case .portrait:  return portraitPlacement
        case .tablet:    return tabletPlacement
        case .landscape: return landscapePlacement
        }
    }

    struct SlotPlacement {
        let x: Double
        let y: Double
        let scale: Double
        let maxFootprint: Double
        var anchor: CabinItemAnchor = .bottomCenter
        var rotation: Double = 0
    }

    // cabin_iphone. Tabletop runs 0.30-0.70; the three slots divide it in
    // proportion 1 : 1.15 : 1 with a 4% breathing gap, so at MAXIMUM footprint
    // the outermost edges land at 0.3025 and 0.6975 and neighbouring pairs clear
    // each other by 0.1365 against 0.1310 of half-widths — no overhang, no
    // overlap, verified arithmetically rather than by eye.
    //
    // The bench is the exception: it is only 0.27 of the picture wide, so two
    // objects at a convincing plush size cannot both fit. Each slot is sized to
    // sit fully inside the bench on its own, and `resolvedPlacements` keeps a
    // second soft item off it.
    private static let portraitPlacement: [CabinSlot: SlotPlacement] = [
        .tableLeft:    .init(x: 0.3635, y: 0.462, scale: 0.1088, maxFootprint: 0.1219),
        .tableCenter:  .init(x: 0.5000, y: 0.462, scale: 0.1252, maxFootprint: 0.1402),
        .tableRight:   .init(x: 0.6365, y: 0.462, scale: 0.1088, maxFootprint: 0.1219),
        .benchLeft:    .init(x: 0.1700, y: 0.605, scale: 0.1960, maxFootprint: 0.2200),
        .benchCenter:  .init(x: 0.2380, y: 0.570, scale: 0.1610, maxFootprint: 0.1800),
        .wallLeft:     .init(x: 0.1350, y: 0.435, scale: 0.1500, maxFootprint: 0.1700,
                             anchor: .center, rotation: -4),
        .wallRight:    .init(x: 0.8650, y: 0.435, scale: 0.1500, maxFootprint: 0.1700,
                             anchor: .center, rotation: 4),
        .hookLeft:     .init(x: 0.1450, y: 0.415, scale: 0.1400, maxFootprint: 0.1600,
                             anchor: .topCenter, rotation: -5),
        .hookRight:    .init(x: 0.8550, y: 0.415, scale: 0.1400, maxFootprint: 0.1600,
                             anchor: .topCenter, rotation: 5),
        .hangingLeft:  .init(x: 0.2800, y: 0.070, scale: 0.1850, maxFootprint: 0.2100,
                             anchor: .topCenter),
        .hangingRight: .init(x: 0.7200, y: 0.070, scale: 0.1850, maxFootprint: 0.2100,
                             anchor: .topCenter),
        .floorRight:   .init(x: 0.7300, y: 0.835, scale: 0.2000, maxFootprint: 0.2300),
    ]

    // cabin_ipad. The widest tabletop of the three (0.27-0.75), so the same
    // 1 : 1.15 : 1 division leaves the most room.
    private static let tabletPlacement: [CabinSlot: SlotPlacement] = [
        .tableLeft:    .init(x: 0.3462, y: 0.505, scale: 0.1306, maxFootprint: 0.1463),
        .tableCenter:  .init(x: 0.5100, y: 0.505, scale: 0.1502, maxFootprint: 0.1682),
        .tableRight:   .init(x: 0.6738, y: 0.505, scale: 0.1306, maxFootprint: 0.1463),
        .benchLeft:    .init(x: 0.1550, y: 0.655, scale: 0.1870, maxFootprint: 0.2100),
        .benchCenter:  .init(x: 0.2120, y: 0.625, scale: 0.1560, maxFootprint: 0.1750),
        .wallLeft:     .init(x: 0.1150, y: 0.425, scale: 0.1450, maxFootprint: 0.1650,
                             anchor: .center, rotation: -4),
        .wallRight:    .init(x: 0.8850, y: 0.425, scale: 0.1450, maxFootprint: 0.1650,
                             anchor: .center, rotation: 4),
        .hookLeft:     .init(x: 0.1250, y: 0.455, scale: 0.1350, maxFootprint: 0.1550,
                             anchor: .topCenter, rotation: -5),
        .hookRight:    .init(x: 0.8750, y: 0.455, scale: 0.1350, maxFootprint: 0.1550,
                             anchor: .topCenter, rotation: 5),
        .hangingLeft:  .init(x: 0.3000, y: 0.065, scale: 0.1750, maxFootprint: 0.2000,
                             anchor: .topCenter),
        .hangingRight: .init(x: 0.7000, y: 0.065, scale: 0.1750, maxFootprint: 0.2000,
                             anchor: .topCenter),
        .floorRight:   .init(x: 0.7000, y: 0.845, scale: 0.1900, maxFootprint: 0.2150),
    ]

    // cabin_mac. Narrowest tabletop as a fraction (0.375-0.75) and an off-centre
    // window at x 0.40-0.725, so the tabletop midpoint is 0.5625, not 0.5. Every
    // x here is shifted accordingly; the previous single shared table could only
    // express one x per slot and put Mac objects left of the furniture.
    private static let landscapePlacement: [CabinSlot: SlotPlacement] = [
        .tableLeft:    .init(x: 0.4345, y: 0.525, scale: 0.1020, maxFootprint: 0.1143),
        .tableCenter:  .init(x: 0.5625, y: 0.525, scale: 0.1173, maxFootprint: 0.1314),
        .tableRight:   .init(x: 0.6905, y: 0.525, scale: 0.1020, maxFootprint: 0.1143),
        .benchLeft:    .init(x: 0.2300, y: 0.730, scale: 0.1870, maxFootprint: 0.2100),
        .benchCenter:  .init(x: 0.2870, y: 0.705, scale: 0.1560, maxFootprint: 0.1750),
        .wallLeft:     .init(x: 0.1000, y: 0.425, scale: 0.1100, maxFootprint: 0.1250,
                             anchor: .center, rotation: -4),
        .wallRight:    .init(x: 0.8750, y: 0.425, scale: 0.1100, maxFootprint: 0.1250,
                             anchor: .center, rotation: 4),
        .hookLeft:     .init(x: 0.1100, y: 0.455, scale: 0.1000, maxFootprint: 0.1150,
                             anchor: .topCenter, rotation: -5),
        .hookRight:    .init(x: 0.8650, y: 0.455, scale: 0.1000, maxFootprint: 0.1150,
                             anchor: .topCenter, rotation: 5),
        .hangingLeft:  .init(x: 0.3000, y: 0.055, scale: 0.1300, maxFootprint: 0.1500,
                             anchor: .topCenter),
        .hangingRight: .init(x: 0.8000, y: 0.055, scale: 0.1300, maxFootprint: 0.1500,
                             anchor: .topCenter),
        .floorRight:   .init(x: 0.7800, y: 0.855, scale: 0.1500, maxFootprint: 0.1750),
    ]
}

enum CabinArtworkLayout {
    case portrait, tablet, landscape
}

/// The rectangle the Cabin artwork actually occupies inside its container, and
/// the only coordinate space cabin objects are ever placed in.
///
/// The Cabin art is drawn `.scaledToFill()` and clipped, so it is scaled by the
/// LARGER of the two container ratios and centre-cropped on one axis. Its
/// rendered rect is therefore bigger than the container in that axis and offset
/// by a negative origin. Placing objects against the container instead — which
/// is what shipped — puts them in the wrong place on every aspect ratio except
/// the one the coordinates were authored on.
struct CabinArtFrame {
    /// Top-left of the rendered artwork in container coordinates. Negative on
    /// the cropped axis, which is exactly the correction that was missing.
    let origin: CGPoint
    /// The rendered artwork's size. Larger than the container on the cropped axis.
    let size: CGSize
    /// Which artwork is on screen, resolved once from the container by the same
    /// rule that picks the asset — so coordinates can never be read from a
    /// different artwork's table than the one being displayed.
    let layout: CabinArtworkLayout

    /// Mirrors SwiftUI's `.scaledToFill()` + centre crop exactly.
    static func fill(image: CGSize, in container: CGSize,
                     layout: CabinArtworkLayout) -> CabinArtFrame {
        guard image.width > 0, image.height > 0 else {
            return CabinArtFrame(origin: .zero, size: container, layout: layout)
        }
        let scale = max(container.width / image.width, container.height / image.height)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CabinArtFrame(
            origin: CGPoint(x: (container.width - size.width) / 2,
                            y: (container.height - size.height) / 2),
            size: size,
            layout: layout
        )
    }

    func x(_ normalized: Double) -> CGFloat { origin.x + CGFloat(normalized) * size.width }
    func y(_ normalized: Double) -> CGFloat { origin.y + CGFloat(normalized) * size.height }
    /// Object widths are a fraction of the ARTWORK's width, so a plush keeps the
    /// same size relative to the bench it sits on however the picture is cropped.
    func width(_ normalized: Double) -> CGFloat { CGFloat(normalized) * size.width }
}

struct CabinSlotTransform {
    let contact: CabinItemAnchor
    let defaultScale: Double
    let anchor: CabinItemAnchor
    let zIndex: Double
    var rotationDegrees: Double = 0
    let maximumFootprint: Double
}

enum CabinItemFootprint: String, Hashable {
    case compact, medium, wide, tall, soft
}

struct CabinItemAnchor: Hashable {
    let x: Double
    let y: Double
    static let zero = CabinItemAnchor(x: 0, y: 0)
    static let center = CabinItemAnchor(x: 0.5, y: 0.5)
    static let topCenter = CabinItemAnchor(x: 0.5, y: 0)
    static let bottomCenter = CabinItemAnchor(x: 0.5, y: 1)
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
    /// Nil inherits the physical anchor declared by the selected Cabin slot.
    var anchorPoint: CabinItemAnchor? = nil
    /// Small, normalized correction for transparent-canvas padding. This is
    /// interpreted inside the Cabin artwork frame, not the device screen.
    var offsetAdjustment: CabinItemAnchor = .zero
    var zIndex: Double = 0
    var rotationDegrees: Double = 0
    /// Tabletop pieces can be pitched into the artwork's perspective while
    /// upright objects remain at zero.
    var perspectivePitchDegrees: Double = 0
    /// Some legacy art includes a display stand. Cropping only that transparent
    /// lower region lets the usable object meet a real hook without regenerating
    /// the source PNG.
    var clippedBottomFraction: Double = 0
    var allowsSharedSurface = false

    init(id: String, name: String, subtitle: String, kind: Kind, price: Int,
         isPremium: Bool, systemImage: String, tintHex: UInt,
         imageName: String? = nil, allowedSlots: [CabinSlot] = [],
         preferredSlot: CabinSlot? = nil, footprint: CabinItemFootprint = .medium,
         normalizedScale: Double = 1, anchorPoint: CabinItemAnchor? = nil,
         offsetAdjustment: CabinItemAnchor = .zero,
         zIndex: Double = 0, rotationDegrees: Double = 0,
         perspectivePitchDegrees: Double = 0, clippedBottomFraction: Double = 0,
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
        self.offsetAdjustment = offsetAdjustment
        self.zIndex = zIndex
        self.rotationDegrees = rotationDegrees
        self.perspectivePitchDegrees = perspectivePitchDegrees
        self.clippedBottomFraction = clippedBottomFraction
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
                  footprint: .compact, normalizedScale: 0.72),
        StoreItem(id: "notebook", name: "Notebook", subtitle: "For your best ideas",
                  kind: .cabinDecoration, price: 40, isPremium: false, systemImage: "book.closed.fill",
                  tintHex: 0xB0783E, imageName: "notebook",
                  allowedSlots: [.tableLeft, .tableCenter, .tableRight, .benchLeft, .benchCenter],
                  preferredSlot: .tableCenter, footprint: .wide, normalizedScale: 0.76,
                  rotationDegrees: -3, perspectivePitchDegrees: 58),
        StoreItem(id: "headphones", name: "Headphones", subtitle: "Sink into deep focus",
                  kind: .cabinDecoration, price: 0, isPremium: true, systemImage: "headphones",
                  tintHex: 0x8FA6D8, imageName: "headphones",
                  allowedSlots: [.hookLeft, .hookRight, .tableLeft, .tableRight, .benchLeft],
                  preferredSlot: .hookLeft, footprint: .medium, normalizedScale: 0.70,
                  clippedBottomFraction: 0.26),
        StoreItem(id: "framed-poster", name: "Framed Poster", subtitle: "A view for the wall",
                  kind: .cabinDecoration, price: 340, isPremium: false, systemImage: "photo.fill",
                  tintHex: 0xE0A46A, imageName: "framed-poster",
                  allowedSlots: [.wallLeft, .wallRight], preferredSlot: .wallLeft,
                  footprint: .tall, normalizedScale: 0.72),
        StoreItem(id: "christmas-ornament", name: "Festive Ornament", subtitle: "A little seasonal cheer",
                  kind: .cabinDecoration, price: 280, isPremium: false, systemImage: "sparkles",
                  tintHex: 0xE8654B, imageName: "christmas-ornament",
                  allowedSlots: [.hangingLeft, .hangingRight], preferredSlot: .hangingRight,
                  footprint: .tall, normalizedScale: 0.66),
        StoreItem(id: "closed-laptop", name: "Closed Laptop", subtitle: "Work set aside for the climb",
                  kind: .cabinDecoration, price: 460, isPremium: false, systemImage: "laptopcomputer",
                  tintHex: 0x9AA7B4, imageName: "closed-laptop",
                  allowedSlots: [.tableCenter, .tableLeft, .tableRight, .benchLeft, .benchCenter],
                  preferredSlot: .tableCenter, footprint: .wide, normalizedScale: 0.78,
                  rotationDegrees: -3, perspectivePitchDegrees: 56),
        StoreItem(id: "sleeping-cat", name: "Sleeping Cat", subtitle: "A calm co-pilot",
                  kind: .cabinDecoration, price: 560, isPremium: false, systemImage: "cat.fill",
                  tintHex: 0xD8C0A0, imageName: "sleeping-cat",
                  allowedSlots: [.benchLeft, .benchCenter, .floorRight], preferredSlot: .benchLeft,
                  footprint: .soft, normalizedScale: 0.95),
        StoreItem(id: "cabin-plant", name: "Tiny Fern", subtitle: "A cabin companion",
                  kind: .cabinDecoration, price: 90, isPremium: false, systemImage: "leaf.fill",
                  tintHex: 0x6FD8B8, allowedSlots: [.tableLeft, .tableRight],
                  preferredSlot: .tableRight, footprint: .compact, normalizedScale: 0.67),
        StoreItem(id: "cabin-teapot", name: "Ceramic Teapot", subtitle: "For longer flights",
                  kind: .cabinDecoration, price: 130, isPremium: false, systemImage: "mug.fill",
                  tintHex: 0xE9C07A, allowedSlots: [.tableLeft, .tableCenter, .tableRight],
                  preferredSlot: .tableRight, footprint: .compact, normalizedScale: 0.72),

        // Curated first Cabin drop — premium stylized transparent artwork.
        StoreItem(id: "strawberry-matcha-latte", name: "Strawberry Matcha Latte",
                  subtitle: "A layered little lift", kind: .cabinDecoration, price: 180,
                  isPremium: false, systemImage: "cup.and.saucer.fill", tintHex: 0xE89AA8,
                  imageName: "Cabin_StrawberryMatcha",
                  allowedSlots: [.tableLeft, .tableCenter, .tableRight], preferredSlot: .tableLeft,
                  footprint: .compact, normalizedScale: 0.70),
        StoreItem(id: "heart-straw-boba", name: "Heart Straw Boba Tea",
                  subtitle: "Sweet focus energy", kind: .cabinDecoration, price: 210,
                  isPremium: false, systemImage: "heart.fill", tintHex: 0xE8A5B5,
                  imageName: "Cabin_HeartBoba",
                  allowedSlots: [.tableLeft, .tableCenter, .tableRight], preferredSlot: .tableRight,
                  footprint: .compact, normalizedScale: 0.66),
        StoreItem(id: "pastel-tumbler", name: "Pastel Insulated Tumbler",
                  subtitle: "Hydration for the long route", kind: .cabinDecoration, price: 0,
                  isPremium: true, systemImage: "waterbottle.fill", tintHex: 0xC9A6DA,
                  imageName: "Cabin_PastelTumbler",
                  allowedSlots: [.tableLeft, .tableCenter, .tableRight], preferredSlot: .tableLeft,
                  footprint: .tall, normalizedScale: 0.64),
        StoreItem(id: "candle-warmer", name: "Candle Warmer Lamp",
                  subtitle: "Amber calm without a flame", kind: .cabinDecoration, price: 340,
                  isPremium: false, systemImage: "lamp.table.fill", tintHex: 0xE7B66D,
                  imageName: "Cabin_CandleWarmer",
                  allowedSlots: [.tableLeft, .tableCenter, .tableRight], preferredSlot: .tableRight,
                  footprint: .tall, normalizedScale: 0.74),
        StoreItem(id: "mushroom-lamp", name: "Mushroom Lamp",
                  subtitle: "A cozy pool of light", kind: .cabinDecoration, price: 320,
                  isPremium: false, systemImage: "lamp.table.fill", tintHex: 0xD9793F,
                  imageName: "Cabin_MushroomLamp",
                  allowedSlots: [.tableLeft, .tableCenter, .tableRight], preferredSlot: .tableLeft,
                  footprint: .medium, normalizedScale: 0.74),
        StoreItem(id: "sunset-projector", name: "Mini Sunset Projector",
                  subtitle: "Warm atmosphere on demand", kind: .cabinDecoration, price: 390,
                  isPremium: false, systemImage: "sun.max.fill", tintHex: 0xEF8D53,
                  imageName: "Cabin_SunsetProjector",
                  allowedSlots: [.tableLeft, .tableRight, .floorRight], preferredSlot: .floorRight,
                  footprint: .medium, normalizedScale: 0.72),
        StoreItem(id: "flip-clock", name: "Digital Flip Clock",
                  subtitle: "Time, quietly kept", kind: .cabinDecoration, price: 280,
                  isPremium: false, systemImage: "clock.fill", tintHex: 0x8B6348,
                  imageName: "Cabin_FlipClock",
                  allowedSlots: [.tableLeft, .tableCenter, .tableRight], preferredSlot: .tableCenter,
                  footprint: .wide, normalizedScale: 0.78, perspectivePitchDegrees: 44),
        StoreItem(id: "vinyl-player", name: "Mini Vinyl Record Player",
                  subtitle: "Slow grooves for deep focus", kind: .cabinDecoration, price: 460,
                  isPremium: false, systemImage: "record.circle.fill", tintHex: 0x9B6D4A,
                  imageName: "Cabin_VinylPlayer",
                  allowedSlots: [.tableCenter, .tableLeft, .tableRight], preferredSlot: .tableCenter,
                  footprint: .wide, normalizedScale: 0.84, perspectivePitchDegrees: 48),
        StoreItem(id: "capybara-plush", name: "Sleepy Capybara Plush",
                  subtitle: "The calmest co-pilot", kind: .cabinDecoration, price: 0,
                  isPremium: true, systemImage: "pawprint.fill", tintHex: 0xC78C52,
                  imageName: "Cabin_CapybaraPlush",
                  allowedSlots: [.benchLeft, .benchCenter, .floorRight], preferredSlot: .benchLeft,
                  footprint: .soft, normalizedScale: 0.95),
        StoreItem(id: "cloud-pillow", name: "Cloud Pillow",
                  subtitle: "A softer place to land", kind: .cabinDecoration, price: 260,
                  isPremium: false, systemImage: "cloud.fill", tintHex: 0xEFE7D7,
                  imageName: "Cabin_CloudPillow",
                  allowedSlots: [.benchLeft, .benchCenter], preferredSlot: .benchCenter,
                  footprint: .soft, normalizedScale: 0.90),
        StoreItem(id: "mini-disco-ball", name: "Mini Disco Ball",
                  subtitle: "A restrained glint overhead", kind: .cabinDecoration, price: 320,
                  isPremium: false, systemImage: "circle.hexagongrid.fill", tintHex: 0xB5B5C8,
                  imageName: "Cabin_DiscoBall",
                  allowedSlots: [.hangingLeft, .hangingRight], preferredSlot: .hangingLeft,
                  footprint: .tall, normalizedScale: 0.68),
        StoreItem(id: "moon-stars-mobile", name: "Moon and Stars Mobile",
                  subtitle: "Celestial calm above you", kind: .cabinDecoration, price: 380,
                  isPremium: false, systemImage: "moon.stars.fill", tintHex: 0xD7B46A,
                  imageName: "Cabin_MoonStarsMobile",
                  allowedSlots: [.hangingLeft, .hangingRight], preferredSlot: .hangingRight,
                  footprint: .tall, normalizedScale: 0.70),
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
