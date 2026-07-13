import SwiftUI

// MARK: - Free Coin Spin button (Home, near the streak)

/// A small, attractive rewarded-ad entry point that lives in the Home top-left
/// beside the streak. A video symbol wearing a Focus Coin, with a gentle shake
/// roughly every ~3 s so it invites a tap without ever dominating Home.
struct CoinSpinButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(systemName: "video.fill")
                    .font(.system(size: Layout.pad(15, 17), weight: .bold))
                    .foregroundStyle(.white)
                FocusCoinIcon(size: Layout.pad(14, 16))
                    .offset(x: Layout.pad(9, 10), y: -Layout.pad(8, 9))
            }
            .frame(width: Layout.pad(26, 30), height: Layout.pad(24, 27))
            .padding(.horizontal, Layout.pad(10, 13))
            .padding(.vertical, Layout.pad(7, 9))
            .background(Capsule().fill(LinearGradient(
                colors: [Color(hex: 0xF2A23C), Color(hex: 0xE9654B)],
                startPoint: .top, endPoint: .bottom)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.28), lineWidth: 1))
            .shadow(color: Color(hex: 0xF2A23C).opacity(0.5), radius: 8, y: 2)
        }
        .buttonStyle(SoftPressStyle())
        .phaseAnimator([0, 1, 2, 3, 4]) { content, phase in
            content.rotationEffect(.degrees(shakeAngle(phase)))
        } animation: { phase in
            // The long rest (phase 0) sets the ~3 s cadence; 1–4 are the quick shake.
            phase == 0 ? .easeInOut(duration: 2.6) : .spring(response: 0.14, dampingFraction: 0.32)
        }
        .accessibilityLabel("Free Coin Spin. Watch a video to win Focus Coins.")
    }

    private func shakeAngle(_ p: Int) -> Double {
        switch p {
        case 1: return -12
        case 2: return 12
        case 3: return -8
        case 4: return 8
        default: return 0
        }
    }
}

// MARK: - Free Coin Spin sheet (video → wheel → result)

struct CoinSpinSheet: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    private enum Phase { case intro, spinning, result }
    @State private var phase: Phase = .intro
    @State private var rotation: Double = 0
    @State private var prize: Int? = nil
    @State private var note: String? = nil
    @State private var busy = false

    private let prizes = [1, 2, 3, 4, 5, 10, 15, 20, 25]

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            VStack(spacing: AppSpacing.lg) {
                header
                switch phase {
                case .intro:    intro
                case .spinning: spinning
                case .result:   result
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

    private var header: some View {
        HStack {
            Text("Free Coin Spin")
                .font(AppTypography.serifTitle2)
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            Button { appModel.tapFeedback(); dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .padding(.top, AppSpacing.md)
    }

    private var intro: some View {
        VStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [AppColors.gold.opacity(0.30), .clear],
                                         center: .center, startRadius: 2, endRadius: 120))
                    .frame(width: 220, height: 220)
                Image(systemName: "video.fill")
                    .font(.system(size: 62, weight: .bold))
                    .foregroundStyle(AppColors.brand)
                HStack(spacing: -10) {
                    FocusCoinIcon(size: 32)
                    FocusCoinIcon(size: 44)
                    FocusCoinIcon(size: 32)
                }
                .offset(y: 56)
            }
            .frame(height: 200)
            Text("Watch a short video for 1 prize spin.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            Text("Win up to 25 FocusCoins.")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.gold)
            if let note {
                Text(note)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            AppPrimaryButton(title: busy ? "Loading…" : "Watch video", systemImage: "play.fill") {
                watch()
            }
            .disabled(busy)
            Button("No thanks") { appModel.tapFeedback(); dismiss() }
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textTertiary)
        }
    }

    private var spinning: some View {
        VStack(spacing: AppSpacing.lg) {
            SpinWheel(prizes: prizes, rotation: rotation)
                .frame(width: 264, height: 264)
                .padding(.top, AppSpacing.lg)
            Text("Spinning…")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private var result: some View {
        VStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [AppColors.gold.opacity(0.4), .clear],
                                         center: .center, startRadius: 2, endRadius: 120))
                    .frame(width: 220, height: 220)
                FocusCoinIcon(size: 96)
            }
            .frame(height: 200)
            Text("You won")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
            Text("\(prize ?? 0) FocusCoins")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
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
            let won = await appModel.spinCoinReward()
            busy = false
            guard let won else {
                note = "No video available right now. Please try again soon."
                return
            }
            prize = won
            let k = prizes.firstIndex(of: won) ?? 0
            let seg = 360.0 / Double(prizes.count)
            // Bring the winning wedge under the fixed top pointer, after 6 turns.
            let target = 360.0 * 6 - Double(k) * seg
            phase = .spinning
            withAnimation(.easeOut(duration: 2.6)) { rotation = target }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.75) {
                appModel.haptics.rewardClaim()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { phase = .result }
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
                .font(.system(size: 13, weight: .heavy, design: .rounded))
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
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                        .monospacedDigit()
                }

                Text("Double your FocusCoins for your next study hour once equipped.")
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
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.gold)
                Text("EARNINGS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Rectangle().fill(AppColors.hairline).frame(width: 1, height: 46)
            VStack(spacing: 2) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.brand)
                Text("1h Max Duration")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
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
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.gold)
                Image(systemName: "clock")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                Text(short(appModel.coinBoostRemaining))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
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
