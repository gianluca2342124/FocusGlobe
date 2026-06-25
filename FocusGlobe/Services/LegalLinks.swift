import Foundation

/// The single, **configurable** place for the app's legal / policy links.
///
/// These power the Privacy and Terms links on the paywall and at the bottom of
/// Settings (and anywhere else the app links out). They point to the real, hosted
/// policy pages — App Review requires working Privacy Policy and Terms links, and
/// auto-renewable subscriptions require a Terms of Use link in the purchase flow.
///
/// No legal text is bundled inside the app — these simply point to the hosted
/// pages, so updating policy never requires an app update.
enum LegalLinks {
    /// FocusGlobe Privacy Policy (hosted).
    static let privacy = URL(string: "https://app.notion.com/p/Privacy-Policy-38a87f11a2a0802489aaf7bbeec65578?source=copy_link")!
    /// FocusGlobe Terms of Use (hosted).
    static let terms = URL(string: "https://app.notion.com/p/Terms-of-Use-38a87f11a2a0806e9a5ed32eebf1b4c9?source=copy_link")!
}
