import SwiftUI

/// A subtle, premium radar pulse — slow expanding white rings used around the
/// current origin on Home and Choose Journey. Low opacity, no neon, GPU-driven
/// (no per-frame work), and non-interactive.
struct RadarPulse: View {
    var color: Color = .white
    var size: CGFloat = 230
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(color.opacity(0.22), lineWidth: 1.4)
                    .frame(width: size, height: size)
                    .scaleEffect(animate ? 1.0 : 0.22)
                    .opacity(animate ? 0 : 0.5)
                    .animation(
                        .easeOut(duration: 3.4).repeatForever(autoreverses: false)
                            .delay(Double(i) * 1.13),
                        value: animate)
            }
            Circle()
                .fill(color.opacity(0.10))
                .frame(width: size * 0.22, height: size * 0.22)
                .scaleEffect(animate ? 1.25 : 0.85)
                .opacity(animate ? 0.15 : 0.4)
                .animation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true), value: animate)
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }
}
