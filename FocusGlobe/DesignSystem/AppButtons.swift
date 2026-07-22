import SwiftUI

/// A gentle press effect shared by all buttons — a soft scale + slight dim.
struct SoftPressStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// The large, calm primary call-to-action.
struct AppPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isEnabled: Bool = true
    var isLoading: Bool = false
    /// Render the symbol AFTER the title. The app rule: directional arrows
    /// always trail their text ("Continue →", never "→ Continue").
    var iconTrailing: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    if let systemImage, !iconTrailing {
                        Image(systemName: systemImage)
                            .font(.system(size: Layout.pad(17, 20), weight: .semibold))
                    }
                    // Scales up on iPad/Mac; identical to AppTypography.headline on iPhone.
                    Text(title)
                        .font(.system(size: Layout.pad(18, 21), weight: .semibold, design: .default))
                    if let systemImage, iconTrailing {
                        Image(systemName: systemImage)
                            .font(.system(size: Layout.pad(17, 20), weight: .semibold))
                    }
                }
            }
            .foregroundStyle(AppColors.ctaText)
            .frame(maxWidth: .infinity)
            .frame(height: Layout.pad(56, 64))
            // Primary CTAs use a FULLY ROUNDED capsule — the app's signature
            // major-action geometry (Start Focus, Continue, Join Flight…).
            .background {
                Capsule(style: .continuous)
                    .fill(AppColors.ctaFill)
                    // Subtle adaptive edge so the white pill separates cleanly from
                    // light surfaces in Light Mode; invisible over dark surfaces and
                    // in Dark Mode (so Dark Mode is unchanged).
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(AppColors.hairline, lineWidth: 1)
                    )
            }
            .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 10)
            .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(SoftPressStyle())
        .disabled(!isEnabled || isLoading)
    }
}

/// A quieter, glass secondary action.
struct AppSecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: Layout.pad(16, 18), weight: .semibold))
                }
                Text(title)
                    .font(.system(size: Layout.pad(15, 17), weight: .medium, design: .default))
            }
            .foregroundStyle(AppColors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: Layout.pad(52, 60))
            .glassBackground(cornerRadius: 18, tintOpacity: 0.25, shadowRadius: 10, shadowY: 5)
        }
        .buttonStyle(SoftPressStyle())
    }
}

/// A non-interactive glass circle matching `AppIconButton` — used as a label
/// for `Menu`s (e.g. the map-style picker).
struct GlassCircle: View {
    let systemImage: String
    var size: CGFloat = 46
    var tint: Color = AppColors.textPrimary

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background {
                Circle().fill(.regularMaterial)
                    .overlay(Circle().fill(AppColors.islandTint.opacity(0.28)))
                    .overlay(Circle().strokeBorder(AppColors.glassStroke, lineWidth: 1))
                    .shadow(color: AppColors.shadow, radius: 12, y: 6)
            }
    }
}

/// A circular glass icon button — used for map and navigation controls.
struct AppIconButton: View {
    let systemImage: String
    var size: CGFloat = 46
    var prominent: Bool = false
    var tint: Color = AppColors.textPrimary
    var accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(prominent ? AppColors.ctaText : tint)
                .frame(width: size, height: size)
                .background {
                    if prominent {
                        Circle().fill(AppColors.ctaFill)
                            .shadow(color: Color.black.opacity(0.28), radius: 12, y: 6)
                    } else {
                        Circle().fill(.regularMaterial)
                            .overlay(Circle().fill(AppColors.islandTint.opacity(0.28)))
                            .overlay(Circle().strokeBorder(AppColors.glassStroke, lineWidth: 1))
                            .shadow(color: AppColors.shadow, radius: 12, y: 6)
                    }
                }
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}
