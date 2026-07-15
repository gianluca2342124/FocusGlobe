import SwiftUI

/// The friendly offline/unavailable state for online surfaces. Solo is always
/// one tap away; no raw errors, no blocking spinners, and never a "Sign in with
/// Apple" prompt — FocusGlobe Online uses the device's own iCloud account.
struct OnlineUnavailableView: View {
    let availability: CloudAvailability
    /// Full card (mode selector / invite sheet) vs. one compact banner (Friends).
    var compact: Bool = false
    var onSolo: (() -> Void)? = nil
    var onLearnHow: (() -> Void)? = nil

    private var isNoAccount: Bool { availability == .noAccount }

    private var title: String {
        isNoAccount ? "iCloud is required for Online Flights" : "You're offline"
    }
    private var body_: String {
        isNoAccount
            ? "Sign in to iCloud in your device settings to fly with other pilots. Solo Flights always work offline."
            : "Reconnect to fly with other pilots. Solo Flights always work offline."
    }
    private var icon: String { isNoAccount ? "icloud.slash" : "wifi.slash" }

    var body: some View {
        if compact { banner } else { card }
    }

    // One compact line for pages that shouldn't be dominated by the state.
    private var banner: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.textTertiary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.85)
                Text("Solo Flights always work offline.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .lineLimit(1).minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 10)
        .glassBackground(cornerRadius: 14, tintOpacity: 0.16, shadowRadius: 4, shadowY: 2)
    }

    private var card: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(AppColors.textTertiary)
                .padding(.bottom, 4)
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            Text(body_)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            HStack(spacing: AppSpacing.sm) {
                if let onSolo {
                    Button("Continue Solo") { onSolo() }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.gold)
                }
                if let onLearnHow {
                    Button("Learn how") { onLearnHow() }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.lg)
    }
}
