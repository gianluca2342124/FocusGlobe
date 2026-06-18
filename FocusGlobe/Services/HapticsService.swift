import UIKit

/// Centralised, intent-named haptics. Respects the user's Haptics setting.
@MainActor
final class HapticsService {
    var isEnabled: Bool = true

    func takeoff() {
        guard isEnabled else { return }
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.prepare(); g.impactOccurred(intensity: 0.9)
    }

    func pause() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.6)
    }

    func resume() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
    }

    func landing() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func rewardClaim() {
        guard isEnabled else { return }
        let g = UIImpactFeedbackGenerator(style: .heavy)
        g.prepare(); g.impactOccurred(intensity: 1.0)
    }

    func tap() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
