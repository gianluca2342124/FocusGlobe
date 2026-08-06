import SwiftUI

/// The night sky the whole first run happens in.
///
/// Extracted from `OnboardingView` for one reason: the onboarding now ends on
/// the REAL paywall — the same view the Home PRO button opens — and that
/// paywall has to appear against this exact sky rather than its own. Two
/// hand-tuned copies of a gradient would drift within a release; one shared
/// view cannot.
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
        .allowsHitTesting(false)
    }
}

/// A deterministic sprinkle of stars.
///
/// Seeded, so the sky does not reshuffle on every redraw — at 70 stars behind a
/// screen that re-renders on each tap, a fresh random field reads as flickering
/// rather than as sky.
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
