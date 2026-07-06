import SwiftUI
import UIKit

/// The arrival screen — a "destination postcard unlocked" reward moment. The
/// hero is the premium postcard with a passport-style LANDED stamp; stats are
/// quiet; the ad action is demoted to a subtle secondary option.
struct LandingView: View {
    let summary: LandingSummary

    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter

    @State private var earnedMiles: Int
    @State private var adState: AdState = .available
    @State private var appeared = false
    @State private var celebrateStreak = false
    @State private var shareImage: UIImage?
    @State private var showShare = false
    /// True once the user watched the rewarded "double miles" ad — used to skip
    /// the completion interstitial so two ads never stack in one landing.
    @State private var didWatchRewarded = false

    private enum AdState { case available, loading, doubled }

    init(summary: LandingSummary) {
        self.summary = summary
        _earnedMiles = State(initialValue: summary.baseMiles)
    }

    private var theme: RouteTheme { summary.route.colorTheme }

    var body: some View {
        ZStack {
            AppBackground()
            RadialGradient(colors: [theme.soft.opacity(0.32), .clear],
                           center: .top, startRadius: 8, endRadius: 380)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    title
                    if summary.streakIncreased { streakCelebration }
                    heroPostcard
                    statsStrip
                    actions
                }
                .padding(AppSpacing.screen)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xxl)
                .contentMaxWidth(Layout.readable)   // wider centred column on iPad/Mac
            }

            // A premium, one-shot confetti burst when the landing appears.
            LandingConfettiView(colors: [theme.accent, theme.soft, AppColors.gold, .white])
                .allowsHitTesting(false)
        }
        .focusScreenChrome()
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.05)) { appeared = true }
            if summary.streakIncreased {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.55).delay(0.35)) { celebrateStreak = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { appModel.haptics.tap() }
            }
        }
        .sheet(isPresented: $showShare) {
            if let shareImage { ActivityView(items: [shareImage, shareText]) }
        }
    }

    private var title: some View {
        VStack(spacing: 4) {
            Text("You've arrived.")
                .font(AppTypography.serifHero)
                .foregroundStyle(AppColors.textPrimary)
            Text("\(summary.originName)  →  \(summary.route.destinationName)")
                .font(AppTypography.subhead)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // A calm one-time streak moment — a warm flame pill that springs in with a
    // soft glow. No confetti; premium and quiet.
    private var streakCelebration: some View {
        StreakPill(days: summary.streak)
            .scaleEffect(celebrateStreak ? 1 : 0.5)
            .opacity(celebrateStreak ? 1 : 0)
            .shadow(color: Color(hex: 0xF2643C).opacity(celebrateStreak ? 0.55 : 0), radius: 16, y: 0)
            .frame(maxWidth: .infinity)
    }

    private var heroPostcard: some View {
        DestinationPostcard(title: summary.postcard.title, place: summary.postcard.place,
                            mood: summary.postcard.mood, theme: theme,
                            landmark: summary.postcard.landmark ?? .generic)
            .overlay(alignment: .topLeading) { landedStamp.padding(AppSpacing.md) }
            .scaleEffect(appeared ? 1 : 0.94)
            .opacity(appeared ? 1 : 0)
    }

    private var landedStamp: some View {
        Text("ARRIVED")
            .font(.system(size: 13, weight: .heavy, design: .serif))
            .tracking(1.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.85), lineWidth: 2))
            .rotationEffect(.degrees(-8))
            .opacity(0.9)
    }

    private var statsStrip: some View {
        HStack(spacing: 0) {
            stat(value: "\(summary.focusedMinutes)", unit: "min", label: "Focused")
            divider
            stat(value: Formatters.distance(km: summary.distanceKm), unit: "", label: "Distance")
            divider
            stat(value: Formatters.miles(earnedMiles), unit: "", label: adState == .doubled ? "Miles ×2" : "Miles")
            divider
            stat(value: "\(summary.streak)", unit: summary.streak == 1 ? "day" : "days", label: "Streak")
        }
        .padding(.vertical, AppSpacing.md)
        .frame(maxWidth: .infinity)
        .glassBackground(cornerRadius: AppSpacing.cardRadius, tintOpacity: 0.18, shadowRadius: 10, shadowY: 5)
    }

    private func stat(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                if !unit.isEmpty {
                    Text(unit).font(AppTypography.micro).foregroundStyle(AppColors.textSecondary)
                }
            }
            Text(label).font(AppTypography.micro).foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(AppColors.hairline).frame(width: 1, height: 28)
    }

    private var actions: some View {
        VStack(spacing: AppSpacing.sm) {
            ExpeditionButton(title: "Claim Miles", systemImage: "checkmark") {
                appModel.haptics.rewardClaim()
                appModel.uiSound.play(.claim)
                appModel.analytics.log(.rewardClaimed, ["route": summary.route.id, "miles": earnedMiles])
                finish(toPassport: false)
            }
            // Double-your-miles sits directly under Claim Miles.
            if !appModel.isPro { doubleReward }
            HStack(spacing: AppSpacing.sm) {
                AppSecondaryButton(title: "Share Postcard", systemImage: "square.and.arrow.up") {
                    sharePostcard()
                }
                AppSecondaryButton(title: "Field Journal", systemImage: "book.closed") {
                    appModel.tapFeedback()
                    finish(toPassport: true)
                }
            }
        }
    }

    // A real secondary reward card. The headline never says "ad"; a small AD
    // badge keeps it transparent, and the final doubled total is shown up front.
    private var doubleReward: some View {
        Button {
            appModel.tapFeedback()
            Task { await watchAdToDouble() }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                ZStack {
                    Circle().fill(AppColors.gold.opacity(0.16)).frame(width: 42, height: 42)
                    Image(systemName: adState == .doubled ? "checkmark" : "bolt.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(adState == .doubled ? AppColors.success : AppColors.gold)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(adState == .doubled ? "Miles doubled" : "Double your miles")
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.textPrimary)
                        if adState == .available { adBadge }
                    }
                    Text(doubleRewardSubtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                if adState == .loading {
                    ProgressView().controlSize(.small).tint(AppColors.textSecondary)
                } else if adState == .available {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity)
            .glassBackground(cornerRadius: AppSpacing.cardRadius, tintOpacity: 0.18, shadowRadius: 10, shadowY: 5)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                    .strokeBorder(AppColors.gold.opacity(adState == .doubled ? 0 : 0.35), lineWidth: 1)
            )
        }
        .buttonStyle(SoftPressStyle())
        .disabled(adState != .available)
    }

    private var doubleRewardSubtitle: String {
        switch adState {
        case .doubled: return "Now \(Formatters.miles(earnedMiles)) miles"
        case .loading: return "Playing…"
        case .available: return "Double to \(Formatters.miles(summary.baseMiles * 2)) miles"
        }
    }

    private var adBadge: some View {
        Text("AD")
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .foregroundStyle(AppColors.textTertiary)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 4)
                .strokeBorder(AppColors.textTertiary.opacity(0.5), lineWidth: 1))
    }

    private var shareText: String {
        "I just drifted to \(summary.route.destinationName) on FocusGlobe — \(summary.focusedMinutes) min focused."
    }

    @MainActor private func sharePostcard() {
        appModel.haptics.tap()
        let card = DestinationPostcard(title: summary.postcard.title, place: summary.postcard.place,
                                       mood: summary.postcard.mood, theme: theme,
                                       landmark: summary.postcard.landmark ?? .generic)
            .frame(width: 360, height: 172)
        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale
        if let image = renderer.uiImage {
            shareImage = image
            showShare = true
        }
    }

    /// Leave the Landing screen. Free users see a single completion interstitial
    /// here — unless they already watched the rewarded "double miles" ad, in which
    /// case it is skipped so two ads never stack in one landing. (Pro users are
    /// skipped inside `presentJourneyCompleteInterstitial`.)
    private func finish(toPassport: Bool) {
        let go = { toPassport ? router.finishToPassport() : router.finishToHome() }
        if didWatchRewarded {
            go()
        } else {
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
            adState = .available
        }
    }
}

/// A thin UIKit share-sheet wrapper.
private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// A tasteful, one-shot confetti burst for the landing screen — small soft
/// pieces in the route/gold palette that drift down and fade once on appear.
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
