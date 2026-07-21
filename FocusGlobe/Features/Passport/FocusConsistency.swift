import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Focus consistency (the ONE shared day-grid model)

/// The single source of truth for the contribution-style focus grid shown in
/// Passport, the streak popover and the share card — one calculation, one rule,
/// so the same day can never disagree between surfaces.
///
/// RULE: a calendar day (user's local time zone) is **active** when at least one
/// COMPLETED session of ≥ 5 focused minutes (300 s) landed that day. Shorter or
/// abandoned sessions never light a square. Intensity grows with the day's total
/// focused minutes across qualifying-day sessions.
enum FocusConsistency {

    /// Minimum focused seconds for a session to qualify a day.
    static let qualifyingSeconds = 300

    /// startOfDay → total focused minutes, ONLY for days with ≥1 qualifying
    /// completed session. Derived purely from the real on-device history.
    static func activeDays(history: [FocusSessionRecord],
                           calendar: Calendar = .current) -> [Date: Int] {
        var out: [Date: Int] = [:]
        var qualified = Set<Date>()
        for record in history where record.completed {
            let day = calendar.startOfDay(for: record.date)
            if record.focusedSeconds >= qualifyingSeconds { qualified.insert(day) }
            out[day, default: 0] += max(0, record.focusedSeconds) / 60
        }
        return out.filter { qualified.contains($0.key) }
    }

    /// 0…4 intensity level for a day's total focused minutes.
    static func level(minutes: Int?) -> Int {
        guard let m = minutes, m > 0 else { return 0 }
        switch m {
        case ..<15:  return 1
        case ..<45:  return 2
        case ..<90:  return 3
        default:     return 4
        }
    }

    /// The restrained FocusGlobe scale: neutral → cream → gold → amber ember.
    /// Level 0/1 are mode-adaptive: a raw white cell is invisible on a light
    /// card, so Light Mode uses faint gold / soft ink instead (Dark unchanged
    /// apart from a slightly clearer level 1 — a single 5-minute day must
    /// read at 9 pt). The share card is unaffected: it forces a dark scheme.
    static func color(level: Int) -> Color {
        switch level {
        case 1:  return Color.dynamic(light: 0xE9C07A, lightAlpha: 0.40,
                                      dark: 0xF4EFE4, darkAlpha: 0.38)
        case 2:  return Color(hex: 0xE9C07A).opacity(0.55)
        case 3:  return Color(hex: 0xD8B56D).opacity(0.85)
        case 4:  return Color(hex: 0xE8A54B)
        default: return Color.dynamic(light: 0x26221D, lightAlpha: 0.07,
                                      dark: 0xFFFFFF, darkAlpha: 0.07)
        }
    }

    /// The trailing `weeks` columns (oldest → newest), each a 7-day column in the
    /// user's calendar; entries after today are nil (visually absent).
    static func columns(weeks: Int, history: [FocusSessionRecord],
                        calendar: Calendar = .current,
                        today: Date = Date()) -> [[(date: Date, minutes: Int?)?]] {
        let days = activeDays(history: history, calendar: calendar)
        let startOfToday = calendar.startOfDay(for: today)
        // The first day of the CURRENT week (respecting the user's firstWeekday).
        let weekday = calendar.component(.weekday, from: startOfToday)
        let offsetIntoWeek = (weekday - calendar.firstWeekday + 7) % 7
        guard let currentWeekStart = calendar.date(byAdding: .day, value: -offsetIntoWeek, to: startOfToday)
        else { return [] }
        var cols: [[(date: Date, minutes: Int?)?]] = []
        for w in stride(from: weeks - 1, through: 0, by: -1) {
            guard let weekStart = calendar.date(byAdding: .day, value: -7 * w, to: currentWeekStart)
            else { continue }
            var col: [(date: Date, minutes: Int?)?] = []
            for d in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: d, to: weekStart) else { col.append(nil); continue }
                if day > startOfToday { col.append(nil) }            // future: absent
                else { col.append((day, days[day])) }
            }
            cols.append(col)
        }
        return cols
    }

    /// Supporting insights derived from the SAME data as the grid.
    struct Summary {
        let activeDays: Int
        let activeDaysThisYear: Int
        let consistencyPercent: Int   // active days ÷ days since first activity (≤365)
    }

    static func summary(history: [FocusSessionRecord],
                        calendar: Calendar = .current, today: Date = Date()) -> Summary {
        let days = activeDays(history: history, calendar: calendar)
        let startOfToday = calendar.startOfDay(for: today)
        let year = calendar.component(.year, from: startOfToday)
        let thisYear = days.keys.filter { calendar.component(.year, from: $0) == year }.count
        var percent = 0
        if let first = days.keys.min() {
            let span = min(365, max(1, (calendar.dateComponents([.day], from: first, to: startOfToday).day ?? 0) + 1))
            let counted = days.keys.filter { $0 >= (calendar.date(byAdding: .day, value: -364, to: startOfToday) ?? first) }.count
            percent = Int((Double(counted) / Double(span) * 100).rounded())
        }
        return Summary(activeDays: days.count, activeDaysThisYear: thisYear,
                       consistencyPercent: min(100, percent))
    }

    #if DEBUG
    /// A focused self-check of the day-qualification rule, callable from a
    /// debugger or a launch assertion. Returns nil on success, or the first
    /// failing case. NOT a production dependency — pure functions only.
    static func _selfCheck(calendar: Calendar = .current) -> String? {
        func rec(_ seconds: Int, daysAgo: Int, completed: Bool = true) -> FocusSessionRecord {
            let d = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            return FocusSessionRecord(routeID: "t", routeName: "t", originName: "t",
                                      destinationName: "t", mood: .sunset, theme: .gold,
                                      date: d, plannedMinutes: 25, focusedSeconds: seconds,
                                      distanceKm: 1, focusMiles: 1, intention: nil,
                                      completed: completed)
        }
        let today = calendar.startOfDay(for: Date())
        // 299 s → inactive.
        if activeDays(history: [rec(299, daysAgo: 0)], calendar: calendar)[today] != nil {
            return "299s should NOT qualify"
        }
        // 300 s → active today.
        if activeDays(history: [rec(300, daysAgo: 0)], calendar: calendar)[today] == nil {
            return "300s should qualify"
        }
        // Two qualifying sessions one day → one active cell, minutes summed.
        let twoToday = activeDays(history: [rec(360, daysAgo: 0), rec(600, daysAgo: 0)], calendar: calendar)
        if twoToday.count != 1 || (twoToday[today] ?? 0) < 16 {
            return "two sessions one day should sum to one cell (>=16 min)"
        }
        // Qualifying sessions on two local days → two cells.
        if activeDays(history: [rec(300, daysAgo: 0), rec(300, daysAgo: 1)], calendar: calendar).count != 2 {
            return "two days should be two cells"
        }
        // A cancelled 600 s session never lights the grid.
        if activeDays(history: [rec(600, daysAgo: 0, completed: false)], calendar: calendar)[today] != nil {
            return "cancelled session should NOT qualify"
        }
        return nil
    }
    #endif
}

// MARK: - The grid view (full + compact)

/// The contribution-style focus grid — a **fixed, non-scrolling 6-month span**
/// (26 rolling weeks × 7 rows, newest week on the right). It sizes itself
/// responsively to fill the available width via `GeometryReader`, so every
/// iPhone width shows all 26 weeks with no horizontal scroll, drag or clipping.
/// This is the ONE grid implementation reused by Passport, the streak sheet and
/// the share card (the PRO widget renders the same 26-week data on its target).
/// VoiceOver reads one summary instead of ~180 cells.
struct FocusConsistencyGrid: View {
    let history: [FocusSessionRecord]
    /// The 6-month span. Kept as a parameter for the debug self-check only; all
    /// product surfaces use the default so they stay identical.
    var weeks: Int = 26
    /// When set, the grid renders at this exact square size instead of sizing to
    /// the available width. Used only by fixed-canvas renderers that want a
    /// specific density; nil everywhere on-screen (fully responsive).
    var fixedCellSize: CGFloat? = nil
    var showsMonthLabels: Bool = true

    @Environment(\.calendar) private var calendar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// One-shot pop for today's square the moment it becomes NEWLY lit.
    @State private var pulseToday = false
    /// Whether today was already lit at the last observation, so the pulse fires
    /// on a genuine new activation — never merely on appear.
    @State private var todayWasLit: Bool? = nil

    private static let spacingFactor: CGFloat = 0.30   // spacing = side × this
    private static let labelFactor: CGFloat = 1.7      // label zone height in side units

    private var columns: [[(date: Date, minutes: Int?)?]] {
        FocusConsistency.columns(weeks: weeks, history: history, calendar: calendar)
    }
    private var todayLit: Bool {
        FocusConsistency.activeDays(history: history, calendar: calendar)[
            calendar.startOfDay(for: Date())] != nil
    }

    var body: some View {
        let cols = columns
        let count = max(1, cols.count)
        let sf = Self.spacingFactor
        // width  = count·side + (count−1)·spacing  (spacing = side·sf)
        // height = 7·side + 6·spacing + labelZone
        let wUnits = CGFloat(count) + CGFloat(count - 1) * sf
        let hUnits = 7 + 6 * sf + (showsMonthLabels ? Self.labelFactor : 0)
        return Group {
            if let side = fixedCellSize {
                grid(cols, side: side)
            } else {
                GeometryReader { geo in
                    grid(cols, side: geo.size.width / wUnits)
                }
                // A matched aspect ratio gives the width-filling grid a definite,
                // never-clipping height at any width — no scroll, no GeometryReader
                // collapse.
                .aspectRatio(wUnits / hUnits, contentMode: .fit)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .onAppear {
            // Record today's state WITHOUT pulsing (never pulse on appear).
            if todayWasLit == nil { todayWasLit = todayLit }
        }
        .onChange(of: history) { _, _ in
            let nowLit = todayLit
            if nowLit && todayWasLit == false { firePulse() }
            todayWasLit = nowLit
        }
    }

    @ViewBuilder private func grid(_ cols: [[(date: Date, minutes: Int?)?]], side: CGFloat) -> some View {
        let spacing = side * Self.spacingFactor
        VStack(alignment: .leading, spacing: 0) {
            if showsMonthLabels {
                monthLabels(cols, side: side, spacing: spacing)
                    .frame(height: side * Self.labelFactor, alignment: .bottomLeading)
            }
            HStack(alignment: .top, spacing: spacing) {
                ForEach(Array(cols.enumerated()), id: \.offset) { _, col in
                    VStack(spacing: spacing) {
                        ForEach(0..<7, id: \.self) { row in
                            dayCell(col.indices.contains(row) ? col[row] : nil, side: side)
                        }
                    }
                }
            }
        }
    }

    /// A brief, premium swell + brightness lift on today's square when it becomes
    /// newly lit — the visible confirmation that the landing just counted.
    /// Immediate (no animation) under Reduce Motion.
    private func firePulse() {
        guard !reduceMotion else { return }
        pulseToday = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { pulseToday = false }
    }

    @ViewBuilder private func dayCell(_ entry: (date: Date, minutes: Int?)?, side: CGFloat) -> some View {
        if let entry {
            let isFreshToday = entry.minutes != nil && calendar.isDateInToday(entry.date)
            RoundedRectangle(cornerRadius: side * 0.28, style: .continuous)
                .fill(FocusConsistency.color(level: FocusConsistency.level(minutes: entry.minutes)))
                .frame(width: side, height: side)
                .scaleEffect(isFreshToday && pulseToday ? 1.32 : 1)
                .brightness(isFreshToday && pulseToday ? 0.12 : 0)
                .animation(.spring(response: 0.35, dampingFraction: 0.55), value: pulseToday)
        } else {
            Color.clear.frame(width: side, height: side)
        }
    }

    /// Subtle month initials above the column where each month begins.
    private func monthLabels(_ cols: [[(date: Date, minutes: Int?)?]],
                             side: CGFloat, spacing: CGFloat) -> some View {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        var lastMonth = -1
        let labels: [(index: Int, text: String)] = cols.enumerated().compactMap { index, col in
            guard let first = col.compactMap({ $0 }).first else { return nil }
            let month = calendar.component(.month, from: first.date)
            defer { lastMonth = month }
            guard month != lastMonth else { return nil }
            return (index, formatter.string(from: first.date))
        }
        return ZStack(alignment: .bottomLeading) {
            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            ForEach(labels, id: \.index) { label in
                Text(label.text)
                    .font(.system(size: max(7, side * 0.95), weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textTertiary)
                    .fixedSize()
                    .offset(x: CGFloat(label.index) * (side + spacing))
            }
        }
    }

    private var accessibilitySummary: String {
        let s = FocusConsistency.summary(history: history, calendar: calendar)
        return "Focus consistency grid, last six months. \(s.activeDays) active focus days, \(s.activeDaysThisYear) this year."
    }
}

// MARK: - Share card + share flow

/// The polished portrait share card (rendered off-screen at high resolution —
/// never a screenshot of the live hierarchy). No private account data: only the
/// chosen display name, the grid, and headline stats.
struct FocusGridShareCard: View {
    let history: [FocusSessionRecord]
    let displayName: String?
    let currentStreak: Int
    let longestStreak: Int

    /// Total real completed focused time across all history (cancelled excluded).
    private var totalFocusedSeconds: Int {
        history.filter { $0.completed }.reduce(0) { $0 + max(0, $1.focusedSeconds) }
    }

    var body: some View {
        let summary = FocusConsistency.summary(history: history)
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                BalloonView(height: 44, showBurner: false, showGlow: false)
                Text("FocusGlobe")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(Color(hex: 0xF7F1E7))
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("My Focus Journey")
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(Color(hex: 0xF7F1E7))
                if let displayName, !displayName.isEmpty {
                    Text(displayName)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: 0xD8B56D))
                }
            }
            FocusConsistencyGrid(history: history)
                .frame(maxWidth: .infinity, alignment: .leading)
            // Two rows of headline stats — current + longest streak, active days
            // and total focused time. No email or account identity is ever shown.
            HStack(spacing: 26) {
                shareStat(value: "\(currentStreak)", label: "day streak")
                shareStat(value: "\(longestStreak)", label: "best streak")
                shareStat(value: "\(summary.activeDays)", label: "focus days")
                Spacer()
            }
            HStack(spacing: 26) {
                shareStat(value: Formatters.durationLabel(minutes: totalFocusedSeconds / 60),
                          label: "focused")
                shareStat(value: "\(summary.consistencyPercent)%", label: "consistency")
                Spacer()
            }
            Spacer(minLength: 0)
        }
        .padding(34)
        .frame(width: 560, height: 760, alignment: .topLeading)
        .background(AppColors.neutralBase)
        .environment(\.colorScheme, .dark)
    }

    private func shareStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: 0xE8A54B))
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: 0xA89D8C))
        }
    }
}

#if canImport(UIKit)
/// The native share sheet, fed with a freshly rendered high-resolution card.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

@MainActor
enum FocusGridShare {
    /// Render the share card at 3× (1680×2100 px). Returns nil on failure —
    /// callers degrade gracefully instead of crashing.
    static func renderImage(history: [FocusSessionRecord], displayName: String?,
                            currentStreak: Int, longestStreak: Int) -> UIImage? {
        let renderer = ImageRenderer(content: FocusGridShareCard(history: history,
                                                                 displayName: displayName,
                                                                 currentStreak: currentStreak,
                                                                 longestStreak: longestStreak))
        renderer.scale = 3
        return renderer.uiImage
    }
}
#endif
