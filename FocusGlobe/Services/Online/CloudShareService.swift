import Foundation

/// Marketing / App Store configuration for the "Share FocusGlobe" flow. This is
/// PURELY promotional and shares NO CloudKit access — it never creates a room,
/// never a CKShare, and must never be mistaken for a Crew/room invitation (that
/// path lives in `FocusRoomService` + `CloudSharingView` and carries a real
/// private CKShare URL). Update `appStoreURLString` to the live listing URL at
/// release; until then it points at the marketing site as a safe placeholder.
enum MarketingConfig {
    static let appName = "FocusGlobe"

    /// The public App Store product URL. Placeholder until the listing is live —
    /// replace with the real `https://apps.apple.com/app/idXXXXXXXXX` link on
    /// release. Kept as a single constant so there's one place to change it.
    static let appStoreURLString = "https://focusglobe.app"
    static var appStoreURL: URL? { URL(string: appStoreURLString) }

    /// One-line marketing hook used across share cards and rich previews.
    static let tagline = "Focus feels better in the sky. Your phone becomes a focus balloon flight."

    /// The image asset used for the rich share-sheet preview (link thumbnail).
    static let previewImageName = "PaywallBalloonHero"
}

/// One reusable sharing payload builder. Everything is explicit-user-action
/// sharing through the system share sheet — nothing shares automatically, and
/// intention text is never included unless the caller passes it deliberately.
enum CloudShareService {
    /// Marketing text that ALWAYS carries the App Store link, so a shared
    /// recommendation actually lets the recipient install the app (no more
    /// bare text with nowhere to go). Room invitations do NOT use this — they
    /// carry a private CKShare URL instead.
    static var appLink: String {
        "\(MarketingConfig.tagline) \(MarketingConfig.appStoreURLString)"
    }

    static func roomInvitation(url: URL?) -> String {
        "Join my FocusGlobe flight — we focus together, side by side. \(url?.absoluteString ?? appLink)"
    }

    static func journeySummary(minutes: Int, skyName: String, streak: Int) -> String {
        "I just focused \(minutes) min over \(skyName) in FocusGlobe. \(streak > 1 ? "Day \(streak) of my streak. " : "")\(appLink)"
    }

    static func streakCard(days: Int) -> String {
        "\(days)-day focus streak in FocusGlobe. \(appLink)"
    }

    static func badge(title: String) -> String {
        "Just earned the \"\(title)\" badge in FocusGlobe. \(appLink)"
    }

    static func skyPreview(skyName: String) -> String {
        "There's a Sky called \(skyName) in FocusGlobe — focus flights above beautiful places. \(appLink)"
    }
}
