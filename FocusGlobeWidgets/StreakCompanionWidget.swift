import SwiftUI
import WidgetKit

// MARK: - Streak Companion (FREE · small)

/// A charming, original FocusGlobe streak companion: a little balloon carrying a
/// streak flame, a big streak number, and a short state line that changes with
/// the day (nothing yet / focused today / streak at risk / milestone). Taps
/// through to the streak details.
struct StreakCompanionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FGStreakCompanion", provider: FGProvider()) { entry in
            StreakCompanionView(snapshot: entry.snapshot)
                .fgWidgetBackground(glow: WTheme.coral)
                .widgetURL(FGLink.url("streak"))
        }
        .configurationDisplayName("Streak Companion")
        .description("Keep your focus streak alive with your balloon companion.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
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
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                Spacer()
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    CompanionBalloon(lit: snapshot.focusedToday, tint: state.tint)
                        .frame(width: 54, height: 66)
                    Spacer()
                    VStack(alignment: .trailing, spacing: -2) {
                        Text("\(snapshot.currentStreak)")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundStyle(WTheme.ink)
                            .minimumScaleFactor(0.6).lineLimit(1)
                        Text(snapshot.currentStreak == 1 ? "DAY" : "DAYS")
                            .font(.system(size: 11, weight: .heavy, design: .rounded)).tracking(1)
                            .foregroundStyle(WTheme.inkSoft)
                    }
                }
                Spacer(minLength: 0)
                Text(state.line)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(state.tint)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(14)
        }
    }
}

/// A small original balloon carrying a streak flame — warm envelope, tiny basket,
/// a burner flame that brightens when today is already focused.
private struct CompanionBalloon: View {
    let lit: Bool
    let tint: Color

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                // Envelope (teardrop).
                Ellipse()
                    .fill(LinearGradient(colors: [tint.opacity(0.95), tint.opacity(0.65)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.86, height: h * 0.72)
                    .position(x: w / 2, y: h * 0.38)
                    .shadow(color: tint.opacity(lit ? 0.6 : 0.2), radius: lit ? 8 : 3)
                // Two soft gore highlights.
                Capsule().fill(WTheme.ink.opacity(0.18))
                    .frame(width: w * 0.08, height: h * 0.5)
                    .position(x: w * 0.42, y: h * 0.34)
                // Basket.
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color(red: 0.42, green: 0.30, blue: 0.20))
                    .frame(width: w * 0.24, height: h * 0.14)
                    .position(x: w / 2, y: h * 0.86)
                // Ropes.
                Path { p in
                    p.move(to: CGPoint(x: w * 0.30, y: h * 0.62))
                    p.addLine(to: CGPoint(x: w * 0.42, y: h * 0.80))
                    p.move(to: CGPoint(x: w * 0.70, y: h * 0.62))
                    p.addLine(to: CGPoint(x: w * 0.58, y: h * 0.80))
                }
                .stroke(WTheme.ink.opacity(0.35), lineWidth: 1)
                // Streak flame riding the basket.
                Image(systemName: "flame.fill")
                    .font(.system(size: h * 0.17, weight: .bold))
                    .foregroundStyle(lit
                        ? LinearGradient(colors: [Color(red: 1, green: 0.72, blue: 0.36),
                                                  Color(red: 0.95, green: 0.40, blue: 0.24)],
                                         startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [WTheme.inkSoft, WTheme.inkSoft],
                                         startPoint: .top, endPoint: .bottom))
                    .position(x: w / 2, y: h * 0.72)
            }
        }
    }
}
