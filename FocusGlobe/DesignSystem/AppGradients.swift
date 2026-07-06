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

/// A reusable full-screen **expedition paper** background: a warm aged-paper
/// gradient (deep navy paper in Dark) with soft lantern/terracotta stains and a
/// tactile grain — the shared page tone across every non-map screen.
struct AppBackground: View {
    var body: some View {
        ZStack {
            AppGradients.appBackground
                .ignoresSafeArea()

            // A warm lantern glow high up (replaces the old cold white orb) —
            // golden-hour light falling across the page.
            Circle()
                .fill(AppColors.lantern.opacity(0.10))
                .frame(width: 340, height: 340)
                .blur(radius: 120)
                .offset(x: -120, y: -220)

            // A faint terracotta stain low-down so the page never looks flat.
            Circle()
                .fill(AppColors.terracotta.opacity(0.07))
                .frame(width: 300, height: 300)
                .blur(radius: 130)
                .offset(x: 150, y: 280)

            // Tactile paper grain over the whole page (subtle, deterministic).
            PaperGrain(intensity: 0.9)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}
