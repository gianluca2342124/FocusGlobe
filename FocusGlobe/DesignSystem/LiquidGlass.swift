import SwiftUI

/// Liquid-Glass design-system components — thin, reusable wrappers over the
/// shared `glassBackground` material so surfaces, cards, buttons, pills and
/// controls all share the same translucent, luminous, dark-first look.
///
/// Existing views already pick up the refined material automatically via
/// `glassBackground`; use these named components for new UI (and to keep new
/// surfaces consistent) rather than writing one-off glass styling.

// MARK: - Surfaces

/// A plain translucent glass surface (rounded) for ad-hoc panels.
struct GlassSurface<Content: View>: View {
    var cornerRadius: CGFloat = AppSpacing.cardRadius
    var padding: CGFloat = AppSpacing.md
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(padding)
            .glassBackground(cornerRadius: cornerRadius)
    }
}

/// A glass content card.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 20
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassBackground(cornerRadius: cornerRadius, tintOpacity: 0.18, shadowRadius: 12, shadowY: 6)
    }
}

/// A titled glass section (label + glass body) for list-style screens.
struct GlassSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold, design: .default)).tracking(0.6)
                .foregroundStyle(AppColors.textSecondary)
                .padding(.leading, 4)
            VStack(spacing: AppSpacing.sm) { content() }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassBackground(cornerRadius: 18, tintOpacity: 0.16, shadowRadius: 10, shadowY: 5)
        }
    }
}

/// A small glass pill (badge / label container).
struct GlassPill<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        HStack(spacing: 6) { content() }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 7)
            .glassBackground(cornerRadius: AppSpacing.pillRadius, tintOpacity: 0.20, shadowRadius: 8, shadowY: 4)
    }
}

/// A full-bleed blurred glass background (e.g. behind sheets).
struct GlassBlurBackground: View {
    var body: some View {
        ZStack {
            AppColors.backgroundTop.ignoresSafeArea()
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
        }
    }
}

// MARK: - Responsive

extension View {
    /// Constrain content to a comfortable reading width and centre it on large
    /// screens (iPad / Mac / landscape), leaving phones (narrower than `maxWidth`)
    /// unchanged. Use on scrollable, content-heavy screens.
    func readableWidth(_ maxWidth: CGFloat = 560) -> some View {
        frame(maxWidth: maxWidth).frame(maxWidth: .infinity)
    }
}

// MARK: - Buttons

/// A secondary glass button (rounded-rect, translucent) for non-primary actions.
struct GlassButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 16, weight: .semibold)) }
                Text(title).font(AppTypography.callout)
            }
            .foregroundStyle(AppColors.textPrimary)
            .frame(maxWidth: .infinity).frame(height: 50)
            .glassBackground(cornerRadius: 16, tintOpacity: 0.22, shadowRadius: 8, shadowY: 4)
        }
        .buttonStyle(SoftPressStyle())
    }
}

/// A circular glass icon button with an optional (non-coloured) active highlight.
struct GlassIconButton: View {
    let systemImage: String
    var size: CGFloat = 46
    var active: Bool = false
    var accessibilityLabel: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: size, height: size)
                .background { liquidGlassCircle(active: active) }
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

/// A circular glass button showing a short text label (e.g. "2D"/"3D"). The
/// active state is a brighter glass highlight — never a coloured/yellow tint.
struct GlassTextButton: View {
    let text: String
    var size: CGFloat = 46
    var active: Bool = false
    var accessibilityLabel: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 15, weight: .heavy, design: .default))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: size, height: size)
                .background { liquidGlassCircle(active: active) }
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Shared glass circle background for the icon/text controls. `active` adds a
/// subtle white luminous glow + brighter border (never a colour) so toggled
/// controls read as "on" while staying in the glass language.
@ViewBuilder
private func liquidGlassCircle(active: Bool) -> some View {
    Circle().fill(.regularMaterial)
        .overlay(Circle().fill(AppColors.islandTint.opacity(active ? 0.10 : 0.28)))
        .overlay(Circle().fill(Color.white.opacity(active ? 0.16 : 0)))
        .overlay(Circle().strokeBorder(Color.white.opacity(active ? 0.50 : 0.18), lineWidth: active ? 1.5 : 1))
        .shadow(color: AppColors.shadow, radius: 12, y: 6)
}
