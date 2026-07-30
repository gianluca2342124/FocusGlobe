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

/// The one FocusGlobe liquid-glass substrate for compact controls. It uses a
/// native material for depth, a soft internal light pass and a tiny specular
/// bloom instead of a conspicuous white outline. Reduce Transparency switches
/// to a fully opaque neutral while retaining the same hierarchy and contrast.
struct FocusLiquidGlassSurface<S: InsettableShape>: View {
    let shape: S
    var tint: Color = AppColors.islandTint
    var tintOpacity: Double = 0.18
    var active = false
    /// A disabled control keeps its footprint and legibility but loses its
    /// liveliness: no specular bloom, a quieter tint and a softer shadow, so it
    /// reads as present-but-inactive rather than vanishing. The caller still dims
    /// its own label; this dims only the substrate.
    var enabled = true

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        substrate
            // An optical edge, not a visible ring. Increased Contrast
            // strengthens it without changing the control's footprint.
            .overlay(
                shape.strokeBorder(
                    .white.opacity(edgeOpacity),
                    lineWidth: contrast == .increased ? 1 : 0.65
                )
            )
            .shadow(color: .black.opacity(enabled ? 0.18 : 0.08), radius: enabled ? 8 : 5, y: 4)
            // CRITICAL: this surface is ONLY ever used as decoration inside
            // `.background { }`. On iOS 26 the substrate below uses
            // `.glassEffect(….interactive(), …)`, and `.interactive()` installs
            // the glass's OWN touch handling on a descendant of the host
            // Button's label — a descendant gesture beats the ancestor Button, so
            // the press is swallowed and the Button's action never fires. That is
            // exactly what broke the Home Sky arrows: the disc lit up but nothing
            // happened. Controls that still worked (StatusCircleButton, the PRO
            // circle) were only saved by their own `.contentShape(Circle())`.
            // Every caller already gives press feedback via SoftPressStyle, so the
            // glass never needs to receive touches at all.
            .allowsHitTesting(false)
    }

    /// The active highlight is suppressed while disabled, so a disabled control
    /// never looks "selected".
    private var showsActive: Bool { active && enabled }

    /// The optical edge fades slightly while disabled — never disappears, so the
    /// footprint stays legible.
    private var edgeOpacity: Double {
        let base = contrast == .increased ? 0.20 : 0.075
        return enabled ? base : base * 0.6
    }

    /// The public Liquid Glass recipe for the current state. A disabled control
    /// drops `.interactive()` (no press-tracking on a non-actionable surface) and
    /// softens its tint. Both branches return `Glass`, so no version shim is needed
    /// beyond the `#available` guard at the call site.
    @available(iOS 26.0, *)
    private var glass: Glass {
        enabled
            ? .regular.tint(tint.opacity(tintOpacity)).interactive()
            : .regular.tint(tint.opacity(tintOpacity * 0.6))
    }

    @ViewBuilder private var substrate: some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            // Use Apple's public Liquid Glass substrate on current systems.
            // Shape, tint and interaction stay centralized here so feature
            // views never need version checks or one-off glass recipes.
            //
            // A disabled control drops `.interactive()`: the interactive glass
            // adds a press-tracking response that a non-actionable surface should
            // not show, and its tint is softened so it reads as inactive.
            shape
                .fill(Color.clear)
                .glassEffect(glass, in: shape)
                .overlay {
                    if showsActive {
                        shape.fill(.white.opacity(0.07))
                    }
                }
        } else {
            legacySubstrate
        }
    }

    private var legacySubstrate: some View {
        ZStack {
            if reduceTransparency {
                shape.fill(AppColors.neutralRaised)
            } else {
                shape.fill(.ultraThinMaterial)
            }

            shape.fill(tint.opacity(reduceTransparency ? 0.26 : tintOpacity))

            shape.fill(
                LinearGradient(
                    colors: [
                        .white.opacity(enabled ? (showsActive ? 0.20 : 0.13) : 0.06),
                        .white.opacity(0.035),
                        .black.opacity(0.08),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .blendMode(.softLight)

            shape.fill(
                RadialGradient(
                    colors: [.white.opacity(enabled ? (showsActive ? 0.18 : 0.10) : 0.04), .clear],
                    center: UnitPoint(x: 0.30, y: 0.16),
                    startRadius: 0,
                    endRadius: 42
                )
            )
            .blendMode(.plusLighter)
        }
    }
}

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
    var enabled: Bool = true
    var accessibilityLabel: String
    let action: () -> Void
    var body: some View {
        Button {
            guard enabled else { return }
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary.opacity(enabled ? 1 : 0.45))
                // Never smaller than a 44 pt target, whatever the visual size.
                .frame(width: max(44, size), height: max(44, size))
                .background {
                    FocusLiquidGlassSurface(shape: Circle(), active: active, enabled: enabled)
                }
                .contentShape(Circle())
        }
        .buttonStyle(SoftPressStyle())
        .disabled(!enabled)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// A compact icon + text capsule on the shared glass substrate — the horizontal
/// sibling of `GlassIconButton`, for utility actions that need a short label
/// (e.g. an in-flight "Pause" / "Land now"). Selected raises the glass highlight;
/// disabled quiets the substrate AND dims the label, and blocks the action. The
/// capsule always clears a 44 pt tap height.
struct GlassCapsuleButton: View {
    let title: String
    var systemImage: String? = nil
    var selected: Bool = false
    var enabled: Bool = true
    /// Comfortable defaults; a caller can grow them but never below the 44 pt min.
    var height: CGFloat = 44
    var horizontalPadding: CGFloat = 18
    var accessibilityLabel: String? = nil
    let action: () -> Void

    var body: some View {
        Button {
            guard enabled else { return }
            action()
        } label: {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 15, weight: .bold))
                }
                Text(title).font(.system(size: 15, weight: .semibold, design: .default))
            }
            .foregroundStyle(AppColors.textPrimary.opacity(enabled ? 0.92 : 0.45))
            .padding(.horizontal, horizontalPadding)
            .frame(height: max(44, height))
            .background {
                FocusLiquidGlassSurface(shape: Capsule(), active: selected, enabled: enabled)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(SoftPressStyle())
        .disabled(!enabled)
        .accessibilityLabel(accessibilityLabel ?? title)
    }
}

/// A circular glass button showing a short text label (e.g. "2D"/"3D"). The
/// active state is a brighter glass highlight — never a coloured/yellow tint.
struct GlassTextButton: View {
    let text: String
    var size: CGFloat = 46
    var active: Bool = false
    var enabled: Bool = true
    var accessibilityLabel: String
    let action: () -> Void
    var body: some View {
        Button {
            guard enabled else { return }
            action()
        } label: {
            Text(text)
                .font(.system(size: 15, weight: .heavy, design: .default))
                .foregroundStyle(AppColors.textPrimary.opacity(enabled ? 1 : 0.45))
                .frame(width: max(44, size), height: max(44, size))
                .background {
                    FocusLiquidGlassSurface(shape: Circle(), active: active, enabled: enabled)
                }
                .contentShape(Circle())
        }
        .buttonStyle(SoftPressStyle())
        .disabled(!enabled)
        .accessibilityLabel(accessibilityLabel)
    }
}
