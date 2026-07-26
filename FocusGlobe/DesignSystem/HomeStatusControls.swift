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
                .background {
                    FocusLiquidGlassSurface(
                        shape: Circle(),
                        tint: ring ?? AppColors.homeControlFill,
                        tintOpacity: ring == nil ? 0.52 : 0.20,
                        active: ring != nil
                    )
                }
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
    var size: CGFloat = Layout.pad(46, 54)
    let action: () -> Void

    private var alive: Bool { streak > 0 }

    var body: some View {
        StatusCircleButton(size: size,
                           ring: alive ? Color(hex: 0xF2643C).opacity(0.45) : nil,
                           accessibilityText: "\(streak) day streak. Opens streak details.",
                           action: action) {
            // The real streak-fire artwork (full-height flame). Desaturated + dimmed
            // when the streak is asleep, so no streak reads calm, not broken.
            Image("streakfire")
                .resizable()
                .scaledToFit()
                .frame(width: Layout.pad(27, 32), height: Layout.pad(27, 32))
                .grayscale(alive ? 0 : 0.9)
                .opacity(alive ? 1 : 0.55)
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
    var size: CGFloat = Layout.pad(46, 54)
    let action: () -> Void

    var body: some View {
        StatusCircleButton(size: size,
                           ring: AppColors.gold.opacity(0.30),
                           accessibilityText: "Free Coin Spin. Watch a video to win Focus Coins.",
                           action: action) {
            // The real free-coin-spin artwork (near full-bleed). No generated
            // play/coin glyphs — the asset carries the whole invitation.
            Image("freecoinspin")
                .resizable()
                .scaledToFit()
                .frame(width: Layout.pad(30, 34), height: Layout.pad(30, 34))
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

/// The active-PRO status as a circle: the real multicolor PRO badge, quiet and
/// proud (no gold crown).
struct ProCircleBadge: View {
    let action: () -> Void

    var body: some View {
        StatusCircleButton(accessibilityText: "FocusGlobe PRO is active",
                           action: action) {
            FocusGlobePROBadge(visibleHeight: Layout.pad(15, 17))
        }
        .shadow(color: ProBrand.glow.opacity(0.32), radius: 8, y: 0)
    }
}
