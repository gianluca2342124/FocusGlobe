import SwiftUI

/// **Friends** — the connection hub. Honest by design: until the presence /
/// referral backend ships, this screen shows a clean invite hero, a cute empty
/// state, a simple 3-step "how it works", and the fly-together incentive —
/// never invented friends, and no per-Sky invite counters (those live on each
/// Sky's own unlock sheet now).
struct FriendsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    ScreenHeader(title: "Friends", subtitle: "Focus feels better together", showsBack: false)
                    emptyState
                    inviteHero
                    howItWorks
                }
                .padding(AppSpacing.screen)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xxl)
                .contentMaxWidth()
            }
        }
        .focusScreenChrome()
    }

    // A cute, lonely-but-warm empty state until real crew exists.
    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle().fill(AppColors.gold.opacity(0.12)).frame(width: 96, height: 96)
                LonelyBalloonFace()
                    .frame(width: 70, height: 84)
            }
            Text("No crew yet")
                .font(AppTypography.serifTitle2)
                .foregroundStyle(AppColors.textPrimary)
            Text("Invite a friend and your next flight can feel less lonely.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
    }

    private var inviteHero: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: 7) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.gold)
                Text("Fly with a friend to earn 2× Focus Coins.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textPrimary)
            }
            ShareLink(item: appModel.inviteShareMessage(for: appModel.selectedSky)) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .bold))
                    Text("Share your invite")
                        .font(AppTypography.headline)
                }
                .foregroundStyle(AppColors.ctaText)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(RoundedRectangle(cornerRadius: AppSpacing.pillRadius, style: .continuous)
                    .fill(AppColors.ctaFill))
            }
            .simultaneousGesture(TapGesture().onEnded { appModel.tapFeedback() })
            Text("Invite code \(appModel.referralCode())")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppColors.textTertiary)
                .frame(maxWidth: .infinity)
        }
        .padding(AppSpacing.lg)
        .glassBackground(cornerRadius: AppSpacing.cardRadius, tintOpacity: 0.24,
                         shadowRadius: 14, shadowY: 8)
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionLabel(text: "How it works")
            VStack(spacing: AppSpacing.xs) {
                stepRow(1, icon: "square.and.arrow.up", title: "Share your invite",
                        subtitle: "Send your link to a friend.")
                stepRow(2, icon: "person.badge.plus", title: "Friend joins FocusGlobe",
                        subtitle: "They open the link and start flying.")
                stepRow(3, icon: "sparkles", title: "Fly together and earn more",
                        subtitle: "Shared flights earn 2× Focus Coins.")
            }
        }
    }

    private func stepRow(_ n: Int, icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle().fill(AppColors.gold.opacity(0.16)).frame(width: 34, height: 34)
                Text("\(n)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.gold)
            }
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .glassBackground(cornerRadius: 18, tintOpacity: 0.22, shadowRadius: 6, shadowY: 3)
    }
}

/// A tiny procedural balloon with a wistful face for the Friends empty state.
private struct LonelyBalloonFace: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                BalloonEnvelope()
                    .fill(LinearGradient(colors: [AppColors.balloonWhite, Color(hex: 0xE7DCC6)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: w, height: h * 0.82)
                    .position(x: w / 2, y: h * 0.41)
                // Two soft eyes + a small downturned mouth.
                Circle().fill(Color(hex: 0x4A4038)).frame(width: w * 0.07, height: w * 0.07)
                    .position(x: w * 0.38, y: h * 0.36)
                Circle().fill(Color(hex: 0x4A4038)).frame(width: w * 0.07, height: w * 0.07)
                    .position(x: w * 0.62, y: h * 0.36)
                MouthShape()
                    .stroke(Color(hex: 0x4A4038), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: w * 0.26, height: h * 0.08)
                    .position(x: w / 2, y: h * 0.5)
            }
        }
    }
}

private struct MouthShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                       control: CGPoint(x: rect.midX, y: rect.minY))
        return p
    }
}
