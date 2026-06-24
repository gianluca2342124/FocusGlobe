import SwiftUI

/// A calm, premium "streak details" sheet opened from the Home streak badge.
/// Duolingo-style motivation, adapted to FocusGlobe's glassy, restrained style:
/// the current streak (even when 0), an encouraging line, a 7-day week row, and
/// today's goals with progress. Read-only — it never changes streak logic.
struct StreakDetailsView: View {
    @EnvironmentObject private var appModel: AppModel

    private var streak: Int { appModel.progress.currentStreak }
    private var best: Int { appModel.progress.longestStreak }

    var body: some View {
        ZStack {
            GlassBlurBackground()
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    header
                    weekRow
                    goalsSection
                }
                .padding(Layout.pad(AppSpacing.screen, AppSpacing.xl))
                .frame(maxWidth: Layout.pad(540, 760))   // fills the iPad modal panel
                .frame(maxWidth: .infinity)
            }
        }
        // iPhone keeps a draggable sheet; on iPad the adaptive modal panel sizes it.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xFFB13C).opacity(0.5), .clear],
                                         center: .center, startRadius: 2, endRadius: 70))
                    .frame(width: Layout.pad(130, 152), height: Layout.pad(130, 152))
                Image(systemName: "flame.fill")
                    .font(.system(size: Layout.pad(64, 76), weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFC24B), Color(hex: 0xF2643C)],
                                                    startPoint: .top, endPoint: .bottom))
                    .shadow(color: Color(hex: 0xF2643C).opacity(0.5), radius: 14, y: 4)
            }
            Text("\(streak)")
                .font(.system(size: Layout.pad(54, 66), weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("day streak")
                .font(AppTypography.headline).foregroundStyle(.white.opacity(0.7))
            Text(message)
                .font(AppTypography.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, AppSpacing.md)
            if best > 0 {
                Text("Best: \(best) days")
                    .font(AppTypography.caption).foregroundStyle(AppColors.gold)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var message: String {
        switch streak {
        case 0:     return "Land a journey today to start your streak."
        case 1:     return "Great start — come back tomorrow to keep it alive."
        case 2...6: return "You're building momentum. Keep flying daily."
        default:    return "Incredible focus. Protect your streak today."
        }
    }

    // MARK: This week

    private var weekRow: some View {
        let days = last7Days()
        return GlassCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("THIS WEEK")
                    .font(.system(size: 12, weight: .bold, design: .rounded)).tracking(0.6)
                    .foregroundStyle(.white.opacity(0.6))
                HStack(spacing: 0) {
                    ForEach(days, id: \.date) { day in
                        VStack(spacing: 6) {
                            Text(day.label)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                            ZStack {
                                Circle()
                                    .fill(day.active
                                          ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFB13C), Color(hex: 0xF2643C)],
                                                                         startPoint: .top, endPoint: .bottom))
                                          : AnyShapeStyle(Color.white.opacity(0.10)))
                                    .frame(width: 30, height: 30)
                                if day.active {
                                    Image(systemName: "flame.fill").font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                } else if day.isToday {
                                    Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1.5).frame(width: 30, height: 30)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: Today's goals

    private var goalsSection: some View {
        let missions = appModel.dailyMissions
        return GlassCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Text("TODAY'S GOALS")
                        .font(.system(size: 12, weight: .bold, design: .rounded)).tracking(0.6)
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text("\(missions.filter { $0.isComplete }.count)/\(missions.count)")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColors.gold)
                }
                ForEach(missions) { mission in
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: mission.isComplete ? "checkmark.circle.fill" : mission.systemImage)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(mission.isComplete ? AppColors.success : .white.opacity(0.6))
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mission.title)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(.white.opacity(0.12))
                                    Capsule().fill(mission.isComplete ? AppColors.success : AppColors.gold)
                                        .frame(width: max(5, g.size.width * mission.fraction))
                                }
                            }
                            .frame(height: 5)
                        }
                        Text(mission.progressText)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private struct Day { let date: Date; let label: String; let active: Bool; let isToday: Bool }

    private func last7Days() -> [Day] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let landedDays = Set(appModel.history.filter { $0.completed }.map { cal.startOfDay(for: $0.date) })
        let fmt = DateFormatter(); fmt.dateFormat = "EEEEE"   // single-letter weekday
        return (0..<7).reversed().map { offset in
            let d = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            return Day(date: d, label: fmt.string(from: d),
                       active: landedDays.contains(d), isToday: cal.isDate(d, inSameDayAs: today))
        }
    }
}
