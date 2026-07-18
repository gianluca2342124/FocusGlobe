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
    static func color(level: Int) -> Color {
        switch level {
        case 1:  return Color(hex: 0xF4EFE4).opacity(0.28)
        case 2:  return Color(hex: 0xE9C07A).opacity(0.55)
        case 3:  return Color(hex: 0xD8B56D).opacity(0.85)
        case 4:  return Color(hex: 0xE8A54B)
        default: return Color.white.opacity(0.07)
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
}

// MARK: - The grid view (full + compact)

/// The contribution-style focus grid. `weeks` controls the span (52–53 for
/// Passport, ~20 for the compact streak popover). VoiceOver reads one summary
/// instead of hundreds of cells.
struct FocusConsistencyGrid: View {
    let history: [FocusSessionRecord]
    var weeks: Int = 53
    var cellSize: CGFloat = 9
    var spacing: CGFloat = 2.5

    @Environment(\.calendar) private var calendar

    private var columns: [[(date: Date, minutes: Int?)?]] {
        FocusConsistency.columns(weeks: weeks, history: history, calendar: calendar)
    }

    var body: some View {
        let cols = columns
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    monthLabels(cols)
                    HStack(alignment: .top, spacing: spacing) {
                        ForEach(Array(cols.enumerated()), id: \.offset) { index, col in
                            VStack(spacing: spacing) {
                                ForEach(0..<7, id: \.self) { row in
                                    cell(col.indices.contains(row) ? col[row] : nil)
                                }
                            }
                            .id(index)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .onAppear { proxy.scrollTo(max(0, cols.count - 1), anchor: .trailing) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    @ViewBuilder private func cell(_ entry: (date: Date, minutes: Int?)?) -> some View {
        if let entry {
            RoundedRectangle(cornerRadius: cellSize * 0.28, style: .continuous)
                .fill(FocusConsistency.color(level: FocusConsistency.level(minutes: entry.minutes)))
                .frame(width: cellSize, height: cellSize)
        } else {
            Color.clear.frame(width: cellSize, height: cellSize)
        }
    }

    /// Subtle month initials above the column where each month begins.
    private func monthLabels(_ cols: [[(date: Date, minutes: Int?)?]]) -> some View {
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
        return ZStack(alignment: .topLeading) {
            Color.clear.frame(height: 12)
            ForEach(labels, id: \.index) { label in
                Text(label.text)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textTertiary)
                    .offset(x: CGFloat(label.index) * (cellSize + spacing))
            }
        }
        .frame(width: CGFloat(cols.count) * (cellSize + spacing), alignment: .leading)
    }

    private var accessibilitySummary: String {
        let s = FocusConsistency.summary(history: history, calendar: calendar)
        return "Focus consistency grid. \(s.activeDays) active focus days, \(s.activeDaysThisYear) this year."
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

    var body: some View {
        let summary = FocusConsistency.summary(history: history)
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                BalloonView(height: 44, showBurner: false, showGlow: false)
                Text("FocusGlobe")
                    .font(.system(size: 26, weight: .semibold, design: .serif))
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
            FocusConsistencyGrid(history: history, weeks: 53, cellSize: 7.6, spacing: 2.2)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 26) {
                shareStat(value: "\(currentStreak)", label: "day streak")
                shareStat(value: "\(summary.activeDays)", label: "focus days")
                shareStat(value: "\(summary.consistencyPercent)%", label: "consistency")
                Spacer()
            }
            Spacer(minLength: 0)
        }
        .padding(34)
        .frame(width: 560, height: 700, alignment: .topLeading)
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
                            currentStreak: Int) -> UIImage? {
        let renderer = ImageRenderer(content: FocusGridShareCard(history: history,
                                                                 displayName: displayName,
                                                                 currentStreak: currentStreak))
        renderer.scale = 3
        return renderer.uiImage
    }
}
#endif
