import SwiftUI
import WidgetKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Streak Companion (FREE · small)

/// A charming, original FocusGlobe streak companion: a little balloon carrying a
/// streak flame, a big streak number, and a short state line that changes with
/// the day (nothing yet / focused today / streak at risk / milestone). Taps
/// through to the streak details.
struct StreakCompanionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FGStreakCompanion", provider: FGProvider()) { entry in
            StreakCompanionView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Color(red: 0.035, green: 0.045, blue: 0.075) }
                .widgetURL(FGLink.url("streak"))
        }
        .configurationDisplayName("Streak Companion")
        .description("Keep your focus streak alive with your balloon companion.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

private enum StreakState {
    case none, focused, atRisk, milestone

    static func resolve(streak: Int, focusedToday: Bool) -> StreakState {
        if focusedToday { return (streak > 0 && streak % 7 == 0) ? .milestone : .focused }
        if streak > 0 { return .atRisk }
        return .none
    }

    var line: String {
        switch self {
        case .none:      return "Start your streak"
        case .focused:   return "Focused today"
        case .atRisk:    return "Focus to keep it"
        case .milestone: return "Milestone! 🎉"
        }
    }
    var tint: Color {
        switch self {
        case .none:      return WTheme.inkSoft
        case .focused:   return WTheme.teal
        case .atRisk:    return WTheme.coral
        case .milestone: return WTheme.gold
        }
    }
}

struct StreakCompanionView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    private var state: StreakState {
        StreakState.resolve(streak: snapshot.currentStreak, focusedToday: snapshot.focusedToday)
    }

    var body: some View {
        if family == .accessoryRectangular {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill").foregroundStyle(.orange)
                Text("\(snapshot.currentStreak)-day streak")
                    .font(.system(size: 15, weight: .heavy, design: .default))
                Spacer()
            }
        } else {
            // The artwork carries the whole message; the number is the ONLY text.
            // "DAY STREAK" and the state line ("Focused today", "Focus to keep
            // it"…) are gone — three stacked captions crowding the bottom of a
            // 158 pt tile read as a label sheet pasted over a picture, and the
            // widget's own gallery title and description already say what it is.
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                ZStack {
                    artwork
                    // A soft pocket of shade behind the digits only. The old
                    // full-height ramp existed to carry bottom text that no
                    // longer exists, and it was dulling the flame.
                    RadialGradient(colors: [.black.opacity(0.42), .clear],
                                   center: UnitPoint(x: 0.5, y: 0.44),
                                   startRadius: 2, endRadius: side * 0.44)
                        .blendMode(.multiply)

                    Text("\(snapshot.currentStreak)")
                        .font(.system(size: side * 0.36, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.85), radius: 7, y: 2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                        .padding(.horizontal, side * 0.12)
                        .frame(width: geo.size.width, height: geo.size.height)
                        // Optically centred in the bright heart of the flame,
                        // which sits above the tile's geometric centre.
                        .offset(y: -side * 0.06)
                        .accessibilityLabel("\(snapshot.currentStreak) day streak. \(state.line).")
                }
            }
            .clipped()
        }
    }

    @ViewBuilder private var artwork: some View {
        #if canImport(UIKit)
        if let art = UIImage(named: "WidgetFireBalloon") {
            Image(uiImage: art)
                .resizable()
                .scaledToFill()
                .grayscale(snapshot.currentStreak > 0 ? 0 : 0.42)
        } else {
            fallbackBackground
        }
        #else
        fallbackBackground
        #endif
    }

    private var fallbackBackground: some View {
        LinearGradient(colors: [Color(red: 0.05, green: 0.07, blue: 0.12),
                                Color(red: 0.12, green: 0.05, blue: 0.035)],
                       startPoint: .top, endPoint: .bottom)
    }
}
