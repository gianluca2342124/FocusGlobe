import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A warm, precious "streak details" sheet opened from the Home streak badge.
/// FocusGlobe's cozy-premium take on a streak screen: a glowing, breathing ember,
/// a big current-streak numeral, an encouraging line, a luminous 7-day continuity
/// strip (with a flight trail linking consecutive days), and a single clean
/// "today" status line. Read-only — it never changes streak logic.
struct StreakDetailsView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var breathe = false
    @State private var appeared = false

    private var streak: Int { appModel.progress.currentStreak }
    private var best: Int { appModel.progress.longestStreak }

    var body: some View {
        ZStack {
            // A warm static streak backdrop: dark charcoal into burgundy with a
            // soft ember glow behind the fire — no moving tile.
            ZStack {
                LinearGradient(colors: [Color(hex: 0x17110F), Color(hex: 0x261016)],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [Color(hex: 0xF2643C).opacity(0.16), .clear],
                               center: UnitPoint(x: 0.5, y: 0.24), startRadius: 4, endRadius: 340)
            }
            .ignoresSafeArea()
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    hero
                    weekRow
                    consistencyCard
                    todayStatus
                    goalsSection
                }
                .padding(Layout.pad(AppSpacing.screen, AppSpacing.xl))
                .frame(maxWidth: Layout.pad(540, 760))   // fills the iPad modal panel
                .frame(maxWidth: .infinity)
                .opacity(appeared ? 1 : 0)
                .onAppear(perform: animateIn)
            }
        }
        // iPhone keeps a draggable sheet; on iPad the adaptive modal panel sizes it.
        // Appearance-adaptive (light card + dark text in Light Mode); no forced dark.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Focus consistency (the SAME shared model as Passport — one rule,
    // one grid, identical day states everywhere) + the share action.

    @State private var shareItems: [Any]? = nil

    private var consistencyCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("YOUR FOCUS JOURNEY")
                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Button {
                    appModel.tapFeedback()
                    if let image = FocusGridShare.renderImage(history: appModel.history,
                                                              displayName: appModel.profile.name,
                                                              currentStreak: streak) {
                        shareItems = [image]
                    } else {
                        appModel.haptics.tap()
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.gold)
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityLabel("Share your focus grid")
            }
            FocusConsistencyGrid(history: appModel.history, weeks: 20, cellSize: 10, spacing: 2.5)
            Text("Every gold square is a day you truly focused. Keep the sky lit.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(AppSpacing.md)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(.white.opacity(0.10), lineWidth: 1))
        .sheet(isPresented: Binding(get: { shareItems != nil },
                                    set: { if !$0 { shareItems = nil } })) {
            if let shareItems { ActivityShareSheet(items: shareItems) }
        }
    }

    private func animateIn() {
        if reduceMotion {
            appeared = true
        } else {
            withAnimation(.easeOut(duration: 0.55)) { appeared = true }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }

    // MARK: Hero ember

    private var hero: some View {
        VStack(spacing: AppSpacing.sm) {
            ember
            Text("\(streak)")
                .font(.system(size: Layout.pad(CGFloat(66), CGFloat(88)),
                              weight: .heavy, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
            Text("day streak")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textSecondary)
            Text(message)
                .font(AppTypography.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.md)
            if best > 0 { bestPill }
        }
        .frame(maxWidth: .infinity)
    }

    private var ember: some View {
        let size = Layout.pad(CGFloat(184), CGFloat(224))
        let flameSize = Layout.pad(CGFloat(86), CGFloat(106))
        return ZStack {
            // A big, soft, diffused warm glow — no hard circular edge.
            Circle()
                .fill(RadialGradient(
                    colors: [Color(hex: 0xFFC24B).opacity(0.55),
                             Color(hex: 0xF2643C).opacity(0.22),
                             .clear],
                    center: .center, startRadius: 2, endRadius: size * 0.62))
                .frame(width: size * 1.35, height: size * 1.35)
                .blur(radius: 24)
                .scaleEffect(reduceMotion ? 1 : (breathe ? 1.08 : 0.94))
                .opacity(reduceMotion ? 0.9 : (breathe ? 1 : 0.7))
            streakHero(flameSize: flameSize)
                .scaleEffect(reduceMotion ? 1 : (breathe ? 1.04 : 0.99))
        }
        .frame(height: size)
    }

    /// The large `streakfire` hero if present, else the SF flame glyph.
    @ViewBuilder private func streakHero(flameSize: CGFloat) -> some View {
        #if canImport(UIKit)
        if let ui = UIImage(named: "streakfire") {
            Image(uiImage: ui).resizable().scaledToFit().frame(height: flameSize * 1.9)
        } else {
            flameGlyph(flameSize: flameSize)
        }
        #else
        flameGlyph(flameSize: flameSize)
        #endif
    }

    private func flameGlyph(flameSize: CGFloat) -> some View {
        Image(systemName: "flame.fill")
            .font(.system(size: flameSize, weight: .bold))
            .foregroundStyle(LinearGradient(
                colors: [Color(hex: 0xFFC24B), Color(hex: 0xF2643C)],
                startPoint: .top, endPoint: .bottom))
            .shadow(color: Color(hex: 0xF2643C).opacity(0.5), radius: 14, y: 4)
    }

    private var bestPill: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "flame.fill")
                .font(.system(size: 13, weight: .bold))
            Text("Best \(best) days")
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .foregroundStyle(AppColors.gold)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .background(Capsule().fill(AppColors.gold.opacity(0.12)))
        .overlay(Capsule().strokeBorder(AppColors.gold.opacity(0.5), lineWidth: 1))
        .padding(.top, AppSpacing.xxs)
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
        let days = weekDays()
        return GlassCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("THIS WEEK")
                    .font(.system(size: 12, weight: .bold, design: .rounded)).tracking(0.6)
                    .foregroundStyle(AppColors.textTertiary)
                weekStrip(days)
            }
        }
    }

    private func weekStrip(_ days: [Day]) -> some View {
        let disc = Layout.pad(CGFloat(36), CGFloat(44))
        return VStack(spacing: AppSpacing.xs) {
            HStack(spacing: 0) {
                ForEach(days, id: \.date) { day in
                    Text(day.label)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
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

    // MARK: Today status

    private var todayStatus: some View {
        let landed = todayLanded
        return GlassCard {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: landed ? "checkmark.seal.fill" : "flame")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(landed ? AppColors.success : AppColors.gold)
                Text(landed
                     ? "Landed today — your streak is safe"
                     : "Land a flight today to keep the streak alive")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
    }

    private var todayLanded: Bool {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return appModel.history.contains { $0.completed && cal.isDate($0.date, inSameDayAs: today) }
    }

    // MARK: Today's goals (kept minimal & premium)

    private var goalsSection: some View {
        let missions = appModel.dailyMissions
        return GlassCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Text("TODAY'S GOALS")
                        .font(.system(size: 12, weight: .bold, design: .rounded)).tracking(0.6)
                        .foregroundStyle(AppColors.textTertiary)
                    Spacer()
                    Text("\(missions.filter { $0.isComplete }.count)/\(missions.count)")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColors.gold)
                }
                ForEach(missions) { mission in
                    missionRow(mission)
                }
            }
        }
    }

    private func missionRow(_ mission: DailyMission) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: mission.isComplete ? "checkmark.circle.fill" : mission.systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(mission.isComplete ? AppColors.success : AppColors.textTertiary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(mission.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppColors.textPrimary.opacity(0.12))
                        Capsule().fill(mission.isComplete ? AppColors.success : AppColors.gold)
                            .frame(width: max(CGFloat(5), g.size.width * CGFloat(mission.fraction)))
                    }
                }
                .frame(height: 5)
            }
            Text(mission.progressText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textTertiary)
        }
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
        let landedDays = Set(appModel.history.filter { $0.completed }.map { cal.startOfDay(for: $0.date) })
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
