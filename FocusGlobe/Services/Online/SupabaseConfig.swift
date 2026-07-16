import Foundation

/// Central Supabase configuration — the ONLY place backend endpoints live.
///
/// Security contract: the app ships ONLY the project URL and the PUBLISHABLE
/// (anon) key — both are designed to be embedded in clients and are useless
/// without Row Level Security passing. The service_role key, database
/// password, JWT secret and the Apple .p8 key must NEVER appear in this app,
/// in source control, or in logs.
enum SupabaseConfig {
    /// Optional Info.plist overrides (set `SupabaseURL` / `SupabasePublishableKey`
    /// via build settings or a config plist to point at another project without
    /// touching code). Falls back to the production FocusGlobe project.
    static let projectURLString: String = {
        (Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String)
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? "https://hmbxpkcolhloszzlqjwr.supabase.co"
    }()

    static let publishableKey: String = {
        (Bundle.main.object(forInfoDictionaryKey: "SupabasePublishableKey") as? String)
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? "sb_publishable_Qx7RPkx-N7SoisYCZxbnsg_z2xL-MfM"
    }()

    static var projectURL: URL? { URL(string: projectURLString) }

    /// True when both values parse — the online layer fails safe (Solo always
    /// works) and DEBUG diagnostics show exactly what's missing.
    static var isConfigured: Bool {
        projectURL != nil && !publishableKey.isEmpty && publishableKey.hasPrefix("sb_")
    }

    // MARK: Invitation links

    /// Future universal-link base (requires the domain + AASA file + Associated
    /// Domains capability — see Documentation/FocusGlobeSupabaseSetup.md).
    /// Leave EMPTY until that infrastructure exists; invites then use the
    /// custom scheme below, which works on any device with the app installed.
    static let universalLinkBaseURLString = ""

    /// Custom-scheme fallback (registered in Info.plist).
    static let customScheme = "focusglobe"

    /// The join URL for a one-time invite token.
    static func inviteURL(token: String) -> URL? {
        if !universalLinkBaseURLString.isEmpty {
            return URL(string: "\(universalLinkBaseURLString)/join/\(token)")
        }
        return URL(string: "\(customScheme)://join/\(token)")
    }

    // MARK: Presence timing (mirrors the previous online tuning)

    static let presenceHeartbeatInterval: TimeInterval = 40
    static let presenceStaleInterval: TimeInterval = 120
    static let publicRefreshInterval: TimeInterval = 35
}
