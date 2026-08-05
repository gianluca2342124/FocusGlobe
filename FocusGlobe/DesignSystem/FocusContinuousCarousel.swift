import SwiftUI

/// A lightweight, continuously moving carousel shared by every premium preview.
///
/// Each item is rendered once. Its position is wrapped mathematically, so the
/// conveyor can run forever without duplicated view trees, sentinel indexes or
/// visible resets. Automatic motion fully yields while the pilot drags and
/// resumes the instant the finger lifts, from the exact position the flick
/// landed on — there is no waiting period, because a carousel that freezes for
/// a second and a half after every touch reads as broken rather than as polite.
///
/// ## Why the motion is derived, not stated
///
/// This used to gate automatic movement behind three pieces of `@State`
/// (`isAutomatic`, `isVisible`) plus a `scenePhase` comparison, all initialised
/// from `onAppear`. Every one of those is a way for the conveyor to be silently
/// stopped — if `onAppear` lands while the scene is not yet `.active` (a modal
/// still presenting, a cold launch mid-onboarding), `isAutomatic` is left false
/// and nothing in the normal course of events sets it back, so the carousel just
/// sits there until the pilot swipes.
///
/// Now the offset is a pure function of the clock: `motionOrigin` is stamped when
/// the state is created, so the FIRST rendered frame is already moving and no
/// callback has to fire for that to be true. Stopping is likewise structural —
/// the `TimelineView` is mounted with the carousel, so dismissing the paywall
/// tears the clock down. The only state left is what genuinely models a user
/// action: the drag.
struct FocusContinuousCarousel<Item: Identifiable, Card: View>: View {
    let items: [Item]
    @Binding var selectedIndex: Int
    /// Gap between card boxes. Small on purpose: the cards hold transparent
    /// artwork whose own bounds already contribute generous empty margin, so
    /// large spacing here reads as the assets drifting apart.
    var spacing: CGFloat = 3
    var maximumCardWidth: CGFloat = 230
    /// Card width as a fraction of the available width. Landscape Sky previews
    /// want a wider box than an isolated balloon or cabin object.
    var cardWidthFraction: CGFloat = 0.54
    var minimumCardWidth: CGFloat = 140
    /// Points per second — THE shared cadence. Call sites inherit this rather
    /// than restating it, so the paywalls cannot drift apart; only onboarding
    /// overrides it, deliberately calmer for a first-run surface.
    ///
    /// 53 pt/s, up from 42 (+26%). At 42 the reel read as drifting rather than
    /// presenting: a pilot who glanced at the page saw roughly one card change.
    /// Raising it here rather than per-paywall is the point of the value living
    /// on the component — five surfaces move together and cannot drift apart.
    var speed: CGFloat = 53
    @ViewBuilder let card: (Item, Double) -> Card

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Stamped when this carousel's state is created — i.e. before the first
    /// frame is drawn. Nothing needs to start the motion.
    @State private var motionOrigin = Date()
    /// Distance already banked from previous auto runs and drags.
    @State private var bankedDistance: CGFloat = 0
    /// Non-nil while automatic motion is held (during and just after a drag).
    /// Holds the exact distance at the moment it was frozen.
    @State private var heldDistance: CGFloat?
    @State private var dragTranslation: CGFloat = 0
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let cardWidth = min(maximumCardWidth,
                                max(minimumCardWidth, width * cardWidthFraction))
            let step = cardWidth + spacing

            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
                let distance = automaticDistance(at: context.date)
                let continuousIndex = Double(normalized(selectedIndex))
                    + Double(distance - dragTranslation) / Double(step)

                ZStack {
                    ForEach(items.indices, id: \.self) { index in
                        let delta = wrappedDelta(
                            from: Double(index) - continuousIndex,
                            count: items.count
                        )
                        let prominence = max(0, 1 - abs(delta))

                        if abs(delta) <= 2.25 {
                            card(items[index], quantized(prominence))
                                .frame(width: cardWidth, height: geometry.size.height)
                                .scaleEffect(0.88 + 0.12 * prominence)
                                .opacity(0.54 + 0.46 * prominence)
                                .position(
                                    x: width / 2 + CGFloat(delta) * step,
                                    y: geometry.size.height / 2
                                )
                                .zIndex(prominence)
                        }
                    }
                }
                .frame(width: width, height: geometry.size.height)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(step: step))
        }
        .clipped()
        .onAppear { selectedIndex = normalized(selectedIndex) }
        .onDisappear {
            // The clock dies with the view, so nothing keeps running after the
            // paywall closes. There is no pending task to cancel any more —
            // clearing the drag state is all that is left.
            isDragging = false
            dragTranslation = 0
        }
        .accessibilityElement(children: .contain)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: moveSelection(by: 1)
            case .decrement: moveSelection(by: -1)
            @unknown default: break
            }
        }
    }

    private func dragGesture(step: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if !isDragging {
                    freezeAutomaticMotion(at: Date())
                    isDragging = true
                }
                dragTranslation = value.translation.width
            }
            .onEnded { value in
                let projected = value.translation.width
                    + (value.predictedEndTranslation.width - value.translation.width) * 0.28
                let held = heldDistance ?? bankedDistance
                let globalIndex = Double(normalized(selectedIndex))
                    + Double(held - projected) / Double(step)
                let nearest = globalIndex.rounded()

                // Fold the drag into the base offset and hand control straight
                // back to the clock. `bankedDistance` becomes the residual
                // relative to the newly selected card and the origin is restamped
                // to NOW, so at the first automatic frame elapsed is zero and the
                // conveyor is at precisely the position the flick landed on.
                // Nothing snaps back, nothing jumps forward, and there is no
                // interval during which the pilot's touch has stopped the page.
                selectedIndex = normalized(Int(nearest))
                bankedDistance = CGFloat(globalIndex - nearest) * step
                heldDistance = nil
                motionOrigin = Date()
                dragTranslation = 0
                isDragging = false
            }
    }

    /// The conveyor offset. Held during a drag, otherwise time since the origin.
    /// Reduce Motion parks it at whatever the pilot last scrubbed to, which is the
    /// "static accessible arrangement" — still fully swipeable, just not moving on
    /// its own.
    private func automaticDistance(at date: Date) -> CGFloat {
        if reduceMotion { return heldDistance ?? bankedDistance }
        if let heldDistance { return heldDistance }
        return bankedDistance + CGFloat(date.timeIntervalSince(motionOrigin)) * speed
    }

    private func freezeAutomaticMotion(at date: Date) {
        heldDistance = automaticDistance(at: date)
    }

    /// VoiceOver's adjustable action. Centres the requested card and lets the
    /// clock carry on from there — deliberately NOT frozen, so the reel behaves
    /// the same way whether it was moved by a finger or by assistive technology.
    private func moveSelection(by delta: Int) {
        guard items.count > 1 else { return }
        selectedIndex = normalized(selectedIndex + delta)
        bankedDistance = 0
        heldDistance = nil
        dragTranslation = 0
        motionOrigin = Date()
    }

    /// Prominence handed to the CARD BUILDER is stepped; the engine keeps the
    /// exact value for its own `scaleEffect`/`opacity`, which are cheap
    /// per-frame transforms of an already-built card.
    ///
    /// This matters because the builder's output is a whole view tree. Passing a
    /// raw `Double` that moves every frame means SwiftUI can never find two
    /// consecutive frames equal, so each card's body is rebuilt 30×/s purely
    /// because a border opacity shifted by 0.003. Twelve steps across a card's
    /// travel is far finer than the eye resolves on these gradients, and it lets
    /// the diffing engine skip the subtree on the ~11 frames out of 12 where
    /// nothing the builder reads has actually changed.
    private func quantized(_ prominence: Double) -> Double {
        (prominence * 12).rounded() / 12
    }

    private func normalized(_ index: Int) -> Int {
        guard !items.isEmpty else { return 0 }
        return ((index % items.count) + items.count) % items.count
    }

    private func wrappedDelta(from raw: Double, count: Int) -> Double {
        guard count > 0 else { return 0 }
        let period = Double(count)
        return raw - (raw / period).rounded() * period
    }
}
