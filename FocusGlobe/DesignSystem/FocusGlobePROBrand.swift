import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - PRO brand colour system (2026 multicolor rebrand)

/// The ONE source of truth for the FocusGlobe PRO identity — the multicolor
/// spectrum, its gradients, glow and the deep-navy ground. Never hard-code the
/// gradient in a screen; reference these tokens. Gold is intentionally absent:
/// it now belongs to Focus Coins / coin rewards ONLY.
enum ProBrand {
    /// The seven authored spectrum stops, left → right.
    static let c1 = Color(hex: 0x18E67E)   // green
    static let c2 = Color(hex: 0x26D9C7)   // teal
    static let c3 = Color(hex: 0x2DB7F5)   // sky
    static let c4 = Color(hex: 0x4D6DFF)   // blue
    static let c5 = Color(hex: 0x8B5CF6)   // violet
    static let c6 = Color(hex: 0xD94DFF)   // magenta
    static let c7 = Color(hex: 0xFF4FA3)   // pink
    static let stops: [Color] = [c1, c2, c3, c4, c5, c6, c7]

    /// Supporting neutrals.
    static let deepNavy  = Color(hex: 0x07122F)
    static let softNavy  = Color(hex: 0x101D46)
    static let softWhite = Color(hex: 0xF7F8FF)

    /// The full multicolor spectrum (badge fallback, primary CTA, major outlines).
    static let gradient = LinearGradient(colors: stops, startPoint: .leading, endPoint: .trailing)
    /// A calmer blue → violet → magenta subset for secondary accents.
    static let softGradient = LinearGradient(colors: [c3, c4, c5, c6],
                                             startPoint: .leading, endPoint: .trailing)
    /// The restrained outline gradient for locked PRO controls.
    static let borderGradient = LinearGradient(colors: [c2, c4, c6],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
    /// A soft glow colour for shadows behind PRO elements.
    static let glow = c5
    /// A low-opacity vertical wash for the comparison-table PRO column (kept light
    /// enough that the checkmarks over it stay perfectly readable).
    static let columnWash = LinearGradient(
        colors: [c3.opacity(0.24), c4.opacity(0.20), c5.opacity(0.20), c6.opacity(0.24)],
        startPoint: .top, endPoint: .bottom)
}

// MARK: - The corrected PRO badge asset wrapper

/// Renders the real `FocusGlobePROBadge` asset at a chosen VISIBLE plaque height,
/// compensating for the wide transparent margins baked into the PNG canvas so the
/// coloured plaque reads large (never tiny) and can sit tight against a neighbour.
///
/// ALL padding correction lives here (three tunable constants) — no screen ever
/// re-applies offsets. If the asset can't be found, a native multicolor PRO pill
/// is drawn instead, so nothing ever shows the broken-image placeholder.
struct FocusGlobePROBadge: View {
    /// Target height of the VISIBLE coloured plaque (NOT the transparent canvas).
    var visibleHeight: CGFloat = 22

    // --- Asset padding calibration (MEASURED from the real asset alpha) --------
    // FocusGlobePROBadge.PNG is 1536×1024; the visible plaque occupies only
    // x[218…1280] y[336…654] → ~31 % of the canvas height and ~69 % of its width,
    // i.e. huge transparent margins. We render the canvas large enough that the
    // visible plaque equals `visibleHeight`, then pull ALL four transparent
    // margins back with negative padding so the layout box hugs the visible
    // plaque (no tiny badge, no dead space). The white outline + glow bleed into
    // the margin and are never clipped (negative padding doesn't clip).
    /// visible plaque height ÷ canvas height.
    private static let plaqueHeightFraction: CGFloat = 0.312
    /// canvas width ÷ height.
    private static let canvasAspect: CGFloat = 1.5
    /// transparent side margin ÷ canvas width (slightly under the true 0.154 so
    /// the wordmark never overlaps the plaque's outline).
    private static let sideMarginFraction: CGFloat = 0.14
    /// transparent top/bottom margin ÷ canvas height (under the true ~0.344).
    private static let vMarginFraction: CGFloat = 0.335

    private var frameH: CGFloat { visibleHeight / Self.plaqueHeightFraction }
    private var sideTrim: CGFloat { frameH * Self.canvasAspect * Self.sideMarginFraction }
    private var vTrim: CGFloat { frameH * Self.vMarginFraction }

    var body: some View {
        Group {
            #if canImport(UIKit)
            if let ui = UIImage(named: "FocusGlobePROBadge") {
                // Inflate the render so the visible plaque ≈ `visibleHeight`, then
                // trim every transparent margin so the layout box hugs the plaque.
                // The outline + glow bleed into the margin — NEVER clipped/tinted.
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
                    .frame(height: frameH)
                    .padding(.horizontal, -sideTrim)
                    .padding(.vertical, -vTrim)
            } else {
                fallback
            }
            #else
            fallback
            #endif
        }
        .accessibilityLabel("PRO")
    }

    /// Native multicolor PRO plaque — shown only if the asset is missing, so the
    /// UI never breaks (the real asset always wins on device).
    private var fallback: some View {
        Text("PRO")
            .font(.system(size: visibleHeight * 0.54, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, visibleHeight * 0.44)
            .frame(height: visibleHeight)
            .background(Capsule().fill(ProBrand.gradient))
            .overlay(Capsule().strokeBorder(.white, lineWidth: max(1.2, visibleHeight * 0.07)))
            .shadow(color: ProBrand.glow.opacity(0.5), radius: visibleHeight * 0.26, y: 1)
            .fixedSize()
    }
}

// MARK: - The reusable FocusGlobe PRO lockup

/// The reusable FocusGlobe PRO identity: a native **FocusGlobe** wordmark with
/// the real PRO badge tight to its right. Clean bold system type (never rounded),
/// white on dark / deep-navy on light; the badge is never tinted or cropped.
///
///   [ FocusGlobe ] [PRO]
///
/// Use `hero`/`standard` in paywalls and major headers; use the badge alone
/// (`FocusGlobePROBadge`) in small controls.
struct FocusGlobePROBrand: View {
    enum Size { case compact, standard, hero }
    var size: Size = .standard
    /// Draw "FocusGlobe" in deep navy for light backgrounds (white otherwise).
    var onLight: Bool = false

    private var wordSize: CGFloat {
        switch size { case .compact: return 17; case .standard: return 25; case .hero: return 34 }
    }
    private var badgeHeight: CGFloat {
        switch size { case .compact: return 15; case .standard: return 23; case .hero: return 32 }
    }
    private var gap: CGFloat {
        switch size { case .compact: return 6; case .standard: return 9; case .hero: return 12 }
    }

    var body: some View {
        HStack(alignment: .center, spacing: gap) {
            Text("FocusGlobe")
                .font(.system(size: wordSize, weight: .bold))
                .foregroundStyle(onLight ? ProBrand.deepNavy : Color.white)
                .fixedSize()
            FocusGlobePROBadge(visibleHeight: badgeHeight)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("FocusGlobe PRO")
    }
}
