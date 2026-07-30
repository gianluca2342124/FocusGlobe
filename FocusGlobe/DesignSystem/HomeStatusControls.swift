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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Drives the occasional attention cue. False keeps the control perfectly at
    /// rest — there is deliberately no continuous scale, opacity or glow pulse.
    @State private var animating = false

    var body: some View {
        StatusCircleButton(size: size,
                           ring: AppColors.gold.opacity(0.30),
                           accessibilityText: "Free Coin Spin. Spin to win Focus Coins.",
                           action: action) {
            // The real free-coin-spin artwork (near full-bleed). No generated
            // play/coin glyphs — the asset carries the whole invitation.
            Image("freecoinspin")
                .resizable()
                .scaledToFit()
                .frame(width: Layout.pad(30, 34), height: Layout.pad(30, 34))
        }
        // At rest by default; one brief tilt roughly every 8 s, then fully still
        // again. The long phase-0 hold IS the rest — the shake phases are a
        // fraction of a second. Never a heartbeat.
        .modifier(OccasionalNudge(active: animating && !reduceMotion))
        .onAppear { animating = true }
        .onDisappear { animating = false }   // no work while off screen
    }

}

/// A rare, restrained attention cue: a long completely-still hold followed by one
/// short tilt, then rest again. Applied only when `active` — so Reduce Motion and
/// an off-screen control do no animation work at all.
private struct OccasionalNudge: ViewModifier {
    let active: Bool
    /// Bumped once per cue. The TRIGGER overload of `phaseAnimator` runs the
    /// sequence once and then holds — which is what makes the rest a genuine
    /// idle state. The untriggered overload loops forever with no gap, so a long
    /// phase-0 animation only *looks* still while a display link keeps ticking:
    /// that is motion, not a pause.
    @State private var cue = 0

    func body(content: Content) -> some View {
        content
            .phaseAnimator([0, 1, 2, 3], trigger: cue) { view, phase in
                view.rotationEffect(.degrees(tilt(phase)))
            } animation: { _ in .spring(response: 0.18, dampingFraction: 0.45) }
            .task(id: active) {
                // Cancelled automatically when `active` flips or the view goes
                // away, so an off-screen control schedules nothing at all.
                guard active else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 9_000_000_000)
                    guard !Task.isCancelled else { return }
                    cue &+= 1
                }
            }
    }

    private func tilt(_ p: Int) -> Double {
        switch p {
        case 1: return -5
        case 2: return 5
        default: return 0   // phases 0 and 3 are the rest pose
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
