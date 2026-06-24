import Foundation

/// The single, **configurable** place for the app's legal / policy links.
///
/// These power the Privacy and Terms links on the paywall (and anywhere else the
/// app links out). They are **placeholders** — replace both URLs with your real,
/// publicly reachable pages before submitting to the App Store:
///  • App Review requires working Privacy Policy and Terms links.
///  • Auto-renewable subscriptions require a Terms of Use (EULA) link in the
///    purchase flow (the paywall already shows it).
///
/// No legal text is bundled inside the app — these simply point to your hosted
/// pages, so updating policy never requires an app update. See
/// APP_STORE_READINESS.md for the full pre-submission checklist.
enum LegalLinks {
    /// TODO: replace with your real Privacy Policy URL before release.
    static let privacy = URL(string: "https://focusglobe.app/privacy")!
    /// TODO: replace with your real Terms of Use (EULA) URL before release.
    static let terms = URL(string: "https://focusglobe.app/terms")!
}
