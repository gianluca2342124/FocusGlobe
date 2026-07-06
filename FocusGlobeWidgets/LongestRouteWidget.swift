import SwiftUI
import WidgetKit

/// The user's longest completed journey, shown as a route landed on the stylized
/// map — origin/destination codes, distance and duration.
struct LongestRouteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FGLongestRoute", provider: FGProvider()) { entry in
            LongestRouteView(entry: entry)
                .widgetURL(FGLink.url(entry.snapshot.gatedLink("passport")))
        }
        .configurationDisplayName("Longest Route")
        .description("Your longest completed expedition.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct LongestRouteView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FGEntry
    private var s: WidgetSnapshot { entry.snapshot }

    var body: some View {
        if !s.isPro {
            LockedTeaser(icon: "map.fill", title: "Longest Route", accent: WTheme.gold)
                .fgWidgetBackground(glow: WTheme.gold)
        } else if let o = s.longestRouteOrigin, let d = s.longestRouteDestination {
            content(origin: o, dest: d)
                .containerBackground(for: .widget) {
                    ZStack {
                        WStylizedMap(progress: 1.0, accent: WTheme.gold)
                        LinearGradient(colors: [.black.opacity(0.1), .clear, .black.opacity(0.6)],
                                       startPoint: .top, endPoint: .bottom)
                    }
                }
        } else {
            empty.fgWidgetBackground(glow: WTheme.gold)
        }
    }

    private func content(origin: String, dest: String) -> some View {
        let big: CGFloat = family == .systemLarge ? 40 : 28
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                WHeader(icon: "trophy.fill", title: "Longest route", tint: WTheme.gold)
                Spacer()
                landedChip
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(origin).font(.system(size: big * 0.62, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                Image(systemName: "ellipsis").font(.system(size: big * 0.4, weight: .black)).foregroundStyle(WTheme.gold)
                Text(dest).font(.system(size: big * 0.62, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            }
            .lineLimit(1).minimumScaleFactor(0.6)
            Text("\(origin)  →  \(dest)")
                .font(.system(size: family == .systemLarge ? 14 : 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78)).lineLimit(1).minimumScaleFactor(0.7)
                .padding(.top, 3)
            Spacer(minLength: 0)
            if family == .systemLarge {
                HStack(spacing: 0) {
                    if let km = s.longestRouteKm {
                        WStat(value: km.fgGrouped, caption: "km", tint: WTheme.gold)
                    }
                    if let m = s.longestRouteDurationMinutes {
                        WStat(value: "\(m)", caption: "minutes", tint: .white)
                    }
                    WStat(value: "\(s.landings)", caption: "discoveries", tint: .white)
                }
            } else if let km = s.longestRouteKm {
                Text(metrics(km: km))
                    .font(.system(size: 12, weight: .heavy, design: .rounded)).foregroundStyle(WTheme.gold)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(family == .systemLarge ? 18 : 16)
    }

    private var landedChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 9, weight: .bold))
            Text("ARRIVED").font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(0.6)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.6))
    }

    private func metrics(km: Int) -> String {
        var parts = ["\(km.fgGrouped) km"]
        if let m = s.longestRouteDurationMinutes { parts.append("\(m) min") }
        return parts.joined(separator: " · ")
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            WHeader(icon: "trophy.fill", title: "Longest route", tint: WTheme.gold)
            Spacer(minLength: 0)
            Text("No expeditions yet").font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(WTheme.ink)
            Text("Complete an expedition to see your longest route here.")
                .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(WTheme.inkSoft)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
    }
}

#Preview("Longest · medium", as: .systemMedium) {
    LongestRouteWidget()
} timeline: {
    FGEntry(date: .now, snapshot: .placeholder)
}

#Preview("Longest · large", as: .systemLarge) {
    LongestRouteWidget()
} timeline: {
    FGEntry(date: .now, snapshot: .placeholder)
}
