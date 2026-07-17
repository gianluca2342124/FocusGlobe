import SwiftUI
import UIKit

/// PHASE 5 — Cabin View: the cozy interior of the balloon basket. A calm,
/// premium alternative the pilot can switch to mid-flight. The very same live
/// world scrolls past an arched wooden window, so interior and exterior stay
/// coherent — you are simply looking *out* rather than *at* the balloon.
///
/// ASSET STRATEGY: every prop is factored into its own small private subview or
/// `Shape`, so an image-based dressing (e.g. a "CabinInterior" overlay in the
/// asset catalog) can later replace or augment the procedural version without
/// touching the layout. Nothing here *depends* on any asset — the procedural
/// cabin builds and runs entirely on its own. If a "CabinInterior" image is ever
/// added to the catalog it is drawn on top; otherwise the procedural art stands
/// alone (see `assetOverlay`).
struct CabinView: View {
    /// Live elapsed focus seconds (pause-aware) — forwarded to the sky window so
    /// the world through the glass matches the exterior exactly.
    let elapsed: () -> Double
    /// Stable per-session world seed (shared with the exterior view).
    var seed: UInt64
    /// When false every layer is frozen (Reduce Motion / low-power calm).
    var animated: Bool
    /// Same Sky identity as the exterior, so the window shows the SAME world.
    var focusSky: FocusSky? = nil
    /// Whether fellow pilots share this Sky (mirrors the exterior; hidden for a
    /// solo flight). When true, the same ambient balloons drift **through the
    /// window** so the cabin looks out on the very same shared journey.
    var showPilots: Bool = true
    /// The SAME real online pilots as the exterior (no second network fetch) —
    /// they drift past the window exactly like the decorative ones.
    var realPilots: [OnlinePilot] = []
    /// Private-room participants show persistent identity bubbles here too.
    var roomMode: Bool = false
    /// Owned Store cabin decorations the pilot has placed (`StoreItem` ids) —
    /// purely additive dressing; the cabin stands alone without any of them.
    var equippedItemIDs: Set<String> = []

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            // One clock drives every layer. Still when !animated.
            TimelineView(.animation(minimumInterval: animated ? 1.0 / 20.0 : 5.0)) { ctx in
                let t = animated ? ctx.date.timeIntervalSinceReferenceDate : 0
                content(W: W, H: H, t: t)
            }
        }
        .ignoresSafeArea()
    }

    // The whole interior, composed back → front. Split into subviews so no single
    // @ViewBuilder container holds more than 10 direct children.
    private func content(W: CGFloat, H: CGFloat, t: Double) -> some View {
        // Gentle float so the cabin feels suspended, not static.
        let floatY = animated ? CGFloat(Foundation.sin(t * 0.5)) * 4 : 0
        let floatRot = animated ? CGFloat(Foundation.sin(t * 0.32)) * 0.35 : 0
        return Group {
            if let asset = cabinAssetName(W: W, H: H) {
                assetCabin(asset: asset, W: W, H: H, t: t)
            } else {
                proceduralCabin(W: W, H: H, t: t)
            }
        }
        .rotationEffect(.degrees(Double(floatRot)))
        .offset(y: floatY)
        .allowsHitTesting(false)
    }

    private func proceduralCabin(W: CGFloat, H: CGFloat, t: Double) -> some View {
        ZStack {
            interiorBackground(W: W, H: H)
            skyWindow(W: W, H: H, t: t)
            topWarmth(W: W, H: H, t: t)
            sill(W: W, H: H)
            sillProps(W: W, H: H, t: t)
            equippedProps(W: W, H: H, t: t)
            floorPet(W: W, H: H, t: t)
            assetOverlay
        }
    }

    // MARK: Bundled cabin art (cabin_iphone / cabin_ipad / cabin_mac)

    /// The device-appropriate cabin image, or nil to use the procedural cabin.
    /// Chosen by aspect ratio: wide → Mac, large square-ish → iPad, else iPhone.
    private func cabinAssetName(W: CGFloat, H: CGFloat) -> String? {
        #if canImport(UIKit)
        let candidate: String
        let aspect = W / max(1, H)
        if aspect > 1.2 { candidate = "cabin_mac" }
        else if min(W, H) > 700 { candidate = "cabin_ipad" }
        else { candidate = "cabin_iphone" }
        return UIImage(named: candidate) != nil ? candidate : nil
        #else
        return nil
        #endif
    }

    /// The live flight world sits BEHIND the cabin art; the art's transparent
    /// window region reveals it, so you look *out* at the Sky. Equipped Store
    /// decorations rest on the sill on top.
    private func assetCabin(asset: String, W: CGFloat, H: CGFloat, t: Double) -> some View {
        ZStack {
            Color(hex: 0x120C08)
            ActiveFlightJourneyWorldView(elapsed: elapsed, seed: seed,
                                         animated: animated, focusSky: focusSky)
                .frame(width: W, height: H).clipped()
            // The SAME fellow pilots as the exterior, drifting behind the cabin
            // art so they read *through the window* (non-interactive in here).
            if showPilots {
                AmbientPilotsLayer(skyID: focusSky?.id ?? "classic",
                                   elapsed: elapsed, animated: animated,
                                   realPilots: realPilots, roomMode: roomMode)
                    .frame(width: W, height: H).clipped()
                    .allowsHitTesting(false)
            }
            #if canImport(UIKit)
            if let ui = UIImage(named: asset) {
                Image(uiImage: ui).resizable().scaledToFill()
                    .frame(width: W, height: H).clipped()
            }
            #endif
            assetEquippedProps(W: W, H: H, t: t)
        }
        .frame(width: W, height: H)
    }

    // Equipped decorations placed over the cabin sill (approximate per-asset
    // anchors; subtle and premium, never overcrowded).
    @ViewBuilder private func assetEquippedProps(W: CGFloat, H: CGFloat, t: Double) -> some View {
        if equippedItemIDs.contains("cabin-plant") {
            CabinFern(t: animated ? t : 0)
                .frame(width: W * 0.12, height: W * 0.15)
                .position(x: W * 0.30, y: H * 0.50)
        }
        if equippedItemIDs.contains("cabin-teapot") {
            CabinTeapot()
                .frame(width: W * 0.15, height: W * 0.11)
                .position(x: W * 0.70, y: H * 0.50)
        }
        newArtProps(W: W, H: H)
    }

    /// Renders any equipped Cabin objects that ship as their own PNG (the new
    /// catalog art), anchored to a real surface by their `cabinPlacement` and
    /// spread along the sill so they don't stack. Never covers the window or timer.
    @ViewBuilder private func newArtProps(W: CGFloat, H: CGFloat) -> some View {
        let items = StoreItem.all.filter {
            equippedItemIDs.contains($0.id) && $0.imageName != nil && $0.cabinPlacement != .none
        }
        ForEach(items, id: \.id) { item in
            cabinItemImage(item)
                .frame(width: W * itemScale(item), height: W * itemScale(item))
                .position(x: W * anchorX(item, in: items), y: H * anchorY(item))
        }
    }

    @ViewBuilder private func cabinItemImage(_ item: StoreItem) -> some View {
        #if canImport(UIKit)
        if let ui = UIImage(named: item.bestAssetName) {
            Image(uiImage: ui).resizable().scaledToFit()
                .shadow(color: .black.opacity(0.32), radius: 6, y: 4)
        }
        #endif
    }

    private func itemScale(_ item: StoreItem) -> CGFloat {
        switch item.cabinPlacement {
        case .wall:     return 0.26
        case .bench:    return 0.24
        case .hook:     return 0.12
        case .tabletop: return 0.15
        case .none:     return 0
        }
    }
    private func anchorY(_ item: StoreItem) -> CGFloat {
        switch item.cabinPlacement {
        case .wall:     return 0.17
        case .bench:    return 0.70
        case .hook:     return 0.10
        case .tabletop: return 0.52
        case .none:     return 0.5
        }
    }
    private static let tabletopSlots: [CGFloat] = [0.26, 0.44, 0.62, 0.78, 0.36, 0.7]
    private func anchorX(_ item: StoreItem, in items: [StoreItem]) -> CGFloat {
        switch item.cabinPlacement {
        case .wall, .bench: return 0.5
        case .hook:         return 0.8
        case .tabletop:
            let tabletop = items.filter { $0.cabinPlacement == .tabletop }
            let idx = tabletop.firstIndex(of: item) ?? 0
            return Self.tabletopSlots[idx % Self.tabletopSlots.count]
        case .none:         return 0.5
        }
    }

    // MARK: 1 — Interior background (warm amber walls + soft lantern glow)

    private func interiorBackground(W: CGFloat, H: CGFloat) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x2E2016), Color(hex: 0x140D08)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [AppColors.lantern.opacity(0.30), .clear],
                           center: UnitPoint(x: 0.5, y: 0.16),
                           startRadius: 0, endRadius: W * 0.72)
        }
    }

    // MARK: 2 — Sky window (the hero: the live world, arched + wood-framed)

    private func skyWindow(W: CGFloat, H: CGFloat, t: Double) -> some View {
        let winW = W * 0.72
        let winH = H * 0.42
        let cx = W / 2
        let cy = H * 0.30
        let shape = CabinWindowShape()
        let wood = LinearGradient(colors: [Color(hex: 0x6B4A2E), Color(hex: 0x3A2617)],
                                  startPoint: .top, endPoint: .bottom)
        return ZStack {
            // The SAME live world as the exterior, seen through the glass.
            ActiveFlightJourneyWorldView(elapsed: elapsed, seed: seed,
                                         animated: animated, focusSky: focusSky)
                .frame(width: winW, height: winH)
                .clipShape(shape)
            // The same fellow pilots drifting past, clipped inside the glass.
            if showPilots {
                AmbientPilotsLayer(skyID: focusSky?.id ?? "classic",
                                   elapsed: elapsed, animated: animated,
                                   realPilots: realPilots, roomMode: roomMode)
                    .frame(width: winW, height: winH)
                    .clipShape(shape)
                    .allowsHitTesting(false)
            }
            // Inner radial shade so the edges read darker → depth.
            shape
                .fill(RadialGradient(colors: [.clear, .black.opacity(0.55)],
                                     center: .center,
                                     startRadius: winW * 0.18, endRadius: winW * 0.62))
                .frame(width: winW, height: winH)
            // Soft diagonal glass sheen.
            shape
                .fill(LinearGradient(colors: [.white.opacity(0.16), .clear, .white.opacity(0.05)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: winW, height: winH)
                .blendMode(.plusLighter)
            // Thin inner white edge.
            shape.stroke(.white.opacity(0.10), lineWidth: 2)
                .frame(width: winW, height: winH)
            // Warm wooden frame.
            shape.stroke(wood, lineWidth: 12)
                .frame(width: winW, height: winH)
        }
        .frame(width: winW, height: winH)
        .shadow(color: .black.opacity(0.5), radius: 22, y: 12)
        .position(x: cx, y: cy)
    }

    // MARK: 3 — Top warmth (breathing burner glow + a shallow string-light arc)

    private func topWarmth(W: CGFloat, H: CGFloat, t: Double) -> some View {
        let breathe = animated ? Foundation.sin(t * 1.1) : 0.0          // -1 … 1
        let pulse = breathe * 0.5 + 0.5                                 // 0 … 1
        let burnerScale = CGFloat(1.0 + 0.12 * pulse)
        let burnerOpacity = 0.35 + 0.25 * pulse
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [AppColors.lantern.opacity(0.8), .clear],
                                     center: .center, startRadius: 0, endRadius: W * 0.22))
                .frame(width: W * 0.5, height: W * 0.5)
                .scaleEffect(burnerScale)
                .opacity(burnerOpacity)
                .blendMode(.plusLighter)
                .position(x: W / 2, y: H * 0.06)
            stringLights(W: W, H: H, t: t)
        }
    }

    private func stringLights(W: CGFloat, H: CGFloat, t: Double) -> some View {
        let spanW = W * 0.66
        return ZStack {
            ForEach(0..<7, id: \.self) { i in
                let f = CGFloat(i) / 6
                let x = W / 2 - spanW / 2 + spanW * f
                // Shallow downward arc: ends high, gently dips in the middle.
                let dip = CGFloat(Foundation.sin(Double(f) * .pi)) * (H * 0.03)
                let y = H * 0.10 + dip
                let tw = animated ? (Foundation.sin(t * 2 + Double(i)) * 0.5 + 0.5) : 0.7
                Circle()
                    .fill(Color(hex: 0xFFD98A))
                    .frame(width: 7, height: 7)
                    .shadow(color: Color(hex: 0xFFD98A).opacity(0.9), radius: CGFloat(4 + 3 * tw))
                    .opacity(0.65 + 0.35 * tw)
                    .position(x: x, y: y)
            }
        }
    }

    // MARK: 4 — Wooden sill / ledge spanning under the window

    private func sill(W: CGFloat, H: CGFloat) -> some View {
        let sillY = H * 0.30 + (H * 0.42) / 2 - 6
        return RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: 0x6E4B2E), Color(hex: 0x5A3D26)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: W * 0.86, height: H * 0.045)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
            .position(x: W / 2, y: sillY)
    }

    // MARK: 5 — Sill props (LEFT: steaming cup · RIGHT: closed book)

    private func sillProps(W: CGFloat, H: CGFloat, t: Double) -> some View {
        let sillTopY = H * 0.30 + (H * 0.42) / 2 - 6 - (H * 0.045) / 2
        return ZStack {
            CabinCup(t: animated ? t : 0)
                .frame(width: W * 0.15, height: W * 0.20)
                .position(x: W * 0.30, y: sillTopY - W * 0.07)
            CabinBook()
                .frame(width: W * 0.18, height: W * 0.11)
                .position(x: W * 0.68, y: sillTopY - W * 0.045)
        }
    }

    // MARK: 5b — Placed Store decorations (bought + equipped in the Store)

    @ViewBuilder private func equippedProps(W: CGFloat, H: CGFloat, t: Double) -> some View {
        let sillTopY = H * 0.30 + (H * 0.42) / 2 - 6 - (H * 0.045) / 2
        if equippedItemIDs.contains("cabin-plant") {
            CabinFern(t: animated ? t : 0)
                .frame(width: W * 0.13, height: W * 0.16)
                .position(x: W * 0.14, y: sillTopY - W * 0.055)
        }
        if equippedItemIDs.contains("cabin-teapot") {
            CabinTeapot()
                .frame(width: W * 0.16, height: W * 0.12)
                .position(x: W * 0.85, y: sillTopY - W * 0.042)
        }
    }

    // MARK: 6 — Floor pet (a curled, softly-breathing cat on a cushion)

    private func floorPet(W: CGFloat, H: CGFloat, t: Double) -> some View {
        let petY = H * 0.9
        let breathe = animated ? CGFloat(Foundation.sin(t * 1.3)) : 0
        let scaleY = 1 + breathe * 0.02
        return CabinPet(quilted: equippedItemIDs.contains("cabin-quilt"))
            .frame(width: W * 0.34, height: H * 0.14)
            .scaleEffect(x: 1, y: scaleY, anchor: .bottom)
            .position(x: W / 2, y: petY)
    }

    // MARK: Optional image dressing (never required — procedural stands alone)

    @ViewBuilder private var assetOverlay: some View {
        if let ui = UIImage(named: "CabinInterior") {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Props (each isolated so an image can swap in later)

/// A cream ceramic cup with a dark coffee surface and gently rising steam.
private struct CabinCup: View {
    var t: Double

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let h = g.size.height
            ZStack {
                steam
                // Cup body.
                RoundedRectangle(cornerRadius: w * 0.14, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0xF3ECDD), Color(hex: 0xEDE4D4)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.58, height: h * 0.42)
                    .position(x: w * 0.5, y: h * 0.74)
                // Handle.
                Circle()
                    .stroke(Color(hex: 0xEDE4D4), lineWidth: w * 0.055)
                    .frame(width: w * 0.26, height: h * 0.24)
                    .position(x: w * 0.82, y: h * 0.72)
                // Coffee surface.
                Ellipse()
                    .fill(Color(hex: 0x3A2214))
                    .frame(width: w * 0.5, height: h * 0.09)
                    .position(x: w * 0.5, y: h * 0.55)
            }
            .shadow(color: .black.opacity(0.3), radius: 5, y: 3)
        }
    }

    // ~3 soft wisps that rise, sway via sin, fade in then out, looping on t.
    private var steam: some View {
        Canvas { ctx, size in
            let cw = Double(size.width)
            let ch = Double(size.height)
            for k in 0..<3 {
                let phase = t * 0.5 + Double(k) * 0.8
                let cycle = phase.truncatingRemainder(dividingBy: 1.0)   // 0 … 1 rising
                let baseX = cw * (0.4 + 0.1 * Double(k))
                let sway = Foundation.sin(phase * 2.4) * (cw * 0.05)
                let x = baseX + sway
                let y = ch * (0.5 - 0.45 * cycle)
                let fade = Foundation.sin(cycle * .pi)                   // in then out
                let r = cw * 0.045
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                // Bake the wisp's alpha into the fill colour (Color.opacity takes a
                // Double) rather than touching GraphicsContext.opacity — same
                // result, and no dependency on that property's exact numeric type.
                ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(fade * 0.45)))
            }
        }
    }
}

/// A small closed notebook with a terracotta cover and a thin page fore-edge.
private struct CabinBook: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let h = g.size.height
            ZStack {
                // Cover.
                RoundedRectangle(cornerRadius: h * 0.14, style: .continuous)
                    .fill(LinearGradient(colors: [AppColors.terracotta, Color(hex: 0x9E3E2A)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.9, height: h * 0.82)
                    .position(x: w * 0.5, y: h * 0.5)
                // Page fore-edge.
                RoundedRectangle(cornerRadius: h * 0.06, style: .continuous)
                    .fill(Color(hex: 0xF0E9DA))
                    .frame(width: w * 0.07, height: h * 0.72)
                    .position(x: w * 0.9, y: h * 0.5)
                // Spine accent.
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(.white.opacity(0.16))
                    .frame(width: 2, height: h * 0.68)
                    .position(x: w * 0.14, y: h * 0.5)
            }
            .rotationEffect(.degrees(-4))
            .shadow(color: .black.opacity(0.35), radius: 6, y: 4)
        }
    }
}

/// A curled sleeping cat/fox silhouette (body + head + 2 ears + tail) resting on
/// a small cushion. Composed only of ellipses and tiny shapes.
private struct CabinPet: View {
    /// "Aurora Quilt" equipped: the cushion wears cold-sky colours + stitching.
    var quilted: Bool = false

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let h = g.size.height
            ZStack {
                // Cushion (the Aurora Quilt re-dresses it when equipped).
                Ellipse()
                    .fill(LinearGradient(colors: quilted
                                            ? [Color(hex: 0x4CC9A0), Color(hex: 0x3B5876)]
                                            : [Color(hex: 0x7E4A5A), Color(hex: 0x5E3543)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.92, height: h * 0.34)
                    .position(x: w * 0.5, y: h * 0.82)
                if quilted {
                    // Quilt stitching — a soft dashed seam across the cushion.
                    Ellipse()
                        .stroke(.white.opacity(0.22),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .frame(width: w * 0.7, height: h * 0.2)
                        .position(x: w * 0.5, y: h * 0.82)
                }
                // Tail curling around the body.
                CabinTailShape()
                    .stroke(Color(hex: 0xB89878),
                            style: StrokeStyle(lineWidth: h * 0.13, lineCap: .round))
                    .frame(width: w * 0.7, height: h * 0.5)
                    .position(x: w * 0.55, y: h * 0.58)
                // Body.
                Ellipse()
                    .fill(LinearGradient(colors: [Color(hex: 0xD8C0A0), Color(hex: 0xB89878)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.66, height: h * 0.46)
                    .position(x: w * 0.52, y: h * 0.62)
                // Ears.
                CabinEarShape()
                    .fill(Color(hex: 0xB89878))
                    .frame(width: w * 0.1, height: h * 0.12)
                    .position(x: w * 0.28, y: h * 0.44)
                CabinEarShape()
                    .fill(Color(hex: 0xB89878))
                    .frame(width: w * 0.1, height: h * 0.12)
                    .position(x: w * 0.4, y: h * 0.44)
                // Head.
                Ellipse()
                    .fill(Color(hex: 0xD8C0A0))
                    .frame(width: w * 0.3, height: h * 0.3)
                    .position(x: w * 0.34, y: h * 0.56)
            }
        }
    }
}

// MARK: - Shapes

/// An arched-top window with rounded bottom corners.
struct CabinWindowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let r = min(w, h) * 0.10                     // bottom corner radius
        let arch = min(h * 0.45, w * 0.55)           // how far the arch reaches
        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY
        let archBaseY = minY + arch
        let ctrlY = minY - arch                      // peak lands exactly on minY
        p.move(to: CGPoint(x: minX, y: maxY - r))
        p.addLine(to: CGPoint(x: minX, y: archBaseY))
        p.addQuadCurve(to: CGPoint(x: maxX, y: archBaseY),
                       control: CGPoint(x: rect.midX, y: ctrlY))
        p.addLine(to: CGPoint(x: maxX, y: maxY - r))
        p.addQuadCurve(to: CGPoint(x: maxX - r, y: maxY),
                       control: CGPoint(x: maxX, y: maxY))
        p.addLine(to: CGPoint(x: minX + r, y: maxY))
        p.addQuadCurve(to: CGPoint(x: minX, y: maxY - r),
                       control: CGPoint(x: minX, y: maxY))
        p.closeSubpath()
        return p
    }
}

/// A single soft curl for the sleeping pet's tail.
struct CabinTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        return p
    }
}

/// A tiny triangular ear.
struct CabinEarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Store decorations (drawn only when bought + placed)

/// The "Tiny Fern" Store decoration — a terracotta pot with arcing mint
/// fronds that sway almost imperceptibly.
private struct CabinFern: View {
    var t: Double

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let h = g.size.height
            ZStack {
                fronds
                RoundedRectangle(cornerRadius: w * 0.1, style: .continuous)
                    .fill(LinearGradient(colors: [AppColors.terracotta, Color(hex: 0x8A3A28)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.44, height: h * 0.30)
                    .position(x: w * 0.5, y: h * 0.85)
            }
            .shadow(color: .black.opacity(0.3), radius: 5, y: 3)
        }
    }

    /// A fan of six quad-curve fronds rooted at the pot's mouth.
    private var fronds: some View {
        Canvas { ctx, size in
            let baseX = Double(size.width) * 0.5
            let baseY = Double(size.height) * 0.72
            for k in 0..<6 {
                let f = Double(k) / 5.0
                let spread = (f - 0.5) * 2.0
                let sway = Foundation.sin(t * 0.9 + Double(k)) * 0.04
                let lift = 0.55 + 0.16 * Foundation.sin(f * .pi)
                let tipX = baseX + (spread * 0.42 + sway) * Double(size.width)
                let tipY = baseY - lift * Double(size.height)
                let ctrlX = baseX + spread * 0.14 * Double(size.width)
                let ctrlY = baseY - 0.34 * Double(size.height)
                var p = Path()
                p.move(to: CGPoint(x: baseX, y: baseY))
                p.addQuadCurve(to: CGPoint(x: tipX, y: tipY),
                               control: CGPoint(x: ctrlX, y: ctrlY))
                ctx.stroke(p, with: .color(Color(hex: 0x6FD8B8).opacity(0.9)),
                           style: StrokeStyle(lineWidth: CGFloat(1.6), lineCap: .round))
            }
        }
    }
}

/// The "Ceramic Teapot" Store decoration — warm glaze, spout, handle, lid.
private struct CabinTeapot: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let h = g.size.height
            ZStack {
                // Body.
                Ellipse()
                    .fill(LinearGradient(colors: [Color(hex: 0xE9C07A), Color(hex: 0xC49855)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: w * 0.62, height: h * 0.62)
                    .position(x: w * 0.48, y: h * 0.62)
                // Spout.
                CabinSpoutShape()
                    .fill(Color(hex: 0xD9B06A))
                    .frame(width: w * 0.22, height: h * 0.30)
                    .position(x: w * 0.13, y: h * 0.52)
                // Handle.
                Circle()
                    .trim(from: 0.55, to: 0.95)
                    .stroke(Color(hex: 0xD9B06A),
                            style: StrokeStyle(lineWidth: w * 0.045, lineCap: .round))
                    .frame(width: w * 0.30, height: w * 0.30)
                    .position(x: w * 0.80, y: h * 0.52)
                // Lid.
                Capsule()
                    .fill(Color(hex: 0xD9B06A))
                    .frame(width: w * 0.24, height: h * 0.08)
                    .position(x: w * 0.48, y: h * 0.30)
                Circle()
                    .fill(Color(hex: 0xF3ECDD))
                    .frame(width: w * 0.08, height: w * 0.08)
                    .position(x: w * 0.48, y: h * 0.22)
                // Glaze highlight.
                Ellipse()
                    .fill(.white.opacity(0.18))
                    .frame(width: w * 0.16, height: h * 0.26)
                    .rotationEffect(.degrees(-24))
                    .position(x: w * 0.36, y: h * 0.50)
            }
            .shadow(color: .black.opacity(0.3), radius: 5, y: 3)
        }
    }
}

/// A short curved teapot spout.
private struct CabinSpoutShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY),
                       control: CGPoint(x: rect.minX + rect.width * 0.2,
                                        y: rect.maxY - rect.height * 0.1))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.35, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.45),
                       control: CGPoint(x: rect.minX + rect.width * 0.45,
                                        y: rect.maxY - rect.height * 0.35))
        p.closeSubpath()
        return p
    }
}
