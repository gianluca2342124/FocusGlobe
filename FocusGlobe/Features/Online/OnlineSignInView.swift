import SwiftUI

/// The FocusGlobe account sheet — clean and premium. Reached from an online
/// feature; Solo never requires an account, and cancelling changes nothing. One
/// Apple authorization signs in completely and the sheet dismisses itself back to
/// the original context.
///
/// Signing in is also offered permanently and free in Settings ▸ Account, which
/// is the path that does not depend on reaching an online surface first. Both use
/// the same `FocusAppleSignInButton`.
struct OnlineSignInView: View {
    @Environment(\.dismiss) private var dismiss
    /// Called after a successful sign-in (sheet dismisses itself).
    var onSignedIn: (() -> Void)? = nil

    @State private var errorMessage: String?
    @State private var succeeded = false

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            VStack(spacing: AppSpacing.lg) {
                Spacer(minLength: 0)

                Image(systemName: succeeded ? "checkmark.circle.fill" : "person.2.wave.2.fill")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(succeeded ? AppColors.success : AppColors.gold)
                    .contentTransition(.symbolEffect(.replace))

                Text(succeeded ? "Online profile ready" : "Fly with others")
                    .font(.system(size: 27, weight: .bold, design: .default))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                if let errorMessage {
                    Text(errorMessage)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.danger.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)
                }

                if !succeeded {
                    // The shared button — one authentication path for this sheet
                    // and for Settings ▸ Account.
                    FocusAppleSignInButton { error in
                        if let error {
                            errorMessage = error
                        } else {
                            errorMessage = nil
                            withAnimation(.snappy) { succeeded = true }
                            // Brief confirmation, then return to context.
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 700_000_000)
                                onSignedIn?()
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppSpacing.screen)
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity)
        }
        .presentationDetents([.fraction(0.55)])
        .presentationDragIndicator(.visible)
    }
}
