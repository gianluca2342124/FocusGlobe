import SwiftUI

/// A small, calm entry point to the Premium modal. Used in screen corners (Home,
/// Choose Journey, Passport). It keeps the shared adaptive glass disc but now
/// wears the real multicolor **PRO** badge instead of a gold crown — present but
/// never loud.
struct CrownButton: View {
    var size: CGFloat = 44
    /// `true` on Home, where the whole control family shares the adaptive
    /// `homeControl` surface (warm-white by day, translucent glass by night);
    /// elsewhere it keeps its neutral glass.
    var onWhite: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            FocusGlobePROBadge(visibleHeight: size * 0.34)
                .frame(width: size, height: size)
                .background {
                    if onWhite {
                        Circle().fill(AppColors.homeControlFill)
                            .overlay(Circle().strokeBorder(AppColors.homeControlStroke, lineWidth: 1))
                            .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
                    } else {
                        Circle().fill(.regularMaterial)
                            .overlay(Circle().strokeBorder(ProBrand.borderGradient, lineWidth: 1))
                            .shadow(color: ProBrand.glow.opacity(0.28), radius: 10, y: 5)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel("FocusGlobe PRO")
    }
}

/// A compact "PRO" badge for premium-gated cards and skins — now the real
/// multicolor PRO plaque asset (compact size), never a gold crown capsule.
struct PremiumBadge: View {
    var compact: Bool = false

    var body: some View {
        FocusGlobePROBadge(visibleHeight: compact ? 15 : 19)
    }
}
