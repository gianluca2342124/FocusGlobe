import SwiftUI

/// **Friends** — the connection hub. Honest by design: until the presence /
/// referral backend ships, this screen shows the pilot's real invite progress
/// per Sky and a clean empty state — never invented friends.
struct FriendsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter

    private var lockedSkies: [FocusSky] { FocusSky.all.filter { !appModel.isSkyUnlocked($0) } }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    ScreenHeader(title: "Friends", subtitle: "Fly together, unlock Skies together")
                    inviteHero
                    if !lockedSkies.isEmpty { skyInvitesSection }
                    friendsSection
                }
                .padding(AppSpacing.screen)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xxl)
                .contentMaxWidth()
            }
        }
        .focusScreenChrome()
    }

    private var inviteHero: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                ZStack {
                    Circle().fill(AppColors.gold.opacity(0.16)).frame(width: 48, height: 48)
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(AppColors.gold)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Invite your friends")
                        .font(AppTypography.serifTitle2)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("3 accepted invites unlock the Sky you shared.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
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

    /// Per-Sky invite progress — each locked Sky earns its own three.
    private var skyInvitesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionLabel(text: "Sky invites")
            VStack(spacing: AppSpacing.xs) {
                ForEach(lockedSkies) { sky in
                    skyInviteRow(sky)
                }
            }
        }
    }

    private func skyInviteRow(_ sky: FocusSky) -> some View {
        let progress = appModel.inviteProgress(for: sky)
        return HStack(spacing: AppSpacing.sm) {
            Circle()
                .fill(LinearGradient(colors: sky.paletteColors, startPoint: .top, endPoint: .bottom))
                .frame(width: 30, height: 30)
                .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(sky.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                HStack(spacing: 5) {
                    ForEach(0..<SkyUnlock.invitesNeeded, id: \.self) { i in
                        Circle()
                            .fill(i < progress ? AppColors.gold : AppColors.textPrimary.opacity(0.14))
                            .frame(width: 7, height: 7)
                    }
                    Text("\(progress)/\(SkyUnlock.invitesNeeded)")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            Spacer()
            ShareLink(item: appModel.inviteShareMessage(for: sky)) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.gold)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(AppColors.gold.opacity(0.12)))
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .glassBackground(cornerRadius: 18, tintOpacity: 0.22, shadowRadius: 6, shadowY: 3)
    }

    /// Real friends only — an honest empty state until the backend exists.
    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionLabel(text: "Your crew")
            AppGlassCard {
                VStack(spacing: AppSpacing.xs) {
                    Image(systemName: "airplane.departure")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppColors.brand)
                    Text("No crew yet")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Friends who join from your invite will appear here — and in your Sky.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xs)
            }
        }
    }
}
