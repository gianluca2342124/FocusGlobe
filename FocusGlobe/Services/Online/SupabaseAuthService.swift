import Foundation
import Supabase
import AuthenticationServices
import CryptoKit

/// Native Sign in with Apple → Supabase Auth (ID-token flow). No web sheets,
/// no passwords, no OAuth secret needed for native sign-in. Sessions persist
/// in the keychain via supabase-swift and are restored/refreshed at launch.
///
/// Privacy: the Apple identity token goes ONLY to Supabase Auth. Email and the
/// Apple subject are never written to any public table; the visible identity
/// is an anonymous alias (SkyPilot####) in `profiles`.
actor SupabaseAuthService {
    private var client: SupabaseClient? { SupabaseService.client }

    // MARK: Nonce (replay protection)

    /// Cryptographically random raw nonce; its SHA-256 goes into the Apple
    /// request, the raw value goes to Supabase which verifies the token claim.
    static func makeRawNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        if status != errSecSuccess {
            // Extremely unlikely; fall back to SystemRandomNumberGenerator.
            var rng = SystemRandomNumberGenerator()
            bytes = (0..<length).map { _ in UInt8.random(in: 0...255, using: &rng) }
        }
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Session

    /// The signed-in Supabase user id (UUID string), if a session exists.
    var currentUserID: String? {
        client?.auth.currentSession?.user.id.uuidString.lowercased()
    }

    /// Restore + refresh the stored session. Returns the user id, or nil when
    /// signed out. Throws only on transport-level failures so the caller can
    /// distinguish "no account" from "can't reach the backend".
    func restoreSession() async throws -> String? {
        guard let client else { return nil }
        guard client.auth.currentSession != nil else { return nil }
        let session = try await client.auth.session   // refreshes if expired
        return session.user.id.uuidString.lowercased()
    }

    /// Exchange an Apple authorization for a Supabase session. `fullName` is
    /// captured once (first authorization only) into auth user metadata —
    /// never into any public record.
    func signInWithApple(authorization: ASAuthorization, rawNonce: String) async throws -> String {
        guard let client else { throw OnlineError.unavailable(.projectUnavailable) }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw OnlineError.requestFailed
        }
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: rawNonce))

        // First-authorization full name (Apple sends it exactly once). Stored
        // privately in auth metadata so it isn't lost; never shown publicly.
        if let name = credential.fullName {
            let formatted = PersonNameComponentsFormatter.localizedString(from: name, style: .default)
            if !formatted.trimmingCharacters(in: .whitespaces).isEmpty {
                try? await client.auth.update(user: UserAttributes(data: ["full_name": .string(formatted)]))
            }
        }
        return session.user.id.uuidString.lowercased()
    }

    func signOut() async {
        try? await client?.auth.signOut()
    }
}
