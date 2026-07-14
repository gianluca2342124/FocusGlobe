import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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

    // A warm, prominent empty state until real crew exists.
    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            crewHero
            Text("No crew yet")
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
            Text("Invite a friend and your next flight can feel less lonely.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
    }

    /// The large `nocrew` hero if present, else the procedural lonely balloon over
    /// a soft diffused glow (never a hard circle).
    @ViewBuilder private var crewHero: some View {
        #if canImport(UIKit)
        if let ui = UIImage(named: "nocrew") {
            Image(uiImage: ui).resizable().scaledToFit()
                .frame(maxHeight: Layout.pad(190, 250))
        } else {
            crewFallback
        }
        #else
        crewFallback
        #endif
    }

    private var crewFallback: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [AppColors.gold.opacity(0.24), .clear],
                                     center: .center, startRadius: 2, endRadius: 100))
                .frame(width: 170, height: 170).blur(radius: 10)
            LonelyBalloonFace().frame(width: 96, height: 116)
        }
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

    // A single connected "journey" — numbered gold nodes linked by a flight line,
    // not three separate settings-style rows.
    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("How it works")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
            VStack(spacing: 0) {
                stepNode(1, icon: "square.and.arrow.up", title: "Share your invite",
                         subtitle: "Send your link to a friend.", connector: true)
                stepNode(2, icon: "person.badge.plus", title: "Friend joins",
                         subtitle: "They open the link and start flying.", connector: true)
                stepNode(3, icon: "sparkles", title: "Fly together — earn 2×",
                         subtitle: "Shared flights earn double Focus Coins.", connector: false)
            }
            .padding(AppSpacing.md)
            .glassBackground(cornerRadius: AppSpacing.cardRadius, tintOpacity: 0.2, shadowRadius: 10, shadowY: 5)
        }
    }

    private func stepNode(_ n: Int, icon: String, title: String, subtitle: String, connector: Bool) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(AppColors.gold).frame(width: 40, height: 40)
                    Text("\(n)")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: 0x2B2510))
                }
                if connector {
                    Rectangle().fill(AppColors.gold.opacity(0.4)).frame(width: 2, height: 32)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppColors.gold)
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                }
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.top, 3)
            Spacer(minLength: 0)
        }
        .padding(.bottom, connector ? 0 : 3)
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
