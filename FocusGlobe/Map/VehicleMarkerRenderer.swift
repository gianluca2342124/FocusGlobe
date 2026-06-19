import SwiftUI
import UIKit

/// Renders map marker images. Keeps a single source of truth for the vehicle's
/// look: the same `BalloonMark` used everywhere in the UI is rasterised here
/// for use as a Google Maps marker icon.
///
/// `ImageRenderer` is main-actor-isolated. These helpers are called from the
/// map renderer's `updateUIView`/coordinator, which SwiftUI always invokes on
/// the main thread, so we use `MainActor.assumeIsolated` to call it without an
/// async hop (and without forcing the coordinator to be an actor).
enum VehicleMarkerRenderer {

    /// The balloon, rendered with room around it for the glow and burner.
    /// The burner is baked in statically (the sense of life comes from the
    /// balloon's movement along the route).
    static func balloonImage(envelopeWidth: CGFloat = 46, glow: Color) -> UIImage? {
        MainActor.assumeIsolated {
            let padded = BalloonMark(size: envelopeWidth, glow: glow, showGlow: true,
                                     showBurner: true, burnerAnimated: false)
                .padding(envelopeWidth * 0.6)
            let renderer = ImageRenderer(content: padded)
            renderer.scale = UIScreen.main.scale
            renderer.isOpaque = false
            return renderer.uiImage
        }
    }

    /// A simple origin/destination dot.
    static func dotImage(diameter: CGFloat, fill: UIColor, ring: UIColor, ringWidth: CGFloat) -> UIImage {
        let totalSize = diameter + ringWidth * 2 + 6
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: totalSize, height: totalSize))
        return renderer.image { ctx in
            let c = ctx.cgContext
            let center = CGPoint(x: totalSize / 2, y: totalSize / 2)

            c.setShadow(offset: CGSize(width: 0, height: 1), blur: 4,
                        color: UIColor.black.withAlphaComponent(0.25).cgColor)

            let outerRect = CGRect(x: center.x - diameter / 2 - ringWidth,
                                   y: center.y - diameter / 2 - ringWidth,
                                   width: diameter + ringWidth * 2,
                                   height: diameter + ringWidth * 2)
            c.setFillColor(ring.cgColor)
            c.fillEllipse(in: outerRect)

            c.setShadow(offset: .zero, blur: 0, color: nil)
            let innerRect = CGRect(x: center.x - diameter / 2,
                                   y: center.y - diameter / 2,
                                   width: diameter, height: diameter)
            c.setFillColor(fill.cgColor)
            c.fillEllipse(in: innerRect)
        }
    }
}
