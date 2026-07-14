import Foundation

/// One reusable sharing payload builder. Everything is explicit-user-action
/// sharing through the system share sheet — nothing shares automatically, and
/// intention text is never included unless the caller passes it deliberately.
enum CloudShareService {
    /// The App Store link once configured; marketing fallback until then.
    static var appLink: String {
        "Focus feels better in the sky. Fly with me on FocusGlobe — your phone becomes a focus balloon flight."
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
