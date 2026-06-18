import SwiftUI

/// A rounded glass card. The standard container for grouped content.
struct AppGlassCard<Content: View>: View {
    var cornerRadius: CGFloat = AppSpacing.cardRadius
    var padding: CGFloat = AppSpacing.lg
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .glassBackground(cornerRadius: cornerRadius)
    }
}

/// A floating glass "island" — used for controls that hover over the map.
/// Stronger blur and a softer, larger shadow so it reads as elevated.
struct AppFloatingIsland<Content: View>: View {
    var cornerRadius: CGFloat = AppSpacing.islandRadius
    var horizontalPadding: CGFloat = AppSpacing.lg
    var verticalPadding: CGFloat = AppSpacing.sm + 2
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .glassBackground(
                cornerRadius: cornerRadius,
                tint: AppColors.islandTint,
                tintOpacity: 0.30,
                material: .regularMaterial,
                shadowRadius: 26,
                shadowY: 14
            )
    }
}
