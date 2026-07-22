import SwiftUI

/// The ONE circular status-control family for the Home top bar — streak, reward
/// video and FocusGlobe PRO all share this exact footprint, glass treatment and
/// press behaviour, so the row reads as a designed set instead of four unrelated
/// pills. (Focus Coins keeps a matching capsule because balances grow wide.)
struct StatusCircleButton<Content: View>: View {
    var size: CGFloat = Layout.pad(46, 54)
    /// Pass `nil` to use the shared adaptive control ring; pass a colour for an
    /// accent ring (e.g. the streak ember).
    var ring: Color? = nil
    var accessibilityText: String
    let action: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Button(action: action) {
            content()
                .frame(width: size, height: size)
                // The shared adaptive control surface: a warm-white disc by day
                // (dark glyphs, matching Start Focus), a premium translucent
                // dark-glass disc by night — never a white circle in Dark Mode.
                .background(Circle().fill(AppColors.homeControlFill)
                    .shadow(color: .black.opacity(0.22), radius: 12, y: 6))
                .overlay(Circle().strokeBorder(ring ?? AppColors.homeControlStroke, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(SoftPressStyle(scale: 0.94))
        .accessibilityLabel(accessibilityText)
    }
}

/// The streak ember as a circle: centred flame, with the day count as a compact
/// badge riding the top edge — readable from 1 to 3+ digits.
struct StreakCircleButton: View {
    let streak: Int
    var pulsing: Bool = false
    let action: () -> Void

    private var alive: Bool { streak > 0 }

    var body: some View {
        StatusCircleButton(ring: alive ? Color(hex: 0xF2643C).opacity(0.45) : nil,
                           accessibilityText: "\(streak) day streak. Opens streak details.",
                           action: action) {
            Image(systemName: "flame.fill")
                .font(.system(size: Layout.pad(19, 22), weight: .bold))
                .foregroundStyle(
                    // The inactive flame is a warm grey (reads on both the day
                    // white disc and the night glass), the active one the ember.
                    LinearGradient(colors: alive ? [Color(hex: 0xFFB65C), Color(hex: 0xF2643C)]
                                                 : [Color(hex: 0xB6A890), Color(hex: 0x9C8E76)],
                                   startPoint: .top, endPoint: .bottom))
        }
        .overlay(alignment: .top) {
            Text("\(min(streak, 999))")
                .font(.system(size: 11, weight: .heavy, design: .default))
                .monospacedDigit()
                .foregroundStyle(alive ? .white : Color(hex: 0x2B2510))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(alive ? Color(hex: 0xC7482A) : Color(hex: 0xE7DFCF)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.8))
                .offset(y: -7)
                .allowsHitTesting(false)
        }
        .shadow(color: Color(hex: 0xF2643C).opacity(alive ? (pulsing ? 0.55 : 0.26) : 0),
                radius: pulsing ? 12 : 7, y: 0)
    }
}

/// The rewarded Coin Spin entry as a circle — the play glyph wearing its coin,
/// same footprint as the rest of the family, keeping its gentle invitation shake.
struct CoinSpinCircleButton: View {
    let action: () -> Void

    var body: some View {
        StatusCircleButton(ring: AppColors.gold.opacity(0.30),
                           accessibilityText: "Free Coin Spin. Watch a video to win Focus Coins.",
                           action: action) {
            ZStack {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: Layout.pad(17, 19), weight: .semibold))
                    .foregroundStyle(AppColors.gold)
                FocusCoinIcon(size: Layout.pad(13, 15))
                    .offset(x: Layout.pad(11, 12), y: -Layout.pad(10, 11))
            }
        }
        .phaseAnimator([0, 1, 2, 3, 4]) { content, phase in
            content.rotationEffect(.degrees(spinShake(phase)))
        } animation: { phase in
            phase == 0 ? .easeInOut(duration: 3.0) : .spring(response: 0.16, dampingFraction: 0.4)
        }
    }

    private func spinShake(_ p: Int) -> Double {
        switch p {
        case 1: return -6
        case 2: return 6
        case 3: return -4
        case 4: return 4
        default: return 0
        }
    }
}

/// The active-PRO status as a circle: the gold crown, quiet and proud.
struct ProCircleBadge: View {
    let action: () -> Void

    var body: some View {
        StatusCircleButton(ring: AppColors.gold.opacity(0.55),
                           accessibilityText: "FocusGlobe PRO is active",
                           action: action) {
            Image(systemName: "crown.fill")
                .font(.system(size: Layout.pad(17, 19), weight: .semibold))
                .foregroundStyle(AppColors.gold)
        }
        .shadow(color: AppColors.gold.opacity(0.4), radius: 8, y: 0)
    }
}
