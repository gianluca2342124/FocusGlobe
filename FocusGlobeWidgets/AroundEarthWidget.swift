import SwiftUI
import WidgetKit

/// Cumulative "around the Earth" progress from total focus miles, shown as an
/// illustrated globe wrapped by a progress ring with an orbiting balloon.
struct AroundEarthWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FGAroundEarth", provider: FGProvider()) { entry in
            AroundEarthView(entry: entry)
                .fgWidgetBackground(glow: WTheme.teal)
                .widgetURL(FGLink.url(entry.snapshot.gatedLink("passport")))
        }
        .configurationDisplayName("Around Earth")
        .description("How far you've travelled around the planet.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct AroundEarthView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FGEntry

    private var s: WidgetSnapshot { entry.snapshot }
    private var laps: Double { s.aroundEarthLaps }
    private var lapText: String { String(format: "%.2f×", laps) }
    private var ringFraction: Double { laps >= 1 ? laps.truncatingRemainder(dividingBy: 1) : laps }

    var body: some View {
        if !s.isPro {
            LockedTeaser(icon: "globe.europe.africa.fill", title: "Around Earth", accent: WTheme.teal)
        } else {
            switch family {
            case .systemLarge:  large
            case .systemMedium: medium
            default:            small
            }
        }
    }

    private func earth(_ size: CGFloat, orbit: Bool = true) -> some View {
        // WEarth caps its own layout box; the atmosphere glow bleeds softly. The
        // orbiting balloon is dropped in the medium layout where the globe sits
        // beside the text (so it never crowds it).
        WEarth(size: size, ringFraction: ringFraction, ringTint: WTheme.teal, orbitBalloon: orbit)
    }

    private var small: some View {
        VStack(spacing: 7) {
            Spacer(minLength: 0)
            earth(68)
            Spacer(minLength: 0)
            Text("\(s.totalFocusMiles.fgGrouped) km")
                .font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(WTheme.ink)
                .minimumScaleFactor(0.7).lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(14)
    }

    private var medium: some View {
        HStack(spacing: 18) {
            earth(84, orbit: false)
            VStack(alignment: .leading, spacing: 5) {
                WHeader(icon: "globe.europe.africa.fill", title: "Around Earth", tint: WTheme.teal)
                Text(lapText + " around")
                    .font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(WTheme.ink)
                    .minimumScaleFactor(0.7).lineLimit(1)
                Text("\(s.totalFocusMiles.fgGrouped) km flown")
                    .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(WTheme.inkSoft)
                Text("\(s.landings) landings · \(s.currentStreak)-day streak")
                    .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(WTheme.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
    }

    private var large: some View {
        VStack(spacing: 0) {
            WHeader(icon: "globe.europe.africa.fill", title: "Around Earth", tint: WTheme.teal)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            earth(140)
            Text(lapText + " around the world")
                .font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(WTheme.ink)
                .padding(.top, 14)
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                WStat(value: "\(s.totalFocusMiles.fgGrouped)", caption: "km flown", tint: WTheme.gold)
                WStat(value: "\(s.landings)", caption: "landings")
                WStat(value: "\(s.currentStreak)", caption: "day streak", tint: WTheme.coral)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(18)
    }
}

#Preview("Earth · small", as: .systemSmall) {
    AroundEarthWidget()
} timeline: {
    FGEntry(date: .now, snapshot: .placeholder)
}

#Preview("Earth · medium", as: .systemMedium) {
    AroundEarthWidget()
} timeline: {
    FGEntry(date: .now, snapshot: .placeholder)
}

#Preview("Earth · large", as: .systemLarge) {
    AroundEarthWidget()
} timeline: {
    FGEntry(date: .now, snapshot: .placeholder)
}
