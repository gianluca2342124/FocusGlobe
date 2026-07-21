import SwiftUI
import UIKit

// MARK: - Brand assets

/// Resolves bundled brand art (see SKINS_SETUP.md):
///   • `BalloonSkin_Default` imageset → the default front-view balloon render
///     (also the universal fallback for any missing skin / hero asset).
///   • `BrandLogo` → optional wordmark override.
enum BrandAssets {
    /// The default balloon image set — the universal fallback when a specific
    /// skin (or the paywall hero) asset is missing. (The legacy `BalloonFront`
    /// asset is no longer required.)
    static let defaultBalloonName = "BalloonSkin_Default"
    static let brandLogoName = "BrandLogo"

    static var hasBrandLogo: Bool { UIImage(named: brandLogoName) != nil }
}

/// The single source of truth for the default balloon image.
///
/// The default balloon render typically has large transparent margins, so used
/// raw it appears tiny (a "dot") at marker size. We trim it to its opaque bounds
/// **once** (cached) so every consumer — SwiftUI hero views and the Google Maps
/// marker — shows the full, properly-sized balloon.
enum BrandBalloon {
    /// The default balloon (`BalloonSkin_Default`), cropped to its opaque
    /// content. `nil` only if the asset is genuinely missing (then callers use
    /// the vector fallback). Does **not** depend on the legacy `BalloonFront`.
    static let image: UIImage? = {
        guard let raw = UIImage(named: BrandAssets.defaultBalloonName) else { return nil }
        return raw.trimmingTransparentPixels() ?? raw
    }()

    static var isAvailable: Bool { image != nil }
}

/// Resolves (and caches) per-skin balloon artwork.
///
/// For a given skin `assetName` it loads `UIImage(named:)`, trims the
/// transparent margins **once** (so the balloon fills its frame/marker like the
/// brand art does), and caches the result. Fallback order, so the app never
/// crashes on a missing asset:
///   1. the requested `assetName`
///   2. `BalloonSkin_Default` (via `BrandBalloon.image`)
///   3. `nil` → callers draw the vector `BalloonMark`
///
/// The cache is guarded by a lock because `VehicleMarkerRenderer` is
/// `nonisolated` and may resolve marker art outside the main actor.
enum BalloonSkinImage {
    private static let lock = NSLock()
    private static var cache: [String: UIImage] = [:]

    /// The trimmed image for a skin asset, or `BalloonSkin_Default` when missing.
    /// `nil` only if neither the skin asset nor `BalloonSkin_Default` exists.
    static func image(named assetName: String) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[assetName] { return cached }
        let resolved: UIImage?
        if let raw = UIImage(named: assetName) {
            resolved = raw.trimmingTransparentPixels() ?? raw
        } else {
            resolved = BrandBalloon.image   // graceful fallback → BalloonSkin_Default
        }
        if let resolved { cache[assetName] = resolved }
        return resolved
    }

    /// Warm the trim cache off the main thread at launch, so the Store's first
    /// frame never pays the decode + alpha-trim cost for every skin inside the
    /// tab tap's transaction. Safe: the cache is lock-guarded and
    /// `UIImage(named:)` is thread-safe.
    static func warmUp() {
        Task.detached(priority: .utility) {
            _ = BrandBalloon.image
            for skin in BalloonSkin.all { _ = image(named: skin.assetName) }
        }
    }
}

extension UIImage {
    /// Returns a copy cropped to the bounding box of non-transparent pixels.
    func trimmingTransparentPixels(alphaThreshold: UInt8 = 12) -> UIImage? {
        guard let cg = cgImage else { return nil }
        let w = cg.width, h = cg.height
        guard w > 0, h > 0 else { return nil }

        let bytesPerRow = w * 4
        var data = [UInt8](repeating: 0, count: bytesPerRow * h)
        guard let ctx = CGContext(
            data: &data, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            let row = y * bytesPerRow
            for x in 0..<w where data[row + x * 4 + 3] > alphaThreshold {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        let rect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        guard let cropped = cg.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
    }
}

// MARK: - Burner glow (premium micro-detail)

/// A tiny, elegant "burner active" glow that sits under the balloon's mouth.
/// Soft, warm and gently pulsing — it makes the balloon feel quietly *on*.
/// No cartoon flame, smoke or sparks. Reusable across balloon skins.
struct BurnerGlow: View {
    var diameter: CGFloat
    var animated: Bool = true
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0xFFC861).opacity(0.85),
                                 Color(hex: 0xFF8A2A).opacity(0.45),
                                 .clear],
                        center: .center, startRadius: 0, endRadius: diameter * 0.5
                    )
                )
                .blur(radius: diameter * 0.10)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0xFFE9B8).opacity(0.95), .clear],
                        center: .center, startRadius: 0, endRadius: diameter * 0.26
                    )
                )
                .frame(width: diameter * 0.5, height: diameter * 0.5)
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(pulse ? 1.07 : 0.9)
        .opacity(pulse ? 1.0 : 0.78)
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Envelope shape

/// The balloon envelope — a full, rounded teardrop that tapers to a small flat
/// mouth (not a sharp point), matching the front-view brand balloon.
struct BalloonEnvelope: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let cx = rect.midX
        let mouth = w * 0.13 // half-width of the bottom opening

        p.move(to: CGPoint(x: cx - mouth, y: rect.maxY))
        p.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + h * 0.44),
            control1: CGPoint(x: cx - mouth - w * 0.06, y: rect.maxY - h * 0.05),
            control2: CGPoint(x: rect.minX, y: rect.minY + h * 0.80)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.minY + h * 0.12),
            control2: CGPoint(x: cx - w * 0.36, y: rect.minY)
        )
        p.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.44),
            control1: CGPoint(x: cx + w * 0.36, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.minY + h * 0.12)
        )
        p.addCurve(
            to: CGPoint(x: cx + mouth, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.minY + h * 0.80),
            control2: CGPoint(x: cx + mouth + w * 0.06, y: rect.maxY - h * 0.05)
        )
        p.closeSubpath()
        return p
    }
}

/// Subtle vertical panel seams (gores) that read as premium fabric, not noise.
private struct BalloonSeams: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let cx = rect.midX
        let top = rect.minY + h * 0.04
        let bottom = rect.maxY - h * 0.02
        for frac in [-0.62, -0.32, 0.0, 0.32, 0.62] {
            let topX = cx + CGFloat(frac) * w * 0.16
            let midX = cx + CGFloat(frac) * w * 0.5
            p.move(to: CGPoint(x: topX, y: top))
            p.addQuadCurve(to: CGPoint(x: cx + CGFloat(frac) * w * 0.13, y: bottom),
                           control: CGPoint(x: midX, y: rect.minY + h * 0.5))
        }
        return p
    }
}

private struct BalloonCords: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.30, y: r.maxY))
        p.move(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.70, y: r.maxY))
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.42, y: r.maxY))
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.58, y: r.maxY))
        return p
    }
}

// MARK: - Vector balloon

/// The default FocusGlobe vehicle, drawn entirely in code: a premium, minimal,
/// soft-white paneled balloon with a small skirt, ropes, a tan basket and an
/// optional warm burner glow. Original art that scales crisply and themes via
/// `glow`. Used as-is in the UI and rasterised for the map marker.
///
/// `size` is the envelope **width**; the full mark (incl. basket) is taller.
struct BalloonMark: View {
    var size: CGFloat = 64
    var glow: Color = .white
    var showGlow: Bool = false
    /// Shows the warm burner glow at the mouth.
    var showBurner: Bool = false
    /// Animate the burner (off when rasterised for a static map marker).
    var burnerAnimated: Bool = true

    private var envW: CGFloat { size }
    private var envH: CGFloat { size * 1.12 }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                envelope
                    .frame(width: envW, height: envH)

                BalloonCords()
                    .stroke(Color(hex: 0x9AA3B5).opacity(0.9),
                            style: StrokeStyle(lineWidth: max(0.8, size * 0.016), lineCap: .round))
                    .frame(width: envW * 0.5, height: size * 0.16)

                basket
            }

            if showBurner {
                BurnerGlow(diameter: size * 0.6, animated: burnerAnimated)
                    .offset(y: envH - size * 0.16)
            }
        }
        .shadow(color: .black.opacity(0.16), radius: size * 0.07, x: 0, y: size * 0.05)
        .background(ambientGlow)
    }

    // The envelope + seams + highlight + skirt.
    private var envelope: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                BalloonEnvelope()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0xFFFFFF), Color(hex: 0xF1F3F8), Color(hex: 0xDCE2EC)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                // Soft upper-left highlight.
                Ellipse()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: envW * 0.4, height: envH * 0.3)
                    .offset(x: -envW * 0.14, y: -envH * 0.18)
                    .blur(radius: envW * 0.08)
                // Gentle right-edge shading for volume.
                BalloonEnvelope()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color(hex: 0xC4CCDA).opacity(0.35)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                // Subtle panel seams.
                BalloonSeams()
                    .stroke(Color(hex: 0xB7C0D0).opacity(0.5), lineWidth: max(0.4, size * 0.006))
            }
            .compositingGroup()
            .clipShape(BalloonEnvelope())
            .overlay(
                BalloonEnvelope()
                    .stroke(Color.black.opacity(0.05), lineWidth: max(0.5, size * 0.006))
            )

            // Skirt / mouth band.
            RoundedRectangle(cornerRadius: size * 0.03, style: .continuous)
                .fill(
                    LinearGradient(colors: [Color(hex: 0xEDEFF4), Color(hex: 0xD8DDE6)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(width: envW * 0.3, height: size * 0.06)
                .offset(y: size * 0.03)
        }
    }

    private var basket: some View {
        RoundedRectangle(cornerRadius: size * 0.045, style: .continuous)
            .fill(
                LinearGradient(colors: [Color(hex: 0xC79A6A), Color(hex: 0x8A6038)],
                               startPoint: .top, endPoint: .bottom)
            )
            .frame(width: envW * 0.30, height: size * 0.17)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.045, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
            )
    }

    @ViewBuilder private var ambientGlow: some View {
        if showGlow {
            Circle()
                .fill(
                    RadialGradient(colors: [glow.opacity(0.5), glow.opacity(0)],
                                   center: .center, startRadius: 0, endRadius: size * 0.8)
                )
                .frame(width: size * 1.8, height: size * 1.8)
                .blur(radius: size * 0.12)
                .offset(y: -size * 0.12)
        }
    }
}

// MARK: - Brand balloon view (asset-preferring)

/// The balloon for hero moments. Prefers the bundled skin/hero PNG when present
/// (falling back to `BalloonSkin_Default`); otherwise renders the crafted
/// `BalloonMark`. An optional animated burner glow adds life on top of either.
struct BalloonView: View {
    /// Overall visual height of the balloon.
    var height: CGFloat = 160
    var showBurner: Bool = true
    var showGlow: Bool = false
    var glow: Color = Color(hex: 0xFFB23E)
    var burnerAnimated: Bool = true
    /// Which skin artwork to render. Defaults to the standard balloon so every
    /// existing call site is unchanged; pass the user's selected skin to theme it.
    var skin: BalloonSkin = .default
    /// Optional explicit asset name (e.g. the paywall hero `PaywallBalloonHero`).
    /// When set it takes precedence over `skin`, and still falls back through
    /// `BalloonSkin_Default` → vector if missing. Swap the art freely in Xcode.
    var assetName: String? = nil

    var body: some View {
        if let balloon = BalloonSkinImage.image(named: assetName ?? skin.assetName) {
            Image(uiImage: balloon)
                .resizable()
                .scaledToFit()
                .frame(height: height)
                .background(ambientGlow)
        } else {
            BalloonMark(size: height * 0.62, glow: glow, showGlow: showGlow,
                        showBurner: showBurner, burnerAnimated: burnerAnimated)
        }
    }

    @ViewBuilder private var ambientGlow: some View {
        if showGlow {
            Circle()
                .fill(RadialGradient(colors: [glow.opacity(0.35), .clear],
                                     center: .center, startRadius: 0, endRadius: height * 0.7))
                .frame(width: height * 1.4, height: height * 1.4)
                .blur(radius: height * 0.1)
        }
    }
}

#Preview {
    ZStack {
        Color(hex: 0x0A0E1A).ignoresSafeArea()
        HStack(spacing: 50) {
            BalloonMark(size: 96, glow: RouteTheme.aurora.soft, showGlow: true, showBurner: true)
            BalloonView(height: 200, showBurner: true, showGlow: true)
        }
    }
}
