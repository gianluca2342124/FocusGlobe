import SwiftUI

/// A short, calm "take off" ritual shown before the live session begins.
/// The balloon lifts, the burner glows, then the scene cross-dissolves into the
/// map. Intentionally minimal — it sets the tone for focus without delay.
struct TakeoffView: View {
    let route: Route
    var onComplete: () -> Void

    @State private var appeared = false
    @State private var rise = false

    private var fg: Color { route.mood.preferredForeground }

    var body: some View {
        ZStack {
            route.mood.gradient
                .ignoresSafeArea()

            // Depth vignette.
            RadialGradient(colors: [.clear, .black.opacity(0.30)],
                           center: .center, startRadius: 120, endRadius: 520)
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.lg) {
                Spacer()

                VStack(spacing: 6) {
                    Text(route.shortName.uppercased())
                        .font(AppTypography.micro)
                        .tracking(2.0)
                        .foregroundStyle(fg.opacity(0.7))
                    Text("Taking off")
                        .font(AppTypography.title)
                        .foregroundStyle(fg)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)

                BalloonView(height: 210, showBurner: true, showGlow: true,
                            glow: route.colorTheme.soft)
                    .offset(y: rise ? -26 : 56)
                    .opacity(appeared ? 1 : 0)

                Spacer()

                VStack(spacing: AppSpacing.sm) {
                    TakeoffProgressBar(color: fg)
                        .frame(width: 150)
                    Text("Leaving distractions below")
                        .font(AppTypography.caption)
                        .foregroundStyle(fg.opacity(0.75))
                }
                .opacity(appeared ? 1 : 0)
                .padding(.bottom, AppSpacing.xxl)
            }
            .padding(AppSpacing.screen)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { appeared = true }
            withAnimation(.easeInOut(duration: 2.0)) { rise = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) { onComplete() }
        }
    }
}

/// A slim indeterminate "boarding" bar that fills once, calmly.
private struct TakeoffProgressBar: View {
    let color: Color
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.2))
                Capsule().fill(color.opacity(0.9))
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 3)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8)) { progress = 1 }
        }
    }
}
