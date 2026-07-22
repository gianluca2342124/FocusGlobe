import SwiftUI
import WidgetKit

// MARK: - The reusable 26-week Focus Grid (widget side)

/// The SAME six-month span as the app's Passport/Streak grid (26 rolling weeks ×
/// 7 rows, newest week on the right), rebuilt on the widget from the shared set
/// of active local-day ordinals. No scrolling; sizes itself to the available
/// width. Active/inactive only (the widget doesn't need per-day intensity).
struct WFocusGrid: View {
    let activeOrdinals: Set<Int>
    var weeks: Int = 26

    private static let spacingFactor: CGFloat = 0.28

    var body: some View {
        GeometryReader { geo in
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            let todayOrd = Self.ordinal(today)
            let wd = cal.component(.weekday, from: today) - 1   // 0 = Sun … 6 = Sat
            let count = weeks
            let sf = Self.spacingFactor
            let side = geo.size.width / (CGFloat(count) + CGFloat(count - 1) * sf)
            let spacing = side * sf
            HStack(alignment: .top, spacing: spacing) {
                ForEach(0..<count, id: \.self) { c in
                    VStack(spacing: spacing) {
                        ForEach(0..<7, id: \.self) { r in
                            cell(column: c, row: r, weeks: count, todayOrd: todayOrd, wd: wd, side: side)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private func cell(column c: Int, row r: Int, weeks: Int, todayOrd: Int, wd: Int, side: CGFloat) -> some View {
        // daysBack from today for this (column,row). Future days (this week, after
        // today) are blank.
        let daysBack = (weeks - 1 - c) * 7 + (wd - r)
        if daysBack < 0 {
            Color.clear.frame(width: side, height: side)
        } else {
            let ord = todayOrd - daysBack
            let active = activeOrdinals.contains(ord)
            let isToday = ord == todayOrd
            RoundedRectangle(cornerRadius: side * 0.28, style: .continuous)
                .fill(active ? WTheme.gold : WTheme.hair)
                .overlay(
                    RoundedRectangle(cornerRadius: side * 0.28, style: .continuous)
                        .strokeBorder(WTheme.ink.opacity(isToday ? 0.9 : 0), lineWidth: 1)
                )
                .frame(width: side, height: side)
        }
    }

    static func ordinal(_ date: Date) -> Int {
        Int((date.timeIntervalSince1970 / 86_400).rounded())
    }
}

// MARK: - Focus Grid widget (PRO)

struct FocusGridWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FGFocusGrid", provider: FGProvider()) { entry in
            FocusGridWidgetView(snapshot: entry.snapshot)
                .fgWidgetBackground(glow: WTheme.teal)
                .widgetURL(FGLink.url(entry.snapshot.gatedLink("passport")))
        }
        .configurationDisplayName("Focus Grid")
        .description("Your last six months of focus days. FocusGlobe PRO.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct FocusGridWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        if snapshot.isPro {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    WHeader(icon: "square.grid.3x3.fill", title: "Focus · 6 months", tint: WTheme.teal)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").font(.system(size: 11, weight: .bold))
                            .foregroundStyle(WTheme.coral)
                        Text("\(snapshot.currentStreak)")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(WTheme.ink)
                    }
                }
                WFocusGrid(activeOrdinals: Set(snapshot.activeDayOrdinals))
                    .frame(maxWidth: .infinity)
                HStack(spacing: 12) {
                    Text("\(snapshot.activeFocusDays) focus days")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(WTheme.inkSoft)
                    Spacer()
                    Text("FocusGlobe")
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(WTheme.gold)
                }
            }
            .padding(14)
        } else {
            LockedTeaser(icon: "square.grid.3x3.fill", title: "Focus Grid", accent: WTheme.teal)
        }
    }
}
