import SwiftUI

/// The luminous 7-day streak continuity strip — flame discs for landed days,
/// a gold ring for today, a quiet ✕ for missed past days, and a soft flight
/// trail linking consecutive active days. ONE shared component so the Streak
/// popup and the post-flight streak card can never disagree about a day.
/// Reads only the real on-device history; the current calendar week respects
/// the locale's first weekday.
struct StreakWeekStrip: View {
    let history: [FocusSessionRecord]

    var body: some View {
        weekStrip(weekDays())
    }

    private func weekStrip(_ days: [Day]) -> some View {
        let disc = Layout.pad(CGFloat(36), CGFloat(44))
        return VStack(spacing: AppSpacing.xs) {
            HStack(spacing: 0) {
                ForEach(days, id: \.date) { day in
                    Text(day.label)
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .foregroundStyle(day.active ? AppColors.gold : AppColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            ZStack {
                trail(days)
                HStack(spacing: 0) {
                    ForEach(days, id: \.date) { day in
                        dayDisc(day, size: disc)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: disc)
        }
    }

    /// A soft luminous "flight trail" drawn behind consecutive active days.
    private func trail(_ days: [Day]) -> some View {
        Canvas { ctx, size in
            let n = days.count
            guard n > 1 else { return }
            let cy = size.height / 2
            var path = Path()
            for i in 0..<(n - 1) where days[i].active && days[i + 1].active {
                let x1 = size.width * CGFloat(Double(i) + 0.5) / CGFloat(n)
                let x2 = size.width * CGFloat(Double(i) + 1.5) / CGFloat(n)
                path.move(to: CGPoint(x: x1, y: cy))
                path.addLine(to: CGPoint(x: x2, y: cy))
            }
            ctx.stroke(path,
                       with: .color(Color(hex: 0xFFB13C).opacity(0.22)),
                       style: StrokeStyle(lineWidth: 10, lineCap: .round))
            ctx.stroke(path,
                       with: .linearGradient(
                        Gradient(colors: [Color(hex: 0xFFC24B), Color(hex: 0xF2643C)]),
                        startPoint: CGPoint(x: 0, y: cy),
                        endPoint: CGPoint(x: size.width, y: cy)),
                       style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }
        .allowsHitTesting(false)
    }

    private func dayDisc(_ day: Day, size: CGFloat) -> some View {
        ZStack {
            if day.active {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: 0xFFC24B), Color(hex: 0xF2643C)],
                        startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                    .shadow(color: Color(hex: 0xF2643C).opacity(0.45), radius: 6, y: 2)
                Image(systemName: "flame.fill")
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(.white)
            } else if day.isToday {
                Circle().fill(AppColors.gold.opacity(0.10))
                Circle().strokeBorder(AppColors.gold.opacity(0.7), lineWidth: 2)
            } else if day.isPast {
                // A clearly missed day: a quiet grey ✕ (shown for new users too).
                Circle().fill(AppColors.textPrimary.opacity(0.06))
                Image(systemName: "xmark")
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(AppColors.textTertiary.opacity(0.75))
            } else {
                // A future day: empty and subtle.
                Circle().fill(AppColors.textPrimary.opacity(0.06))
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: Helpers

    private struct Day {
        let date: Date; let label: String; let active: Bool
        let isToday: Bool; let isPast: Bool; let isFuture: Bool
    }

    /// The current calendar week (respects the locale's first weekday): completed
    /// days flame, today is ringed, missed *past* days get a grey ✕, and future
    /// days stay empty/subtle.
    private func weekDays() -> [Day] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let landedDays = Set(history.filter { $0.completed }.map { cal.startOfDay(for: $0.date) })
        let fmt = DateFormatter(); fmt.dateFormat = "EEEEE"   // single-letter weekday
        let startOfWeek = cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return (0..<7).map { offset in
            let d = cal.startOfDay(for: cal.date(byAdding: .day, value: offset, to: startOfWeek) ?? today)
            return Day(date: d, label: fmt.string(from: d),
                       active: landedDays.contains(d),
                       isToday: cal.isDate(d, inSameDayAs: today),
                       isPast: d < today, isFuture: d > today)
        }
    }
}
