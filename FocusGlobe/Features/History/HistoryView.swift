import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    ScreenHeader(title: "History",
                                 subtitle: "Every journey you've taken")
                        .padding(.bottom, AppSpacing.xs)

                    if appModel.history.isEmpty {
                        emptyState
                    } else {
                        ForEach(appModel.history) { record in
                            HistoryRow(record: record)
                        }
                    }
                }
                .padding(AppSpacing.screen)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xxl)
            }
        }
        .focusScreenChrome()
        .onAppear { appModel.analytics.log(.historyOpened) }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            BalloonView(height: 92, showBurner: true, showGlow: true)
                .padding(.bottom, AppSpacing.xs)
            Text("No journeys yet")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)
            Text("Take off on your first route and it will appear here.")
                .font(AppTypography.subhead)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxl)
    }
}

private struct HistoryRow: View {
    let record: FocusSessionRecord

    var body: some View {
        AppGlassCard(padding: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(alignment: .top) {
                    moodBadge
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.routeName)
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)
                        Text("\(record.originName) → \(record.destinationName)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    statusBadge
                }

                HStack(spacing: AppSpacing.md) {
                    metric(systemImage: "clock", text: "\(record.focusedMinutes) min")
                    metric(systemImage: "ruler", text: Formatters.distance(km: record.distanceKm))
                    if record.completed {
                        metric(systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                               text: Formatters.miles(record.focusMiles))
                    }
                    Spacer()
                    Text(Formatters.dateTime(record.date))
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.textTertiary)
                }

                if let intention = record.intention, !intention.isEmpty {
                    Text("“\(intention)”")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                        .padding(.top, 1)
                }
            }
        }
    }

    private var moodBadge: some View {
        Image(systemName: record.mood.systemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(record.theme.accent)
            .frame(width: 34, height: 34)
            .background(Circle().fill(record.theme.accent.opacity(0.14)))
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: record.completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 10, weight: .bold))
            Text(record.completed ? "Landed" : "Cancelled")
                .font(AppTypography.micro)
        }
        .foregroundStyle(record.completed ? AppColors.success : AppColors.textTertiary)
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, 4)
        .background(Capsule().fill((record.completed ? AppColors.success : AppColors.textTertiary).opacity(0.14)))
    }

    private func metric(systemImage: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage).font(.system(size: 11, weight: .semibold))
            Text(text).font(AppTypography.caption)
        }
        .foregroundStyle(AppColors.textSecondary)
    }
}
