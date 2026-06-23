import SwiftUI
import WidgetKit

/// Shows an unfinished (paused) journey to resume, or a tasteful prompt to start
/// a new one when none is in progress.
struct CurrentJourneyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FGCurrentJourney", provider: FGProvider()) { entry in
            CurrentJourneyView(entry: entry)
                .fgWidgetBackground()
                .widgetURL(FGLink.url(entry.snapshot.hasResumable ? "resume" : "choose"))
        }
        .configurationDisplayName("Current Journey")
        .description("Resume an unfinished journey, or start a new one.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct CurrentJourneyView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FGEntry
    private var s: WidgetSnapshot { entry.snapshot }

    var body: some View {
        if !s.isPro {
            LockedTeaser(icon: "paperplane.circle.fill", title: "Current Journey", accent: WTheme.sky)
        } else if s.hasResumable {
            active
        } else {
            fallback
        }
    }

    private var active: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                WHeader(icon: "paperplane.fill", title: "In progress", tint: WTheme.sky)
                Spacer()
                Text("RESUME").font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(WTheme.gold))
            }
            Spacer(minLength: 0)
            Text("\(s.resumeOriginCity ?? "") → \(s.resumeDestinationCity ?? "")")
                .font(.system(size: family == .systemLarge ? 24 : 19, weight: .heavy, design: .rounded))
                .foregroundStyle(WTheme.ink).lineLimit(1).minimumScaleFactor(0.6)
            if let p = s.resumeProgress { WBar(fraction: p, tint: WTheme.sky) }
            HStack {
                if let r = s.resumeRemainingSeconds {
                    Text("\(fgDuration(r)) left")
                        .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(WTheme.inkSoft)
                }
                Spacer()
                if let p = s.resumeProgress {
                    Text("\(Int((p * 100).rounded()))%")
                        .font(.system(size: 12, weight: .heavy, design: .rounded)).foregroundStyle(WTheme.sky)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }

    private var fallback: some View {
        VStack(alignment: .leading, spacing: 8) {
            WHeader(icon: "paperplane.fill", title: "Ready to fly", tint: WTheme.sky)
            Spacer(minLength: 0)
            Text("No active journey")
                .font(.system(size: 19, weight: .heavy, design: .rounded)).foregroundStyle(WTheme.ink)
            Text("Tap to choose a destination and start a focus flight.")
                .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(WTheme.inkSoft)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Image(systemName: "paperplane.fill").font(.system(size: 12, weight: .bold))
                Text("Start journey").font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color.black).padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(WTheme.ink))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }
}
