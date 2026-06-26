import Foundation
#if canImport(ManagedSettings)
import ManagedSettings
#endif

// ============================================================================
//  Shield Action Extension — handles the shield's buttons
//
//  Keeps it deliberately simple and non-bypassing: "Back to Focus" closes the
//  blocked app (returning the user to the Home Screen / FocusGlobe). There is no
//  "unlock anyway" path during an active journey by design.
//
//  TARGET: add this file to the **FocusGlobeShieldAction** extension target (only
//  needed if you add a Shield Action extension). Point its Info.plist
//  `NSExtensionPrincipalClass` at this class. See FOCUS_SHIELD_SETUP.md.
// ============================================================================

#if canImport(ManagedSettings)

@available(iOS 16.0, *)
final class FocusGlobeShieldActionProvider: ShieldActionDelegate {

    override func handle(action: ShieldAction,
                         for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(response(for: action))
    }

    override func handle(action: ShieldAction,
                         for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(response(for: action))
    }

    override func handle(action: ShieldAction,
                         for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(response(for: action))
    }

    /// "Back to Focus" (primary) closes the blocked app; we never silently unlock.
    private func response(for action: ShieldAction) -> ShieldActionResponse {
        switch action {
        case .primaryButtonPressed:   return .close
        case .secondaryButtonPressed: return .defer
        @unknown default:             return .none
        }
    }
}

#endif
