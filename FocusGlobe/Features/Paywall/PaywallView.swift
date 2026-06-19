import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false

    private let benefits: [(String, String)] = [
        ("nosign", "No ads, ever"),
        ("map.fill", "All premium routes unlocked"),
        ("infinity", "Long & ultra focus, up to 12 hours"),
        ("music.note", "Premium ambient soundscapes"),
        ("balloon.fill", "Premium balloon & airship skins"),
        ("globe.europe.africa.fill", "The full Globe Passport"),
        ("rectangle.3.group.fill", "Widgets, Live Activities & Dynamic Island"),
    ]

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    header
                    benefitsCard
                    Spacer(minLength: AppSpacing.md)
                    purchaseArea
                }
                .padding(AppSpacing.screen)
                .padding(.top, AppSpacing.md)
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear { appModel.analytics.log(.paywallOpened) }
    }

    private var header: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack {
                Spacer()
                AppIconButton(systemImage: "xmark", size: 38, accessibilityLabel: "Close") { dismiss() }
            }
            BalloonView(height: 132, showBurner: true, showGlow: true,
                        glow: AppColors.brand.opacity(0.85))
                .padding(.bottom, AppSpacing.xs)
            Text("FocusGlobe Pro")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)
            Text("Unlock every route and keep the skies ad-free.")
                .font(AppTypography.subhead)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var benefitsCard: some View {
        AppGlassCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                ForEach(benefits, id: \.1) { benefit in
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: benefit.0)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.brand)
                            .frame(width: 26)
                        Text(benefit.1)
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppColors.success)
                    }
                }
            }
        }
    }

    @ViewBuilder private var purchaseArea: some View {
        if appModel.isPro {
            VStack(spacing: AppSpacing.sm) {
                Label("You're a Pro member", systemImage: "checkmark.seal.fill")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.success)
                AppSecondaryButton(title: "Close") { dismiss() }
            }
        } else {
            VStack(spacing: AppSpacing.sm) {
                Text("Founder's price · $3.99 / month")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                AppPrimaryButton(title: "Start FocusGlobe Pro",
                                 systemImage: "sparkles",
                                 isLoading: isPurchasing) {
                    Task { await purchase() }
                }
                Button("Restore Purchases") {
                    Task { _ = await appModel.restorePurchases() }
                }
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)

                Text("Mock purchase for the MVP — no real charge. Replace with StoreKit before release.")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
        }
    }

    private func purchase() async {
        isPurchasing = true
        let ok = await appModel.goPro()
        isPurchasing = false
        if ok {
            appModel.haptics.rewardClaim()
            dismiss()
        }
    }
}
