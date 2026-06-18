import SwiftUI

/// A collectible postcard / stamp. Used full-width on the Landing screen and as
/// compact tiles in the Globe Passport.
struct PostcardTile: View {
    let postcard: Postcard
    var isNew: Bool = false
    var compact: Bool = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            postcard.mood.gradient

            // A faint "stamp" ring in the corner.
            Circle()
                .strokeBorder(postcard.mood.preferredForeground.opacity(0.35),
                              style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .frame(width: compact ? 30 : 44, height: compact ? 30 : 44)
                .overlay(
                    Image(systemName: postcard.mood.systemImage)
                        .font(.system(size: compact ? 12 : 16, weight: .semibold))
                        .foregroundStyle(postcard.mood.preferredForeground.opacity(0.9))
                )
                .padding(compact ? AppSpacing.xs : AppSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .topTrailing)

            VStack(alignment: .leading, spacing: compact ? 2 : 6) {
                if !compact {
                    Text("Postcard unlocked")
                        .font(AppTypography.micro)
                        .tracking(0.6)
                        .foregroundStyle(postcard.mood.preferredForeground.opacity(0.8))
                }
                Spacer()
                Text(postcard.title)
                    .font(compact ? AppTypography.callout : AppTypography.title2)
                    .foregroundStyle(postcard.mood.preferredForeground)
                    .lineLimit(1)
                Text(postcard.place)
                    .font(AppTypography.caption)
                    .foregroundStyle(postcard.mood.preferredForeground.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(compact ? AppSpacing.sm : AppSpacing.md)

            if isNew {
                Text("NEW")
                    .font(AppTypography.micro)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppColors.success))
                    .padding(AppSpacing.sm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .frame(height: compact ? 116 : 168)
        .clipShape(RoundedRectangle(cornerRadius: compact ? AppSpacing.pillRadius : AppSpacing.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: compact ? AppSpacing.pillRadius : AppSpacing.cardRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: AppColors.shadow, radius: 12, x: 0, y: 6)
    }
}

/// A locked stamp placeholder for routes not yet completed.
struct LockedStampTile: View {
    let route: Route
    var requiresPro: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: requiresPro ? "lock.fill" : route.mood.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColors.textTertiary)
            Text(route.shortName)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)
                .lineLimit(1)
            Text(route.durationLabel)
                .font(AppTypography.micro)
                .foregroundStyle(AppColors.textTertiary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 116)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.pillRadius, style: .continuous)
                .fill(AppColors.hairline)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.pillRadius, style: .continuous)
                .strokeBorder(AppColors.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
    }
}
