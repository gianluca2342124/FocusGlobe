import SwiftUI
import UIKit

/// One aligned production scene. Every image uses the same full-canvas
/// coordinate system for its orientation: an opaque atmosphere base followed
/// by transparent far, mid and near depth plates.
struct SkyArtworkSet {
    let base: UIImage
    let far: UIImage?
    let mid: UIImage?
    let near: UIImage?

    var hasDepthPlates: Bool { far != nil || mid != nil || near != nil }
}

/// Centralized artwork resolution shared by Home, ritual, locked previews,
/// Online lobby/join, active flight, Cabin View and Landing. No presentation
/// surface owns raw scene-asset strings.
enum SkyArtworkResolver {
    private static func productionPrefix(for sky: FocusSky) -> String {
        "FGSky_\(sky.artworkAssetName.replacingOccurrences(of: "SkyArtwork_", with: ""))"
    }

    private static func productionName(for sky: FocusSky, layer: String,
                                       landscape: Bool) -> String {
        "\(productionPrefix(for: sky))_\(layer)_\(landscape ? "Landscape" : "Portrait")"
    }

    static func scene(for sky: FocusSky, landscape: Bool) -> SkyArtworkSet? {
        let baseNames = [
            productionName(for: sky, layer: "Base", landscape: landscape),
            sky.orientedArtworkAssetName(landscape: landscape),
            sky.artworkAssetName,
            sky.backgroundAssetName(landscape: landscape),
            sky.previewImageName,
        ]
        guard let base = firstImage(named: baseNames) else { return nil }
        return SkyArtworkSet(
            base: base,
            far: UIImage(named: productionName(for: sky, layer: "Far", landscape: landscape)),
            mid: UIImage(named: productionName(for: sky, layer: "Mid", landscape: landscape)),
            near: UIImage(named: productionName(for: sky, layer: "Near", landscape: landscape))
        )
    }

    /// Compatibility helper for surfaces that only need a thumbnail bitmap.
    static func image(for sky: FocusSky, landscape: Bool) -> UIImage? {
        scene(for: sky, landscape: landscape)?.base
    }

    private static func firstImage(named names: [String?]) -> UIImage? {
        for name in names.compactMap({ $0 }) {
            if let image = UIImage(named: name) { return image }
        }
        return nil
    }
}

/// A single full-canvas art plate. A small overscan prevents slow parallax from
/// exposing an edge on any aspect ratio.
struct SkyArtworkFoundation: View {
    let image: UIImage
    var scale: CGFloat = 1
    var offset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(scale)
                .offset(offset)
                .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The shared 2.5D scene compositor. Artwork provides the authored world; only
/// glacial, bounded multi-plane motion is applied here. Far, mid and near stay
/// aligned because they use identical canvases and identical aspect-fill rules.
struct LayeredSkyArtworkFoundation: View {
    let artwork: SkyArtworkSet
    let t: Double
    var motionEnabled: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                SkyArtworkFoundation(image: artwork.base)
                plate(artwork.far, scale: 1.025,
                      x: drift(phase: 0.4, rate: 0.0041, fraction: 0.010) * w,
                      y: drift(phase: 1.7, rate: 0.0032, fraction: 0.004) * h)
                plate(artwork.mid, scale: 1.055,
                      x: drift(phase: 2.1, rate: 0.0050, fraction: 0.022) * w,
                      y: drift(phase: 0.8, rate: 0.0038, fraction: 0.007) * h)
                plate(artwork.near, scale: 1.085,
                      x: drift(phase: 3.4, rate: 0.0060, fraction: 0.040) * w,
                      y: drift(phase: 2.6, rate: 0.0044, fraction: 0.010) * h)
            }
            .frame(width: w, height: h)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func plate(_ image: UIImage?, scale: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        if let image {
            SkyArtworkFoundation(image: image, scale: scale,
                                 offset: CGSize(width: x, height: y))
        }
    }

    private func drift(phase: Double, rate: Double, fraction: CGFloat) -> CGFloat {
        guard motionEnabled else { return 0 }
        return CGFloat(Foundation.sin(t * rate + phase)) * fraction
    }
}
