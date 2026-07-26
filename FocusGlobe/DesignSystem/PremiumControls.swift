import SwiftUI

/// A small, calm entry point to the Premium modal. The crown carries the PRO
/// spectrum while its outer control uses the shared liquid-glass substrate.
struct CrownButton: View {
    var size: CGFloat = 44
    /// `true` on Home, where the whole control family shares the adaptive
    /// `homeControl` surface (warm-white by day, translucent glass by night);
    /// elsewhere it keeps its neutral glass.
    var onWhite: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "crown.fill")
                .font(.system(size: size * 0.39, weight: .bold))
                .foregroundStyle(ProBrand.gradient)
                .frame(width: size, height: size)
                .background {
                    FocusLiquidGlassSurface(
                        shape: Circle(),
                        tint: onWhite ? AppColors.homeControlFill : ProBrand.softNavy,
                        tintOpacity: onWhite ? 0.52 : 0.22,
                        active: true
                    )
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
