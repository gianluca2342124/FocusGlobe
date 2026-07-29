import SwiftUI

/// A lightweight, continuously moving carousel shared by premium previews.
///
/// Each item is rendered once. Its position is wrapped mathematically, so the
/// conveyor can run forever without duplicated view trees, sentinel indexes or
/// visible resets. Automatic motion fully yields while the pilot drags and
/// resumes after a short pause without snapping away the drag's momentum.
struct FocusContinuousCarousel<Item: Identifiable, Card: View>: View {
    let items: [Item]
    @Binding var selectedIndex: Int
    var spacing: CGFloat = 12
    var maximumCardWidth: CGFloat = 340
    /// Points per second. A card advances one position every
    /// `(cardWidth + spacing) / speed` seconds — on a 390 pt phone that is ~7.5 s
    /// at 34, versus ~19.5 s at the previous 14, which read as a static row.
    var speed: CGFloat = 34
    var resumeDelay: TimeInterval = 2.4
    @ViewBuilder let card: (Item, Double) -> Card

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var motionOrigin = Date()
    @State private var frozenDistance: CGFloat = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var isDragging = false
    @State private var isAutomatic = false
    @State private var isVisible = false
    @State private var resumeTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let cardWidth = min(maximumCardWidth, max(196, width * 0.62))
            let step = cardWidth + spacing

            TimelineView(.animation(
                minimumInterval: 1.0 / 30.0,
                paused: reduceMotion || !isVisible || scenePhase != .active
            )) { context in
                let distance = reduceMotion ? 0 : automaticDistance(at: context.date)
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
        .onAppear {
            selectedIndex = normalized(selectedIndex)
            isVisible = true
            motionOrigin = Date()
            isAutomatic = !reduceMotion && scenePhase == .active
        }
        .onDisappear {
            resumeTask?.cancel()
            resumeTask = nil
            isVisible = false
            isAutomatic = false
            isDragging = false
            dragTranslation = 0
        }
        .onChange(of: reduceMotion) { _, reduced in
            resumeTask?.cancel()
            resumeTask = nil
            frozenDistance = 0
            dragTranslation = 0
            isDragging = false
            motionOrigin = Date()
            isAutomatic = !reduced && isVisible && scenePhase == .active
        }
        .onChange(of: scenePhase) { _, phase in
            resumeTask?.cancel()
            resumeTask = nil
            if phase == .active {
                motionOrigin = Date()
                isAutomatic = !reduceMotion && isVisible
            } else {
                freezeAutomaticMotion(at: Date())
            }
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
                let now = Date()
                if !isDragging {
                    freezeAutomaticMotion(at: now)
                    isDragging = true
                }
                resumeTask?.cancel()
                resumeTask = nil
                dragTranslation = value.translation.width
            }
            .onEnded { value in
                let projected = value.translation.width
                    + (value.predictedEndTranslation.width - value.translation.width) * 0.28
                let globalIndex = Double(normalized(selectedIndex))
                    + Double(frozenDistance - projected) / Double(step)
                let nearest = globalIndex.rounded()

                selectedIndex = normalized(Int(nearest))
                frozenDistance = CGFloat(globalIndex - nearest) * step
                dragTranslation = 0
                isDragging = false
                scheduleAutomaticResume()
            }
    }

    private func automaticDistance(at date: Date) -> CGFloat {
        guard isAutomatic else { return frozenDistance }
        return frozenDistance + CGFloat(date.timeIntervalSince(motionOrigin)) * speed
    }

    private func freezeAutomaticMotion(at date: Date) {
        frozenDistance = automaticDistance(at: date)
        motionOrigin = date
        isAutomatic = false
    }

    private func scheduleAutomaticResume() {
        guard !reduceMotion, isVisible, scenePhase == .active else { return }
        resumeTask?.cancel()
        resumeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(resumeDelay * 1_000_000_000))
            guard !Task.isCancelled, !isDragging, isVisible, !reduceMotion,
                  scenePhase == .active else { return }
            motionOrigin = Date()
            isAutomatic = true
        }
    }

    private func moveSelection(by delta: Int) {
        guard items.count > 1 else { return }
        resumeTask?.cancel()
        resumeTask = nil
        selectedIndex = normalized(selectedIndex + delta)
        frozenDistance = 0
        dragTranslation = 0
        motionOrigin = Date()
        isAutomatic = false
        scheduleAutomaticResume()
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
