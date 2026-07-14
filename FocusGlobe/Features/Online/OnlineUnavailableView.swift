import SwiftUI

/// The friendly offline/unavailable state for online surfaces. Solo is always
/// one tap away; no raw errors, no blocking spinners.
struct OnlineUnavailableView: View {
    let availability: CloudAvailability
    var onSolo: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: availability == .noAccount ? "icloud.slash" : "wifi.slash")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(AppColors.textTertiary)
                .padding(.bottom, 4)
            Text(availability.userMessage)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            Text("You can continue flying Solo without an internet connection.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            if let onSolo {
                Button("Switch to Solo") { onSolo() }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.gold)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.lg)
    }
}
