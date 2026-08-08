import SwiftUI

/// A compact glass stat tile (value + label + icon). Shared across screens.
struct StatTile: View {
    let systemImage: String
    let value: String
    let label: String
    var accent: Color = AppColors.brand

    var body: some View {
        AppGlassCard(padding: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
                Text(value)
                    .font(AppTypography.title2)
                    .foregroundStyle(AppColors.textPrimary)
                Text(LocalizedStringKey(label))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
