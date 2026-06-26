import Foundation
#if canImport(ManagedSettings)
import ManagedSettings
#endif
#if canImport(ManagedSettingsUI)
import ManagedSettingsUI
#endif
#if canImport(UIKit)
import UIKit
#endif

// ============================================================================
//  Shield Configuration Extension — the custom blocked screen
//
//  Renders FocusGlobe's branded, calm shield when a blocked app/site is opened
//  during a journey. Dark "space" aesthetic, gold CTA, productivity tone.
//
//  TARGET: add this file to the **FocusGlobeShieldConfiguration** extension
//  target. Point its Info.plist `NSExtensionPrincipalClass` at this class.
//  See FOCUS_SHIELD_SETUP.md.
// ============================================================================

#if canImport(ManagedSettingsUI) && canImport(UIKit)

@available(iOS 16.0, *)
final class FocusGlobeShieldConfigurationProvider: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        Self.focusGlobeShield()
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        Self.focusGlobeShield()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        Self.focusGlobeShield()
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        Self.focusGlobeShield()
    }

    /// FocusGlobe's branded shield — dark space navy, gold "Back to Focus" CTA.
    static func focusGlobeShield() -> ShieldConfiguration {
        let navy = UIColor(red: 0.04, green: 0.05, blue: 0.10, alpha: 1)
        let gold = UIColor(red: 0.95, green: 0.78, blue: 0.47, alpha: 1)
        let onGold = UIColor(red: 0.06, green: 0.07, blue: 0.10, alpha: 1)

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: navy,
            icon: shieldIcon(),
            title: ShieldConfiguration.Label(text: "Not the time for distractions", color: .white),
            subtitle: ShieldConfiguration.Label(text: "Your FocusGlobe journey is still in progress.",
                                                color: UIColor.white.withAlphaComponent(0.72)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Back to Focus", color: onGold),
            primaryButtonBackgroundColor: gold
        )
    }

    /// Optional bundled glyph — add a "FocusShieldGlyph" image (a balloon mark) to
    /// the extension's asset catalog for full branding; otherwise an on-brand SF
    /// Symbol is used so the screen is never blank.
    private static func shieldIcon() -> UIImage? {
        if let bundled = UIImage(named: "FocusShieldGlyph") { return bundled }
        return UIImage(systemName: "airplane.departure")
    }
}

#endif
