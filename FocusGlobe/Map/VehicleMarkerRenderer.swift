import SwiftUI
import UIKit

/// Renders map marker images.
///
/// The moving vehicle on the live map is the **official balloon asset**
/// (`BalloonFront`) so the protagonist is identical everywhere. Only if the
/// asset is genuinely missing do we fall back to the crafted vector balloon.
///
/// These methods are deliberately **nonisolated** so the Google Maps coordinator
/// can call them synchronously from `updateUIView`. Asset lookup and
/// `UIGraphicsImageRenderer` resizing are thread-safe; the rare vector fallback
/// uses main-actor-only APIs (`ImageRenderer` / `UIScreen`), so that branch hops
/// onto the main actor via `MainActor.assumeIsolated` — the coordinator always
/// runs on the main thread, so this is safe.
enum VehicleMarkerRenderer {

    /// The balloon marker, sized for the map. Uses the official (trimmed) PNG
    /// when present — trimmed so the full balloon fills the marker rather than
    /// appearing tiny inside the asset's transparent padding.
    static func balloonImage(targetHeight: CGFloat = 110, glow: Color) -> UIImage? {
        if let balloon = BrandBalloon.image {
            return resized(balloon, targetHeight: targetHeight)
        }
        // Fallback: the crafted vector (only when the asset is unavailable).
        // ImageRenderer / UIScreen are main-actor-isolated.
        return MainActor.assumeIsolated {
            let padded = BalloonMark(size: targetHeight * 0.62, glow: glow, showGlow: true,
                                     showBurner: true, burnerAnimated: false)
                .padding(targetHeight * 0.4)
            let renderer = ImageRenderer(content: padded)
            renderer.scale = UIScreen.main.scale
            renderer.isOpaque = false
            return renderer.uiImage
        }
    }

    private static func resized(_ image: UIImage, targetHeight: CGFloat) -> UIImage {
        guard image.size.height > 0 else { return image }
        let scale = targetHeight / image.size.height
        let size = CGSize(width: image.size.width * scale, height: targetHeight)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
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
