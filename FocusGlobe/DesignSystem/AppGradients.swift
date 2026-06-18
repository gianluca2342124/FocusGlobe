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

/// A reusable full-screen calm background with two soft, blurred orbs of light.
struct AppBackground: View {
    var body: some View {
        ZStack {
            AppGradients.appBackground
                .ignoresSafeArea()

            Circle()
                .fill(AppColors.brand.opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: -120, y: -200)

            Circle()
                .fill(AppColors.gold.opacity(0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 100)
                .offset(x: 140, y: 260)
        }
        .ignoresSafeArea()
    }
}
