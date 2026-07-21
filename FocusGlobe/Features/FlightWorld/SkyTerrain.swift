import Foundation
import SwiftUI

// MARK: - Authored terrain & landmark geometry
//
// Hand-authored Path shapes — NOT a generic sine-wave generator. Each shape
// carries explicit, asymmetric control points so a dune reads as a dune, an
// alpine ridge bites, a skyline has real rooftops. A `parallax` value shifts
// the whole silhouette horizontally for glacial depth drift without ever
// revealing a side edge (the profile always spans minX…maxX at the base).
//
// All shapes are pure/deterministic (no per-frame randomness), so SwiftUI
// caches them and only re-rasterises when the frame actually changes.

// MARK: Desert dunes — long windward slope, short steep leeward face

/// A field of wind-shaped dunes. Crests are authored as
/// (peakX, peakHeight, windwardReach, leewardReach) fractions, so no two
/// crests share a contour and the profile is believably asymmetric.
struct DuneField: Shape {
    /// Authored crests, left→right. All values are fractions of the rect.
    let crests: [(x: CGFloat, h: CGFloat, wind: CGFloat, lee: CGFloat)]
    var parallax: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, base = rect.maxY
        var p = Path()
        p.move(to: CGPoint(x: rect.minX - 4, y: base))
        // Trace the sky-line left→right as a chain of asymmetric dune humps.
        for (i, c) in crests.enumerated() {
            let peakX = rect.minX + (c.x * w) + parallax
            let peakY = base - c.h * h
            let windX = peakX - c.wind * w
            let leeX = peakX + c.lee * w
            if i == 0 { p.addLine(to: CGPoint(x: windX, y: base)) }
            // Windward: long, gentle, slightly convex rise.
            p.addCurve(to: CGPoint(x: peakX, y: peakY),
                       control1: CGPoint(x: windX + c.wind * w * 0.55, y: base - c.h * h * 0.12),
                       control2: CGPoint(x: peakX - c.wind * w * 0.30, y: peakY - c.h * h * 0.06))
            // Leeward: short, steep, concave drop back to the sand floor.
            p.addCurve(to: CGPoint(x: leeX, y: base),
                       control1: CGPoint(x: peakX + c.lee * w * 0.24, y: peakY + c.h * h * 0.10),
                       control2: CGPoint(x: leeX - c.lee * w * 0.30, y: base - c.h * h * 0.04))
        }
        p.addLine(to: CGPoint(x: rect.maxX + 4, y: base))
        p.closeSubpath()
        return p
    }
}

// MARK: Alpine / ice ridge — sharp, irregular, non-repeating peaks

/// A jagged mountain ridge from authored peak points
/// (peakX, peakHeight, leftShoulder, rightShoulder). Faces are near-straight
/// with a whisper of curve so summits are crisp but never a clean triangle.
struct AlpineRidge: Shape {
    let peaks: [(x: CGFloat, h: CGFloat, left: CGFloat, right: CGFloat)]
    var parallax: CGFloat = 0
    /// 0 = softer shoulders … 1 = knife-edge summits.
    var sharpness: CGFloat = 0.7

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, base = rect.maxY
        var p = Path()
        p.move(to: CGPoint(x: rect.minX - 4, y: base))
        for (i, pk) in peaks.enumerated() {
            let peakX = rect.minX + pk.x * w + parallax
            let peakY = base - pk.h * h
            let lX = peakX - pk.left * w
            let rX = peakX + pk.right * w
            let sag = (1 - sharpness) * 0.18
            if i == 0 { p.addLine(to: CGPoint(x: lX, y: base)) }
            // Rising face: a slightly bowed straight line to the summit.
            p.addQuadCurve(to: CGPoint(x: peakX, y: peakY),
                           control: CGPoint(x: peakX - pk.left * w * 0.5,
                                            y: peakY + pk.h * h * (0.34 + sag)))
            // Falling face: steeper, with a small secondary shelf.
            p.addQuadCurve(to: CGPoint(x: rX, y: base),
                           control: CGPoint(x: peakX + pk.right * w * 0.42,
                                            y: peakY + pk.h * h * (0.42 + sag)))
        }
        p.addLine(to: CGPoint(x: rect.maxX + 4, y: base))
        p.closeSubpath()
        return p
    }
}

/// Snow caps: the top slice of each alpine peak, drawn as its own light shape
/// clipped near the summits. Shares the peak set with `AlpineRidge`.
struct SnowCaps: Shape {
    let peaks: [(x: CGFloat, h: CGFloat, left: CGFloat, right: CGFloat)]
    var parallax: CGFloat = 0
    /// How far down each peak the snow reaches, as a fraction of peak height.
    var coverage: CGFloat = 0.36

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, base = rect.maxY
        var p = Path()
        for pk in peaks {
            let peakX = rect.minX + pk.x * w + parallax
            let peakY = base - pk.h * h
            let capY = peakY + pk.h * h * coverage
            let lX = peakX - pk.left * w * coverage
            let rX = peakX + pk.right * w * coverage
            p.move(to: CGPoint(x: lX, y: capY))
            // Two little sub-summits so the snow edge is ragged, not a clean V.
            p.addQuadCurve(to: CGPoint(x: peakX, y: peakY),
                           control: CGPoint(x: (lX + peakX) / 2 - pk.left * w * 0.06,
                                            y: capY - pk.h * h * 0.10))
            p.addQuadCurve(to: CGPoint(x: rX, y: capY),
                           control: CGPoint(x: (peakX + rX) / 2 + pk.right * w * 0.05,
                                            y: capY - pk.h * h * 0.06))
            // Wavy snow-line back to the start.
            p.addQuadCurve(to: CGPoint(x: lX, y: capY),
                           control: CGPoint(x: peakX, y: capY + pk.h * h * 0.12))
            p.closeSubpath()
        }
        return p
    }
}

// MARK: Rolling forested hills (Kyoto midground) — soft but varied

struct ForestHills: Shape {
    /// Authored hill crowns (x, height, halfWidth) — deliberately uneven.
    let hills: [(x: CGFloat, h: CGFloat, half: CGFloat)]
    var parallax: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, base = rect.maxY
        var p = Path()
        p.move(to: CGPoint(x: rect.minX - 4, y: base))
        for hill in hills {
            let cx = rect.minX + hill.x * w + parallax
            let topY = base - hill.h * h
            p.addLine(to: CGPoint(x: cx - hill.half * w, y: base))
            p.addQuadCurve(to: CGPoint(x: cx + hill.half * w, y: base),
                           control: CGPoint(x: cx, y: topY))
        }
        p.addLine(to: CGPoint(x: rect.maxX + 4, y: base))
        p.closeSubpath()
        return p
    }
}

// MARK: Pagoda — proper tapering tiers

/// A five-tier pagoda with a finial. Believable tier proportions (each roof
/// narrower than the one below), not a stack of identical triangles.
struct PagodaShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, base = rect.maxY
        let cx = rect.midX
        var p = Path()
        let tiers = 5
        for i in 0..<tiers {
            let f = CGFloat(i) / CGFloat(tiers - 1)               // 0 (bottom) … 1 (top)
            let tierY = base - h * (0.16 + f * 0.70)
            let half = w * (0.46 - f * 0.30)                      // roofs taper up
            let eave = h * 0.05
            // Upswept roof: eaves dip then lift at the corners.
            p.move(to: CGPoint(x: cx - half, y: tierY + eave))
            p.addQuadCurve(to: CGPoint(x: cx, y: tierY - eave * 0.6),
                           control: CGPoint(x: cx - half * 0.4, y: tierY - eave * 0.2))
            p.addQuadCurve(to: CGPoint(x: cx + half, y: tierY + eave),
                           control: CGPoint(x: cx + half * 0.4, y: tierY - eave * 0.2))
            p.addLine(to: CGPoint(x: cx + half * 0.62, y: tierY + eave))
            p.addLine(to: CGPoint(x: cx - half * 0.62, y: tierY + eave))
            p.closeSubpath()
            // Body wall under each roof (except the very top).
            if i < tiers - 1 {
                let bodyH = h * 0.09
                p.addRect(CGRect(x: cx - half * 0.34, y: tierY + eave,
                                 width: half * 0.68, height: bodyH))
            }
        }
        // Finial spire.
        p.addRect(CGRect(x: cx - w * 0.012, y: base - h * 0.98, width: w * 0.024, height: h * 0.10))
        // Ground plinth so it stands on the hill, not in mid-air.
        p.addRect(CGRect(x: cx - w * 0.30, y: base - h * 0.02, width: w * 0.60, height: h * 0.06))
        return p
    }
}

/// A low row of traditional temple/house rooflines — varied widths and ridge
/// heights, gently upswept. Fills to the base so it reads as a settlement.
struct TempleRoofline: Shape {
    /// (centerX, roofHalfWidth, roofHeight) fractions.
    let roofs: [(x: CGFloat, half: CGFloat, h: CGFloat)]
    var parallax: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, base = rect.maxY
        var p = Path()
        for r in roofs {
            let cx = rect.minX + r.x * w + parallax
            let half = r.half * w
            let ridgeY = base - r.h * h
            let eaveY = base - r.h * h * 0.42
            p.move(to: CGPoint(x: cx - half, y: base))
            p.addLine(to: CGPoint(x: cx - half, y: eaveY))
            p.addQuadCurve(to: CGPoint(x: cx, y: ridgeY),
                           control: CGPoint(x: cx - half * 0.5, y: ridgeY + r.h * h * 0.10))
            p.addQuadCurve(to: CGPoint(x: cx + half, y: eaveY),
                           control: CGPoint(x: cx + half * 0.5, y: ridgeY + r.h * h * 0.10))
            p.addLine(to: CGPoint(x: cx + half, y: base))
            p.closeSubpath()
        }
        return p
    }
}

// MARK: Tropical island silhouette with an organic tree line

struct IslandSilhouette: Shape {
    /// (centerX, height, halfWidth) fractions; palms toggled per island.
    let islands: [(x: CGFloat, h: CGFloat, half: CGFloat, palms: Bool)]
    var parallax: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, base = rect.maxY
        var p = Path()
        for isle in islands {
            let cx = rect.minX + isle.x * w + parallax
            let half = isle.half * w
            let topY = base - isle.h * h
            // Low, wide landmass with a soft asymmetric crown.
            p.move(to: CGPoint(x: cx - half, y: base))
            p.addQuadCurve(to: CGPoint(x: cx - half * 0.1, y: topY),
                           control: CGPoint(x: cx - half * 0.7, y: topY + isle.h * h * 0.2))
            p.addQuadCurve(to: CGPoint(x: cx + half, y: base),
                           control: CGPoint(x: cx + half * 0.6, y: topY + isle.h * h * 0.5))
            p.closeSubpath()
            if isle.palms {
                // A couple of lean palm silhouettes rising off the crown.
                for k in [-0.18, 0.12] {
                    let px = cx + CGFloat(k) * half
                    let trunkTop = topY - isle.h * h * 0.9
                    let lean = CGFloat(k) * half * 0.5
                    p.move(to: CGPoint(x: px, y: topY))
                    p.addQuadCurve(to: CGPoint(x: px + lean, y: trunkTop),
                                   control: CGPoint(x: px + lean * 0.3, y: (topY + trunkTop) / 2))
                    // Frond fan.
                    for a in stride(from: -0.9, through: 0.9, by: 0.45) {
                        let fx = px + lean + CGFloat(cos(Double.pi * (0.5 + a))) * half * 0.22
                        let fy = trunkTop - CGFloat(sin(Double.pi * (0.5 + a))) * isle.h * h * 0.16
                        p.move(to: CGPoint(x: px + lean, y: trunkTop))
                        p.addLine(to: CGPoint(x: fx, y: fy))
                    }
                }
            }
        }
        return p
    }
}

// MARK: City skyline — varied building families with real rooftops

/// One authored building profile (fraction coordinates, base at rect.maxY).
struct Building {
    let x: CGFloat            // left edge
    let width: CGFloat
    let height: CGFloat
    enum Roof { case flat, stepped, antenna, watertank, peak }
    let roof: Roof
}

struct CitySkyline: Shape {
    let buildings: [Building]
    var parallax: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, base = rect.maxY
        var p = Path()
        for b in buildings {
            let x = rect.minX + b.x * w + parallax
            let bw = b.width * w
            let topY = base - b.height * h
            p.addRect(CGRect(x: x, y: topY, width: bw, height: base - topY))
            switch b.roof {
            case .flat:
                break
            case .stepped:
                p.addRect(CGRect(x: x + bw * 0.18, y: topY - h * 0.04,
                                 width: bw * 0.64, height: h * 0.04))
                p.addRect(CGRect(x: x + bw * 0.34, y: topY - h * 0.07,
                                 width: bw * 0.32, height: h * 0.03))
            case .antenna:
                p.addRect(CGRect(x: x + bw * 0.46, y: topY - h * 0.12,
                                 width: bw * 0.06, height: h * 0.12))
                p.addRect(CGRect(x: x + bw * 0.30, y: topY - h * 0.03,
                                 width: bw * 0.4, height: h * 0.03))
            case .watertank:
                p.addRect(CGRect(x: x + bw * 0.24, y: topY - h * 0.05,
                                 width: bw * 0.3, height: h * 0.05))
                p.addRect(CGRect(x: x + bw * 0.2, y: topY - h * 0.055,
                                 width: bw * 0.38, height: h * 0.01))
            case .peak:
                p.move(to: CGPoint(x: x, y: topY))
                p.addLine(to: CGPoint(x: x + bw * 0.5, y: topY - h * 0.05))
                p.addLine(to: CGPoint(x: x + bw, y: topY))
                p.closeSubpath()
            }
        }
        return p
    }
}

// MARK: Cosmic — a distant curved planetary limb (foreground for space skies)

/// A huge, dark planet edge curving across the very bottom of the frame — the
/// "you are above an alien world" cue. Purely a big arc filled downward.
struct PlanetLimb: Shape {
    /// How high the limb's apex sits, as a fraction of height (small = flatter).
    var rise: CGFloat = 0.10
    func path(in rect: CGRect) -> Path {
        let w = rect.width, base = rect.maxY
        var p = Path()
        p.move(to: CGPoint(x: rect.minX - 4, y: base))
        p.addLine(to: CGPoint(x: rect.minX - 4, y: base - rect.height * rise * 0.5))
        p.addQuadCurve(to: CGPoint(x: rect.maxX + 4, y: base - rect.height * rise * 0.5),
                       control: CGPoint(x: rect.midX, y: base - rect.height * rise - w * 0.02))
        p.addLine(to: CGPoint(x: rect.maxX + 4, y: base))
        p.closeSubpath()
        return p
    }
}
