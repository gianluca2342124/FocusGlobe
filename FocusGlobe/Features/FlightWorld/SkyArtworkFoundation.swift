import SwiftUI
import UIKit

/// Centralized artwork resolution shared by Home, ritual, locked previews,
/// Online lobby/join, active flight, Cabin View and Landing.
///
/// Orientation-specific hero art wins. The base name and older background /
/// preview fields remain as compatibility fallbacks, so a missing future asset
/// can never turn a Sky blank or disturb existing navigation.
enum SkyArtworkResolver {
    static func image(for sky: FocusSky, landscape: Bool) -> UIImage? {
        let names = [
            sky.orientedArtworkAssetName(landscape: landscape),
            sky.artworkAssetName,
            sky.backgroundAssetName(landscape: landscape),
            sky.previewImageName,
        ]
        for name in names.compactMap({ $0 }) {
            if let image = UIImage(named: name) { return image }
        }
        return nil
    }
}

/// The stable art foundation. Motion stays in the existing lightweight
/// Canvas/gradient layers above it; the bitmap never pans, tiles or exposes an
/// edge during a long session.
struct SkyArtworkFoundation: View {
    let image: UIImage

    var body: some View {
        GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
