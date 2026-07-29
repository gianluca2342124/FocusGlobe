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

    /// "That didn't take" — a refused action the pilot should notice without
    /// being scolded, e.g. equipping a fifth object into a full Cabin.
    func refused() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// A very soft "bubble pop" — for subtle, premium confirmations such as a
    /// drag grab. Lighter than `tap()`; never used repeatedly per frame.
    func bubble() {
        guard isEnabled else { return }
        let g = UIImpactFeedbackGenerator(style: .soft)
        g.prepare(); g.impactOccurred(intensity: 0.5)
    }
}
