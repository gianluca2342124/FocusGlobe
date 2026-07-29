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
            ZStack {
                #if canImport(UIKit)
                if let art = UIImage(named: "WidgetFireBalloon") {
                    Image(uiImage: art)
                        .resizable()
                        .scaledToFill()
                        .grayscale(snapshot.currentStreak > 0 ? 0 : 0.42)
                } else {
                    LinearGradient(colors: [Color(red: 0.05, green: 0.07, blue: 0.12),
                                            Color(red: 0.12, green: 0.05, blue: 0.035)],
                                   startPoint: .top, endPoint: .bottom)
                }
                #endif
                LinearGradient(colors: [.black.opacity(0.02), .black.opacity(0.16), .black.opacity(0.72)],
                               startPoint: .top, endPoint: .bottom)
                VStack(spacing: -2) {
                    Spacer()
                    Text("\(snapshot.currentStreak)")
                        .font(.system(size: 47, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.85), radius: 7, y: 2)
                        .minimumScaleFactor(0.55).lineLimit(1)
                    Text("DAY STREAK")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.86))
                    Text(state.line)
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .padding(.top, 3)
                }
                .padding(12)
            }
            .clipped()
        }
    }
}
