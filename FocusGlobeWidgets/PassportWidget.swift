import SwiftUI
import WidgetKit

/// A snapshot of the user's lifetime focus stats.
struct PassportWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FGPassport", provider: FGProvider()) { entry in
            PassportSnapshotView(entry: entry)
                .fgWidgetBackground()
                .widgetURL(FGLink.url("passport"))
        }
        .configurationDisplayName("Passport")
        .description("Your focus stats at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct PassportSnapshotView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FGEntry
    private var s: WidgetSnapshot { entry.snapshot }

    var body: some View {
        if !s.isPro {
            LockedTeaser(icon: "globe.europe.africa.fill", title: "Passport", accent: WTheme.indigo)
        } else if family == .systemMedium {
            medium
        } else {
            small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            WHeader(icon: "globe.europe.africa.fill", title: "Passport", tint: WTheme.indigo)
            Spacer(minLength: 0)
            WStat(value: s.totalFocusMiles.fgGrouped, caption: "focus miles", tint: WTheme.gold)
            HStack(spacing: 10) {
                WStat(value: "\(s.landings)", caption: "landings")
                WStat(value: "\(s.currentStreak)", caption: "streak", tint: WTheme.coral)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 12) {
            WHeader(icon: "globe.europe.africa.fill", title: "Passport", tint: WTheme.indigo)
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                WStat(value: s.totalFocusMiles.fgGrouped, caption: "focus miles", tint: WTheme.gold)
                WStat(value: "\(s.landings)", caption: "landings")
                WStat(value: "\(s.currentStreak)", caption: "day streak", tint: WTheme.coral)
                WStat(value: "\(s.bestFocusMinutes)m", caption: "best focus")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }
}
