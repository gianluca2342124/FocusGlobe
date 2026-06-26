import SwiftUI
import WidgetKit

/// The hero "journey on the map" widget. When a flight is in progress it shows a
/// stylized dark map with the route arc and the balloon sitting at the current
/// progress, overlaid with the route codes, percent and time/distance remaining.
/// Otherwise it's a calm "Ready for takeoff" invitation. Locked for non-Pro.
struct CurrentJourneyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FGCurrentJourney", provider: FGProvider()) { entry in
            CurrentJourneyView(entry: entry)
                .widgetURL(FGLink.url(entry.snapshot.journeyLink()))
        }
        .configurationDisplayName("Current Journey")
        .description("Resume an unfinished journey on the map.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct CurrentJourneyView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FGEntry
    private var s: WidgetSnapshot { entry.snapshot }

    private var progress: Double { min(1, max(0, s.resumeProgress ?? 0)) }
    private var pct: Int { Int((progress * 100).rounded()) }
    private var origin: String { s.resumeOriginCode ?? (s.resumeOriginCity?.fgCityCode ?? "YOU") }
    private var dest: String { s.resumeDestinationCode ?? (s.resumeDestinationCity?.fgCityCode ?? "FLY") }
    private var timeLeft: String { fgDuration(s.resumeRemainingSeconds ?? 0) }
    private var kmToGo: Int? {
        guard let km = s.resumeRouteKm else { return nil }
        return max(0, Int((Double(km) * (1 - progress)).rounded()))
    }

    var body: some View {
        if !s.isPro {
            LockedTeaser(icon: "map.fill", title: "Current Journey", accent: WTheme.sky)
                .fgWidgetBackground(glow: WTheme.sky)
        } else if s.hasResumable {
            active
        } else {
            ready.fgWidgetBackground(glow: WTheme.sky)
        }
    }

    // MARK: In-flight (map hero)

    private var active: some View {
        Group {
            switch family {
            case .systemSmall: activeSmall
            case .systemLarge: activeLarge
            default:           activeMedium
            }
        }
        .containerBackground(for: .widget) {
            ZStack {
                WStylizedMap(progress: progress, accent: WTheme.gold)
                LinearGradient(colors: [.black.opacity(0.05), .clear, .black.opacity(0.62)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
    }

    private var activeSmall: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                inFlightChip
                Spacer()
                Text("\(pct)%").font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 0)
            Text("\(origin)→\(dest)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            Text("\(timeLeft) left")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }

    private var activeMedium: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                WHeader(icon: "paperplane.fill", title: "In flight", tint: WTheme.sky)
                Spacer()
                resumePill
            }
            Spacer(minLength: 0)
            routeCodes(size: 26)
            WBar(fraction: progress, tint: WTheme.gold)
            HStack {
                Text("\(timeLeft) left")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(kmToGo.map { "\($0.fgGrouped) km to go" } ?? "\(pct)% complete")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
    }

    private var activeLarge: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                WHeader(icon: "paperplane.fill", title: "Current journey", tint: WTheme.sky)
                Spacer()
                resumePill
            }
            Spacer(minLength: 0)
            routeCodes(size: 40)
            Text("\(s.resumeOriginCity ?? origin)  →  \(s.resumeDestinationCity ?? dest)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8)).lineLimit(1).minimumScaleFactor(0.7)
                .padding(.top, 4)
            Spacer(minLength: 0)
            WBar(fraction: progress, tint: WTheme.gold)
                .padding(.bottom, 12)
            HStack(spacing: 0) {
                WStat(value: timeLeft, caption: "left", tint: .white)
                WStat(value: kmToGo.map { "\($0.fgGrouped)" } ?? "—", caption: "km to go", tint: .white)
                WStat(value: "\(pct)%", caption: "complete", tint: WTheme.gold)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(18)
    }

    private func routeCodes(size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(origin).font(.system(size: size, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            Image(systemName: "ellipsis").font(.system(size: size * 0.4, weight: .black))
                .foregroundStyle(WTheme.gold)
            Text(dest).font(.system(size: size, weight: .heavy, design: .rounded)).foregroundStyle(.white)
        }
        .lineLimit(1).minimumScaleFactor(0.6)
    }

    private var inFlightChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "paperplane.fill").font(.system(size: 9, weight: .bold))
            Text("IN FLIGHT").font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(0.6)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.6))
    }

    private var resumePill: some View {
        Text("RESUME").font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundStyle(.black)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(WTheme.gold))
    }

    // MARK: Ready for takeoff

    private var ready: some View {
        VStack(spacing: family == .systemSmall ? 8 : 12) {
            Spacer(minLength: 0)
            WBalloon(size: family == .systemSmall ? 44 : 64, tint: WTheme.sky)
            VStack(spacing: 3) {
                Text("Ready for takeoff")
                    .font(.system(size: family == .systemSmall ? 15 : 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(WTheme.ink)
                if family != .systemSmall {
                    Text("Pick a destination and fly")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(WTheme.inkSoft)
                }
            }
            Spacer(minLength: 0)
            WPill(icon: "paperplane.fill", title: "Start journey", fill: WTheme.ink, fg: .black)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(14)
    }
}

#Preview("Journey · medium", as: .systemMedium) {
    CurrentJourneyWidget()
} timeline: {
    FGEntry(date: .now, snapshot: .placeholder)
}

#Preview("Journey · large", as: .systemLarge) {
    CurrentJourneyWidget()
} timeline: {
    FGEntry(date: .now, snapshot: .placeholder)
}

#Preview("Journey · ready", as: .systemMedium) {
    CurrentJourneyWidget()
} timeline: {
    FGEntry(date: .now, snapshot: .placeholder)
}
