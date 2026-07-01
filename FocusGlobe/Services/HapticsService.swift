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

    /// A light, premium button tap. A prepared *light impact* (not a bare
    /// selection tick) so it's actually perceptible on a real device for normal
    /// buttons — subtle and Apple-like, never aggressive. This is the default
    /// tap used across the app (via `AppModel.tapFeedback()`), so strengthening
    /// it here upgrades the feel of every button in one place.
    func tap() {
        guard isEnabled else { return }
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare(); g.impactOccurred(intensity: 0.7)
    }

    /// A soft selection tick for *choosing* something (route/category, focus
    /// type, balloon skin, journey sound). The canonical picker feedback —
    /// distinct, lighter texture than a button `tap()`.
    func select() {
        guard isEnabled else { return }
        let g = UISelectionFeedbackGenerator()
        g.prepare(); g.selectionChanged()
    }

    /// A soft warning for an action that couldn't complete — an unavailable Pro
    /// action or a failed/empty restore. Gentle, not alarming.
    func warning() {
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
