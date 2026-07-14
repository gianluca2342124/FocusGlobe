import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A seamless, slowly-rising tiled background for a page or popup.
///
/// The named tile is repeated to fill the whole window (with an extra row/column
/// drawn outside the visible bounds) and scrolled continuously **upward** by a
/// wrapped offset, so there is never a seam, gap or jump. A page-specific dark
/// scrim sits above it for text legibility. Reduce Motion renders it static.
///
/// If the tile asset isn't in the bundle yet it falls back to `AppBackground()`,
/// so every page keeps its current look until the art is uploaded — then the
/// animated pattern appears automatically. Not used on onboarding.
struct AnimatedTileBackground: View {
    let assetName: String
    /// Upward speed in points per second (a calm ~20–35 s visual loop).
    var speed: CGFloat = 22
    /// Tile size multiplier (1 = the asset's native size).
    var scale: CGFloat = 1.0
    /// Strength of the readability scrim above the pattern (0…1).
    var overlayOpacity: Double = 0.55

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            #if canImport(UIKit)
            if let ui = UIImage(named: assetName) {
                TimelineView(.animation(minimumInterval: reduceMotion ? 8 : 1.0 / 30.0)) { ctx in
                    let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
                    tiled(ui: ui, t: t)
                }
                LinearGradient(colors: [.black.opacity(overlayOpacity * 0.42), .black.opacity(overlayOpacity)],
                               startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false)
            } else {
                AppBackground()
            }
            #else
            AppBackground()
            #endif
        }
        .ignoresSafeArea()
    }

    #if canImport(UIKit)
    private func tiled(ui: UIImage, t: Double) -> some View {
        Canvas { c, size in
            let tw = max(1, ui.size.width * scale)
            let th = max(1, ui.size.height * scale)
            let img = Image(uiImage: ui)
            // Wrapped upward offset kept inside [-th, 0] so the seam always sits
            // one full tile above the visible top edge.
            var yShift = (-CGFloat(t) * speed).truncatingRemainder(dividingBy: th)
            if yShift > 0 { yShift -= th }
            let cols = Int((size.width / tw).rounded(.up)) + 1
            let rows = Int((size.height / th).rounded(.up)) + 2
            var r = -1
            while r < rows {
                var col = 0
                while col < cols {
                    let x = CGFloat(col) * tw
                    let y = CGFloat(r) * th + yShift
                    c.draw(img, in: CGRect(x: x, y: y, width: tw, height: th))
                    col += 1
                }
                r += 1
            }
        }
        .allowsHitTesting(false)
    }
    #endif
}

/// The branded in-app loading state — a full-bleed portrait/landscape image shown
/// only while the app is genuinely initialising, then crossfaded away. No text,
/// spinner or controls. Falls back to the app background + hero balloon until the
/// `LoadingScreen_*` art is uploaded.
struct LoadingView: View {
    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            let name = landscape ? "LoadingScreen_Landscape" : "LoadingScreen_Portrait"
            ZStack {
                #if canImport(UIKit)
                if let ui = UIImage(named: name) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    brandedFallback
                }
                #else
                brandedFallback
                #endif
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }

    private var brandedFallback: some View {
        ZStack {
            AppBackground()
            FlightBalloonView(size: 120, showGlow: true)
        }
    }
}
