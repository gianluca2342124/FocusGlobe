import ManagedSettings

/// Apple does not provide a supported URL-opening hook from a shield action.
/// Both actions therefore close the blocked app without weakening the active
/// shield. The primary label still guides the pilot back to FocusGlobe.
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
