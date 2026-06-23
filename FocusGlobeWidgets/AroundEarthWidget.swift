import SwiftUI
import WidgetKit

/// Cumulative "around the Earth" progress from total focus miles.
struct AroundEarthWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FGAroundEarth", provider: FGProvider()) { entry in
            AroundEarthView(entry: entry)
                .fgWidgetBackground()
                .widgetURL(FGLink.url("passport"))
        }
        .configurationDisplayName("Around Earth")
        .description("How far you've travelled around the planet.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct AroundEarthView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FGEntry

    private var s: WidgetSnapshot { entry.snapshot }
    private var laps: Double { s.aroundEarthLaps }
    private var lapText: String { String(format: "%.2f×", laps) }
    private var ringFraction: Double { laps >= 1 ? 1 : laps.truncatingRemainder(dividingBy: 1) }

    var body: some View {
        if !s.isPro {
            LockedTeaser(icon: "globe.europe.africa.fill", title: "Around Earth", accent: WTheme.teal)
        } else if family == .systemMedium {
            medium
        } else {
            small
        }
    }

    private var ring: some View {
        ZStack {
            WRing(fraction: ringFraction, tint: WTheme.teal)
            VStack(spacing: 0) {
                Text(lapText).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(WTheme.ink)
                Text("laps").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(WTheme.inkSoft)
            }
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            WHeader(icon: "globe.europe.africa.fill", title: "Around Earth", tint: WTheme.teal)
            ring.frame(width: 60, height: 60)
            Spacer(minLength: 0)
            Text("\(s.totalFocusMiles.fgGrouped) km")
                .font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(WTheme.ink)
            Text("flown").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(WTheme.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }

    private var medium: some View {
        HStack(spacing: 16) {
            ring.frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 5) {
                WHeader(icon: "globe.europe.africa.fill", title: "Around Earth", tint: WTheme.teal)
                Text(lapText + " around")
                    .font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundStyle(WTheme.ink)
                Text("Flown \(s.totalFocusMiles.fgGrouped) km")
                    .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(WTheme.inkSoft)
                Text("\(s.landings) landings · \(s.currentStreak)-day streak")
                    .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(WTheme.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }
}
