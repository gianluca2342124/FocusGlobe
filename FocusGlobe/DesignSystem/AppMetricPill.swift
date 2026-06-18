import SwiftUI

/// A small glass pill showing a metric — e.g. remaining time or distance.
struct AppMetricPill: View {
    var systemImage: String? = nil
    let value: String
    var label: String? = nil
    var tint: Color = AppColors.textPrimary
    var monospacedValue: Bool = false

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(monospacedValue ? AppTypography.timerPill : AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)
                if let label {
                    Text(label)
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
        }
        .padding(.horizontal, AppSpacing.sm + 2)
        .padding(.vertical, AppSpacing.xs)
        .glassBackground(cornerRadius: AppSpacing.pillRadius, tintOpacity: 0.25,
                         shadowRadius: 8, shadowY: 4)
    }
}

/// A compact single-value pill for Pure Mode (just the time + an icon).
struct AppTimePill: View {
    let value: String
    var body: some View {
        Text(value)
            .font(AppTypography.timerPill)
            .foregroundStyle(AppColors.textPrimary)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs + 2)
            .glassBackground(cornerRadius: AppSpacing.pillRadius, tintOpacity: 0.25,
                             shadowRadius: 10, shadowY: 5)
            .monospacedDigit()
    }
}
