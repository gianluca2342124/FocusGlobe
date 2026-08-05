import SwiftUI

/// Dynamic Type for the onboarding.
///
/// The rest of FocusGlobe sizes its type with fixed points through
/// `AppTypography`, which does not respond to Larger Text at all. Converting
/// the whole app is a separate piece of work; the first run cannot wait for it,
/// because a pilot who needs bigger text needs it most on the screens that
/// decide whether they stay.
///
/// `@ScaledMetric` gives these screens real Dynamic Type. Titles are clamped
/// more tightly than body copy on purpose: an unclamped 34 pt heading at the
/// largest accessibility size pushes the answers themselves off screen, which
/// helps nobody.
enum OnboardingType {
    static let titleCeiling: CGFloat = 1.45
    static let bodyCeiling: CGFloat = 1.9
    static func clamp(_ scale: CGFloat, _ ceiling: CGFloat) -> CGFloat {
        min(max(scale, 1), ceiling)
    }
}

// ============================================================================
// The pieces every onboarding screen is built from.
//
// Shared rather than per-screen because the previous flow's eleven steps each
// re-declared their own title font, their own padding and their own Continue
// button, and they had drifted apart: three different title sizes, two
// different button paddings, and a progress bar that measured a step count no
// screen agreed with. One scaffold means a change to the rhythm of the flow is
// one edit, and means every screen is responsive and accessible by default
// rather than by remembering.
// ============================================================================

/// The continuous night sky behind every step.
///
/// One backdrop for the whole flow — never re-created per screen — so moving
/// between questions reads as moving through one place rather than cutting
/// between eleven separate screens.
struct OnboardingBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0B1024), Color(hex: 0x1C2444), Color(hex: 0x2E2350)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [AppColors.gold.opacity(0.14), .clear],
                           center: UnitPoint(x: 0.5, y: 0.85), startRadius: 8, endRadius: 420)
            OnboardingStarfield()
        }
        .ignoresSafeArea()
    }
}

/// A deterministic sprinkle of stars. Seeded, so the sky does not reshuffle on
/// every redraw — which, at 70 stars behind a screen that re-renders on each
/// tap, would read as flickering rather than as sky.
struct OnboardingStarfield: View {
    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: 0x0B0A)
            for _ in 0..<70 {
                let x = CGFloat(rng.unit()) * size.width
                let y = CGFloat(rng.unit()) * size.height * 0.7
                let r = CGFloat(0.5 + rng.unit() * 1.4)
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(0.14 + rng.unit() * 0.4)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Header

/// Back control, section progress and the section name.
///
/// The bar measures SECTIONS, not screens, which is what lets it stay honest
/// across a branching flow: skipping the soundscape question moves the pilot
/// within "Your atmosphere" rather than making the bar jump. It also means the
/// bar can never be inflated by adding screens — the thing a progress indicator
/// is most often quietly used for.
struct OnboardingHeader: View {
    let step: OnboardingStepID
    let progress: Double
    let canGoBack: Bool
    let onBack: () -> Void

    @Environment(\.focusStrings) private var strings
    @Environment(\.focusViewport) private var viewport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            backControl
            if step.showsProgress {
                progressBar
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, viewport.pagePadding)
        .padding(.top, AppSpacing.xs)
        .frame(height: 44)
    }

    @ViewBuilder private var backControl: some View {
        // The control keeps its footprint whether or not it is tappable, so the
        // progress bar does not shift sideways between screens.
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(canGoBack ? 0.85 : 0))
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .disabled(!canGoBack)
        .accessibilityLabel(Text(strings(.obBack)))
        .accessibilityHidden(!canGoBack)
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.14))
                    Capsule()
                        .fill(AppColors.brand)
                        .frame(width: max(4, geo.size.width * progress))
                }
            }
            .frame(height: 4)
            if let key = step.section.titleKey {
                Text(strings(key))
                    .font(AppTypography.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.32), value: progress)
        // One accessible element: a percentage plus the section name, rather
        // than VoiceOver reading a decorative capsule and then a stray label.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(step.section.titleKey.map { strings($0) } ?? ""))
        .accessibilityValue(Text("\(Int((progress * 100).rounded()))%"))
    }
}

// MARK: - Scaffold

/// Title, subtitle, content and a pinned footer.
///
/// The footer is pinned rather than scrolled with the content: a Continue
/// button that scrolls away is a Continue button a pilot has to hunt for, and
/// on a short device with Larger Text it disappears entirely.
struct OnboardingScaffold<Content: View, Footer: View>: View {
    let title: String
    var subtitle: String? = nil
    /// An optional personalized line ABOVE the title — the commitment sentence
    /// on the duration screen lives here rather than on a screen of its own.
    var preamble: String? = nil
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    @Environment(\.focusViewport) private var viewport
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: viewport.cardSpacing) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let preamble {
                            Text(preamble)
                                .font(AppTypography.callout)
                                .foregroundStyle(AppColors.gold.opacity(0.92))
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.bottom, 2)
                        }
                        Text(title)
                            .font(.system(size: (viewport.isShort ? viewport.titleSize * 0.86 : viewport.titleSize)
                                          * OnboardingType.clamp(typeScale, OnboardingType.titleCeiling),
                                          weight: .bold, design: .default))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        if let subtitle {
                            Text(subtitle)
                                .font(AppTypography.callout)
                                .foregroundStyle(.white.opacity(0.66))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                    content()
                }
                .padding(.top, viewport.isShort ? AppSpacing.md : AppSpacing.lg)
                .padding(.bottom, AppSpacing.lg)
                // Pad first, THEN take the width. Growing to the full width and
                // insetting afterwards puts the content outside its container.
                .padding(.horizontal, viewport.pagePadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            footer()
                .padding(.horizontal, viewport.pagePadding)
                .padding(.bottom, viewport.isShort ? AppSpacing.md : AppSpacing.lg)
        }
        .frame(maxWidth: viewport.readableContentWidth)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Footer

/// The standard footer: one primary action, and an optional secondary that is
/// always a real, visible way past the screen.
struct OnboardingFooter: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            AppPrimaryButton(title: title, systemImage: "arrow.right",
                             isEnabled: isEnabled, iconTrailing: true, action: action)
            if let secondaryTitle, let secondaryAction {
                Button(action: secondaryAction) {
                    Text(secondaryTitle)
                        .font(AppTypography.callout)
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .contentShape(Rectangle())
                }
            }
        }
    }
}

// MARK: - Options

/// One answer. A full-width row with an icon, sized for a thumb and readable at
/// the largest Dynamic Type sizes.
struct OnboardingOptionRow: View {
    let title: String
    var systemImage: String? = nil
    var badge: String? = nil
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.focusViewport) private var viewport
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isSelected ? Color(hex: 0x14120E) : AppColors.gold)
                        .frame(width: 26)
                }
                Text(title)
                    .font(.system(size: viewport.bodySize
                                  * OnboardingType.clamp(typeScale, OnboardingType.bodyCeiling),
                                  weight: .semibold, design: .default))
                    .foregroundStyle(isSelected ? Color(hex: 0x14120E) : .white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: AppSpacing.xs)
                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isSelected ? Color(hex: 0x14120E).opacity(0.7) : AppColors.gold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(isSelected
                                                   ? Color(hex: 0x14120E).opacity(0.1)
                                                   : AppColors.gold.opacity(0.16)))
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 15)
            // Grows with the text rather than clipping it: the row's height is a
            // FLOOR, never a fixed size.
            .frame(minHeight: 56 * OnboardingType.clamp(typeScale, OnboardingType.bodyCeiling))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color(hex: 0xF4EFE4) : Color.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(isSelected ? 0 : 0.12), lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle(scale: 0.985))
        // One element carrying the label AND the selection, so VoiceOver never
        // reads a decorative icon or announces a badge as a separate control.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(badge.map { "\(title), \($0)" } ?? title))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// A compact option, for short values that read better side by side than
/// stacked — the five first-flight lengths.
struct OnboardingCompactOption: View {
    let title: String
    var badge: String? = nil
    let isSelected: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 17 * OnboardingType.clamp(typeScale, OnboardingType.bodyCeiling),
                                  weight: .semibold, design: .default))
                    .foregroundStyle(isSelected ? Color(hex: 0x14120E) : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let badge {
                    Text(badge)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(isSelected ? Color(hex: 0x14120E).opacity(0.66) : AppColors.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56 * OnboardingType.clamp(typeScale, OnboardingType.bodyCeiling))
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color(hex: 0xF4EFE4) : Color.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(isSelected ? 0 : 0.12), lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle(scale: 0.985))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(badge.map { "\(title), \($0)" } ?? title))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The transition between steps. Extracted so every screen moves the same way,
/// and so Reduce Motion is honoured in one place rather than eleven.
extension AnyTransition {
    static func onboardingStep(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(insertion: .opacity.combined(with: .offset(y: 22)),
                           removal: .opacity.combined(with: .offset(y: -14)))
    }
}
