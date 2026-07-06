import SwiftUI

/// The expedition's **motion language**: slow, physical, eased. Nothing snaps —
/// things drift, settle and unfurl. Centralising the durations and curves here
/// keeps every new animation on the same cadence, the way the colours and type
/// are centralised in `AppColors` / `AppTypography`.
///
/// Reach for these instead of ad-hoc `.easeInOut(duration:)` literals so the whole
/// app feels like one hand made it. Every motion also has a Reduce-Motion escape
/// hatch (`respecting(reduceMotion:)`) so accessibility gets a static fallback.
enum AppMotion {

    // MARK: Durations (seconds)  — deliberately unhurried

    /// A small acknowledgement (a tap settling, a chip toggling).
    static let quick:  Double = 0.28
    /// The standard "settle" — most transitions and card reveals.
    static let settle: Double = 0.55
    /// A slow drift — hero motion, sky changes, page turns.
    static let drift:  Double = 0.9
    /// The longest, most cinematic beat — unfurling a map, opening an envelope.
    static let unfurl: Double = 1.2

    // MARK: Curves / ready-made animations

    /// Gentle ease for most UI. Calm in, calm out.
    static var soft: Animation { .easeInOut(duration: settle) }
    /// Eases *out* only — good for things that arrive and come to rest.
    static var drifting: Animation { .easeOut(duration: drift) }
    /// A physical settle with a little life — cards, sheets, the basket dip.
    static var settling: Animation { .interpolatingSpring(stiffness: 70, damping: 14) }
    /// A soft, weighty spring for large elements that unfurl into place.
    static var unfurling: Animation { .interpolatingSpring(stiffness: 45, damping: 12) }
    /// The wax-seal "thud": a firm, slightly overshooting impact that then holds.
    static var sealImpact: Animation { .spring(response: 0.34, dampingFraction: 0.52) }
    /// The rope-snap release: quick tension break into the rise.
    static var ropeSnap: Animation { .spring(response: 0.26, dampingFraction: 0.6) }

    // MARK: Reduce-Motion helper

    /// Returns `animation` normally, or `nil` when Reduce Motion is on — so a call
    /// site can write `withAnimation(AppMotion.soft.respecting(reduceMotion))` and
    /// get an instant, non-animated state change for accessibility.
    ///
    /// Usage:
    /// ```
    /// @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// withAnimation(AppMotion.settling.respecting(reduceMotion)) { … }
    /// ```
    static func flat(_ reduceMotion: Bool, else animation: Animation) -> Animation? {
        reduceMotion ? nil : animation
    }
}

extension Animation {
    /// Collapses this animation to `nil` (instant) when Reduce Motion is enabled.
    func respecting(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : self
    }
}
