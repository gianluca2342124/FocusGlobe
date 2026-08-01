import ManagedSettings

/// What the shield's buttons actually do.
///
/// `ShieldActionResponse` declares four cases — `.none`, `.close`, `.defer` and
/// `.openParentalControlsApp`. The last one is "an instruction for the system to
/// open your parental controls app that is responsible for shielding the
/// application or web browser", and FocusGlobe IS that app, so it is exactly the
/// supported way to send a pilot back to their flight. It arrived in
/// **iOS / iPadOS / Mac Catalyst 26.5**, well after this target's 17.0 minimum,
/// which is why it is behind an availability check rather than used outright.
///
/// Below 26.5 there is genuinely no supported way to launch the containing app
/// from here: no URL hook, no `extensionContext.open`, and `UIApplication` is
/// unavailable to an app extension. Those OS versions fall back to `.close`,
/// which dismisses the blocked app, and the shield's own primary label changes
/// to match — the button never claims to do something this device cannot.
///
/// The same response is used for all three token kinds, so an app shielded
/// directly, an app shielded through a category and a web domain all behave
/// identically.
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(Self.response(for: action))
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(Self.response(for: action))
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(Self.response(for: action))
    }

    /// Whether this device can be asked to open FocusGlobe from the shield.
    ///
    /// Read by the CONFIGURATION extension too, so the label and the behaviour
    /// are decided by one condition and cannot drift apart.
    static var canOpenParentalControlsApp: Bool {
        if #available(iOS 26.5, *) { return true }
        return false
    }

    static func response(for action: ShieldAction) -> ShieldActionResponse {
        switch action {
        case .primaryButtonPressed:
            // Return to FocusGlobe where the system supports it; otherwise just
            // leave the blocked app. Either way the shield stays armed — nothing
            // here weakens the active restriction.
            if #available(iOS 26.5, *) { return .openParentalControlsApp }
            return .close
        case .secondaryButtonPressed:
            return .close
        default:
            // Submenu actions FocusGlobe does not offer. Leaving the blocked app
            // is the only safe answer for an action we did not author.
            return .close
        }
    }
}
