import SwiftUI
import WidgetKit

/// The focus-streak widget — a single, iconic glowing flame. The number lives
/// inside the flame; there is almost no text. At zero it becomes a calm "ember"
/// (an invitation, never guilt); when the streak is active but nothing's been
/// done today it warms with a gentle urgency.
struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FGStreak", provider: FGProvider()) { entry in
            StreakWidgetView(entry: entry)
                .widgetURL(FGLink.url("streak"))
        }
        .configurationDisplayName("Streak")
        .description("Keep your focus streak alive.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

private struct StreakWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FGEntry
    private var s: WidgetSnapshot { entry.snapshot }

    /// Active streak, but nothing finished today → a gentle "don't lose it" nudge.
    private var atRisk: Bool { s.currentStreak > 0 && s.goalsCompleted == 0 }

    private var headline: String {
        if s.currentStreak == 0 { return "Light your flame" }
        if atRisk { return "Keep it alive" }
        return "You're on fire"
    }

    private var microcopy: String {
        if s.currentStreak == 0 { return "Take one flight today to begin" }
        if atRisk { return "A quick flight keeps the streak" }
        if s.goalsTotal > 0 && s.goalsCompleted >= s.goalsTotal { return "Every goal done today" }
        return "\(s.currentStreak) days of focus and counting"
    }

    var body: some View {
        switch family {
        case .accessoryCircular:    accessoryCircular
        case .accessoryRectangular: accessoryRectangular
        case .accessoryInline:      accessoryInline
        case .systemMedium:         medium.fgWidgetBackground(glow: WTheme.coral)
        default:                    small.fgWidgetBackground(glow: WTheme.coral)
        }
    }

    // MARK: Home Screen

    private var small: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            WFlame(streak: s.currentStreak, size: 74, atRisk: atRisk)
            Spacer(minLength: 0)
            Text(s.currentStreak == 0 ? "START TODAY" : "DAY STREAK")
                .font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(1.4)
                .foregroundStyle(WTheme.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(14)
    }

    private var medium: some View {
        HStack(spacing: 16) {
            WFlame(streak: s.currentStreak, size: 76, atRisk: atRisk)
                .frame(width: 92)
            VStack(alignment: .leading, spacing: 10) {
                WHeader(icon: "flame.fill", title: "Focus streak", tint: WTheme.coral)
                WDayDots(streak: s.currentStreak)
                Text(headline)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(WTheme.ink).lineLimit(1).minimumScaleFactor(0.7)
                if s.longestStreak > s.currentStreak {
                    Text("Best · \(s.longestStreak) days")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(WTheme.gold.opacity(0.9))
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }

    // MARK: Lock Screen accessories

    private var accessoryCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "flame.fill").font(.system(size: 13, weight: .bold))
                Text("\(s.currentStreak)").font(.system(size: 17, weight: .heavy, design: .rounded))
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    private var accessoryRectangular: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill").font(.system(size: 20, weight: .bold))
            VStack(alignment: .leading, spacing: 1) {
                Text("\(s.currentStreak)-day streak").font(.system(size: 15, weight: .heavy, design: .rounded))
                Text(microcopy).font(.system(size: 11, weight: .medium)).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.clear, for: .widget)
    }

    private var accessoryInline: some View {
        Label("\(s.currentStreak)-day streak", systemImage: "flame.fill")
            .containerBackground(.clear, for: .widget)
    }
}

#Preview("Streak · on fire", as: .systemSmall) {
    StreakWidget()
} timeline: {
    FGEntry(date: .now, snapshot: .placeholder)
}

#Preview("Streak · ember", as: .systemSmall) {
    StreakWidget()
} timeline: {
    FGEntry(date: .now, snapshot: WidgetSnapshot())
}

#Preview("Streak · medium", as: .systemMedium) {
    StreakWidget()
} timeline: {
    FGEntry(date: .now, snapshot: .placeholder)
}
