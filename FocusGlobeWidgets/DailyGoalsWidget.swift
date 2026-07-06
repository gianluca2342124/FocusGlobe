import SwiftUI
import WidgetKit

/// Today's focus missions, presented as premium glass cards on the space
/// backdrop. One hero mission (small), three cards (medium), the full set with
/// the bonus-reward line (large).
struct DailyGoalsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FGDailyGoals", provider: FGProvider()) { entry in
            DailyGoalsView(entry: entry)
                .fgWidgetBackground(glow: WTheme.indigo)
                .widgetURL(FGLink.url(entry.snapshot.gatedLink("goals")))
        }
        .configurationDisplayName("Daily Goals")
        .description("Today's focus goals and progress.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct DailyGoalsView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FGEntry
    private var s: WidgetSnapshot { entry.snapshot }

    private func tint(_ i: Int) -> Color {
        [WTheme.indigo, WTheme.teal, WTheme.gold, WTheme.coral][i % 4]
    }

    /// The goal to feature on the small widget: the first unfinished one, or the
    /// last completed if everything's done.
    private var heroIndex: Int {
        s.goals.firstIndex(where: { !$0.isComplete }) ?? max(0, s.goals.count - 1)
    }

    var body: some View {
        if !s.isPro {
            LockedTeaser(icon: "target", title: "Daily Goals", accent: WTheme.coral)
        } else if s.goals.isEmpty {
            empty
        } else {
            switch family {
            case .systemSmall: small
            case .systemLarge: large
            default:           medium
            }
        }
    }

    private var counter: some View {
        Text("\(s.goalsCompleted)/\(s.goalsTotal)")
            .font(.system(size: 12, weight: .heavy, design: .rounded)).foregroundStyle(WTheme.gold)
    }

    // MARK: Small — one hero mission

    private var small: some View {
        let goal = s.goals[heroIndex]
        return VStack(alignment: .leading, spacing: 10) {
            HStack { WHeader(icon: "target", title: "Today", tint: WTheme.coral); Spacer(); counter }
            Spacer(minLength: 0)
            WGlassCard {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: goal.isComplete ? "checkmark.circle.fill" : goal.systemImage)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(goal.isComplete ? WTheme.teal : tint(heroIndex))
                    Text(goal.title)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(WTheme.ink).lineLimit(2).minimumScaleFactor(0.85)
                    WBar(fraction: goal.fraction, tint: tint(heroIndex))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }

    // MARK: Medium — three glass cards

    private var medium: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { WHeader(icon: "target", title: "Daily goals", tint: WTheme.coral); Spacer(); counter }
            HStack(spacing: 10) {
                ForEach(Array(s.goals.prefix(3).enumerated()), id: \.offset) { i, goal in
                    tile(goal, tint: tint(i))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(16)
    }

    private func tile(_ goal: WidgetGoal, tint: Color) -> some View {
        WGlassCard(tint: tint) {
            VStack(spacing: 6) {
                ZStack {
                    WRing(fraction: goal.fraction, tint: tint, lineWidth: 5).frame(width: 32, height: 32)
                    Image(systemName: goal.isComplete ? "checkmark" : goal.systemImage)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(goal.isComplete ? tint : WTheme.ink)
                }
                Text(goal.title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(WTheme.inkSoft)
                    .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8).padding(.horizontal, 6)
        }
    }

    // MARK: Large — full dashboard

    private var large: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack { WHeader(icon: "target", title: "Daily goals", tint: WTheme.coral); Spacer(); counter }
            ForEach(Array(s.goals.prefix(4).enumerated()), id: \.offset) { i, goal in
                row(goal, tint: tint(i))
            }
            Spacer(minLength: 0)
            HStack(spacing: 7) {
                Image(systemName: s.canClaimReward ? "gift.fill" : "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(s.canClaimReward ? WTheme.gold : WTheme.inkSoft)
                Text(s.canClaimReward
                     ? "All done — claim +\(FocusGlobeShared.dailyGoalRewardMiles) miles"
                     : "Finish all goals for +\(FocusGlobeShared.dailyGoalRewardMiles) bonus miles")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(s.canClaimReward ? WTheme.gold : WTheme.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(16)
    }

    private func row(_ goal: WidgetGoal, tint: Color) -> some View {
        WGlassCard(tint: tint) {
            HStack(spacing: 11) {
                Image(systemName: goal.isComplete ? "checkmark.circle.fill" : goal.systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(goal.isComplete ? tint : WTheme.inkSoft)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title).font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(WTheme.ink).lineLimit(1)
                    WBar(fraction: goal.fraction, tint: tint)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            WHeader(icon: "target", title: "Daily goals", tint: WTheme.coral)
            Spacer(minLength: 0)
            Text("Fresh goals at midnight")
                .font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(WTheme.ink)
            Text("Set off today to start completing them.")
                .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(WTheme.inkSoft)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
    }
}

#Preview("Goals · small", as: .systemSmall) {
    DailyGoalsWidget()
} timeline: {
    FGEntry(date: .now, snapshot: .placeholder)
}

#Preview("Goals · medium", as: .systemMedium) {
    DailyGoalsWidget()
} timeline: {
    FGEntry(date: .now, snapshot: .placeholder)
}

#Preview("Goals · large", as: .systemLarge) {
    DailyGoalsWidget()
} timeline: {
    FGEntry(date: .now, snapshot: .placeholder)
}
