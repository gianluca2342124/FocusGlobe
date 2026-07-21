import SwiftUI

/// The friendly unavailable state for online surfaces. Solo is always one tap
/// away; no raw errors and no blocking spinners. When the reason is "no
/// account", the card offers Sign in with Apple (via `onSignIn`) — auth is
/// requested only from an explicit user tap, never automatically.
struct OnlineUnavailableView: View {
    let availability: OnlineState
    /// Full card (mode selector / invite sheet) vs. one compact banner (Friends).
    var compact: Bool = false
    var onSolo: (() -> Void)? = nil
    var onLearnHow: (() -> Void)? = nil
    var onSignIn: (() -> Void)? = nil

    private var needsSignIn: Bool {
        availability == .signedOut || availability == .sessionExpired
    }

    private var title: String {
        switch availability {
        case .signedOut:           return "Sign in to fly Online"
        case .sessionExpired:      return "Please sign in again"
        case .networkUnavailable:  return "You're offline"
        case .rateLimited:         return "One moment…"
        default:                   return "Online is temporarily unavailable"
        }
    }
    private var body_: String {
        needsSignIn
            ? "Online Flights use a private FocusGlobe account with Sign in with Apple — you appear only as an anonymous alias."
            : "Reconnect to fly with other pilots."
    }
    private var icon: String {
        switch availability {
        case .signedOut, .sessionExpired: return "person.crop.circle.badge.questionmark"
        case .networkUnavailable:         return "wifi.slash"
        default:                          return "cloud.slash"
        }
    }

    var body: some View {
        if compact { banner } else { card }
    }

    // One compact line for pages that shouldn't be dominated by the state.
    private var banner: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.textTertiary)
            Text(title)
                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            if needsSignIn, let onSignIn {
                Button("Sign in") { onSignIn() }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.gold)
            }
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
            HStack(spacing: AppSpacing.md) {
                if needsSignIn, let onSignIn {
                    Button("Sign in with Apple") { onSignIn() }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.gold)
                }
                if let onSolo {
                    Button("Continue Solo") { onSolo() }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(needsSignIn && onSignIn != nil ? AppColors.textSecondary : AppColors.gold)
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
