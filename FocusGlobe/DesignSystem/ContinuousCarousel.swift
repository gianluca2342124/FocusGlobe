import SwiftUI

/// The ONE promotional carousel engine used by every FocusGlobe showcase (the
/// Exclusive Skies paywall, the Exclusive Skins & Items paywall and the final
/// onboarding PRO screen). There is deliberately no second carousel system.
///
/// Motion model — a true marquee, not a paged index:
///
///  • The strip is the item set repeated enough times to cover the viewport
///    twice, drawn at `x = -(phase mod setWidth)`. Because one full set is
///    exactly `setWidth` wide, wrapping the phase lands on *pixel-identical*
///    content, so the loop is seamless: no snap, no reset flash, no card
///    appearing or disappearing.
///  • `phase` is NOT stored per frame. A `TimelineView` derives it from
///    `basePhase + elapsed * speed`, so continuous travel costs one cheap offset
///    recomputation per tick and zero `@State` churn.
///  • Dragging adds directly to the phase and **suspends** the auto travel (the
///    accumulated phase is banked into `basePhase`), so the finger and the
///    animation can never fight. After `resumeDelay` of stillness the travel
///    starts again smoothly from wherever the user left it.
///  • The timeline runs only while the view is on screen (`isOnScreen`), so a
///    dismissed or backgrounded carousel stops doing work entirely.
///  • Reduce Motion renders a still, centred strip and never schedules a tick.
///
/// Content should be CHEAP (a cached image + a label). Never hand this engine a
/// live Sky renderer per card — several simultaneous animated scenes is exactly
/// what overloads the render loop.
struct ContinuousCarousel<Item: Identifiable, Content: View>: View {
    let items: [Item]
    /// Fixed width of one card. A fixed width keeps the loop math exact (no
    /// GeometryReader round-trips) and guarantees a seamless wrap.
    var itemWidth: CGFloat
    var itemHeight: CGFloat
    var spacing: CGFloat = 14
    /// Travel speed in points per second — slow and calm by design.
    var pointsPerSecond: Double = 24
    /// How long after the user lets go before automatic travel resumes.
    var resumeDelay: Double = 1.6
    @ViewBuilder var content: (Item) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Phase banked from previous travel + drags. Updated only on interaction
    /// boundaries (a handful of times), never per frame.
    @State private var basePhase: CGFloat = 0
    /// Timeline date when the current travel leg began; nil while suspended.
    @State private var legStart: Date?
    @State private var dragTranslation: CGFloat = 0
    @State private var isDragging = false
    @State private var isOnScreen = false
    /// Incremented on every drag end; a delayed resume only fires if it is still
    /// the newest interaction (so rapid drags don't stack resumes).
    @State private var interactionToken = 0

    private var setWidth: CGFloat {
        max(1, CGFloat(items.count) * (itemWidth + spacing))
    }

    /// Enough repeats to cover the widest plausible viewport twice over.
    private func repeatCount(for width: CGFloat) -> Int {
        guard setWidth > 0 else { return 1 }
        return max(2, Int(ceil((width * 2) / setWidth)) + 1)
    }

    var body: some View {
        GeometryReader { geo in
            let reps = repeatCount(for: geo.size.width)
            Group {
                if reduceMotion || !isOnScreen {
                    strip(reps: reps, phase: basePhase + dragTranslation)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { tl in
                        strip(reps: reps, phase: phase(at: tl.date))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
            .clipped()
            .contentShape(Rectangle())
            .gesture(dragGesture)
        }
        .frame(height: itemHeight)
        .onAppear {
            isOnScreen = true
            if !reduceMotion { legStart = Date() }
        }
        .onDisappear {
            // Bank the travelled distance and stop the timeline completely.
            basePhase = wrapped(basePhase)
            legStart = nil
            isOnScreen = false
        }
    }

    /// Live phase = banked phase + this leg's travel + the finger's translation.
    private func phase(at date: Date) -> CGFloat {
        guard let legStart, !isDragging else { return basePhase + dragTranslation }
        let elapsed = date.timeIntervalSince(legStart)
        return basePhase + CGFloat(max(0, elapsed) * pointsPerSecond) + dragTranslation
    }

    private func wrapped(_ p: CGFloat) -> CGFloat {
        let w = setWidth
        guard w > 0 else { return 0 }
        return p.truncatingRemainder(dividingBy: w)
    }

    private func strip(reps: Int, phase: CGFloat) -> some View {
        // Wrapping into (-setWidth, 0] keeps the strip anchored over the viewport
        // while the content underneath is identical every `setWidth` points.
        let x = -wrapped(phase)
        return HStack(spacing: spacing) {
            ForEach(0..<reps, id: \.self) { rep in
                ForEach(items) { item in
                    content(item)
                        .frame(width: itemWidth, height: itemHeight)
                        .id("\(rep)-\(item.id)")
                }
            }
        }
        .padding(.trailing, spacing)
        .offset(x: x)
        // The repeated copies are decorative duplicates; expose the set once.
        .accessibilityElement(children: .contain)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                if !isDragging {
                    // Bank whatever the auto travel had accumulated, then hand
                    // control entirely to the finger — the two never overlap.
                    basePhase = wrapped(phase(at: Date()))
                    isDragging = true
                    legStart = nil
                }
                dragTranslation = -value.translation.width
            }
            .onEnded { value in
                basePhase = wrapped(basePhase - value.translation.width)
                dragTranslation = 0
                isDragging = false
                interactionToken &+= 1
                let token = interactionToken
                // Resume smoothly a moment after the user stops interacting.
                DispatchQueue.main.asyncAfter(deadline: .now() + resumeDelay) {
                    guard token == interactionToken, isOnScreen, !isDragging, !reduceMotion else { return }
                    legStart = Date()
                }
            }
    }
}
