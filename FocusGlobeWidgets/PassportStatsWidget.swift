import SwiftUI
import WidgetKit

// MARK: - Passport Stats (PRO)

/// Real Passport statistics in a premium travel/passport language: journeys,
/// focused time, longest journey, current + longest streak and active focus
/// days. Taps through to the Passport.
struct PassportStatsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FGPassportStats", provider: FGProvider()) { entry in
            PassportStatsView(snapshot: entry.snapshot)
                .fgWidgetBackground(glow: WTheme.indigo)
                .widgetURL(FGLink.url(entry.snapshot.gatedLink("passport")))
        }
        .configurationDisplayName("Passport Stats")
        .description("Your journeys, focused time and streaks. FocusGlobe PRO.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct PassportStatsView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    private var focusedTime: String {
        let m = snapshot.totalFocusedMinutes
        if m < 60 { return "\(m)m" }
        return "\(m / 60)h \(String(format: "%02d", m % 60))m"
    }

    var body: some View {
        if !snapshot.isPro {
            LockedTeaser(icon: "book.closed.fill", title: "Passport Stats", accent: WTheme.indigo)
        } else if family == .systemSmall {
            VStack(alignment: .leading, spacing: 6) {
                WHeader(icon: "book.closed.fill", title: "Passport", tint: WTheme.gold)
                Spacer(minLength: 0)
                WStat(value: "\(snapshot.landings)", caption: "journeys", tint: WTheme.ink)
                WStat(value: focusedTime, caption: "focused", tint: WTheme.teal)
                WStat(value: "\(snapshot.currentStreak)", caption: "day streak", tint: WTheme.coral)
            }
            .padding(14)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                WHeader(icon: "book.closed.fill", title: "FocusGlobe Passport", tint: WTheme.gold)
                HStack(spacing: 10) {
                    WStat(value: "\(snapshot.landings)", caption: "journeys", tint: WTheme.ink)
                    WStat(value: focusedTime, caption: "focused", tint: WTheme.teal)
                    WStat(value: "\(snapshot.activeFocusDays)", caption: "focus days", tint: WTheme.indigo)
                }
                HStack(spacing: 10) {
                    WStat(value: "\(snapshot.currentStreak)", caption: "streak", tint: WTheme.coral)
                    WStat(value: "\(snapshot.longestStreak)", caption: "best streak", tint: WTheme.coral)
                    WStat(value: "\(snapshot.bestFocusMinutes)m", caption: "longest", tint: WTheme.gold)
                }
                if family == .systemLarge {
                    Spacer(minLength: 0)
                    WFocusGrid(activeOrdinals: Set(snapshot.activeDayOrdinals))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
