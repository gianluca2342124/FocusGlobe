import SwiftUI
import AuthenticationServices

/// The FocusGlobe account sheet — clean and premium. Shown ONLY when the user
/// explicitly chooses an online feature; Solo never requires an account, and
/// cancelling changes nothing. One Apple authorization signs in completely and
/// the sheet dismisses itself back to the original context.
struct OnlineSignInView: View {
    @EnvironmentObject private var online: FocusOnlineModel
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    /// Called after a successful sign-in (sheet dismisses itself).
    var onSignedIn: (() -> Void)? = nil

    @State private var errorMessage: String?
    @State private var working = false
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
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                if !succeeded {
                    Text("Focus alongside real pilots and invite friends into private flights.")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.danger.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)
                }

                if !succeeded {
                    ZStack {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName]
                            request.nonce = online.makeAppleNonce()
                        } onCompletion: { result in
                            guard !working else { return }
                            working = true
                            errorMessage = nil
                            Task { @MainActor in
                                let error = await online.completeAppleSignIn(result)
                                working = false
                                if error == nil, online.availability.isAvailable {
                                    appModel.tapFeedback()
                                    withAnimation(.snappy) { succeeded = true }
                                    // Brief confirmation, then return to context.
                                    try? await Task.sleep(nanoseconds: 700_000_000)
                                    onSignedIn?()
                                    dismiss()
                                } else if let error, !error.isEmpty {
                                    errorMessage = error
                                }
                            }
                        }
                        .signInWithAppleButtonStyle(colorScheme == .light ? .black : .white)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.pillRadius, style: .continuous))
                        .disabled(working)
                        .opacity(working ? 0 : 1)

                        if working {
                            ProgressView().tint(AppColors.gold)
                        }
                    }
                    .frame(height: 52)
                    .padding(.horizontal, AppSpacing.md)

                    Text("Your public alias is shown — never your email.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                        .multilineTextAlignment(.center)
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
