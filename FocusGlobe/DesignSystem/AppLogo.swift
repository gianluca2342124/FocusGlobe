import SwiftUI

/// The app's brand glyph — a calm night-sky tile with a small drifting balloon.
struct BrandGlyph: View {
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x2A3A72), Color(hex: 0x4A63C8)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            // A faint route arc of dots.
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(0.45))
                    .frame(width: size * 0.05, height: size * 0.05)
                    .offset(x: size * (0.18 + Double(i) * 0.12),
                            y: size * (0.22 - Double(i) * 0.04))
            }

            BalloonMark(size: size * 0.4, glow: .white, showGlow: false)
                .offset(x: -size * 0.06, y: -size * 0.02)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: AppColors.shadow, radius: 8, y: 4)
    }
}

/// The FocusGlobe wordmark, with optional glyph.
struct AppLogo: View {
    var size: CGFloat = 32
    var showGlyph: Bool = true

    var body: some View {
        HStack(spacing: 9) {
            if showGlyph {
                BrandGlyph(size: size)
            }
            (Text("Focus").foregroundStyle(AppColors.textPrimary)
                + Text("Globe").foregroundStyle(AppColors.brand))
                .font(.system(size: size * 0.6, weight: .bold, design: .rounded))
        }
        .accessibilityElement()
        .accessibilityLabel("FocusGlobe")
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
