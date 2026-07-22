import SwiftUI
import WidgetKit

// MARK: - Badge Collection (PRO)

/// Real Passport badges: the unlocked ones prominently, a tasteful hint of the
/// next badge to earn, and the unlocked count. Taps through to the Passport
/// badge section.
struct BadgeCollectionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FGBadgeCollection", provider: FGProvider()) { entry in
            BadgeCollectionView(snapshot: entry.snapshot)
                .fgWidgetBackground(glow: WTheme.gold)
                .widgetURL(FGLink.url(entry.snapshot.gatedLink("badges")))
        }
        .configurationDisplayName("Badge Collection")
        .description("Your unlocked badges and the next to earn. FocusGlobe PRO.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct BadgeCollectionView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    private var earned: [WidgetBadge] { snapshot.badges.filter { $0.earned } }
    private var next: WidgetBadge? { snapshot.nextBadge }
    private var columns: Int { family == .systemSmall ? 3 : 5 }

    var body: some View {
        if !snapshot.isPro {
            LockedTeaser(icon: "rosette", title: "Badge Collection", accent: WTheme.gold)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    WHeader(icon: "rosette", title: "Badges", tint: WTheme.gold)
                    Spacer()
                    Text("\(snapshot.badgeUnlockedCount)/\(max(snapshot.badgeTotal, snapshot.badges.count))")
                        .font(.system(size: 12, weight: .heavy, design: .default))
                        .foregroundStyle(WTheme.ink)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns),
                          spacing: 8) {
                    ForEach(Array(earned.prefix(family == .systemSmall ? 6 : 10).enumerated()), id: \.offset) { _, b in
                        badgeDot(icon: b.icon, earned: true)
                    }
                    if let next {
                        badgeDot(icon: next.icon, earned: false)
                    }
                }
                if family != .systemSmall, let next {
                    Text("Next: \(next.name)")
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .foregroundStyle(WTheme.inkSoft)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
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
        .frame(height: 34)
    }
}
