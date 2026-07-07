import SwiftUI
import WidgetKit

/// The user's collectible passport — their current balloon skin and lifetime
/// focus stats (miles, landings, postcards), styled like a travel keepsake.
struct PassportWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FGPassport", provider: FGProvider()) { entry in
            PassportSnapshotView(entry: entry)
                .fgWidgetBackground(glow: WTheme.indigo)
                .widgetURL(FGLink.url(entry.snapshot.gatedLink("passport")))
        }
        .configurationDisplayName("Passport")
        .description("Your collection and focus stats at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct PassportSnapshotView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FGEntry
    private var s: WidgetSnapshot { entry.snapshot }
    private var skin: String { s.selectedSkinName ?? "Classic" }

    var body: some View {
        if !s.isPro {
            LockedTeaser(icon: "books.vertical.fill", title: "Passport", accent: WTheme.indigo)
        } else {
            switch family {
            case .systemLarge:  large
            case .systemMedium: medium
            default:            small
            }
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                WHeader(icon: "books.vertical.fill", title: "Passport", tint: WTheme.indigo)
                Spacer()
                WBalloon(size: 24, tint: WTheme.gold)
            }
            Spacer(minLength: 0)
            WStat(value: s.totalFocusMiles.fgGrouped, caption: "miles charted", tint: WTheme.gold)
            HStack(spacing: 10) {
                WStat(value: "\(s.landings)", caption: "discoveries")
                WStat(value: "\(s.postcardCount)", caption: "postcards", tint: WTheme.teal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }

    private var medium: some View {
        HStack(spacing: 16) {
            VStack(spacing: 8) {
                WBalloon(size: 62, tint: WTheme.gold)
                Text(skin.uppercased())
                    .font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(0.8)
                    .foregroundStyle(WTheme.inkSoft).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(width: 92)
            VStack(alignment: .leading, spacing: 10) {
                WHeader(icon: "books.vertical.fill", title: "Passport", tint: WTheme.indigo)
                WStat(value: s.totalFocusMiles.fgGrouped, caption: "miles charted", tint: WTheme.gold)
                HStack(spacing: 12) {
                    WStat(value: "\(s.landings)", caption: "discoveries")
                    WStat(value: "\(s.postcardCount)", caption: "postcards", tint: WTheme.teal)
                    WStat(value: "\(s.currentStreak)", caption: "streak", tint: WTheme.coral)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
    }

    private var large: some View {
        VStack(spacing: 0) {
            HStack {
                WHeader(icon: "books.vertical.fill", title: "Passport", tint: WTheme.indigo)
                Spacer()
                Text("\(s.postcardCount) STAMPS")
                    .font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(0.6)
                    .foregroundStyle(WTheme.inkSoft)
            }
            Spacer(minLength: 0)
            WBalloon(size: 96, tint: WTheme.gold)
            VStack(spacing: 2) {
                Text(skin).font(.system(size: 20, weight: .heavy, design: .rounded)).foregroundStyle(WTheme.ink)
                Text("CURRENT BALLOON").font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(1.0)
                    .foregroundStyle(WTheme.inkSoft)
            }
            .padding(.top, 12)
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                WStat(value: s.totalFocusMiles.fgGrouped, caption: "miles charted", tint: WTheme.gold)
                WStat(value: "\(s.landings)", caption: "discoveries")
                WStat(value: "\(s.postcardCount)", caption: "postcards", tint: WTheme.teal)
                WStat(value: "\(s.currentStreak)", caption: "day streak", tint: WTheme.coral)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(18)
    }
}

#Preview("Passport · small", as: .systemSmall) {
    PassportWidget()
} timeline: {
    FGEntry(date: .now, snapshot: .placeholder)
}

#Preview("Passport · medium", as: .systemMedium) {
    PassportWidget()
} timeline: {
    FGEntry(date: .now, snapshot: .placeholder)
}

#Preview("Passport · large", as: .systemLarge) {
    PassportWidget()
} timeline: {
    FGEntry(date: .now, snapshot: .placeholder)
}
