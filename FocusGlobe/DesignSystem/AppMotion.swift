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

    // MARK: Interaction tiers — how fast the app answers a finger
    //
    // The four tiers below cover everything between "the finger just went down"
    // and "a hero is arriving". They were added because the durations further
    // down all start at 0.28 s: there was nothing in the app's vocabulary fast
    // enough for press feedback, so controls were borrowing a content-transition
    // curve and reading as laggy.

    /// Immediate acknowledgement — the press itself. Must land under the finger,
    /// not after the action completes.
    static let pressDuration:    Double = 0.12
    /// A control changing state: a toggle, a selection, enabling/disabling.
    static let controlDuration:  Double = 0.22
    /// Content swapping in or out: a card revealing, a section expanding.
    static let contentDuration:  Double = 0.30
    /// A premium entrance — a hero or a reward arriving.
    static let entranceDuration: Double = 0.50

    /// Press feedback. Near-critically damped on purpose: the brief for this app
    /// is "no bouncing, no large spring overshoot".
    static var press:    Animation { .spring(response: pressDuration, dampingFraction: 0.86) }
    /// Standard control response.
    static var control:  Animation { .spring(response: controlDuration, dampingFraction: 0.86) }
    /// Content transition.
    static var content:  Animation { .easeInOut(duration: contentDuration) }
    /// Premium entrance, with just enough weight to feel physical.
    static var entrance: Animation { .spring(response: entranceDuration, dampingFraction: 0.82) }

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

    // MARK: Reusable transitions

    /// Content arriving: a short fade with a small lift, leaving on a plain fade.
    ///
    /// Under Reduce Motion this becomes a pure crossfade. That is the rule the
    /// app follows everywhere — remove the spatial movement, keep the feedback,
    /// never leave the change unexplained by making it instant and invisible.
    static func appear(reduceMotion: Bool, lift: CGFloat = 8) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: lift)),
            removal: .opacity
        )
    }
}

extension Animation {
    /// Collapses this animation to `nil` (instant) when Reduce Motion is enabled.
    func respecting(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : self
    }
}
