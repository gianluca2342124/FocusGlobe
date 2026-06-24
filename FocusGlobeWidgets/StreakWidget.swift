import SwiftUI
import WidgetKit

/// A focus-streak widget — the flame, the day count, and today's momentum.
/// Home Screen (small/medium) + Lock Screen accessories.
struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FGStreak", provider: FGProvider()) { entry in
            StreakWidgetView(entry: entry)
                .widgetURL(FGLink.url("home"))
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

    private var microcopy: String {
        if s.currentStreak == 0 { return "Fly today to start your streak" }
        if s.goalsTotal > 0 && s.goalsCompleted >= s.goalsTotal { return "All goals done today" }
        return "Take a quick flight to keep it going"
    }

    var body: some View {
        switch family {
        case .accessoryCircular:    accessoryCircular
        case .accessoryRectangular: accessoryRectangular
        case .accessoryInline:      accessoryInline
        case .systemMedium:         medium.fgWidgetBackground()
        default:                    small.fgWidgetBackground()
        }
    }

    // MARK: Home Screen

    private var flame: some View {
        Image(systemName: "flame.fill")
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(LinearGradient(colors: [WTheme.gold, WTheme.coral],
                                            startPoint: .top, endPoint: .bottom))
            .shadow(color: WTheme.coral.opacity(0.5), radius: 8, y: 2)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { WHeader(icon: "flame.fill", title: "Streak", tint: WTheme.coral); Spacer() }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(s.currentStreak)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(WTheme.ink)
                Text(s.currentStreak == 1 ? "day" : "days")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(WTheme.inkSoft)
            }
            Text(microcopy)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(WTheme.inkSoft)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }

    private var medium: some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                flame
                Text("\(s.currentStreak)")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(WTheme.ink)
                Text(s.currentStreak == 1 ? "day" : "days")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(WTheme.inkSoft)
            }
            .frame(width: 92)
            VStack(alignment: .leading, spacing: 8) {
                WHeader(icon: "flame.fill", title: "Focus streak", tint: WTheme.coral)
                Text(microcopy)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(WTheme.ink)
                    .lineLimit(2)
                if s.goalsTotal > 0 {
                    HStack(spacing: 6) {
                        ForEach(0..<min(s.goalsTotal, 6), id: \.self) { i in
                            Circle()
                                .fill(i < s.goalsCompleted ? WTheme.gold : WTheme.hair)
                                .frame(width: 8, height: 8)
                        }
                        Text("\(s.goalsCompleted)/\(s.goalsTotal) goals")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(WTheme.inkSoft)
                    }
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
