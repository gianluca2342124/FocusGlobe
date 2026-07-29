import SwiftUI
import WidgetKit

// MARK: - Passport Dashboard (PRO)

/// The real Passport dashboard in a premium travel/passport language: journeys,
/// focused time, current + longest streak, longest session and active focus days
/// — plus a few genuinely unlocked badges (folded in from the retired standalone
/// Badge Collection widget). Taps through to the Passport.
struct PassportStatsWidget: Widget {
    var body: some WidgetConfiguration {
        // Kind stays "FGPassportStats" so existing installs keep working.
        StaticConfiguration(kind: "FGPassportStats", provider: FGProvider()) { entry in
            PassportStatsView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(red: 0.09, green: 0.105, blue: 0.15),
                                 Color(red: 0.035, green: 0.043, blue: 0.065)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .widgetURL(FGLink.url(entry.snapshot.gatedLink("passport")))
        }
        .configurationDisplayName("Passport Dashboard")
        .description("Your journeys, focused time, streaks and badges. FocusGlobe PRO.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
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
                .padding(14)
        } else if family == .systemSmall {
            VStack(alignment: .leading, spacing: 6) {
                WHeader(icon: "book.closed.fill", title: "Passport", tint: WTheme.gold)
                Spacer(minLength: 0)
                WStat(value: "\(snapshot.landings)", caption: "journeys", tint: WTheme.ink)
                WStat(value: focusedTime, caption: "focused", tint: WTheme.teal)
                WStat(value: "\(snapshot.currentStreak)", caption: "day streak", tint: WTheme.coral)
            }
            .padding(14)
            .background(passportBackground)
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
                    badgeRow
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(passportBackground)
        }
    }

    private var passportBackground: some View {
        LinearGradient(
            colors: [Color(red: 0.09, green: 0.105, blue: 0.15),
                     Color(red: 0.035, green: 0.043, blue: 0.065)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // A few genuinely unlocked badges (folded in from the retired Badge Collection
    // widget) using the same passport badge language.
    private var earnedBadges: [WidgetBadge] { snapshot.badges.filter { $0.earned } }

    private var badgeRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                WHeader(icon: "rosette", title: "Badges", tint: WTheme.gold)
                Spacer()
                Text("\(snapshot.badgeUnlockedCount)/\(max(snapshot.badgeTotal, snapshot.badges.count))")
                    .font(.system(size: 12, weight: .heavy, design: .default))
                    .foregroundStyle(WTheme.ink)
            }
            HStack(spacing: 8) {
                ForEach(Array(earnedBadges.prefix(6).enumerated()), id: \.offset) { _, b in
                    badgeDot(icon: b.icon, earned: true)
                }
                if let next = snapshot.nextBadge { badgeDot(icon: next.icon, earned: false) }
                Spacer(minLength: 0)
            }
        }
    }

    private func badgeDot(icon: String, earned: Bool) -> some View {
        ZStack {
            Circle()
                .fill(earned ? WTheme.gold.opacity(0.18) : WTheme.hair)
                .overlay(Circle().strokeBorder(earned ? WTheme.gold.opacity(0.6) : WTheme.inkSoft.opacity(0.3),
                                               lineWidth: 1))
            Image(systemName: earned ? icon : "lock.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(earned ? WTheme.gold : WTheme.inkSoft)
        }
        .frame(width: 34, height: 34)
    }
}
