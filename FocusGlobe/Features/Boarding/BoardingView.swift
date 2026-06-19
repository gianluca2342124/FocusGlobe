import SwiftUI

struct BoardingView: View {
    let route: Route

    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @State private var intention: String = ""
    @FocusState private var intentionFocused: Bool

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    ScreenHeader(title: "Prepare journey")

                    JourneyPassCard(route: route)

                    intentionField

                    Text("Your journey ends when your focus session is complete.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    VStack(spacing: AppSpacing.sm) {
                        AppPrimaryButton(title: "Take Off", systemImage: "paperplane.fill") {
                            takeOff()
                        }
                        AppSecondaryButton(title: "Change Route", systemImage: "arrow.left") {
                            dismiss()
                        }
                    }
                }
                .padding(AppSpacing.screen)
                .padding(.top, AppSpacing.xs)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .focusScreenChrome()
        .onAppear { appModel.analytics.log(.journeyPassViewed, ["route": route.id]) }
        .contentShape(Rectangle())
        .onTapGesture { intentionFocused = false }
    }

    private var intentionField: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "target")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(route.colorTheme.accent)
            TextField("What are you focusing on?", text: $intention)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)
                .focused($intentionFocused)
                .submitLabel(.done)
                .onSubmit { intentionFocused = false }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.md - 2)
        .glassBackground(cornerRadius: 18, tintOpacity: 0.25, shadowRadius: 8, shadowY: 4)
    }

    private func takeOff() {
        appModel.haptics.tap()
        intentionFocused = false
        router.startJourney(route: route, intention: intention)
    }
}

// MARK: - Journey Pass

private struct JourneyPassCard: View {
    let route: Route
    private let stubHeight: CGFloat = 176

    var body: some View {
        VStack(spacing: 0) {
            stub
            details
        }
        .background {
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous)
                        .fill(AppColors.glassTint.opacity(0.4))
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius, style: .continuous))
        .overlay(alignment: .top) {
            DashLine()
                .stroke(AppColors.textTertiary.opacity(0.5),
                        style: StrokeStyle(lineWidth: 1.2, dash: [4, 5]))
                .frame(height: 1)
                .padding(.horizontal, AppSpacing.md)
                .offset(y: stubHeight)
        }
        .compositingGroup()
        .overlay(alignment: .topLeading) { notch.offset(x: -9, y: stubHeight - 9) }
        .overlay(alignment: .topTrailing) { notch.offset(x: 9, y: stubHeight - 9) }
        .compositingGroup()
        .shadow(color: AppColors.shadow, radius: 18, x: 0, y: 10)
    }

    private var notch: some View {
        Circle()
            .frame(width: 18, height: 18)
            .blendMode(.destinationOut)
    }

    private var stub: some View {
        ZStack {
            route.mood.gradient
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Text("FocusGlobe · Journey Pass")
                        .font(AppTypography.micro)
                        .tracking(0.6)
                        .foregroundStyle(route.mood.preferredForeground.opacity(0.85))
                    Spacer()
                    AppTagChip(title: route.category.displayName,
                               systemImage: route.category.systemImage,
                               foreground: route.mood.preferredForeground)
                }

                Spacer()

                HStack(alignment: .center) {
                    endpoint(code: code(route.originName), name: route.originName)
                    Spacer()
                    VStack(spacing: 2) {
                        BalloonMark(size: 30, glow: route.colorTheme.soft,
                                    showGlow: false, showBurner: true)
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(route.mood.preferredForeground.opacity(0.7))
                    }
                    Spacer()
                    endpoint(code: code(route.destinationName), name: route.destinationName, alignment: .trailing)
                }

                Text(route.name)
                    .font(AppTypography.headline)
                    .foregroundStyle(route.mood.preferredForeground)
            }
            .padding(AppSpacing.md)
        }
        .frame(height: stubHeight)
    }

    private var details: some View {
        let columns = [GridItem(.flexible(), spacing: AppSpacing.sm),
                       GridItem(.flexible(), spacing: AppSpacing.sm)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: AppSpacing.md) {
            PassDetail(label: "Duration", value: route.durationLabel, systemImage: "clock")
            PassDetail(label: "Distance", value: route.distanceLabel, systemImage: "ruler")
            PassDetail(label: "Mood", value: route.mood.displayName, systemImage: route.mood.systemImage)
            PassDetail(label: "Vehicle", value: Vehicle.default.name, systemImage: "balloon")
            PassDetail(label: "Reward", value: route.rewardName, systemImage: "gift")
            PassDetail(label: "Theme", value: route.colorTheme.rawValue.capitalized,
                       systemImage: "paintpalette", accent: route.colorTheme.accent)
        }
        .padding(AppSpacing.md)
        .padding(.top, AppSpacing.xs)
    }

    private func endpoint(code: String, name: String, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(code)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(route.mood.preferredForeground)
            Text(name)
                .font(AppTypography.caption)
                .foregroundStyle(route.mood.preferredForeground.opacity(0.85))
                .lineLimit(1)
        }
    }

    private func code(_ name: String) -> String {
        let letters = name.uppercased().filter { $0.isLetter }
        return String(letters.prefix(3))
    }
}

private struct PassDetail: View {
    let label: String
    let value: String
    let systemImage: String
    var accent: Color = AppColors.brand

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased())
                    .font(AppTypography.micro)
                    .tracking(0.5)
                    .foregroundStyle(AppColors.textTertiary)
                Text(value)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
            }
        }
    }
}

private struct DashLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
