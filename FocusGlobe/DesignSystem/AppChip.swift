import SwiftUI

/// A small pill label, optionally selectable. Used for category filters and
/// mood / reward tags.
struct AppChip: View {
    let title: String
    var systemImage: String? = nil
    var isSelected: Bool = false
    var accent: Color = AppColors.selection

    var body: some View {
        HStack(spacing: Layout.pad(5, 7)) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: Layout.pad(11.5, 14), weight: .semibold))
            }
            Text(LocalizedStringKey(title))
                .font(AppTypography.caption)
        }
        // `selectionInk`, not white: the selected fill is warm gold, and white
        // on gold is unreadable (~1.9:1).
        .foregroundStyle(isSelected ? AppColors.selectionInk : AppColors.textSecondary)
        .padding(.horizontal, Layout.pad(AppSpacing.sm, AppSpacing.md + 2))
        .padding(.vertical, Layout.pad(7, 11))
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
            Text(LocalizedStringKey(title))
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
