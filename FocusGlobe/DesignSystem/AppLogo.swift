import SwiftUI

/// The app's brand glyph — a calm night-sky tile with a small drifting balloon.
/// Used as the wordmark companion when no `BrandLogo` PNG is bundled.
struct BrandGlyph: View {
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x141B33), Color(hex: 0x2A3A72)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: size * 0.045, height: size * 0.045)
                    .offset(x: size * (0.16 + Double(i) * 0.12),
                            y: size * (0.2 - Double(i) * 0.04))
            }

            BalloonView(height: size * 0.54, showBurner: false, showGlow: false)
                .offset(x: -size * 0.06, y: -size * 0.02)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: AppColors.shadow, radius: 8, y: 4)
    }
}

/// The FocusGlobe lockup. Prefers a bundled `BrandLogo` PNG; otherwise renders
/// the glyph + wordmark.
struct AppLogo: View {
    var size: CGFloat = 32
    var showGlyph: Bool = true

    var body: some View {
        if BrandAssets.hasBrandLogo {
            Image(BrandAssets.brandLogoName)
                .resizable()
                .scaledToFit()
                .frame(height: size * 1.1)
                .accessibilityLabel("FocusGlobe")
        } else {
            HStack(spacing: 9) {
                if showGlyph { BrandGlyph(size: size) }
                (Text("Focus").foregroundStyle(AppColors.textPrimary)
                    + Text("Globe").foregroundStyle(AppColors.brand))
                    .font(.system(size: size * 0.6, weight: .bold, design: .rounded))
            }
            .accessibilityElement()
            .accessibilityLabel("FocusGlobe")
        }
    }
}

#Preview {
    ZStack {
        AppBackground()
        VStack(spacing: 24) {
            AppLogo(size: 40)
            BrandGlyph(size: 80)
        }
    }
}
