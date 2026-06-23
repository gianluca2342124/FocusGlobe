import SwiftUI
import WidgetKit

/// Today's daily goals and their progress.
struct DailyGoalsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FGDailyGoals", provider: FGProvider()) { entry in
            DailyGoalsView(entry: entry)
                .fgWidgetBackground()
                .widgetURL(FGLink.url("goals"))
        }
        .configurationDisplayName("Daily Goals")
        .description("Today's focus goals and progress.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct DailyGoalsView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FGEntry
    private var s: WidgetSnapshot { entry.snapshot }

    private func tint(_ i: Int) -> Color {
        [WTheme.indigo, WTheme.teal, WTheme.gold, WTheme.coral][i % 4]
    }

    var body: some View {
        if !s.isPro {
            LockedTeaser(icon: "target", title: "Daily Goals", accent: WTheme.coral)
        } else {
            content
        }
    }

    private var content: some View {
        let isLarge = family == .systemLarge
        return VStack(alignment: .leading, spacing: isLarge ? 12 : 10) {
            HStack {
                WHeader(icon: "target", title: "Daily Goals")
                Spacer()
                Text("\(s.goalsCompleted)/\(s.goalsTotal)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded)).foregroundStyle(WTheme.gold)
            }
            ForEach(Array(s.goals.prefix(4).enumerated()), id: \.offset) { i, goal in
                row(goal, tint: tint(i), showTitle: isLarge)
            }
            if isLarge {
                Spacer(minLength: 0)
                Text(s.canClaimReward
                     ? "All goals done — claim +\(FocusGlobeShared.dailyGoalRewardMiles) miles!"
                     : "Finish all goals for +\(FocusGlobeShared.dailyGoalRewardMiles) bonus miles")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(s.canClaimReward ? WTheme.gold : WTheme.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(14)
    }

    private func row(_ goal: WidgetGoal, tint: Color, showTitle: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: goal.isComplete ? "checkmark.circle.fill" : goal.systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(goal.isComplete ? tint : WTheme.inkSoft)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                if showTitle {
                    Text(goal.title).font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(WTheme.ink).lineLimit(1)
                }
                WBar(fraction: goal.fraction, tint: tint)
            }
        }
    }
}
