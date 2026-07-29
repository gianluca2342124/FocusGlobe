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

/// One motionless face of a Sky, for surfaces that show SEVERAL Skies at once
/// (the paywall conveyor, the onboarding PRO showcase, gallery tiles).
///
/// A finished Sky's authored artwork already contains its sky, terrain, moon and
/// planets, so a still preview only needs to draw that bitmap. Routing these
/// surfaces through `SkyFlightSceneView` instead meant five simultaneous scene
/// graphs — gradient field, grade, atmosphere, effects and weather, each a
/// `Canvas` — rebuilt on every conveyor frame, because the view carries a
/// non-`Equatable` `elapsed` closure and can never compare equal to the previous
/// frame. That is stutter bought for no visible difference: at `.still` those
/// layers are already frozen and, over artwork, nearly transparent.
///
/// A Sky whose art is missing still falls back to the full still scene, so a
/// future or not-yet-shipped asset can never render as an empty card.
struct SkyStillPreview: View {
    let sky: FocusSky
    /// Match the card's own aspect: conveyor cards are portrait.
    var landscape: Bool = false

    var body: some View {
        if let image = SkyArtworkResolver.image(for: sky, landscape: landscape) {
            SkyArtworkFoundation(image: image)
        } else {
            SkyFlightSceneView(
                sky: sky,
                elapsed: { 24 },
                animated: false,
                seed: 0x50524F,
                presentationMode: .paywall,
                renderQuality: .still
            )
        }
    }
}
