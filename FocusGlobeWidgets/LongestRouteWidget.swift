import SwiftUI
import WidgetKit

/// The user's longest completed route, as an elegant route card.
struct LongestRouteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FGLongestRoute", provider: FGProvider()) { entry in
            LongestRouteView(entry: entry)
                .fgWidgetBackground()
                .widgetURL(FGLink.url("passport"))
        }
        .configurationDisplayName("Longest Route")
        .description("Your longest completed journey.")
        .supportedFamilies([.systemMedium])
    }
}

private struct LongestRouteView: View {
    let entry: FGEntry
    private var s: WidgetSnapshot { entry.snapshot }

    var body: some View {
        if !s.isPro {
            LockedTeaser(icon: "point.topleft.down.to.point.bottomright.curvepath", title: "Longest Route", accent: WTheme.gold)
        } else if let o = s.longestRouteOrigin, let d = s.longestRouteDestination {
            content(origin: o, dest: d)
        } else {
            empty
        }
    }

    private func content(origin: String, dest: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            WHeader(icon: "point.topleft.down.to.point.bottomright.curvepath", title: "Longest Route")
            WRouteArc(tint: WTheme.gold).frame(height: 50)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(origin).font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(WTheme.ink).lineLimit(1).minimumScaleFactor(0.7)
                    Text("Origin").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(WTheme.inkSoft)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(dest).font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(WTheme.ink).lineLimit(1).minimumScaleFactor(0.7)
                    Text("Destination").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(WTheme.inkSoft)
                }
            }
            if let km = s.longestRouteKm {
                Text(metrics(km: km))
                    .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(WTheme.gold)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }

    private func metrics(km: Int) -> String {
        var parts = ["\(km.fgGrouped) km"]
        if let m = s.longestRouteDurationMinutes { parts.append("\(m) min") }
        return parts.joined(separator: " · ")
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            WHeader(icon: "point.topleft.down.to.point.bottomright.curvepath", title: "Longest Route")
            Spacer(minLength: 0)
            Text("No journeys yet").font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(WTheme.ink)
            Text("Complete a flight to see your longest route here.")
                .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(WTheme.inkSoft)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }
}
