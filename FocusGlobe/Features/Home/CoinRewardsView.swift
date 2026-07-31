import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Free Coin Spin button (Home, near the streak)

/// A small, attractive rewarded-ad entry point that lives in the Home top-left
/// beside the streak. A video symbol wearing a Focus Coin, with a gentle shake
/// roughly every ~3 s so it invites a tap without ever dominating Home.
struct CoinSpinButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            // The real Free Coin Spin artwork, scaled to fit the chip (never
            // clipped). A procedural video+coin glyph is kept only as a fallback
            // if the asset is ever missing, so the button is never blank.
            Group {
                if let ui = UIImage(named: "freecoinspin") {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                } else {
                    ZStack {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: Layout.pad(15, 17), weight: .semibold))
                            .foregroundStyle(AppColors.gold)
                        FocusCoinIcon(size: Layout.pad(13, 15))
                            .offset(x: Layout.pad(9, 10), y: -Layout.pad(8, 9))
                    }
                }
            }
            .frame(width: Layout.pad(26, 30), height: Layout.pad(24, 27))
            .padding(.horizontal, Layout.pad(10, 12))
            .padding(.vertical, Layout.pad(7, 9))
            // The same calm dark-glass family as the streak / coins chips, with
            // only a subtle gold accent — noticeable, never protagonist.
            .background(Capsule().fill(.white.opacity(0.1)))
            .overlay(Capsule().strokeBorder(AppColors.gold.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle())
        .phaseAnimator([0, 1, 2, 3, 4]) { content, phase in
            content.rotationEffect(.degrees(shakeAngle(phase)))
        } animation: { phase in
            // The long rest (phase 0) sets the ~3 s cadence; 1–4 are a gentle shake.
            phase == 0 ? .easeInOut(duration: 3.0) : .spring(response: 0.16, dampingFraction: 0.4)
        }
        .accessibilityLabel("Free Coin Spin. Watch a video to spin for Focus Coins.")
    }

    private func shakeAngle(_ p: Int) -> Double {
        switch p {
        case 1: return -6
        case 2: return 6
        case 3: return -4
        case 4: return 4
        default: return 0
        }
    }
}

// MARK: - Free Coin Spin sheet (video → wheel → result)

struct CoinSpinSheet: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase { case intro, spinning, result }
    @State private var phase: Phase = .intro
    @State private var rotation: Double = 0
    @State private var prize: Int? = nil
    @State private var note: String? = nil
    @State private var busy = false

    private let prizes = [1, 2, 3, 4, 5, 10, 15, 20, 25]

    var body: some View {
        ZStack {
            // A calm premium half-sheet: deep dark base by night, the app's
            // clean warm paper by day — a gold bloom and a restrained turquoise
            // accent in both. Static, never a moving tile.
            ZStack {
                (scheme == .dark ? Color(hex: 0x0D100E) : AppColors.backgroundTop)
                RadialGradient(colors: [AppColors.gold.opacity(scheme == .dark ? 0.16 : 0.10), .clear],
                               center: UnitPoint(x: 0.5, y: 0.22), startRadius: 4, endRadius: 320)
                RadialGradient(colors: [Color(hex: 0x2AC8B0).opacity(scheme == .dark ? 0.07 : 0.05), .clear],
                               center: UnitPoint(x: 0.85, y: 0.9), startRadius: 4, endRadius: 300)
            }
            .ignoresSafeArea()
            // Centre the hero + content group vertically so it sits comfortably in
            // the sheet — no longer crammed against the top with a large empty gap
            // below. A slightly larger top spacer biases the group a touch downward.
            VStack(spacing: AppSpacing.sm) {
                Spacer(minLength: AppSpacing.md)
                switch phase {
                case .intro:    intro
                case .spinning: spinning
                case .result:   result
                }
                Spacer(minLength: AppSpacing.sm)
            }
            .padding(.horizontal, AppSpacing.screen)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.md)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        // A premium half-sheet at the SAME height as the Streak popup. Dismissed
        // by swipe-down or tapping outside — no redundant close chrome.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// The `freecoinspin` artwork if present; a soft procedural fallback otherwise
    /// (a diffused radial, no hard circular glow edge).
    @ViewBuilder private var heroImage: some View {
        if let ui = UIImage(named: "freecoinspin") {
            Image(uiImage: ui).resizable().scaledToFit()
        } else {
            ZStack {
                // endRadius must stay UNDER the frame's half-extent or the shape
                // crops the gradient while it is still opaque and the glow reads
                // as a hard gold disc. (Was 130 against a 110 pt half-width.)
                RadialGradient(colors: [AppColors.gold.opacity(0.28), .clear],
                               center: .center, startRadius: 2, endRadius: 100)
                    .frame(width: 220, height: 220)
                    .blur(radius: 10)
                    .allowsHitTesting(false)
                Image(systemName: "video.fill")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(AppColors.brand)
                HStack(spacing: -10) {
                    FocusCoinIcon(size: 28)
                    FocusCoinIcon(size: 40)
                    FocusCoinIcon(size: 28)
                }
                .offset(y: 46)
            }
        }
    }

    private var intro: some View {
        VStack(spacing: AppSpacing.sm) {
            heroImage.frame(height: 138)
            Text("Free Coin Spin")
                .font(.system(size: 27, weight: .heavy, design: .default))
                .foregroundStyle(AppColors.textPrimary)
            Text("WIN UP TO 25 COINS!")
                .font(.system(size: 15, weight: .heavy, design: .default))
                .tracking(0.5)
                .foregroundStyle(AppColors.gold)
            // One promise for every pilot, PRO included: the video is the price
            // of the spin, so nobody is told they can skip it and nobody is
            // shown a button that claims the wheel turns on its own.
            Text("Watch a short video and spin for a reward.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            Text("1 · 2 · 3 · 5 · 10 · 15 · 20 · 25")
                .font(.system(size: 13, weight: .bold, design: .default))
                .foregroundStyle(AppColors.textTertiary)
            if let note {
                Text(note)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            AppPrimaryButton(title: spinButtonTitle, systemImage: "play.fill") {
                watch()
            }
            .disabled(busy)
        }
    }

    /// Names the exchange rather than the outcome. "Spin now" would promise a
    /// wheel that turns on tap, which it never does — the reward callback has to
    /// fire first. `busy` is the ad's load/present window, unchanged.
    private var spinButtonTitle: String { busy ? "Loading ad…" : "Watch Ad & Spin" }

    private var spinning: some View {
        VStack(spacing: AppSpacing.md) {
            SpinWheel(prizes: prizes, rotation: rotation)
                .frame(width: 224, height: 224)
                .padding(.top, AppSpacing.xs)
            Text("Spinning…")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private var result: some View {
        VStack(spacing: AppSpacing.sm) {
            ZStack {
                // Same rule: 190 pt frame → 95 pt half-extent, so the falloff has
                // to finish before that (was 120, leaving a visible gold disc).
                RadialGradient(colors: [AppColors.gold.opacity(0.4), .clear],
                               center: .center, startRadius: 2, endRadius: 86)
                    .frame(width: 190, height: 190)
                    .blur(radius: 6)
                    .allowsHitTesting(false)
                FocusCoinIcon(size: 88)
            }
            .frame(height: 170)
            Text("You won")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
            Text("\(prize ?? 0) Coins")
                .font(.system(size: 36, weight: .heavy, design: .default))
                .foregroundStyle(AppColors.gold)
            AppPrimaryButton(title: "Awesome", systemImage: "checkmark") {
                appModel.tapFeedback(); dismiss()
            }
        }
    }

    private func watch() {
        guard !busy else { return }
        busy = true
        note = nil
        appModel.tapFeedback()
        Task { @MainActor in
            // Read the gate BEFORE spinning so the two failure modes can be told
            // apart: still cooling down, versus no rewarded video available.
            let onCooldown = !appModel.canCoinSpin
            let won = await appModel.spinCoinReward()
            busy = false
            guard let won else {
                // Every non-cooldown failure lands here — closed early, failed to
                // load, none available, consent unresolved — and the wheel stays
                // put in all of them. One sentence that is true for each, rather
                // than one that claims a video played when it may not have.
                note = onCooldown
                    ? "Your next free spin is warming up. Try again in a moment."
                    : "No spin yet — the video has to finish to earn your coins. If it didn't load, try again shortly."
                return
            }
            prize = won
            let k = prizes.firstIndex(of: won) ?? 0
            let seg = 360.0 / Double(prizes.count)
            // Bring the winning wedge under the fixed top pointer, after 6 turns.
            let target = 360.0 * 6 - Double(k) * seg

            // Reduce Motion skips the 2.6-second spin outright — six spatial
            // revolutions is exactly the kind of motion that setting exists to
            // suppress — and crossfades straight to the result the pilot won.
            guard !reduceMotion else {
                appModel.haptics.rewardClaim()
                withAnimation(AppMotion.content) { phase = .result }
                return
            }

            phase = .spinning
            withAnimation(.easeOut(duration: 2.6)) { rotation = target }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.75) {
                appModel.haptics.rewardClaim()
                withAnimation(AppMotion.entrance) { phase = .result }
            }
        }
    }
}

/// A premium prize wheel: warm wedges, a gold rim, coin labels, a top pointer and
/// a hub. Purely presentational — the granted prize is decided by the model.
private struct SpinWheel: View {
    let prizes: [Int]
    var rotation: Double

    var body: some View {
        GeometryReader { g in
            let d = min(g.size.width, g.size.height)
            ZStack {
                wheelBody(d: d).rotationEffect(.degrees(rotation))
                pointer(d: d)
                hub(d: d)
            }
            .frame(width: d, height: d)
        }
    }

    private func wheelBody(d: CGFloat) -> some View {
        let n = prizes.count
        let seg = 360.0 / Double(n)
        return ZStack {
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let r = min(size.width, size.height) / 2
                for i in 0..<n {
                    let start = Angle.degrees(Double(i) * seg - 90 - seg / 2)
                    let end = Angle.degrees(Double(i) * seg - 90 + seg / 2)
                    var path = Path()
                    path.move(to: c)
                    path.addArc(center: c, radius: r, startAngle: start, endAngle: end, clockwise: false)
                    path.closeSubpath()
                    let warm = i % 2 == 0 ? Color(hex: 0x3A2E1A) : Color(hex: 0x241B10)
                    ctx.fill(path, with: .color(warm))
                }
                let ring = CGRect(x: c.x - r + 2, y: c.y - r + 2, width: 2 * (r - 2), height: 2 * (r - 2))
                ctx.stroke(Path(ellipseIn: ring), with: .color(AppColors.gold.opacity(0.7)), lineWidth: 3)
            }
            ForEach(0..<n, id: \.self) { i in
                labelView(prizes[i])
                    .rotationEffect(.degrees(Double(i) * seg))
            }
        }
    }

    private func labelView(_ value: Int) -> some View {
        VStack(spacing: 1) {
            FocusCoinIcon(size: 17)
            Text("\(value)")
                .font(.system(size: 13, weight: .heavy, design: .default))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func pointer(d: CGFloat) -> some View {
        Triangle()
            .fill(AppColors.gold)
            .frame(width: 20, height: 18)
            .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
            .offset(y: -d / 2 + 2)
    }

    private func hub(d: CGFloat) -> some View {
        Circle()
            .fill(LinearGradient(colors: [Color(hex: 0xF6D28A), Color(hex: 0xC79A4E)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: d * 0.16, height: d * 0.16)
            .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
    }
}

/// A simple downward-pointing triangle for the wheel pointer.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Coins Boost gift popup

/// The periodic "Coins Boost Gifted" gift: a giant glowing coin, a real 24-hour
/// countdown, the 2× / 1-hour feature block, and one accept button that arms the
/// boost for the pilot's next flight.
struct CoinsBoostPopup: View {
    var onAccept: () -> Void
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var start = Date()
    @State private var glow = false

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            VStack(spacing: AppSpacing.md) {
                Spacer(minLength: 0)
                Text("Coins Boost Gifted")
                    .font(AppTypography.serifTitle2)
                    .foregroundStyle(AppColors.textPrimary)

                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [AppColors.gold.opacity(glow ? 0.55 : 0.3), .clear],
                                             center: .center, startRadius: 2, endRadius: 130))
                        .frame(width: 240, height: 240)
                        .scaleEffect(glow ? 1.05 : 0.95)
                    FocusCoinIcon(size: 118)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(.white)
                        .shadow(color: Color(hex: 0xF2A23C), radius: 6)
                        .offset(y: 2)
                }
                .frame(height: 210)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { glow = true }
                }

                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text("Gift expires in \(countdown(now: ctx.date))")
                        .font(.system(size: 13, weight: .bold, design: .default))
                        .foregroundStyle(AppColors.textSecondary)
                        .monospacedDigit()
                }

                Text("Double your Coins for your next study hour once equipped.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)

                featureBlock

                AppPrimaryButton(title: "Awesome, thanks", systemImage: "bolt.fill") {
                    appModel.tapFeedback(); onAccept(); dismiss()
                }
                Spacer(minLength: 0)
            }
            .padding(AppSpacing.screen)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var featureBlock: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(spacing: 0) {
                Text("2×")
                    .font(.system(size: 44, weight: .heavy, design: .default))
                    .foregroundStyle(AppColors.gold)
                Text("EARNINGS")
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .tracking(1)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Rectangle().fill(AppColors.hairline).frame(width: 1, height: 46)
            VStack(spacing: 2) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.brand)
                Text("1h Max Duration")
                    .font(.system(size: 12, weight: .bold, design: .default))
                    .foregroundStyle(AppColors.textPrimary)
            }
        }
        .padding(.vertical, AppSpacing.md)
        .padding(.horizontal, AppSpacing.lg)
        .background(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
            .fill(AppColors.textPrimary.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
            .strokeBorder(AppColors.gold.opacity(0.3), lineWidth: 1))
    }

    private func countdown(now: Date) -> String {
        let end = start.addingTimeInterval(24 * 60 * 60)
        let r = Int(max(0, end.timeIntervalSince(now)))
        return String(format: "%02d:%02d:%02d", r / 3600, (r % 3600) / 60, r % 60)
    }
}

// MARK: - Equipped-boost side tag (Home, near Start Focus)

/// A subtle side tag shown beside Start Focus while a Coins Boost is armed —
/// a 2× coin and the live countdown until it expires.
struct CoinBoostTag: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            HStack(spacing: 5) {
                FocusCoinIcon(size: 15)
                Text("2×")
                    .font(.system(size: 13, weight: .heavy, design: .default))
                    .foregroundStyle(AppColors.gold)
                Image(systemName: "clock")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                Text(short(appModel.coinBoostRemaining))
                    .font(.system(size: 12, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().fill(Color.black.opacity(0.2)))
            .overlay(Capsule().strokeBorder(AppColors.gold.opacity(0.45), lineWidth: 1))
        }
        .accessibilityLabel("Coins Boost active: double coins on your next flight.")
    }

    private func short(_ r: TimeInterval) -> String {
        let s = Int(max(0, r))
        let h = s / 3600, m = (s % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}
