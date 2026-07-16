import SwiftUI
import AuthenticationServices

/// The FocusGlobe account sheet: a warm explanation of what Online is (and
/// isn't), then Apple's native button. Shown ONLY when the user explicitly
/// chooses an online feature — Solo never requires an account, and cancelling
/// changes nothing.
struct OnlineSignInView: View {
    @EnvironmentObject private var online: FocusOnlineModel
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    /// Called after a successful sign-in (sheet dismisses itself).
    var onSignedIn: (() -> Void)? = nil

    @State private var errorMessage: String?
    @State private var working = false

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            VStack(spacing: AppSpacing.md) {
                Capsule().fill(.white.opacity(0.2)).frame(width: 40, height: 4).padding(.top, 10)

                Image(systemName: "person.2.badge.key.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(AppColors.gold)
                    .padding(.top, AppSpacing.sm)

                Text("Fly with other pilots")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                VStack(alignment: .leading, spacing: 10) {
                    benefit(icon: "person.3.fill", text: "See real pilots focusing in your Sky.")
                    benefit(icon: "airplane.departure", text: "Create private flights and invite friends.")
                    benefit(icon: "sparkles", text: "Earn 2× Focus Coins on verified friend flights.")
                    benefit(icon: "eye.slash.fill",
                            text: "You appear only as an anonymous alias — your name and email are never shown to anyone.")
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassBackground(cornerRadius: AppSpacing.cardRadius, tintOpacity: 0.2,
                                 shadowRadius: 8, shadowY: 4)

                if let errorMessage {
                    Text(errorMessage)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName]
                    request.nonce = online.makeAppleNonce()
                } onCompletion: { result in
                    working = true
                    Task { @MainActor in
                        let error = await online.completeAppleSignIn(result)
                        working = false
                        if error == nil, online.availability.isAvailable {
                            appModel.tapFeedback()
                            onSignedIn?()
                            dismiss()
                        } else {
                            errorMessage = error
                        }
                    }
                }
                .signInWithAppleButtonStyle(colorScheme == .light ? .black : .white)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.pillRadius, style: .continuous))
                .disabled(working)
                .opacity(working ? 0.6 : 1)

                Text("Solo Flights never need an account. You can delete your online data at any time in Settings.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .multilineTextAlignment(.center)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppSpacing.screen)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        .presentationDetents([.fraction(0.72), .large])
        .presentationDragIndicator(.visible)
    }

    private func benefit(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppColors.gold)
                .frame(width: 24)
            Text(text)
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
