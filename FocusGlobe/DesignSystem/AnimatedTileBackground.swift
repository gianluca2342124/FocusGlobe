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
    /// Strength of the readability scrim above the pattern (0…1).
    var overlayOpacity: Double = 0.55

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Drives the single compositor-side scroll (see below) — no per-frame CPU.
    @State private var phase = false

    var body: some View {
        ZStack {
            #if canImport(UIKit)
            if let ui = UIImage(named: assetName) {
                // One pre-tiled layer moved by a single repeatForever offset:
                // the render server animates it, so the pattern costs ZERO
                // main-thread work per frame (the old Canvas re-tiled at 30 fps
                // the whole time the page was open — a constant drag on every
                // interaction). Sliding exactly one tile height and repeating
                // from the start is seamless because the pattern repeats with
                // that same period (tiles render at the asset's native size).
                GeometryReader { geo in
                    let th = max(1, ui.size.height)
                    Image(uiImage: ui)
                        .resizable(resizingMode: .tile)
                        .frame(width: geo.size.width, height: geo.size.height + th)
                        .offset(y: phase ? -th : 0)
                        .onAppear {
                            guard !reduceMotion else { return }
                            withAnimation(.linear(duration: Double(th / speed))
                                .repeatForever(autoreverses: false)) { phase = true }
                        }
                }
                .clipped()
                .allowsHitTesting(false)
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
}
