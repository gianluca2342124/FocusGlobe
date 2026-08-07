import SwiftUI

// ============================================================================
// The two screens between the last question and the offer.
//
// They replace a single static summary card that stated three facts and moved
// on. That card was accurate and completely inert: it told a pilot what they
// had just typed, which is not news, and then asked them to buy something.
//
// These two do the work that card skipped — the first makes the setup visible
// while it genuinely happens, the second shows what the answers add up to. Both
// are held to the same rule: nothing on either screen is a claim the app cannot
// keep. There are no invented statistics, no fabricated reviews, no ratings, no
// user counts, and no prediction about the pilot. The graph is a PLAN drawn
// from a stated assumption, labelled as one.
// ============================================================================

/// Step 1 — the setup actually running.
///
/// The percentage tracks real elapsed progress through a real list of writes.
/// `onApply` is invoked partway through and is where the pilot's answers are
/// committed to the canonical settings, so by the time the last line ticks the
/// app HAS configured the things the list names. It is short by design: long
/// enough to read as care, short enough that nobody waits it out.
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

    /// How long the screen is on display, end to end.
    ///
    /// 4.0 s, up from 2.7 s. The old pacing was six fixed 380 ms sleeps plus a
    /// 420 ms wait AFTER the final tick — and that wait was dead time sitting at
    /// 100%, which is the one thing that makes a progress screen read as
    /// theatre. This is a single continuous run instead: the bar and the
    /// percentage never stop moving, and the screen hands off the instant it
    /// reaches 100% rather than pausing there first.
    private static let totalDuration: Double = 4.0

    /// Where the checklist finishes, leaving the rest to "Finalizing results…".
    private static let checklistCompletesAt: Double = 0.88

    /// ~30 fps. Enough for the bar to read as continuous and for the numeric
    /// content transition to roll its digits, without re-evaluating this body on
    /// every display frame for four seconds.
    private static let tickNanoseconds: UInt64 = 33_000_000

    /// How elapsed time maps onto 0 → 100%.
    ///
    /// A gentle ease-out. Lines tick ~0.48 s apart at the start and ~0.67 s
    /// apart at the end, and the closing 12% of the bar takes ~0.73 s — which is
    /// what gives "Finalizing results…" room to read as a real step rather than
    /// a caption on a pause. The exponent is deliberately mild: at 1.6 and above
    /// the tail decelerates so hard it reads as a stall, which is the opposite
    /// of the point.
    private static func eased(_ elapsedFraction: Double) -> Double {
        let u = min(max(elapsedFraction, 0), 1)
        return 1 - pow(1 - u, 1.25)
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
                .monospacedDigit()
                .contentTransition(.numericText())
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
/// ONE stated assumption (three flights a week), and the screen says so in
/// plain sight rather than burying it. That is the difference between a plan
/// and a promise: a plan can be shown a target and a curve, because it is
/// describing a schedule the pilot could keep, not predicting that they will.
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
                    goalHeadline
                    graphCard
                    detailsCard
                    howToReach
                    comparison
                    trustCarousel
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

    private var goalHeadline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Goal")
                .font(.system(size: 12, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(AppColors.selectionGold)
            Text(plan.goalHeadline)
                .font(.system(size: viewport.isShort ? 25 : 30, weight: .bold, design: .default))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            // The assumption, stated where the number is — not in a footnote.
            Text(plan.goalAssumption)
                .font(AppTypography.caption)
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: Graph

    private var graphCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Focused hours, if you keep this rhythm")
                .font(AppTypography.caption)
                .foregroundStyle(.white.opacity(0.6))

            ResultsPlanChart(reveal: $curveProgress,
                             reduceMotion: reduceMotion,
                             height: viewport.isShort ? 100 : 124)

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
        .accessibilityLabel(Text("Planned focused hours from now to \(plan.targetDateLabel)"))
        .accessibilityValue(Text(plan.goalHeadline))
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

    /// Four different meaningful glyphs — take-off, the shield, the streak
    /// flame, the Passport — carried in one restrained PRO-gradient treatment.
    /// Variation by SYMBOL rather than by colour: four accent colours here
    /// would compete with the gold above and the red/green below, and the page
    /// would read as a swatch test.
    private var howToReach: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("How you'll get there")
            ForEach(Array(OnboardingResultPlan.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(.white.opacity(0.06))
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                        Image(systemName: step.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ProBrand.softGradient)
                    }
                    .frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(.system(size: 15.5, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(step.detail)
                            .font(AppTypography.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                if index < OnboardingResultPlan.steps.count - 1 {
                    Color.clear.frame(height: 2)
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

    /// The premium carousel, deliberately NOT a review carousel.
    ///
    /// The shape is the one the old onboarding had — swipeable cards, gold at
    /// the top of each, a partial card peeking to say "there is more" — because
    /// that presentation was good. What it is NOT is the old CONTENT: those
    /// cards carried four invented names under five gold stars, and the code
    /// that wrote them called them "illustrative". FocusGlobe has no verified
    /// ratings, review quotes or user counts, so there is nothing legitimate to
    /// put under a star row and the star rows are gone with the names.
    ///
    /// What each card carries instead is a claim that can be checked in this
    /// repository: local storage, the optional account, every soundscape being
    /// ungated, and App Store cancellation. Gold stays as the section's colour
    /// so the block still reads as the trust block.
    private var trustCarousel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("Built to be trusted")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(OnboardingResultPlan.trust) { item in
                        trustCard(item)
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

    private func trustCard(_ item: OnboardingResultPlan.Trust) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: item.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColors.gold)
                .shadow(color: AppColors.gold.opacity(0.35), radius: 6)
            Text(item.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(item.detail)
                .font(AppTypography.caption)
                .foregroundStyle(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .frame(width: 236, alignment: .leading)
        .frame(minHeight: 152, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1))
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
                    // else; the mask fades it downward to nothing, so the area
                    // has no bottom edge to look harsh.
                    area(width: w, height: h)
                        .fill(ProBrand.softGradient)
                        .opacity(0.30)
                        .mask {
                            LinearGradient(colors: [.white, .white.opacity(0.28), .clear],
                                           startPoint: .top, endPoint: .bottom)
                        }
                    curve(width: w, height: h)
                        .stroke(ProBrand.softGradient,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
                .mask(alignment: .leading) {
                    Rectangle().frame(width: w * reveal)
                }

                Circle()
                    .fill(AppColors.selectionGold)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 2))
                    .position(x: w, y: h - h * Self.curveTop)
                    .opacity(reveal > 0.95 ? 1 : 0)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: reveal)
            }
            // Everything is drawn inside the plot rect, marker included, so
            // clipping costs nothing and guarantees no bleed past the card.
            .clipped()
        }
        .frame(height: height)
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

    /// A gentle ease rather than a straight line: real weeks are uneven. It is
    /// presentation, not a different claim — both ends are the honest
    /// arithmetic the headline states.
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
            ForEach(OnboardingView.flightLengths, id: \.self) { value in
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

    /// Total planned focus over the window, in whole hours (floored, so the
    /// figure can never overstate the plan).
    var targetHours: Int {
        max(1, (minutes * Self.flightsPerWeek * Self.weeks) / 60)
    }

    var goalHeadline: String {
        "\(targetHours) hours of focused \(focusTitle.lowercased()) by \(targetDateLabel)"
    }

    var goalAssumption: String {
        "\(Self.flightsPerWeek) flights a week at \(Formatters.durationLabel(minutes: minutes)), starting today."
    }

    var targetDateLabel: String {
        targetDate.formatted(.dateTime.day().month(.abbreviated))
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

    struct Step: Equatable { let icon: String; let title: String; let detail: String }

    /// Four glyphs the app actually uses elsewhere — take-off, the Focus Shield,
    /// the streak flame and the Passport — so the row art points at real parts
    /// of FocusGlobe rather than at generic productivity iconography.
    static let steps: [Step] = [
        Step(icon: "paperplane.fill", title: "Start your first flight",
             detail: "Everything is already set — pick a destination and lift off."),
        Step(icon: "shield.lefthalf.filled", title: "Protect the time",
             detail: "One screen, one Sky, nothing competing for your attention."),
        Step(icon: "flame.fill", title: "Fly again tomorrow",
             detail: "Short flights you finish beat long ones you abandon."),
        Step(icon: "book.closed.fill", title: "Watch the distance add up",
             detail: "Every landing is logged in your Passport, city by city."),
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

    struct Trust: Equatable, Identifiable {
        let icon: String
        let title: String
        let detail: String
        var id: String { title }
    }

    /// Four statements, every one checkable in this repository — local
    /// persistence, the optional account, ungated soundscapes, App Store
    /// cancellation. No ratings, no review quotes, no user counts, no reviewer
    /// names: FocusGlobe has none of those verified, so it claims none of them.
    /// The soundscape count is read from the catalogue rather than typed, so it
    /// cannot go stale.
    static let trust: [Trust] = [
        Trust(icon: "iphone", title: "Your history stays on your device",
              detail: "Journeys, streaks and stats are written locally, not to a server."),
        Trust(icon: "person.crop.circle.badge.checkmark", title: "No account needed to fly",
              detail: "Sign in only if you want your progress on another device."),
        Trust(icon: "waveform", title: "Every soundscape is free",
              detail: "All \(JourneyAudioOption.all.count) flight atmospheres are unlocked from the start."),
        Trust(icon: "arrow.uturn.backward", title: "Cancel anytime",
              detail: "Subscriptions are managed in the App Store, not here."),
    ]
}
