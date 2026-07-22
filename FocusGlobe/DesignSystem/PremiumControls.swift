import SwiftUI

/// A small, calm crown entry point to the Premium modal. Used in screen corners
/// (Home, Choose Journey, Passport). Glass circle + gold crown — present but
/// never loud.
struct CrownButton: View {
    var size: CGFloat = 44
    /// `true` on Home, where the whole control family shares the adaptive
    /// `homeControl` surface (warm-white by day, translucent glass by night)
    /// with a gold crown; elsewhere it keeps its neutral glass.
    var onWhite: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "crown.fill")
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(AppColors.gold)
                .frame(width: size, height: size)
                .background {
                    if onWhite {
                        Circle().fill(AppColors.homeControlFill)
                            .overlay(Circle().strokeBorder(AppColors.gold.opacity(0.4), lineWidth: 1))
                            .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
                    } else {
                        Circle().fill(.regularMaterial)
                            .overlay(Circle().fill(AppColors.gold.opacity(0.14)))
                            .overlay(Circle().strokeBorder(AppColors.gold.opacity(0.45), lineWidth: 1))
                            .shadow(color: AppColors.shadow, radius: 10, y: 5)
                    }
                }
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel("FocusGlobe PRO")
    }
}

/// A compact "PRO" badge for premium-gated cards and skins (gold capsule).
struct PremiumBadge: View {
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "crown.fill")
                .font(.system(size: compact ? 8 : 9, weight: .bold))
            if !compact {
                Text("PRO")
                    .font(.system(size: 10, weight: .heavy, design: .default))
            }
        }
        .foregroundStyle(Color(hex: 0x2B2620))
        .padding(.horizontal, compact ? 5 : 7)
        .padding(.vertical, 4)
        .background(Capsule().fill(AppColors.gold))
        .shadow(color: AppColors.gold.opacity(0.35), radius: 5, y: 2)
    }
}
