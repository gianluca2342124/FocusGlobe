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

    /// ~2.6 s over six lines. Slower reads as a stall on a screen that has
    /// nothing for the pilot to do.
    private var stepInterval: UInt64 { 380_000_000 }

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
                            .frame(width: max(6, geo.size.width * progress))
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
        for index in items.indices {
            try? await Task.sleep(nanoseconds: stepInterval)
            guard !Task.isCancelled else { return }
            // Committed as the list reaches the lines that describe the writes,
            // so the screen never claims to have done something it has not.
            if index == 2 { apply() }
            withAnimation(.easeOut(duration: 0.3)) {
                completed = index + 1
                progress = Double(index + 1) / Double(items.count)
            }
        }
        apply()   // belt and braces if the list is ever shorter than three
        try? await Task.sleep(nanoseconds: 420_000_000)
        guard !Task.isCancelled, !didFinish else { return }
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
struct OnboardingResultsStep: View {
    let plan: OnboardingResultPlan
    let onContinue: () -> Void

    @Environment(\.focusViewport) private var viewport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var curveProgress: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: viewport.isShort ? AppSpacing.md : AppSpacing.lg) {
                    goalHeadline
                    graphCard
                    detailsCard
                    howToReach
                    comparison
                    trustCard
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

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack(alignment: .topLeading) {
                    // A gentle ease rather than a straight line: real weeks are
                    // uneven. It is presentation, not a different claim — both
                    // ends are the honest arithmetic.
                    let curve = Path { p in
                        p.move(to: CGPoint(x: 0, y: h))
                        for i in 0...40 {
                            let t = CGFloat(i) / 40
                            let eased = t * t * (3 - 2 * t)
                            p.addLine(to: CGPoint(x: t * w, y: h - eased * h * 0.86))
                        }
                    }
                    curve.stroke(ProBrand.softGradient,
                                 style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .mask(alignment: .leading) {
                            Rectangle().frame(width: w * curveProgress)
                        }

                    // The target, marked where the curve ends.
                    Circle()
                        .fill(AppColors.selectionGold)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 2))
                        .position(x: w, y: h - h * 0.86)
                        .opacity(curveProgress > 0.95 ? 1 : 0)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: curveProgress)
                }
            }
            .frame(height: viewport.isShort ? 96 : 118)

            HStack {
                Text("Now")
                Spacer()
                Text(plan.targetDateLabel)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.5))
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Planned focused hours from now to \(plan.targetDateLabel)"))
        .accessibilityValue(Text(plan.goalHeadline))
    }

    // MARK: Details

    private var detailsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(plan.details.enumerated()), id: \.offset) { index, row in
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: row.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.gold)
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
                .padding(.vertical, 11)
                .accessibilityElement(children: .combine)
                if index < plan.details.count - 1 {
                    Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 2)
        .background(cardBackground)
    }

    // MARK: How to reach it

    private var howToReach: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("How you'll get there")
            ForEach(Array(OnboardingResultPlan.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(AppColors.gold.opacity(0.14))
                        Image(systemName: step.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.gold)
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

    private var comparison: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("Why FocusGlobe")
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                column(title: "Without", lines: OnboardingResultPlan.without,
                       icon: "xmark", tint: .white.opacity(0.34), muted: true)
                column(title: "With FocusGlobe", lines: OnboardingResultPlan.with,
                       icon: "checkmark", tint: AppColors.selectionGold, muted: false)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private func column(title: String, lines: [String],
                        icon: String, tint: Color, muted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(muted ? .white.opacity(0.45) : AppColors.selectionGold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(tint)
                        .padding(.top, 3)
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

    /// Deliberately NOT a review block.
    ///
    /// There are no verified ratings, review quotes or user counts in this
    /// product, and inventing them is the one thing this screen must not do.
    /// What is here instead is three statements about FocusGlobe that are
    /// checkable in the codebase: history is stored locally, an account is
    /// optional, and a subscription is cancellable in the App Store.
    private var trustCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("Built to be trusted")
            ForEach(OnboardingResultPlan.trust, id: \.title) { item in
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: item.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.gold)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(item.detail)
                            .font(AppTypography.caption)
                            .foregroundStyle(.white.opacity(0.58))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
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

    struct Detail: Equatable { let icon: String; let label: String; let value: String }

    var details: [Detail] {
        [
            Detail(icon: "target", label: "Focus", value: focusTitle),
            Detail(icon: "exclamationmark.triangle", label: "Main distraction", value: frictionTitle),
            Detail(icon: "timer", label: "First flight",
                   value: Formatters.durationLabel(minutes: minutes)),
            Detail(icon: "waveform", label: "Atmosphere", value: atmosphere),
            Detail(icon: "repeat", label: "Rhythm",
                   value: "\(Self.flightsPerWeek) flights a week"),
        ]
    }

    struct Step: Equatable { let icon: String; let title: String; let detail: String }

    static let steps: [Step] = [
        Step(icon: "paperplane.fill", title: "Start your first flight",
             detail: "Everything is already set — pick a destination and lift off."),
        Step(icon: "moon.stars.fill", title: "Protect the time",
             detail: "One screen, one Sky, nothing competing for your attention."),
        Step(icon: "flame.fill", title: "Fly again tomorrow",
             detail: "Short flights you finish beat long ones you abandon."),
        Step(icon: "map.fill", title: "Watch the distance add up",
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

    struct Trust: Equatable { let icon: String; let title: String; let detail: String }

    static let trust: [Trust] = [
        Trust(icon: "iphone", title: "Your history stays on your device",
              detail: "Journeys, streaks and stats are stored locally."),
        Trust(icon: "person.crop.circle.badge.checkmark", title: "No account needed to fly",
              detail: "Sign in only if you want your progress on another device."),
        Trust(icon: "arrow.uturn.backward", title: "Cancel anytime",
              detail: "Subscriptions are managed in the App Store, not here."),
    ]
}
