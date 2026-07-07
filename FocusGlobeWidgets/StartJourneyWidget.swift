import SwiftUI
import WidgetKit

/// A one-tap launcher into a new focus flight from the user's city. Iconic
/// glowing balloon, the departure code, and a "Take off" call to action.
/// Available to everyone — it's a launcher, not private data.
struct StartJourneyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FGStartJourney", provider: FGProvider()) { entry in
            StartJourneyView(entry: entry)
                .fgWidgetBackground(glow: WTheme.gold)
                .widgetURL(FGLink.url("choose"))
        }
        .configurationDisplayName("Start Focus")
        .description("Start a focus flight in one tap.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct StartJourneyView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FGEntry

    private var city: String { entry.snapshot.originCity ?? "Anywhere" }

    var body: some View {
        switch family {
        case .systemLarge:  large
        case .systemMedium: medium
        default:            small
        }
    }

    private var small: some View {
        VStack(spacing: 7) {
            Spacer(minLength: 0)
            WBalloon(size: 40, tint: WTheme.gold)
            Text(city).font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(WTheme.ink).lineLimit(1).minimumScaleFactor(0.6)
            Spacer(minLength: 0)
            WPill(icon: "paperplane.fill", title: "Set off", fill: WTheme.gold, fg: .black)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(14)
    }

    private var medium: some View {
        HStack(spacing: 16) {
            WBalloon(size: 70, tint: WTheme.gold)
                .frame(width: 96)
            VStack(alignment: .leading, spacing: 6) {
                WHeader(icon: "location.fill", title: "Set off from", tint: WTheme.gold)
                Text(city).font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(WTheme.ink).lineLimit(1).minimumScaleFactor(0.7)
                Text("Ready when you are").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(WTheme.inkSoft)
                Spacer(minLength: 0)
                WPill(icon: "paperplane.fill", title: "Set off", fill: WTheme.gold, fg: .black)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
    }

    private var large: some View {
        VStack(spacing: 14) {
            WHeader(icon: "location.fill", title: "Set off", tint: WTheme.gold)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            WBalloon(size: 104, tint: WTheme.gold)
            VStack(spacing: 2) {
                Text(city).font(.system(size: 32, weight: .heavy, design: .rounded)).foregroundStyle(WTheme.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text("Choose your focus, then set off")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(WTheme.inkSoft)
            }
            Spacer(minLength: 0)
            WPill(icon: "paperplane.fill", title: "Set off", fill: WTheme.gold, fg: .black)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(18)
    }
}

#Preview("Start · small", as: .systemSmall) {
    StartJourneyWidget()
} timeline: {
    FGEntry(date: .now, snapshot: .placeholder)
}

#Preview("Start · medium", as: .systemMedium) {
    StartJourneyWidget()
} timeline: {
    FGEntry(date: .now, snapshot: .placeholder)
}

#Preview("Start · large", as: .systemLarge) {
    StartJourneyWidget()
} timeline: {
    FGEntry(date: .now, snapshot: .placeholder)
}
