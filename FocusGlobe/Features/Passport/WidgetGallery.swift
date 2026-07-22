import SwiftUI

/// One entry in the in-app Widgets gallery. These are *previews* that mirror the
/// real Home Screen widgets (the widget views live in the extension target and
/// can't be imported into the app), plus guidance on how to add them — iOS does
/// not allow an app to install a widget programmatically, so we show the native
/// Add-Widget flow instead of faking it.
struct WidgetGalleryItem: Identifiable {
    let id: String            // widget `kind`
    let name: String
    let blurb: String
    let systemImage: String
    let glow: Color
    let families: [String]    // e.g. ["Small", "Medium", "Large"]
    let isPro: Bool

    /// The FIVE final FocusGlobe widgets — two Free, three PRO. Kept in lock-step
    /// with the widget extension so the gallery always mirrors what a pilot can
    /// actually add.
    static let all: [WidgetGalleryItem] = [
        // FREE
        .init(id: "FGStreakCompanion", name: "Streak Companion",
              blurb: "An expressive balloon, your streak flame and today's state — nothing yet, focused, at risk or a milestone.",
              systemImage: "flame.fill", glow: WGTheme.coral,
              families: ["Small", "Lock Screen"], isPro: false),
        .init(id: "FGFocusNow", name: "Focus Now",
              blurb: "Start a flight in a tap when idle, or watch the live time remaining on the flight you're on.",
              systemImage: "paperplane.fill", glow: WGTheme.gold,
              families: ["Medium"], isPro: false),
        // PRO
        .init(id: "FGFocusGrid", name: "Focus Grid",
              blurb: "Your last six months of real focus days as a living contribution grid — tap to open your Passport.",
              systemImage: "square.grid.3x3.fill", glow: WGTheme.teal,
              families: ["Medium", "Large"], isPro: true),
        .init(id: "FGPassportStats", name: "Passport Stats",
              blurb: "Journeys, focused time, your longest journey and your current + longest streak.",
              systemImage: "book.closed.fill", glow: WGTheme.indigo,
              families: ["Small", "Medium", "Large"], isPro: true),
        .init(id: "FGBadgeCollection", name: "Badge Collection",
              blurb: "Your unlocked badges, a hint at the next one to earn, and how many you've collected.",
              systemImage: "rosette", glow: WGTheme.gold,
              families: ["Small", "Medium"], isPro: true),
    ]
}

/// Widget-preview palette (mirrors the extension's `WTheme` so previews look like
/// the real, always-dark widgets — independent of the app's Light/Dark mode).
enum WGTheme {
    static let bgTop    = Color(red: 0.11, green: 0.14, blue: 0.20)
    static let bgBottom = Color(red: 0.05, green: 0.07, blue: 0.10)
    static let ink      = Color.white
    static let inkSoft  = Color.white.opacity(0.62)
    static let gold     = Color(red: 0.95, green: 0.78, blue: 0.47)
    static let indigo   = Color(red: 0.40, green: 0.45, blue: 0.96)
    static let teal     = Color(red: 0.20, green: 0.78, blue: 0.62)
    static let coral    = Color(red: 0.96, green: 0.47, blue: 0.36)
    static let sky      = Color(red: 0.36, green: 0.56, blue: 0.95)
}

// MARK: - Passport section

struct WidgetsGallerySection: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @State private var selected: WidgetGalleryItem?

    /// A PRO widget the pilot hasn't unlocked yet.
    private func locked(_ item: WidgetGalleryItem) -> Bool { item.isPro && !appModel.isPro }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                SectionLabel(text: "Widgets")
                Text("Five widgets for your Home & Lock Screen")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(WidgetGalleryItem.all) { item in
                        Button { appModel.tapFeedback(); selected = item } label: {
                            WidgetPreviewTile(item: item, locked: locked(item), side: Layout.pad(150, 178))
                        }
                        .buttonStyle(SoftPressStyle(scale: 0.98))
                        // The name is no longer drawn on the tile, so carry the full
                        // identity + lock state as the VoiceOver label.
                        .accessibilityLabel(
                            "\(item.name)\(item.isPro ? ", FocusGlobe PRO" : ", free")\(locked(item) ? ", locked" : "")")
                        .accessibilityHint("Opens preview and how to add")
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .sheet(item: $selected) { item in
            WidgetDetailSheet(item: item, locked: locked(item))
                .environmentObject(appModel)
                .environmentObject(router)
        }
    }
}

/// A dark, premium tile that reads as a real FocusGlobe widget.
private struct WidgetPreviewTile: View {
    let item: WidgetGalleryItem
    var locked: Bool = false
    var side: CGFloat = 156

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            WidgetPreviewCanvas(glow: item.glow)
            // Signature glyph, top-trailing.
            Image(systemName: item.systemImage)
                .font(.system(size: side * 0.26, weight: .bold))
                .foregroundStyle(item.glow)
                .shadow(color: item.glow.opacity(0.6), radius: 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(side * 0.12)

            // Image-only preview: the card + signature glyph read as the widget
            // itself. Only the PRO/lock affordance remains (no name, no size
            // labels) — the identity + families live in the detail sheet.
            HStack(spacing: 5) {
                Text(item.isPro ? "PRO" : "FREE")
                    .font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(0.6)
                    .foregroundStyle(item.isPro ? WGTheme.gold : WGTheme.inkSoft)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill((item.isPro ? WGTheme.gold : Color.white).opacity(0.18)))
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(WGTheme.gold)
                }
            }
            .padding(side * 0.11)
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: side * 0.16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: side * 0.16, style: .continuous)
            .strokeBorder(.white.opacity(0.10), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
    }
}

/// The dark "space" widget background + starfield + signature glow.
private struct WidgetPreviewCanvas: View {
    let glow: Color
    var body: some View {
        ZStack {
            LinearGradient(colors: [WGTheme.bgTop, WGTheme.bgBottom],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [glow.opacity(0.5), .clear],
                           center: .topTrailing, startRadius: 2, endRadius: 150)
            // A few stars.
            GeometryReader { g in
                ForEach(0..<10, id: \.self) { i in
                    Circle().fill(.white.opacity(0.5))
                        .frame(width: 1.6, height: 1.6)
                        .position(x: g.size.width * WidgetPreviewCanvas.star(i).x,
                                  y: g.size.height * WidgetPreviewCanvas.star(i).y)
                }
            }
        }
    }
    // Deterministic star field (no Math.random).
    static func star(_ i: Int) -> (x: CGFloat, y: CGFloat) {
        let xs: [CGFloat] = [0.12, 0.31, 0.52, 0.73, 0.88, 0.20, 0.44, 0.64, 0.80, 0.37]
        let ys: [CGFloat] = [0.18, 0.42, 0.24, 0.55, 0.33, 0.70, 0.82, 0.68, 0.50, 0.90]
        return (xs[i % xs.count], ys[i % ys.count])
    }
}

// MARK: - Detail / how-to-add sheet

private struct WidgetDetailSheet: View {
    let item: WidgetGalleryItem
    var locked: Bool = false
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    private let steps: [(String, String)] = [
        ("hand.tap.fill", "Touch and hold an empty area of your Home Screen until the apps jiggle."),
        ("plus.circle.fill", "Tap the + (Add Widget) button in the top corner."),
        ("magnifyingglass", "Search for “FocusGlobe”."),
        ("square.grid.2x2.fill", "Choose a size, then tap Add Widget."),
        ("checkmark.circle.fill", "Tap Done — your widget is on the Home Screen."),
    ]

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    closeRow
                    WidgetPreviewTile(item: item, locked: locked, side: 210)
                        .padding(.top, AppSpacing.xs)
                    VStack(spacing: 6) {
                        Text(item.name)
                            .font(AppTypography.title2).foregroundStyle(AppColors.textPrimary)
                        Text(item.blurb)
                            .font(AppTypography.callout).foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.md)
                        HStack(spacing: 6) {
                            Text(item.isPro ? "FocusGlobe PRO" : "Free")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(item.isPro ? AppColors.gold : AppColors.success)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Capsule().fill((item.isPro ? AppColors.gold : AppColors.success).opacity(0.14)))
                            ForEach(item.families, id: \.self) { fam in
                                Text(fam)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppColors.textSecondary)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Capsule().fill(AppColors.textPrimary.opacity(0.06)))
                                    .overlay(Capsule().strokeBorder(AppColors.hairline, lineWidth: 1))
                            }
                        }
                        .padding(.top, 2)
                    }

                    // A locked PRO widget leads with the contextual Widgets
                    // paywall instead of the add-instructions.
                    if locked {
                        AppPrimaryButton(title: "Unlock Widgets with FocusGlobe PRO", systemImage: "crown.fill") {
                            appModel.tapFeedback()
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                router.presentPaywall(context: .widget)
                            }
                        }
                        .padding(.horizontal, AppSpacing.xs)
                    }

                    AppGlassCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text("How to add this widget")
                                .font(AppTypography.headline).foregroundStyle(AppColors.textPrimary)
                            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                                HStack(alignment: .top, spacing: AppSpacing.sm) {
                                    ZStack {
                                        Circle().fill(AppColors.brand.opacity(0.14)).frame(width: 30, height: 30)
                                        Text("\(idx + 1)")
                                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                                            .foregroundStyle(AppColors.brand)
                                    }
                                    Text(step.1)
                                        .font(AppTypography.callout)
                                        .foregroundStyle(AppColors.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            Text("iOS doesn't let apps add widgets automatically — this is Apple's standard way to add any widget.")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }
                }
                .padding(AppSpacing.screen)
                .padding(.bottom, AppSpacing.xxl)
                .frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var closeRow: some View {
        HStack {
            Spacer()
            Button { appModel.tapFeedback(); dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(width: 34, height: 34)
                    .glassBackground(cornerRadius: 17, tintOpacity: 0.2, shadowRadius: 6, shadowY: 3)
            }
        }
    }
}
