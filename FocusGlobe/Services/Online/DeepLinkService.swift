import Foundation

/// FocusGlobe Online deep links. Two accepted invitation shapes:
///   focusglobe://join/<token>              (custom scheme — works today)
///   https://focusglobe.app/join/<token>    (universal link — once the domain,
///                                           AASA file and Associated Domains
///                                           capability exist)
/// Tokens are opaque one-time secrets minted by the server; nothing else is
/// ever parsed out of an invitation URL.
enum DeepLinkService {
    /// Extract an invite token, or nil when the URL is not an invitation.
    static func inviteToken(from url: URL) -> String? {
        // focusglobe://join/<token>  → host == "join", token in path
        if url.scheme?.lowercased() == SupabaseConfig.customScheme {
            guard url.host?.lowercased() == "join" else { return nil }
            let token = url.pathComponents.filter { $0 != "/" }.first
            return validated(token)
        }
        // https://<any focusglobe domain>/join/<token>
        if url.scheme?.lowercased() == "https" {
            let parts = url.pathComponents.filter { $0 != "/" }
            guard parts.count >= 2, parts[0].lowercased() == "join" else { return nil }
            return validated(parts[1])
        }
        return nil
    }

    /// Tokens are base64url (server-minted). Reject anything else outright.
    private static func validated(_ raw: String?) -> String? {
        guard let raw, raw.count >= 16, raw.count <= 64 else { return nil }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        guard raw.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        return raw
    }
}
