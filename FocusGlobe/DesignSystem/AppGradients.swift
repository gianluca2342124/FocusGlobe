import SwiftUI

/// Shared gradients for backgrounds and brand surfaces.
enum AppGradients {

    /// The calm app background used behind non-map screens.
    static var appBackground: LinearGradient {
        LinearGradient(
            colors: [AppColors.backgroundTop, AppColors.backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Brand gradient for the primary CTA.
    static var brandButton: LinearGradient {
        LinearGradient(
            colors: [AppColors.brand, AppColors.brandDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// A soft radial glow, used sparingly behind hero elements.
    static func glow(_ color: Color, opacity: Double = 0.5) -> RadialGradient {
        RadialGradient(
            colors: [color.opacity(opacity), color.opacity(0)],
            center: .center,
            startRadius: 2,
            endRadius: 160
        )
    }
}

/// A reusable full-screen calm background: an elegant neutral graphite/near-black
/// gradient with subtle, blurred depth (no blue tint) — the shared tone across
/// every non-map screen, matching the Streak details look.
struct AppBackground: View {
    var body: some View {
        ZStack {
            AppGradients.appBackground
                .ignoresSafeArea()

            // A soft neutral top glow for depth (replaces the old blue orb).
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 340, height: 340)
                .blur(radius: 110)
                .offset(x: -120, y: -220)

            // A faint warm accent low-down keeps it premium, never flat.
            Circle()
                .fill(AppColors.gold.opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 120)
                .offset(x: 150, y: 280)
        }
        .ignoresSafeArea()
    }
}
