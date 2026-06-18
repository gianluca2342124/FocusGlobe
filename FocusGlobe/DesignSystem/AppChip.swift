import SwiftUI

/// A small pill label, optionally selectable. Used for category filters and
/// mood / reward tags.
struct AppChip: View {
    let title: String
    var systemImage: String? = nil
    var isSelected: Bool = false
    var accent: Color = AppColors.brand

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 11.5, weight: .semibold))
            }
            Text(title)
                .font(AppTypography.caption)
        }
        .foregroundStyle(isSelected ? Color.white : AppColors.textSecondary)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 7)
        .background {
            Capsule(style: .continuous)
                .fill(isSelected ? AnyShapeStyle(accent) : AnyShapeStyle(.ultraThinMaterial))
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(isSelected ? Color.clear : AppColors.hairline, lineWidth: 1)
        }
    }
}

/// A static tag chip drawn on top of a (possibly dark) mood gradient.
struct AppTagChip: View {
    let title: String
    var systemImage: String? = nil
    var foreground: Color = .white

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10.5, weight: .semibold))
            }
            Text(title)
                .font(AppTypography.micro)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, AppSpacing.xs + 2)
        .padding(.vertical, 5)
        .background {
            Capsule(style: .continuous).fill(.ultraThinMaterial)
        }
    }
}
