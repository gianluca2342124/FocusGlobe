import SwiftUI

/// A soft "glass" surface: system blur material + a subtle adaptive tint + a
/// hairline stroke + a gentle shadow. Shared by cards, islands and pills so
/// every floating surface in the app feels like the same material.
struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = AppSpacing.cardRadius
    var tint: Color = AppColors.glassTint
    var tintOpacity: Double = 0.35
    var material: Material = .ultraThinMaterial
    var strokeOpacity: Double = 1.0
    var shadowRadius: CGFloat = 18
    var shadowY: CGFloat = 10

    func body(content: Content) -> some View {
        content.background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(material)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint.opacity(tintOpacity))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(AppColors.glassStroke.opacity(strokeOpacity), lineWidth: 1)
                }
                .shadow(color: AppColors.shadow, radius: shadowRadius, x: 0, y: shadowY)
        }
    }
}

extension View {
    func glassBackground(cornerRadius: CGFloat = AppSpacing.cardRadius,
                         tint: Color = AppColors.glassTint,
                         tintOpacity: Double = 0.35,
                         material: Material = .ultraThinMaterial,
                         strokeOpacity: Double = 1.0,
                         shadowRadius: CGFloat = 18,
                         shadowY: CGFloat = 10) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius, tint: tint,
                                 tintOpacity: tintOpacity, material: material,
                                 strokeOpacity: strokeOpacity,
                                 shadowRadius: shadowRadius, shadowY: shadowY))
    }
}
