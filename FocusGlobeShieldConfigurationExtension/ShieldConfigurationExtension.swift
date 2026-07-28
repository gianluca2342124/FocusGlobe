import ManagedSettings
import ManagedSettingsUI
import UIKit

/// FocusGlobe's calm, branded use of Apple's system-owned Screen Time shield.
/// ManagedSettingsUI controls the layout; the extension supplies only the
/// supported icon, labels and colors.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        Self.focusGlobeShield()
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        Self.focusGlobeShield()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        Self.focusGlobeShield()
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        Self.focusGlobeShield()
    }

    private static func focusGlobeShield() -> ShieldConfiguration {
        let navy = UIColor(red: 0.035, green: 0.047, blue: 0.10, alpha: 1)
        let ivory = UIColor(red: 0.96, green: 0.94, blue: 0.89, alpha: 1)
        let teal = UIColor(red: 0.22, green: 0.78, blue: 0.73, alpha: 1)

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: navy,
            icon: UIImage(named: "FocusShieldGlyph")
                ?? UIImage(systemName: "balloon.2.fill"),
            title: .init(text: "Stay on course", color: ivory),
            subtitle: .init(
                text: "Your focus flight is still active.",
                color: ivory.withAlphaComponent(0.72)
            ),
            primaryButtonLabel: .init(text: "Return to FocusGlobe", color: navy),
            primaryButtonBackgroundColor: teal,
            secondaryButtonLabel: .init(text: "Close", color: ivory.withAlphaComponent(0.78))
        )
    }
}
