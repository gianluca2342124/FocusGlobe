import SwiftUI

/// The standard, visual route card used in Route Selection and elsewhere.
/// Shows a scenic mood banner, route name, origin → destination, duration,
/// distance, mood and reward — plus a premium lock when applicable.
struct AppRouteCard: View {
    let route: Route
    /// `true` when the route is premium and the user isn't Pro.
    var isLocked: Bool = false
    /// Adds a soft brand ring to mark the recommended route.
    var highlighted: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                banner
                info
            }
            .background {
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                            .fill(AppColors.glassTint.opacity(0.4))
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .strokeBorder(highlighted ? AppColors.brand.opacity(0.6) : AppColors.glassStroke,
                                  lineWidth: highlighted ? 1.5 : 1)
            }
            .shadow(color: AppColors.shadow, radius: 16, x: 0, y: 8)
        }
        .buttonStyle(SoftPressStyle(scale: 0.98))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(route.name), \(route.durationLabel), \(route.distanceLabel)\(isLocked ? ", premium" : "")")
    }

    // MARK: - Banner

    private var banner: some View {
        ZStack {
            route.mood.gradient

            VStack {
                HStack(alignment: .top) {
                    AppTagChip(title: route.category.displayName,
                               systemImage: route.category.systemImage,
                               foreground: route.mood.preferredForeground)
                    Spacer()
                    if isLocked {
                        lockBadge
                    } else {
                        AppTagChip(title: route.durationLabel,
                                   systemImage: "clock",
                                   foreground: route.mood.preferredForeground)
                    }
                }
                Spacer()
                HStack(alignment: .bottom) {
                    Text(route.shortName)
                        .font(AppTypography.title2)
                        .foregroundStyle(route.mood.preferredForeground)
                    Spacer()
                    BalloonView(height: 46, showBurner: false, showGlow: false)
                        .opacity(0.97)
                }
            }
            .padding(AppSpacing.sm + 2)
        }
        .frame(height: 120)
        .clipped()
    }

    private var lockBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold))
            Text("PRO").font(AppTypography.micro)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, 5)
        .background(Capsule().fill(AppColors.gold))
    }

    // MARK: - Info

    private var info: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs + 2) {
            Text(route.name)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(route.originName)
                Image(systemName: "arrow.right").font(.system(size: 10, weight: .bold))
                Text(route.destinationName)
            }
            .font(AppTypography.subhead)
            .foregroundStyle(AppColors.textSecondary)
            .lineLimit(1)

            HStack(spacing: AppSpacing.xs) {
                infoChip(systemImage: route.mood.systemImage, text: route.mood.displayName)
                infoChip(systemImage: "ruler", text: route.distanceLabel)
            }
            .padding(.top, 2)

            HStack(spacing: 5) {
                Image(systemName: "gift")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(route.colorTheme.accent)
                Text(route.rewardName)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }
            .padding(.top, 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
    }

    private func infoChip(systemImage: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage).font(.system(size: 10.5, weight: .semibold))
            Text(text).font(AppTypography.caption)
        }
        .foregroundStyle(AppColors.textSecondary)
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, 5)
        .background(Capsule().fill(AppColors.hairline))
    }
}
