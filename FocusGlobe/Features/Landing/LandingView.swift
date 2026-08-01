import SwiftUI
import UIKit

/// The completion sequence — a minimal, premium two-card flow over the **frozen**
/// Sky the pilot just flew. First a "Success!" card (Time · Focus Coins ·
/// Focus Type, with an optional rewarded "Double" ), then a streak card; a single
/// completion interstitial plays for free users before returning Home. No
/// postcards, no passport/share buttons, no old "You landed" screen.
struct LandingView: View {
    let summary: LandingSummary

    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.focusViewport) private var viewport

    @State private var earnedMiles: Int
    @State private var adState: AdState = .available
    @State private var phase: Phase = .success
    @State private var appeared = false
    /// True once the user watched the rewarded "double" ad — used to skip the
    /// completion interstitial so two ads never stack in one landing.
    @State private var didWatchRewarded = false

    private enum AdState { case available, loading, doubled }
    private enum Phase { case success, streak }

    init(summary: LandingSummary) {
        self.summary = summary
        _earnedMiles = State(initialValue: summary.baseMiles)
    }

    private var matchedSky: FocusSky { FocusSky.matching(routeID: summary.route.id) ?? .defaultFree }

    var body: some View {
        ZStack {
            // The Sky the pilot just flew, held frozen behind a soft scrim.
            SkyFlightSceneView(
                sky: matchedSky,
                elapsed: { 24 },
                animated: false,
                presentationMode: .completion,
                renderQuality: .still
            )
                .overlay(Color.black.opacity(0.5).ignoresSafeArea())
                .allowsHitTesting(false)

            if phase == .success && !reduceMotion {
                LandingConfettiView(colors: [matchedSky.glowColor, AppColors.gold, .white])
                    .allowsHitTesting(false)
            }

            Group {
                switch phase {
                case .success: successCard
                case .streak:  streakCard
                }
            }
            .padding(viewport.pagePadding)
            .frame(maxWidth: viewport.modalWidth)
            .frame(maxWidth: .infinity)
            .scaleEffect(appeared ? 1 : 0.96)
            .opacity(appeared ? 1 : 0)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.05)) { appeared = true }
            appModel.haptics.rewardClaim()
        }
    }

    // MARK: Success card

    private var successCard: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("Success!")
                // The app's modern display language (bold rounded, like every
                // page title) — not the old serif treatment.
                .font(.system(size: viewport.modalTitleSize, weight: .bold, design: .default))
                .foregroundStyle(AppColors.textPrimary)

            HStack(spacing: 0) {
                statTile(icon: "clock.fill",
                         value: Formatters.durationLabel(minutes: max(1, summary.focusedMinutes)),
                         label: "Time", tint: AppColors.brand)
                divider
                coinTile
                divider
                // The third stat is the session's real Focus Type (its chosen
                // preset — Fly / Study / Work / …), never a duplicate of Time.
                statTile(icon: focusTypeIcon,
                         value: focusTypeName,
                         label: "Focus Type", tint: AppColors.teal)
            }
            .padding(.vertical, AppSpacing.md)
            .glassBackground(cornerRadius: AppSpacing.cardRadius, tintOpacity: 0.2, shadowRadius: 12, shadowY: 6)

            VStack(spacing: AppSpacing.sm) {
                // The app's signature capsule CTA — arrow AFTER the text, no
                // wax-seal dot, same button language as everywhere else.
                AppPrimaryButton(title: "Continue", systemImage: "arrow.right", iconTrailing: true) {
                    appModel.uiSound.play(.claim)
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { phase = .streak }
                }
                .frame(minHeight: viewport.buttonHeight)
                if !appModel.isPro { doubleReward }
            }
        }
        .padding(viewport.modalPadding)
        .glassBackground(cornerRadius: 28, tint: AppColors.goldFoil, tintOpacity: 0.12,
                         shadowRadius: 26, shadowY: 14)
    }

    private var coinTile: some View {
        VStack(spacing: 3) {
            FocusCoinIcon(size: 22)
            Text(Formatters.miles(earnedMiles))
                .font(.system(size: viewport.isWide ? 23 : 19, weight: .bold, design: .default))
                .foregroundStyle(AppColors.textPrimary)
                .contentTransition(.numericText())
            Text(adState == .doubled ? "Coins ×2" : "Focus Coins")
                .font(AppTypography.micro).foregroundStyle(AppColors.textTertiary)
            // Only when the multiplier genuinely paid out on THIS landing, so
            // the badge can never appear over a single-rate number.
            if summary.proMultiplierApplied {
                Text("2× PRO Coins")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.3)
                    .foregroundStyle(AppColors.gold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(AppColors.gold.opacity(0.14)))
                    .padding(.top, 1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func statTile(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(tint)
            Text(value)
                .font(.system(size: viewport.isWide ? 23 : 19, weight: .bold, design: .default))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(AppTypography.micro).foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    /// The session's Focus Type — its chosen preset title. A plain flight with no
    /// preset defaults to the app's default preset, "Fly" (never a fabricated one).
    private var focusTypeName: String {
        let t = summary.intention?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (t?.isEmpty == false) ? t! : "Fly"
    }
    private var focusTypeIcon: String {
        FocusPreset.all.first { $0.title == focusTypeName }?.systemImage ?? "paperplane.fill"
    }

    private var divider: some View {
        Rectangle().fill(AppColors.hairline).frame(width: 1, height: 40)
    }

    // The rewarded "Double" — X highlighted in accent; fails gracefully if no ad.
    private var doubleReward: some View {
        Button {
            appModel.tapFeedback()
            Task { await watchAdToDouble() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: adState == .doubled ? "checkmark" : "bolt.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(adState == .doubled ? AppColors.success : AppColors.gold)
                if adState == .loading {
                    Text("Playing…").font(AppTypography.headline).foregroundStyle(AppColors.textSecondary)
                } else if adState == .doubled {
                    Text("Coins doubled").font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                } else {
                    HStack(spacing: 4) {
                        Text("Double to").font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                        Text("\(summary.baseMiles * 2)").font(AppTypography.headline).foregroundStyle(AppColors.gold)
                        Text("Coins").font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                    }
                    adBadge
                }
            }
            .frame(maxWidth: .infinity).frame(height: max(52, viewport.buttonHeight - 4))
            .glassBackground(cornerRadius: AppSpacing.pillRadius, tintOpacity: 0.18, shadowRadius: 8, shadowY: 4)
            .overlay(RoundedRectangle(cornerRadius: AppSpacing.pillRadius, style: .continuous)
                .strokeBorder(AppColors.gold.opacity(adState == .doubled ? 0 : 0.35), lineWidth: 1))
        }
        .buttonStyle(SoftPressStyle())
        .disabled(adState != .available)
    }

    private var adBadge: some View {
        Text("AD")
            .font(.system(size: 9, weight: .heavy, design: .default))
            .foregroundStyle(AppColors.textTertiary)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 4)
                .strokeBorder(AppColors.textTertiary.opacity(0.5), lineWidth: 1))
    }

    // MARK: Streak card

    private var streakCard: some View {
        VStack(spacing: AppSpacing.lg) {
            ZStack {
                Circle().fill(RadialGradient(colors: [Color(hex: 0xF2643C).opacity(0.35), .clear],
                                             center: .center, startRadius: 2, endRadius: 80))
                    .frame(width: 140, height: 140)
                Image(systemName: "flame.fill")
                    .font(.system(size: viewport.isWide ? 82 : (viewport.isCompact ? 60 : 72),
                                  weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFB65C), Color(hex: 0xF2643C)],
                                                    startPoint: .top, endPoint: .bottom))
                    .shadow(color: Color(hex: 0xF2643C).opacity(0.5), radius: 16)
            }
            Text("\(summary.streak)-day streak")
                .font(.system(size: viewport.titleSize - 3, weight: .bold, design: .default))
                .foregroundStyle(AppColors.textPrimary)
            // The recent week at a glance — the SAME strip as the Streak popup,
            // so the day just landed glows here immediately.
            StreakWeekStrip(history: appModel.history)
            VStack(spacing: 5) {
                Text("“\(streakQuote.text)”")
                    .font(AppTypography.serifBody)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("— \(streakQuote.author)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(.horizontal, AppSpacing.xs)
            AppPrimaryButton(title: "Continue", systemImage: "arrow.right", iconTrailing: true) {
                finish()
            }
            .frame(minHeight: viewport.buttonHeight)
        }
        .padding(viewport.modalPadding)
        .glassBackground(cornerRadius: 28, tint: AppColors.goldFoil, tintOpacity: 0.1,
                         shadowRadius: 26, shadowY: 14)
    }

    /// Real, properly attributed words — rotated deterministically by streak
    /// length, so the card stays fresh without ever inventing an author.
    private var streakQuote: (text: String, author: String) {
        let quotes: [(String, String)] = [
            ("We are what we repeatedly do. Excellence, then, is not an act, but a habit.",
             "Will Durant"),
            ("Success is the sum of small efforts, repeated day in and day out.",
             "Robert Collier"),
            ("Habit is a cable; we weave a thread of it every day, and at last we cannot break it.",
             "Horace Mann"),
            ("Rivers know this: there is no hurry. We shall get there some day.",
             "A. A. Milne"),
            ("It does not matter how slowly you go as long as you do not stop.",
             "Confucius"),
        ]
        return quotes[max(0, summary.streak) % quotes.count]
    }

    // MARK: Flow

    private func finish() {
        appModel.haptics.rewardClaim()
        let go = { router.finishToHome() }
        // One post-flight ad opportunity per journey: if the Double-Coins
        // rewarded ad was already watched (or any attempt was used), skip the
        // interstitial so two ads never stack. Otherwise this is the attempt.
        if appModel.postFlightAdSatisfied {
            go()
        } else {
            appModel.postFlightAdSatisfied = true
            appModel.ads.presentJourneyCompleteInterstitial(isPro: appModel.isPro) { go() }
        }
    }

    private func watchAdToDouble() async {
        adState = .loading
        let success = await appModel.watchRewardedAd()
        if success {
            didWatchRewarded = true
            appModel.grantBonusMiles(for: summary)
            appModel.haptics.rewardClaim()
            appModel.uiSound.play(.claim)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                earnedMiles = summary.baseMiles * 2
                adState = .doubled
            }
        } else {
            adState = .available   // no ad (e.g. simulator) — leave the offer intact
        }
    }
}

/// A tasteful, one-shot confetti burst — small soft pieces in the Sky/gold
/// palette that drift down and fade once on appear.
private struct LandingConfettiView: View {
    let colors: [Color]
    private let pieces: [Piece]
    @State private var go = false

    struct Piece: Identifiable {
        let id = UUID()
        let x: CGFloat
        let size: CGFloat
        let delay: Double
        let drift: CGFloat
        let spin: Double
        let color: Color
    }

    init(colors: [Color]) {
        self.colors = colors
        var rng = SystemRandomNumberGenerator()
        let palette = colors.isEmpty ? [Color.white] : colors
        self.pieces = (0..<44).map { _ in
            Piece(x: .random(in: 0.03...0.97, using: &rng),
                  size: .random(in: 5...9, using: &rng),
                  delay: .random(in: 0...0.45, using: &rng),
                  drift: .random(in: -36...36, using: &rng),
                  spin: .random(in: 180...520, using: &rng),
                  color: palette.randomElement(using: &rng) ?? .white)
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { p in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(p.color)
                        .frame(width: p.size, height: p.size * 1.7)
                        .rotationEffect(.degrees(go ? p.spin : 0))
                        .position(x: geo.size.width * p.x + (go ? p.drift : 0),
                                  y: go ? geo.size.height + 40 : -50)
                        .opacity(go ? 0 : 1)
                        .animation(.easeIn(duration: 2.3).delay(p.delay), value: go)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { go = true }
    }
}
