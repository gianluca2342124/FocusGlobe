import SwiftUI

/// A small, warm "day streak" pill. Readable on any background (solid warm
/// gradient + white text), so it works over the map on Home and on the Landing
/// reward screen alike.
struct StreakPill: View {
    let days: Int
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .bold))
            Text("\(days)-day streak")
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(
                LinearGradient(colors: [Color(hex: 0xFF9D3C), Color(hex: 0xF2643C)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        )
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
        .shadow(color: Color(hex: 0xF2643C).opacity(0.45), radius: 8, y: 4)
        .accessibilityLabel("\(days) day streak")
    }
}
