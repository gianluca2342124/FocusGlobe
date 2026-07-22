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

// MARK: Desert dunes — ONE broad, smooth, asymmetric ridge per layer

/// The shared smooth dune ridge: a long, gentle windward rise sweeping up to a
/// single crest, then a shorter, smooth leeward settle — one elegant sand ridge
/// spanning the WHOLE width. Not a row of bumps, not a sine wave, not a
/// symmetric hill: the asymmetry (long approach, short far side) is what reads as
/// a real dune. Appends the top-edge curve to `p` (already positioned at the
/// left-edge start). Each depth layer uses a different crest, so no two ridges
/// share a contour.
func fgDuneRidge(_ p: inout Path, minX: CGFloat, maxX: CGFloat,
                 cx: CGFloat, cy: CGFloat, lY: CGFloat, rY: CGFloat) {
    // Windward: long, gentle, faintly convex rise from the left edge to the crest.
    p.addCurve(to: CGPoint(x: cx, y: cy),
               control1: CGPoint(x: minX + (cx - minX) * 0.46, y: lY - (lY - cy) * 0.06),
               control2: CGPoint(x: cx - (cx - minX) * 0.22, y: cy + (lY - cy) * 0.16))
    // Leeward: shorter, smooth settle down to the right edge (never a cliff).
    p.addCurve(to: CGPoint(x: maxX + 6, y: rY),
               control1: CGPoint(x: cx + (maxX - cx) * 0.24, y: cy + (rY - cy) * 0.55),
               control2: CGPoint(x: cx + (maxX - cx) * 0.66, y: rY - (rY - cy) * 0.10))
}

/// A single broad dune, filled to the base (surface-shaded by the caller's
/// gradient so it reads as a 3-D sand slope, never a flat cut-out silhouette).
struct DuneBand: Shape {
    /// Crest x (fraction) and crest height (fraction of rect). `leftFrac` /
    /// `rightFrac` set the ridge height at each far edge (× crestH), so the ridge
    /// enters and leaves the frame partway up — never at the base (no hard humps).
    var crestX: CGFloat
    var crestH: CGFloat
    var leftFrac: CGFloat = 0.28
    var rightFrac: CGFloat = 0.46
    var parallax: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, base = rect.maxY
        let cx = rect.minX + crestX * w + parallax
        let cy = base - crestH * h
        let lY = base - crestH * h * leftFrac
        let rY = base - crestH * h * rightFrac
        var p = Path()
        p.move(to: CGPoint(x: rect.minX - 6, y: base))
        p.addLine(to: CGPoint(x: rect.minX - 6, y: lY))
        fgDuneRidge(&p, minX: rect.minX, maxX: rect.maxX, cx: cx, cy: cy, lY: lY, rY: rY)
        p.addLine(to: CGPoint(x: rect.maxX + 6, y: base))
        p.closeSubpath()
        return p
    }
}

/// The bright moonlit crest LINE — the SAME ridge as `DuneBand` but left open,
/// so it can be stroked as the crisp silver edge that catches the moon.
struct DuneCrestLine: Shape {
    var crestX: CGFloat
    var crestH: CGFloat
    var leftFrac: CGFloat = 0.28
    var rightFrac: CGFloat = 0.46
    var parallax: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, base = rect.maxY
        let cx = rect.minX + crestX * w + parallax
        let cy = base - crestH * h
        let lY = base - crestH * h * leftFrac
        let rY = base - crestH * h * rightFrac
        var p = Path()
        p.move(to: CGPoint(x: rect.minX - 6, y: lY))
        fgDuneRidge(&p, minX: rect.minX, maxX: rect.maxX, cx: cx, cy: cy, lY: lY, rY: rY)
        return p
    }
}

// MARK: Desert camp — a tiny, distant Bedouin camp on a far dune ridge

/// One or two low, wide tents with a softly peaked ridge — never a sharp
/// cartoon triangle. Authored to read as a distant camp at very small size.
struct TentCamp: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, base = rect.maxY
        var p = Path()
        // Main tent: wide skirt, a gentle peaked ridge left of centre.
        p.move(to: CGPoint(x: rect.minX, y: base))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.40, y: rect.minY + h * 0.08),
                       control: CGPoint(x: rect.minX + w * 0.20, y: rect.minY + h * 0.46))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.60, y: base),
                       control: CGPoint(x: rect.minX + w * 0.52, y: rect.minY + h * 0.40))
        p.closeSubpath()
        // A smaller second tent to the right.
        p.move(to: CGPoint(x: rect.minX + w * 0.56, y: base))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.80, y: rect.minY + h * 0.34),
                       control: CGPoint(x: rect.minX + w * 0.70, y: rect.minY + h * 0.60))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: base),
                       control: CGPoint(x: rect.minX + w * 0.90, y: rect.minY + h * 0.52))
        p.closeSubpath()
        return p
    }
}

/// A minimal camel silhouette (two humps, neck, head) — faint and secondary.
struct CamelSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, base = rect.maxY
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: base))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.08, y: rect.minY + h * 0.5))
        // Two humps.
        p.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.48, y: rect.minY + h * 0.5),
                       control: CGPoint(x: rect.minX + w * 0.28, y: rect.minY - h * 0.12))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.74, y: rect.minY + h * 0.42),
                       control: CGPoint(x: rect.minX + w * 0.60, y: rect.minY - h * 0.02))
        // Neck up-right, small head, back down to the leg line.
        p.addLine(to: CGPoint(x: rect.minX + w * 0.86, y: rect.minY + h * 0.06))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.12))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.90, y: rect.minY + h * 0.34))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.94, y: base))
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
                // A couple of lean palm silhouettes rising off the crown. These
                // are CLOSED filled shapes (a thin trunk sliver + small frond
                // wedges) — the plane is filled, so open line-work would be
                // invisible.
                for k in [-0.18, 0.12] {
                    let px = cx + CGFloat(k) * half
                    let trunkTop = topY - isle.h * h * 0.9
                    let lean = CGFloat(k) * half * 0.5
                    let tw = max(0.6, half * 0.03)                 // trunk half-width
                    let ctrlY = (topY + trunkTop) / 2
                    // Trunk as a thin leaning sliver.
                    p.move(to: CGPoint(x: px - tw, y: topY))
                    p.addQuadCurve(to: CGPoint(x: px + lean - tw, y: trunkTop),
                                   control: CGPoint(x: px + lean * 0.3 - tw, y: ctrlY))
                    p.addLine(to: CGPoint(x: px + lean + tw, y: trunkTop))
                    p.addQuadCurve(to: CGPoint(x: px + tw, y: topY),
                                   control: CGPoint(x: px + lean * 0.3 + tw, y: ctrlY))
                    p.closeSubpath()
                    // Fronds as small filled wedges fanning from the crown.
                    // Explicit off-vertical angles (never exactly 0.5, which would
                    // make cos = 0 → a collinear, zero-area wedge) give a reliable
                    // symmetric fan.
                    let hubX = px + lean, hubY = trunkTop
                    let perp = max(0.6, half * 0.02)
                    for a in [-0.85, -0.5, -0.18, 0.18, 0.5, 0.85] {
                        let fx = hubX + CGFloat(cos(Double.pi * (0.5 + a))) * half * 0.24
                        let fy = hubY - CGFloat(abs(sin(Double.pi * (0.5 + a)))) * isle.h * h * 0.2
                        p.move(to: CGPoint(x: hubX, y: hubY - perp))
                        p.addLine(to: CGPoint(x: fx, y: fy))
                        p.addLine(to: CGPoint(x: hubX, y: hubY + perp))
                        p.closeSubpath()
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
