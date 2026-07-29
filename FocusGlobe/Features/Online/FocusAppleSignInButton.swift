import AuthenticationServices
import SwiftUI

/// The ONE Sign in with Apple button in FocusGlobe.
///
/// Wraps Apple's native `SignInWithAppleButton` together with the existing
/// Supabase path (`FocusOnlineModel.makeAppleNonce()` →
/// `completeAppleSignIn(_:)`), so the account sheet and Settings ▸ Account share
/// a single implementation. There is deliberately no second authentication flow
/// and no hand-drawn imitation of Apple's button.
///
/// Signing in is FREE. This button must never be placed behind a PRO gate: it is
/// how a pilot recovers an account, its progress and any entitlement it already
/// owns. (See `SettingsView.accountSection` and `FriendsView`.)
struct FocusAppleSignInButton: View {
    /// Called when the flow ends. `nil` means signed in successfully; a non-nil
    /// string is a user-presentable error the caller can render in its own style.
    var onFinished: (String?) -> Void

    @EnvironmentObject private var online: FocusOnlineModel
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var working = false

    var body: some View {
        ZStack {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName]
                request.nonce = online.makeAppleNonce()
            } onCompletion: { result in
                guard !working else { return }
                working = true
                Task { @MainActor in
                    // On success this sets `FocusOnlineModel.myUserID`, whose
                    // `didSet` drives `SubscriptionManager.syncIdentity` →
                    // RevenueCat `logIn(uuid)` → CustomerInfo applied →
                    // `revenueCatPro` → widget snapshot. Nothing extra is needed
                    // here to recover an existing entitlement.
                    let error = await online.completeAppleSignIn(result)
                    working = false
                    if error == nil, online.availability.isAvailable {
                        appModel.tapFeedback()
                        onFinished(nil)
                    } else {
                        onFinished(error?.isEmpty == false ? error : nil)
                    }
                }
            }
            .signInWithAppleButtonStyle(colorScheme == .light ? .black : .white)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.pillRadius, style: .continuous))
            .disabled(working)
            .opacity(working ? 0 : 1)

            if working { ProgressView().tint(AppColors.gold) }
        }
        .frame(height: 52)
    }
}
