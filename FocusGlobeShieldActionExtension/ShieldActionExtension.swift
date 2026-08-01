import ManagedSettings

/// A shield action extension's only output is a `ShieldActionResponse`, and its
/// three cases — `.none`, `.close`, `.defer` — do not include "open an app".
/// There is no URL-opening hook here, no `extensionContext.open`, and
/// `UIApplication` is unavailable to an app extension, so nothing in this file
/// can launch FocusGlobe. `.close` dismisses the BLOCKED app, which returns the
/// user to the Home Screen.
///
/// That is why the shield's primary button now reads "Stay Focused" rather than
/// "Return to FocusGlobe": the label describes what actually happens. Do not
/// re-label it back without a supported API that genuinely opens the app.
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(response(for: action))
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(response(for: action))
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(response(for: action))
    }

    private func response(for _: ShieldAction) -> ShieldActionResponse {
        // All current and future shield actions must leave the blocked app
        // without weakening the active focus restriction.
        .close
    }
}
