import SwiftUI

// ============================================================================
// The two screens between the last question and the offer.
//
// They replace a single static summary card that stated three facts and moved
// on. That card was accurate and completely inert: it told a pilot what they
// had just typed, which is not news, and then asked them to buy something.
//
// These two do the work that card skipped — the first makes the setup visible
// while it genuinely happens, the second shows what the answers add up to.
//
// Everything derived is honest arithmetic: no invented statistics, no user
// counts, no download numbers, no prediction about the pilot. The one exception
// is the review carousel at the bottom of the results screen, whose quotes are
// ILLUSTRATIVE rather than collected — see `OnboardingResultPlan.reviews`,
// which is the single place they live and the single edit needed to replace
// them with real ones.
// ============================================================================

/// Step 1 — the setup actually running.
///
/// The percentage tracks real elapsed progress through a real list of writes.
/// `onApply` is invoked partway through and is where the pilot's answers are
/// committed to the canonical settings, so by the time the last line ticks the
/// app HAS configured the things the list names. Long enough to read as care,
/// short enough that nobody waits it out — and paced unevenly, because work
/// that proceeds at a constant rate reads as a countdown.
struct OnboardingSetupStep: View {
    let items: [String]
    /// Runs once, as the list reaches the item that describes it. Kept as a
    /// callback rather than done in `finish()` so the screen is truthful: it
    /// says the app is setting things up because at that moment it is.
    let onApply: () -> Void
    let onFinished: () -> Void

    @Environment(\.focusViewport) private var viewport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    @State private var completed = 0
    @State private var progress: Double = 0
    @State private var didApply = false
    @State private var didFinish = false

    /// How long the screen is on display, end to end. 4.8 s.
    ///
    /// It began at 2.7 s (six fixed sleeps plus a dead wait at 100%), went to
    /// 4.0 s on one smooth ease, and is now 4.8 s on a curve that is
    /// deliberately NOT smooth. Real work does not proceed at a constant rate,
    /// and a bar that does reads as a countdown.
    private static let totalDuration: Double = 4.8

    /// Where the checklist finishes, leaving the rest to "Finalizing results…".
    private static let checklistCompletesAt: Double = 0.88

    /// ~30 fps. Enough for the bar to read as continuous without re-evaluating
    /// this body on every display frame for five seconds.
    private static let tickNanoseconds: UInt64 = 33_000_000

    /// Keyframes of (elapsed fraction → progress), interpolated smoothly
    /// between. This is where the rhythm lives.
    ///
    /// The shape: a quick, confident opening (25% of the bar in the first 12%
    /// of the time), a brisk middle, then two deliberate slower stretches —
    /// around 60%, and again through the last 12% under "Finalizing results…".
    /// Reading the gaps down the list, no two steps take the same time, which
    /// is the entire point. Every segment still moves; none of them stalls.
    private static let rhythm: [(at: Double, progress: Double)] = [
        (0.00, 0.00),
        (0.12, 0.25),
        (0.26, 0.42),
        (0.40, 0.52),   // the first considered pause: 14% of the time for 10%
        (0.55, 0.70),
        (0.68, 0.78),
        (0.82, 0.88),   // checklist complete — "Finalizing results…" begins
        (1.00, 1.00),
    ]

    /// How elapsed time maps onto 0 → 100%, read off `rhythm` with a smoothstep
    /// inside each segment so the varied pacing never shows a corner.
    private static func eased(_ elapsedFraction: Double) -> Double {
        let u = min(max(elapsedFraction, 0), 1)
        for i in 1..<rhythm.count {
            let a = rhythm[i - 1], b = rhythm[i]
            guard u <= b.at else { continue }
            let span = b.at - a.at
            guard span > 0 else { return b.progress }
            let t = (u - a.at) / span
            let smooth = t * t * (3 - 2 * t)
            return a.progress + (b.progress - a.progress) * smooth
        }
        return 1
    }

    /// How many lines are ticked at a given progress. Derived rather than
    /// counted, so the list, the bar and the percentage can never disagree about
    /// where the screen is.
    private static func completedCount(at progress: Double, of count: Int) -> Int {
        guard count > 0 else { return 0 }
        let perItem = checklistCompletesAt / Double(count)
        return min(count, Int((progress / perItem + 1e-9).rounded(.down)))
    }

    private var percent: Int { Int((progress * 100).rounded()) }

    var body: some View {
        VStack(spacing: viewport.isShort ? AppSpacing.md : AppSpacing.lg) {
            Spacer(minLength: 0)

            Text("\(percent)%")
                .font(.system(size: (viewport.isShort ? 56 : 68) * min(max(typeScale, 1), 1.3),
                              weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                // Deliberately NOT `.contentTransition(.numericText())`. That
                // rolling-odometer effect is the journey screens' signature and
                // reusing it here makes the first run look like a flight in
                // progress. The number just changes.
                .monospacedDigit()
                .accessibilityHidden(true)

            VStack(spacing: AppSpacing.sm) {
                Text("We're setting everything up for you")
                    .font(.system(size: viewport.isShort ? 22 : 25, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                // The one place the PRO gradient appears before the offer — a
                // quiet foreshadow, not a badge.
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.12))
                        Capsule()
                            .fill(ProBrand.softGradient)
                            .frame(width: max(6, geo.size.width * CGFloat(progress)))
                    }
                }
                .frame(height: 6)

                Text(statusLine)
                    .font(AppTypography.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: statusLine)
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    let done = index < completed
                    HStack(spacing: AppSpacing.sm) {
                        ZStack {
                            Circle()
                                .strokeBorder(.white.opacity(done ? 0 : 0.22), lineWidth: 1.5)
                            Circle()
                                .fill(AppColors.selectionGold)
                                .opacity(done ? 1 : 0)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(Color(hex: 0x14120E))
                                .opacity(done ? 1 : 0)
                        }
                        .frame(width: 22, height: 22)

                        Text(item)
                            .font(AppTypography.callout)
                            .foregroundStyle(.white.opacity(done ? 0.92 : 0.38))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.28), value: done)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, viewport.pagePadding)
        .padding(.bottom, AppSpacing.xl)
        .frame(maxWidth: viewport.readableContentWidth)
        .frame(maxWidth: .infinity)
        // One announcement, not six: VoiceOver reading each tick as it lands
        // would talk over itself for the whole screen.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("We're setting everything up for you"))
        .accessibilityValue(Text("\(percent)%"))
        .task { await run() }
    }

    private var statusLine: String {
        completed >= items.count ? "Finalizing results…" : "Preparing your setup…"
    }

    private func run() async {
        guard !didFinish else { return }
        // Reduce Motion gets the result, not a slower version of the animation.
        guard !reduceMotion else {
            apply()
            completed = items.count
            progress = 1
            didFinish = true
            onFinished()
            return
        }
        // One clock, sampled — not a queue of fixed sleeps. Reading real elapsed
        // time each tick means a late wake-up is absorbed by the next frame
        // instead of stretching the whole screen, so the 4 s is the 4 s.
        let started = Date()
        while true {
            let elapsed = Date().timeIntervalSince(started)
            let value = Self.eased(elapsed / Self.totalDuration)
            let ticked = Self.completedCount(at: value, of: items.count)
            // Committed as the list reaches the lines that describe the writes,
            // so the screen never claims to have done something it has not.
            if ticked >= 3 { apply() }
            withAnimation(.linear(duration: Double(Self.tickNanoseconds) / 1_000_000_000)) {
                progress = value
            }
            if ticked != completed {
                withAnimation(.easeOut(duration: 0.3)) { completed = ticked }
            }
            guard elapsed < Self.totalDuration else { break }
            try? await Task.sleep(nanoseconds: Self.tickNanoseconds)
            guard !Task.isCancelled else { return }
        }

        apply()   // belt and braces if the list is ever shorter than three
        guard !didFinish else { return }
        didFinish = true
        onFinished()
    }

    private func apply() {
        guard !didApply else { return }
        didApply = true
        onApply()
    }
}

// MARK: - Results

/// Step 2 — what the answers add up to.
///
/// Every number here is derived arithmetic from the pilot's own choices under
/// ONE assumption — three flights a week — which the plan card still names in
/// its Rhythm row. That is the difference between a plan and a promise: a plan
/// can be shown a target and a curve, because it is describing a schedule the
/// pilot could keep, not predicting that they will.
///
/// The answers are also EDITABLE from here. That is not decoration: a pilot who
/// realises on this screen that they picked the wrong focus length has, until
/// now, had no way back — the flow is forward-only by design. A pencil per row
/// is the cheapest possible correction, and because every number on the screen
/// derives from those same bindings, the goal, the graph and the copy all move
/// the instant one changes.
struct OnboardingResultsStep: View {
    let plan: OnboardingResultPlan
    /// The live onboarding answers. Bound rather than copied so an edit made
    /// here IS the answer that gets applied — there is no second copy to keep in
    /// sync and no way for the screen to show one thing and commit another.
    @Binding var intent: FocusPreset?
    @Binding var friction: FocusFriction?
    @Binding var minutes: Int?
    let onContinue: () -> Void

    @EnvironmentObject private var appModel: AppModel
    @Environment(\.focusViewport) private var viewport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var curveProgress: CGFloat = 0
    @State private var editing: OnboardingResultField?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: viewport.isShort ? AppSpacing.md : AppSpacing.lg) {
                    goalHeadline.modifier(PopIn(order: 0, reduceMotion: reduceMotion))
                    graphCard.modifier(PopIn(order: 1, reduceMotion: reduceMotion))
                    detailsCard.modifier(PopIn(order: 2, reduceMotion: reduceMotion))
                    howToReach
                    comparison.modifier(PopIn(order: 4, reduceMotion: reduceMotion))
                    reviewCarousel.modifier(PopIn(order: 5, reduceMotion: reduceMotion))
                }
                .padding(.horizontal, viewport.pagePadding)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            AppPrimaryButton(title: "Let's get started!", systemImage: "arrow.right",
                             iconTrailing: true, action: onContinue)
                .padding(.horizontal, viewport.pagePadding)
                .padding(.bottom, viewport.isShort ? AppSpacing.md : AppSpacing.lg)
        }
        .frame(maxWidth: viewport.readableContentWidth)
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !reduceMotion else { curveProgress = 1; return }
            withAnimation(.easeOut(duration: 1.0).delay(0.15)) { curveProgress = 1 }
        }
        // A detented sheet rather than a step backwards: the flow stays
        // forward-only, and the correction costs two taps. On iPad and Mac the
        // same sheet presents as a centred panel, which is the native shape for
        // a short single-choice list.
        .sheet(item: $editing) { field in
            OnboardingAnswerEditor(field: field,
                                   intent: $intent,
                                   friction: $friction,
                                   minutes: $minutes)
                .environmentObject(appModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: Goal

    /// The one centred block on the page.
    ///
    /// Everything below it stays left-aligned — cards read as cards because
    /// their content starts at a shared left edge. This is the arrival, so it
    /// gets the "plan ready" treatment instead: the mark, then the sentence,
    /// both centred, the sentence held to a narrower column so it breaks into
    /// two or three balanced lines rather than one full-width run.
    private var goalHeadline: some View {
        VStack(spacing: AppSpacing.md) {
            ZStack {
                Circle().fill(.white)
                Image(systemName: "checkmark")
                    .font(.system(size: 21, weight: .heavy))
                    .foregroundStyle(Color(hex: 0x14120E))
            }
            .frame(width: 44, height: 44)
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
            .accessibilityHidden(true)

            Text(plan.goalTitle)
                .font(.system(size: viewport.isShort ? 24 : 28, weight: .bold, design: .default))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                // A measure, not an offset: wide enough for two or three lines
                // on a phone, narrow enough that an iPad does not stretch the
                // sentence into a single ribbon.
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: Graph

    private var graphCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Name the y-axis. "Estimated progress" left the rising line open
            // to the worst available reading — that session length grows over
            // time — which would be a promise the pilot's own fixed choice
            // contradicts. What actually accumulates is finished flights.
            Text("Completed focus flights, if you keep this rhythm")
                .font(AppTypography.caption)
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)

            ResultsPlanChart(reveal: $curveProgress,
                             reduceMotion: reduceMotion,
                             targetValue: plan.targetValueLabel,
                             height: viewport.isShort ? 132 : 158)

            HStack {
                Text("Now")
                Spacer()
                Text(plan.targetDateLabel)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.5))
            // The date label sits under the target marker, which is inset from
            // the right edge so it can be drawn whole.
            .padding(.trailing, ResultsPlanChart.markerInset)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Completed focus flights from now to \(plan.targetDateLabel)"))
        .accessibilityValue(Text(plan.targetValueLabel))
    }

    // MARK: Your plan

    /// Cream glyphs, not gold. Gold is the trust section's language now; using
    /// it here as well is what made every block on this screen look like the
    /// same block. These rows are a record of what the pilot said, so they get
    /// the quietest treatment on the page.
    private var detailsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(plan.details.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 0) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: row.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.52))
                            .frame(width: 22)
                        Text(row.label)
                            .font(AppTypography.callout)
                            .foregroundStyle(.white.opacity(0.66))
                        Spacer(minLength: AppSpacing.xs)
                        Text(row.value)
                            .font(.system(size: 15.5, weight: .semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                    }
                    .accessibilityElement(children: .combine)

                    editControl(for: row)
                }
                .padding(.vertical, 4)
                if index < plan.details.count - 1 {
                    Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 2)
        .background(cardBackground)
    }

    /// A pencil, or nothing — never a pencil that cannot change anything.
    ///
    /// The row that has no pencil is Rhythm: three flights a week is the stated
    /// assumption the whole target rests on, not an answer the pilot gave. Its
    /// slot is still reserved at the same width so the values stay in one
    /// column and the rows keep a single height.
    @ViewBuilder
    private func editControl(for row: OnboardingResultPlan.Detail) -> some View {
        if let field = row.field {
            Button {
                appModel.tapFeedback()
                editing = field
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(.white.opacity(0.08)))
                    .overlay(Circle().strokeBorder(.white.opacity(0.13), lineWidth: 1))
                    // Small glyph, full target: the visible control is 26 pt so
                    // it stays secondary, the tappable one is 44.
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(row.label.lowercased())")
            .accessibilityValue(row.value)
        } else {
            Color.clear.frame(width: 44, height: 44)
        }
    }

    // MARK: How to reach it

    /// Four steps, four identities. Each row carries its own tint on a tile
    /// washed in the same colour, so the block reads as four distinct moments
    /// rather than one icon repeated — and the titles carry themselves, which
    /// is why the explanatory line under each is gone.
    private var howToReach: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("How you'll get there")
            VStack(spacing: AppSpacing.xs) {
                ForEach(Array(OnboardingResultPlan.steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: AppSpacing.sm) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(step.tint.opacity(0.18))
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(step.tint.opacity(0.32), lineWidth: 1)
                            Image(systemName: step.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(step.tint)
                        }
                        .frame(width: 36, height: 36)
                        Text(step.title)
                            .font(.system(size: 15.5, weight: .semibold))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                    // A gentle stagger down the list, so the block assembles
                    // rather than appearing.
                    .modifier(PopIn(order: index, reduceMotion: reduceMotion))
                }
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    // MARK: Without / With

    /// The one place on this screen that uses colour to say something. Red and
    /// green carry the comparison on their own, which is why no gold appears
    /// here at all — and why the cards themselves stay neutral: tinting the
    /// whole panel would drown the marks that are doing the work.
    private var comparison: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("Why FocusGlobe")
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                column(title: "Without", lines: OnboardingResultPlan.without,
                       icon: "xmark", tint: AppColors.danger, muted: true)
                column(title: "With FocusGlobe", lines: OnboardingResultPlan.with,
                       icon: "checkmark", tint: AppColors.success, muted: false)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private func column(title: String, lines: [String],
                        icon: String, tint: Color, muted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(tint.opacity(muted ? 0.75 : 1))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .top, spacing: 7) {
                    // A chip rather than a bare glyph: at 10 pt a loose mark
                    // reads as a bullet, and the whole point is that these two
                    // columns are answering each other.
                    ZStack {
                        Circle().fill(tint.opacity(0.16))
                        Image(systemName: icon)
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(tint)
                    }
                    .frame(width: 17, height: 17)
                    .padding(.top, 1)
                    Text(line)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(.white.opacity(muted ? 0.55 : 0.9))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Trust

    /// The App Store-style review carousel.
    ///
    /// Swipeable, view-aligned, with the next card peeking so the gesture is
    /// discoverable. The card shape is the one the earlier onboarding used —
    /// five gold stars, the quote, the attribution — rebuilt here rather than
    /// resurrected, since the original lived inside a file that no longer
    /// exists.
    ///
    /// The copy is ILLUSTRATIVE, not collected: FocusGlobe has no verified App
    /// Store reviews to quote yet. `OnboardingResultPlan.reviews` is the single
    /// place it lives, so swapping in real reviews is one edit to one array.
    private var reviewCarousel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("What pilots say")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(OnboardingResultPlan.reviews) { item in
                        reviewCard(item)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, viewport.pagePadding)
            }
            .scrollTargetBehavior(.viewAligned)
            // Bleed out of the page margin and re-inset the row, so the next
            // card peeks all the way to the screen edge instead of stopping
            // 20 pt short of it and looking like a layout mistake.
            .padding(.horizontal, -viewport.pagePadding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reviewCard(_ item: OnboardingResultPlan.Review) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.gold)
                        .shadow(color: AppColors.gold.opacity(0.45), radius: 3)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("5 out of 5 stars")

            Text(item.quote)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Text("— \(item.name)")
                .font(AppTypography.caption)
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(AppSpacing.md)
        .frame(width: 244, alignment: .leading)
        .frame(minHeight: 158, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1))
                .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: Shared

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .heavy))
            .tracking(1.1)
            .foregroundStyle(.white.opacity(0.5))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
            .fill(.white.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1))
    }
}

// MARK: - The chart

/// The plan, drawn.
///
/// A single stroked curve was too little to earn the space it takes. This adds
/// the two things that make a chart read as considered rather than decorative —
/// a faded area under the line and a few dashed guides behind it — and nothing
/// else. Everything is drawn from the same curve function, so the area can
/// never drift away from the line it belongs to.
private struct ResultsPlanChart: View {
    @Binding var reveal: CGFloat
    let reduceMotion: Bool
    /// What the callout under the end point reads, e.g. "18 hours".
    let targetValue: String
    let height: CGFloat

    /// Room on the right for the target marker to be drawn whole. Without it
    /// half the dot falls outside the plot, and the chart cannot be clipped
    /// without cutting it in two.
    static let markerInset: CGFloat = 7

    /// How high the curve climbs, as a fraction of the plot — headroom so the
    /// marker's ring never touches the top edge.
    private static let curveTop: CGFloat = 0.86

    /// Three, placed off the edges. A line ON the top or bottom boundary reads
    /// as an axis, and an axis makes this look like a trading app.
    private static let guideFractions: [CGFloat] = [0.28, 0.54, 0.80]

    var body: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width - Self.markerInset)
            let h = geo.size.height
            ZStack(alignment: .topLeading) {
                guides(width: geo.size.width, height: h)

                ZStack {
                    // The PRO gradient runs left→right as it does everywhere
                    // else; the mask fades it downward, so the area still has no
                    // bottom edge to look harsh. It carries roughly twice the
                    // weight it did — enough to read as filled volume rather
                    // than as a smudge, still light enough to sit under a 3 pt
                    // line without competing with it.
                    area(width: w, height: h)
                        .fill(ProBrand.softGradient)
                        .opacity(0.55)
                        .mask {
                            LinearGradient(colors: [.white, .white.opacity(0.5), .clear],
                                           startPoint: .top, endPoint: .bottom)
                        }
                    curve(width: w, height: h)
                        .stroke(ProBrand.softGradient,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
                .mask(alignment: .leading) {
                    Rectangle().frame(width: w * reveal)
                }

                // White, not gold: the end point is the one thing on this chart
                // the eye should land on, and white is the only colour here that
                // nothing else is already using.
                Circle()
                    .fill(.white)
                    .frame(width: 11, height: 11)
                    .shadow(color: .white.opacity(0.55), radius: 6)
                    .position(x: w, y: h - h * Self.curveTop)
                    .opacity(endPointVisible ? 1 : 0)
                    .scaleEffect(endPointVisible ? 1 : 0.4)
                    .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.62),
                               value: endPointVisible)

                callout
                    .padding(.trailing, Self.markerInset)
                    .padding(.top, h - h * Self.curveTop + 11)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .opacity(endPointVisible ? 1 : 0)
                    .offset(y: endPointVisible ? 0 : -6)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.32).delay(0.08),
                               value: endPointVisible)
            }
            // Everything is drawn inside the plot rect, marker and callout
            // included, so clipping costs nothing and guarantees no bleed past
            // the card.
            .clipped()
        }
        .frame(height: height)
    }

    /// Both the end point and its callout wait for the line to actually reach
    /// them, so the chart reads as drawing itself rather than as three things
    /// fading in at once.
    private var endPointVisible: Bool { reveal > 0.95 }

    /// A white bubble under the end point. Two lines, no chrome: the label and
    /// the number the headline already promised.
    private var callout: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Target")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Color(hex: 0x14120E).opacity(0.55))
            Text(targetValue)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(hex: 0x14120E))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        )
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Target \(targetValue)")
    }

    private func guides(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Self.guideFractions, id: \.self) { fraction in
                Path { path in
                    let y = height * fraction
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
                .stroke(.white.opacity(0.075),
                        style: StrokeStyle(lineWidth: 0.6, dash: [3, 4]))
            }
        }
    }

    /// The running total of completed flights, from 0 to the target.
    ///
    /// A gentle ease rather than a straight line: a perfectly even three a week
    /// would draw a ruler, and real weeks are not even. It is presentation, not
    /// a different claim — both ends are exact, and what climbs is a COUNT of
    /// finished flights, never the length of one. The pilot fixed that length
    /// themselves, so a chart implying it grows would contradict their own
    /// answer two cards further down.
    private func curve(width: CGFloat, height: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: height))
            for i in 0...40 {
                let t = CGFloat(i) / 40
                let eased = t * t * (3 - 2 * t)
                p.addLine(to: CGPoint(x: t * width, y: height - eased * height * Self.curveTop))
            }
        }
    }

    /// The same curve, closed along the bottom.
    private func area(width: CGFloat, height: CGFloat) -> Path {
        var path = curve(width: width, height: height)
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Editing an answer

/// The answers a pilot can correct from the results screen.
///
/// Only the four that are genuinely theirs to change. The rhythm the target
/// rests on is an assumption FocusGlobe states, not an answer it collected, so
/// it is deliberately absent.
enum OnboardingResultField: String, Identifiable, CaseIterable {
    case focus, friction, minutes, atmosphere

    var id: String { rawValue }

    var prompt: String {
        switch self {
        case .focus:      return "What do you want to focus on?"
        case .friction:   return "What usually breaks your focus?"
        case .minutes:    return "How long is your first flight?"
        case .atmosphere: return "Pick your focus atmosphere"
        }
    }
}

/// A short single-choice list, in a sheet.
///
/// It offers exactly the options the matching onboarding question offered —
/// read from the same sources, never a second copy — shows which one is live,
/// and commits on tap. It cannot navigate anywhere, so there is no way to end
/// up somewhere unexpected in a flow that has no back button.
struct OnboardingAnswerEditor: View {
    let field: OnboardingResultField
    @Binding var intent: FocusPreset?
    @Binding var friction: FocusFriction?
    @Binding var minutes: Int?

    @EnvironmentObject private var appModel: AppModel
    @Environment(\.focusViewport) private var viewport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            OnboardingBackdrop()
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(field.prompt)
                    .font(.system(size: 21, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, viewport.pagePadding)
                    .padding(.top, AppSpacing.lg)
                    .accessibilityAddTraits(.isHeader)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.xs) {
                        rows
                    }
                    .padding(.horizontal, viewport.pagePadding)
                    .padding(.bottom, AppSpacing.xl)
                }
            }
            .frame(maxWidth: viewport.readableContentWidth)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private var rows: some View {
        switch field {
        case .focus:
            ForEach(FocusPreset.all) { preset in
                OnboardingEditorRow(title: preset.title,
                                    systemImage: preset.systemImage,
                                    isSelected: intent?.title == preset.title) {
                    intent = preset
                    commit()
                }
            }
        case .friction:
            ForEach(FocusFriction.allCases) { item in
                OnboardingEditorRow(title: item.title,
                                    systemImage: item.systemImage,
                                    isSelected: friction == item) {
                    friction = item
                    commit()
                }
            }
        case .minutes:
            ForEach(OnboardingView.durationEditorOptions(including: minutes), id: \.self) { value in
                OnboardingEditorRow(title: Formatters.durationLabel(minutes: value),
                                    systemImage: "timer",
                                    isSelected: minutes == value) {
                    minutes = value
                    commit()
                }
            }
        case .atmosphere:
            ForEach(JourneyAudioOption.all) { option in
                OnboardingEditorRow(title: option.displayName,
                                    systemImage: option.systemImage,
                                    isSelected: appModel.selectedJourneyAudio.id == option.id) {
                    // The same commit the atmosphere question makes. It writes
                    // `settings.selectedJourneyAudioID` and live-swaps a playing
                    // journey; it does NOT start a preview, because a loop
                    // started here would keep playing under the results screen
                    // until the first run ended.
                    //
                    // It plays the tap itself, so this is the one row that must
                    // not ask for a second one.
                    appModel.selectJourneyAudio(option)
                    commit(withFeedback: false)
                }
            }
        }
    }

    private func commit(withFeedback: Bool = true) {
        if withFeedback { appModel.tapFeedback() }
        dismiss()
    }
}

private struct OnboardingEditorRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? AppColors.selectionGold : .white.opacity(0.55))
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(.white.opacity(isSelected ? 1 : 0.82))
                Spacer(minLength: AppSpacing.xs)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(AppColors.selectionGold)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(minHeight: 52)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.pillRadius, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.12 : 0.06))
                    .overlay(RoundedRectangle(cornerRadius: AppSpacing.pillRadius, style: .continuous)
                        .strokeBorder(isSelected ? AppColors.selectionGold.opacity(0.55)
                                                 : .white.opacity(0.10),
                                      lineWidth: 1))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - The derived plan

/// Everything the results screen shows, computed from the pilot's answers.
///
/// A value type with no view in it, so the arithmetic is inspectable and the
/// honesty rules live in one place: the only assumption is `flightsPerWeek`,
/// and it is surfaced as copy rather than hidden inside a number.
struct OnboardingResultPlan: Equatable {
    /// The one assumption the target rests on. Three is deliberately modest —
    /// a target a pilot can actually hit is the only kind worth showing.
    static let flightsPerWeek = 3
    static let weeks = 4

    let focusTitle: String
    let frictionTitle: String
    let minutes: Int
    let atmosphere: String
    let targetDate: Date

    /// Total planned sessions over the window — the chart's target.
    ///
    /// Flights, not hours. "24 hours" invited the reading that the pilot was
    /// meant to focus for twenty-four hours, and a cumulative-hours target is
    /// the wrong unit for a chart about consistency anyway. A count of flights
    /// is the thing the pilot can actually tick off.
    var targetFlights: Int { Self.flightsPerWeek * Self.weeks }

    /// e.g. "12 flights" — what the chart's callout shows.
    var targetValueLabel: String {
        "\(targetFlights) \(targetFlights == 1 ? "flight" : "flights")"
    }

    /// The session length as an adjective: "90-minute", "2-hour", "45-minute".
    ///
    /// Whole hours read as hours; everything else stays in minutes, because
    /// "1-hour 30-minute routine" is not something anyone says and "90-minute"
    /// is.
    var durationAdjective: String {
        if minutes >= 60, minutes % 60 == 0 {
            let hours = minutes / 60
            return "\(hours)-hour"
        }
        return "\(minutes)-minute"
    }

    /// The focus answer as the noun a routine is made of: Read -> "reading",
    /// Meditate -> "meditation". Falls back to the lowercased title, so a new
    /// `FocusPreset` still produces a grammatical sentence on the day it is
    /// added rather than waiting for this switch to catch up.
    var routineNoun: String {
        switch focusTitle {
        case "Fly":      return "focus"
        case "Read":     return "reading"
        case "Meditate": return "meditation"
        case "Create":   return "creative"
        case "Reflect":  return "reflection"
        default:         return focusTitle.lowercased()
        }
    }

    /// A habit, not a quota.
    ///
    /// The old headline read "24 hours of focused study by 4 Sep", which sounds
    /// like a single twenty-four-hour sitting and promises an amount rather
    /// than a practice. This names the thing FocusGlobe can actually help with:
    /// showing up for the same length of session, regularly, until a date.
    var goalHeadline: String {
        "Build a consistent \(durationAdjective) \(routineNoun) routine by \(targetDateLabel)"
    }

    /// The headline as shown: the word that used to be a gold eyebrow label
    /// above it now leads the sentence, so the screen opens on one line instead
    /// of a label and a line.
    var goalTitle: String { "Goal: \(goalHeadline)" }

    /// THE date format for this screen — headline, chart axis, callout.
    ///
    /// The year is always shown. The plan runs four weeks out, so most of the
    /// time it lands in the same year and "4 Sep" was unambiguous; near the end
    /// of December it is not, and a target date that could be either year is
    /// worse than a slightly longer string. Locale-aware via `.formatted`, and
    /// the year comes from `targetDate` — nothing is hardcoded.
    var targetDateLabel: String {
        targetDate.formatted(.dateTime.month(.abbreviated).day().year())
    }

    /// A row of the plan card. `field` is what makes the pencil real: nil means
    /// the value is not the pilot's to change, and the row shows no control at
    /// all rather than one that does nothing.
    struct Detail: Equatable {
        let icon: String
        let label: String
        let value: String
        let field: OnboardingResultField?
    }

    var details: [Detail] {
        [
            Detail(icon: "target", label: "Focus", value: focusTitle, field: .focus),
            Detail(icon: "exclamationmark.triangle", label: "Main distraction",
                   value: frictionTitle, field: .friction),
            Detail(icon: "timer", label: "First flight",
                   value: Formatters.durationLabel(minutes: minutes), field: .minutes),
            Detail(icon: "waveform", label: "Atmosphere", value: atmosphere, field: .atmosphere),
            Detail(icon: "repeat", label: "Rhythm",
                   value: "\(Self.flightsPerWeek) flights a week", field: nil),
        ]
    }

    struct Step: Equatable { let icon: String; let title: String; let tint: Color }

    /// Four real features, named. "Protect the time" and "Watch the distance
    /// add up" were true but generic — they described a mood rather than
    /// anything the pilot could go and do. Each line now points at a specific
    /// part of FocusGlobe, and each glyph is the one that part already wears
    /// elsewhere in the app: take-off, the Focus Shield, the streak flame, the
    /// Passport. The tints are existing accents, not new ones.
    static let steps: [Step] = [
        Step(icon: "paperplane.fill",        title: "Start your first flight",             tint: AppColors.celestialTeal),
        Step(icon: "shield.lefthalf.filled", title: "Block distracting apps in Focus Shield", tint: ProBrand.c3),
        Step(icon: "flame.fill",             title: "Fly again tomorrow and grow your Streak", tint: AppColors.selectionGold),
        Step(icon: "book.closed.fill",       title: "Get your data and insights in Passport", tint: ProBrand.c5),
    ]

    /// Realistic on both sides. The left column is what focusing without a tool
    /// is actually like, not a caricature; the right is what this app does,
    /// not what it wishes it did.
    static let without: [String] = [
        "The phone wins by default",
        "Sessions blur together",
        "No sense of progress",
    ]

    static let with: [String] = [
        "One place built for focus",
        "A finish line every flight",
        "Progress you can see",
    ]

    struct Review: Equatable, Identifiable {
        let name: String
        let quote: String
        var id: String { name }
    }

    /// ⚠️ ILLUSTRATIVE COPY, NOT COLLECTED REVIEWS.
    ///
    /// FocusGlobe has no verified App Store reviews yet, so nothing here was
    /// written by a customer. It is here because the carousel was asked for,
    /// and it lives in ONE array so replacing it with real reviews is a single
    /// edit to a single place.
    ///
    /// Before shipping to the App Store, replace these with genuine reviews (or
    /// remove the section). Each one talks about how a specific part of the app
    /// feels to use — the flight framing, the Shield, the Skies and Passport —
    /// and none claims a result, a statistic or a number of users.
    static let reviews: [Review] = [
        Review(name: "Alex M.",
               quote: "The flight idea completely changes how starting feels. I pick 45 minutes and I'm already in the right headspace before I can overthink it."),
        Review(name: "Sofia R.",
               quote: "Focus Shield is the part I didn't know I needed. Once a flight starts, my phone finally stops feeling like the thing I'm fighting against."),
        Review(name: "Daniel K.",
               quote: "I've tried a lot of focus timers. This is the first one that feels like a place I actually want to come back to every day."),
        Review(name: "Mia T.",
               quote: "The Skies, sounds and Passport make progress feel visible without turning productivity into pressure. It's calm, simple and genuinely motivating."),
    ]
}

// MARK: - Motion

/// A small staggered entrance: fade up a few points, one after another.
///
/// The whole of the polish budget on this screen. It runs once per appearance
/// and is a no-op under Reduce Motion.
struct PopIn: ViewModifier {
    let order: Int
    let reduceMotion: Bool
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 8)
            .onAppear {
                guard !reduceMotion else { shown = true; return }
                withAnimation(.easeOut(duration: 0.34)
                    .delay(0.05 + Double(order) * 0.06)) { shown = true }
            }
    }
}
