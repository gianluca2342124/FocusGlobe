import SwiftUI
import WidgetKit

/// Quick-launch into the app to choose a journey from the current city.
/// Available to everyone — it's a launcher, not private data.
struct StartJourneyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FGStartJourney", provider: FGProvider()) { entry in
            StartJourneyView(entry: entry)
                .fgWidgetBackground()
                .widgetURL(FGLink.url("choose"))
        }
        .configurationDisplayName("Start a Journey")
        .description("Depart from your city and begin a focus flight.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct StartJourneyView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FGEntry

    private var city: String { entry.snapshot.originCity ?? "Anywhere" }
    private var code: String { entry.snapshot.originCode ?? "FLY" }

    var body: some View {
        if family == .systemMedium { medium } else { small }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            WHeader(icon: "location.fill", title: "Depart")
            Spacer(minLength: 0)
            Text(code).font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(WTheme.ink)
            Text(city).font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(WTheme.inkSoft).lineLimit(1)
            Spacer(minLength: 0)
            cta
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                WHeader(icon: "location.fill", title: "Depart from")
                Spacer(minLength: 0)
                Text(city).font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(WTheme.ink).lineLimit(1).minimumScaleFactor(0.7)
                Text(code).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(WTheme.gold)
                Spacer(minLength: 0)
                cta
            }
            VStack(spacing: 6) {
                WRouteArc(tint: WTheme.sky).frame(height: 64)
                Text("Choose your focus, then fly")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(WTheme.inkSoft).multilineTextAlignment(.center)
            }
            .frame(width: 132)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }

    private var cta: some View {
        HStack(spacing: 6) {
            Image(systemName: "paperplane.fill").font(.system(size: 12, weight: .bold))
            Text("Start journey").font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .foregroundStyle(Color.black)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Capsule().fill(WTheme.ink))
    }
}
