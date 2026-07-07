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

    static let all: [WidgetGalleryItem] = [
        .init(id: "FGStreak", name: "Streak",
              blurb: "Keep your focus streak alive at a glance — right on your Home or Lock Screen.",
              systemImage: "flame.fill", glow: WGTheme.coral,
              families: ["Small", "Medium", "Lock Screen"], isPro: false),
        .init(id: "FGStartJourney", name: "Start Focus",
              blurb: "Set off from your city and begin a focused expedition in one tap.",
              systemImage: "paperplane.fill", glow: WGTheme.gold,
              families: ["Small", "Medium", "Large"], isPro: false),
        .init(id: "FGCurrentJourney", name: "Current Flight",
              blurb: "Resume an unfinished expedition, shown on a live map.",
              systemImage: "location.north.line.fill", glow: WGTheme.sky,
              families: ["Small", "Medium", "Large"], isPro: true),
        .init(id: "FGAroundEarth", name: "Around Earth",
              blurb: "See how far you've travelled around the planet.",
              systemImage: "globe.europe.africa.fill", glow: WGTheme.teal,
              families: ["Small", "Medium", "Large"], isPro: true),
        .init(id: "FGLongestRoute", name: "Longest Route",
              blurb: "Your longest completed expedition.",
              systemImage: "ruler.fill", glow: WGTheme.gold,
              families: ["Medium", "Large"], isPro: true),
        .init(id: "FGDailyGoals", name: "Daily Goals",
              blurb: "Today's focus goals and your progress toward them.",
              systemImage: "target", glow: WGTheme.indigo,
              families: ["Small", "Medium", "Large"], isPro: true),
        .init(id: "FGPassport", name: "Passport",
              blurb: "Your collection, miles and focus stats at a glance.",
              systemImage: "book.closed.fill", glow: WGTheme.indigo,
              families: ["Small", "Medium", "Large"], isPro: true),
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
    @State private var selected: WidgetGalleryItem?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                SectionLabel(text: "Widgets")
                Text("Add FocusGlobe to your Home & Lock Screen")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(WidgetGalleryItem.all) { item in
                        Button { appModel.tapFeedback(); selected = item } label: {
                            WidgetPreviewTile(item: item, side: Layout.pad(150, 178))
                        }
                        .buttonStyle(SoftPressStyle(scale: 0.98))
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .sheet(item: $selected) { item in
            WidgetDetailSheet(item: item).environmentObject(appModel)
        }
    }
}

/// A dark, premium tile that reads as a real FocusGlobe widget.
private struct WidgetPreviewTile: View {
    let item: WidgetGalleryItem
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

            VStack(alignment: .leading, spacing: 3) {
                if item.isPro {
                    Text("PRO")
                        .font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(0.6)
                        .foregroundStyle(WGTheme.gold)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(WGTheme.gold.opacity(0.18)))
                }
                Text(item.name)
                    .font(.system(size: side * 0.10, weight: .bold, design: .rounded))
                    .foregroundStyle(WGTheme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
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
    @EnvironmentObject private var appModel: AppModel
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
                    WidgetPreviewTile(item: item, side: 210)
                        .padding(.top, AppSpacing.xs)
                    VStack(spacing: 6) {
                        Text(item.name)
                            .font(AppTypography.title2).foregroundStyle(AppColors.textPrimary)
                        Text(item.blurb)
                            .font(AppTypography.callout).foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.md)
                        HStack(spacing: 6) {
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
