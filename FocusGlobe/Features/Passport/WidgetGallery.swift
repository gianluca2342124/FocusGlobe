import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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

    /// The four final FocusGlobe widgets — two Free, two PRO. Kept in lock-step
    /// with the widget extension so the gallery always mirrors what a pilot can
    /// actually add.
    static let all: [WidgetGalleryItem] = [
        // FREE
        .init(id: "FGStreakCompanion", name: "Streak Companion",
              blurb: "The FocusGlobe fire balloon carrying your live streak count.",
              systemImage: "flame.fill", glow: WGTheme.coral,
              families: ["Small", "Lock Screen"], isPro: false),
        .init(id: "FGFocusNow", name: "Focus Now",
              blurb: "Start a flight in a tap when idle, or watch the live time remaining on the flight you're on.",
              systemImage: "paperplane.fill", glow: WGTheme.teal,
              families: ["Small", "Medium"], isPro: false),
        // PRO
        .init(id: "FGFocusGrid", name: "Focus Grid",
              blurb: "Your last six months of real focus days as a living contribution grid — tap to open your Passport.",
              systemImage: "square.grid.3x3.fill", glow: WGTheme.teal,
              families: ["Medium", "Large"], isPro: true),
        .init(id: "FGPassportStats", name: "Passport Dashboard",
              blurb: "Journeys, focused time, current + longest streak, your longest session — plus a few unlocked badges.",
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
    static let teal     = Color(red: 88 / 255, green: 214 / 255, blue: 194 / 255)
    static let coral    = Color(red: 0.96, green: 0.47, blue: 0.36)
    static let sky      = Color(red: 0.36, green: 0.56, blue: 0.95)
}

// MARK: - Passport section

struct WidgetsGallerySection: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @State private var selected: WidgetGalleryItem?

    /// A PRO widget the pilot hasn't unlocked yet.
    private func locked(_ item: WidgetGalleryItem) -> Bool {
        item.isPro && appModel.entitlement == .free
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                SectionLabel(text: "Widgets")
                Text("Four widgets for your Home & Lock Screen")
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
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            preview

            // Image-only preview: the card + signature glyph read as the widget
            // itself. ONLY the PRO/lock affordance remains — a free widget carries
            // no "FREE" badge at all (it just appears available). The identity +
            // families live in the detail sheet.
            //
            // The PRO plaque marks a *purchase*: it is shown only while the pilot
            // has not unlocked it (`locked`). An entitled owner sees the widget as
            // plainly available — matching the Store, where an owned premium item
            // reads "Owned", never a PRO badge — and the row collapses with no
            // retained badge width. VoiceOver still carries the PRO identity above.
            HStack(spacing: 5) {
                if locked {
                    FocusGlobePROBadge(visibleHeight: 13)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.9))
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

    @ViewBuilder
    private var preview: some View {
        switch item.id {
        case "FGStreakCompanion":
            streakPreview
        case "FGFocusNow":
            focusNowPreview
        case "FGFocusGrid":
            focusGridPreview
        default:
            passportPreview
        }
    }

    /// Mirrors the real Streak Companion exactly: flame artwork, the number as the
    /// only text, seated in the bright heart of the flame above centre.
    private var streakPreview: some View {
        ZStack {
            if let image = UIImage(named: "WidgetFireBalloon") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                WGTheme.bgBottom
            }
            RadialGradient(colors: [.black.opacity(0.42), .clear],
                           center: UnitPoint(x: 0.5, y: 0.44),
                           startRadius: 2, endRadius: side * 0.44)
                .blendMode(.multiply)
            Text("\(appModel.progress.currentStreak)")
                .font(.system(size: side * 0.36, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.85), radius: 6, y: 2)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .padding(.horizontal, side * 0.12)
                .frame(width: side, height: side)
                .offset(y: -side * 0.06)
        }
    }

    /// Mirrors the real `.systemSmall` Focus Now layout: state eyebrow and Sky
    /// name at the top, the Sky breathing through the middle, a centred action
    /// pill at 74 % of the content width at the bottom, and the same two-ended
    /// legibility scrim. Kept in lock-step with `FocusNowView.smallLayout` — if
    /// the widget changes, this changes with it, or the gallery starts
    /// advertising a widget that no longer exists.
    ///
    /// Nothing here is `.fixedSize()`, for the same reason it is gone from the
    /// widget: a fixed-size child that does not fit makes its ancestors wider
    /// than the tile, and the clip then removes characters from BOTH ends.
    private var focusNowPreview: some View {
        let resumable = appModel.hasResumableJourney
        // The tile's own content width, matching the widget's inset. Derived
        // from `side`, so the mirror scales with the tile the gallery draws.
        let contentWidth = side * (1 - 0.093 * 2)
        return ZStack {
            SkyStillPreview(sky: appModel.selectedSky)
            LinearGradient(stops: [
                .init(color: .black.opacity(0.55), location: 0.00),
                .init(color: .black.opacity(0.14), location: 0.34),
                .init(color: .black.opacity(0.30), location: 0.62),
                .init(color: .black.opacity(0.80), location: 1.00),
            ], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: side * 0.045) {
                VStack(alignment: .leading, spacing: side * 0.006) {
                    Text("FOCUS NOW")
                        .font(.system(size: max(8, side * 0.065), weight: .heavy))
                        .tracking(1.0)
                        .foregroundStyle(WGTheme.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(appModel.selectedSky.name)
                        .font(.system(size: side * 0.092, weight: .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: side * 0.02)
                // 74 % of the content width, centred — the same measurement the
                // widget makes from its own row.
                Label(resumable ? "Resume" : "Start Focus",
                      systemImage: resumable ? "arrow.uturn.up" : "arrow.up")
                    .font(.system(size: side * 0.072, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(Color(red: 0.08, green: 0.07, blue: 0.05))
                    .padding(.vertical, side * 0.038)
                    .frame(width: contentWidth * 0.74)
                    .background(Capsule().fill(WGTheme.gold))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .foregroundStyle(.white)
            // Padding BEFORE frame, matching the real widget — the other order
            // grows to the container and then adds insets outside it.
            .padding(side * 0.093)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        // The Sky preview fills, so it can render WIDER than the tile; without
        // this the ZStack grew with it and the leading text was pushed outside
        // the visible square ("US NOW", "sert Night").
        .frame(width: side, height: side)
        .clipped()
    }

    private var focusGridPreview: some View {
        let calendar = Calendar.current
        let active = FocusConsistency.activeDays(history: appModel.history, calendar: calendar)
        let today = calendar.startOfDay(for: Date())
        let ordinals = Set(active.keys.map {
            Int((calendar.startOfDay(for: $0).timeIntervalSince1970 / 86_400).rounded())
        })
        let todayOrdinal = Int((today.timeIntervalSince1970 / 86_400).rounded())
        return VStack(alignment: .leading, spacing: side * 0.055) {
            HStack {
                Label("FOCUS GRID", systemImage: "square.grid.3x3.fill")
                    .font(.system(size: side * 0.06, weight: .heavy))
                    .foregroundStyle(WGTheme.inkSoft)
                Spacer()
                Label("\(appModel.progress.currentStreak)", systemImage: "flame.fill")
                    .font(.system(size: side * 0.065, weight: .heavy))
                    .foregroundStyle(WGTheme.gold)
            }
            GeometryReader { geo in
                let columns = 12
                let spacing: CGFloat = 2
                let cell = (geo.size.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)
                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { column in
                        VStack(spacing: spacing) {
                            ForEach(0..<7, id: \.self) { row in
                                let day = todayOrdinal - ((columns - 1 - column) * 7 + (6 - row))
                                RoundedRectangle(cornerRadius: 1.8, style: .continuous)
                                    .fill(ordinals.contains(day)
                                          ? (day == todayOrdinal ? WGTheme.gold : WGTheme.teal.opacity(0.74))
                                          : Color.white.opacity(0.075))
                                    .frame(width: cell, height: cell)
                            }
                        }
                    }
                }
            }
            Text("\(active.count) focus days")
                .font(.system(size: side * 0.06, weight: .bold))
                .foregroundStyle(WGTheme.inkSoft)
        }
        .padding(side * 0.09)
        .background(Color(red: 0.055, green: 0.058, blue: 0.066))
    }

    private var passportPreview: some View {
        VStack(alignment: .leading, spacing: side * 0.06) {
            Label("PASSPORT", systemImage: "book.closed.fill")
                .font(.system(size: side * 0.065, weight: .heavy))
                .foregroundStyle(WGTheme.gold)
            Spacer(minLength: 0)
            HStack {
                previewStat("\(appModel.progress.landings)", "JOURNEYS", WGTheme.ink)
                previewStat("\(appModel.lifetimeFocusMinutes)m", "FOCUSED", WGTheme.teal)
            }
            HStack {
                previewStat("\(appModel.progress.currentStreak)", "STREAK", WGTheme.coral)
                previewStat("\(appModel.progress.bestFocusMinutes)m", "LONGEST", WGTheme.gold)
            }
        }
        .padding(side * 0.10)
        .background(LinearGradient(colors: [WGTheme.bgTop, WGTheme.bgBottom],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private func previewStat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: side * 0.13, weight: .heavy))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: side * 0.047, weight: .bold))
                .foregroundStyle(WGTheme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Focus Now · medium preview

/// The square tile mirrors the `.systemSmall` Focus Now widget. Focus Now also
/// ships `.systemMedium`, and that is the layout the gallery was silently not
/// showing, so the detail sheet renders it at the real medium aspect ratio
/// (329 × 155 on a standard iPhone ≈ 2.12 : 1).
///
/// Deliberately scoped to Focus Now: no other widget's preview changes.
private struct FocusNowMediumPreview: View {
    @EnvironmentObject private var appModel: AppModel
    /// A ceiling, not a fixed size — the tile shrinks on a narrow screen rather
    /// than overflowing the sheet.
    var maximumWidth: CGFloat = 320

    var body: some View {
        let resumable = appModel.hasResumableJourney
        ZStack {
            SkyStillPreview(sky: appModel.selectedSky)
            LinearGradient(stops: [
                .init(color: .black.opacity(0.55), location: 0.00),
                .init(color: .black.opacity(0.14), location: 0.34),
                .init(color: .black.opacity(0.30), location: 0.62),
                .init(color: .black.opacity(0.80), location: 1.00),
            ], startPoint: .top, endPoint: .bottom)
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("FOCUS NOW")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.0)
                        .foregroundStyle(WGTheme.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(appModel.selectedSky.name)
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(resumable ? "Your flight is ready to continue."
                                   : "A quiet flight is one tap away.")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(WGTheme.inkSoft)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Label(resumable ? "Resume" : "Start Focus",
                      systemImage: resumable ? "arrow.uturn.up" : "arrow.up")
                    .font(.system(size: 13, weight: .heavy))
                    .lineLimit(1)
                    .foregroundStyle(Color(red: 0.08, green: 0.07, blue: 0.05))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(WGTheme.gold))
                    .fixedSize()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(16)
        }
        .aspectRatio(2.12, contentMode: .fit)
        .frame(maxWidth: maximumWidth)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(.white.opacity(0.10), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focus Now, medium size preview")
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
                    if item.id == "FGFocusNow" {
                        FocusNowMediumPreview()
                            .environmentObject(appModel)
                    }
                    VStack(spacing: 6) {
                        Text(item.name)
                            .font(AppTypography.title2).foregroundStyle(AppColors.textPrimary)
                        Text(item.blurb)
                            .font(AppTypography.callout).foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.md)
                        HStack(spacing: 6) {
                            // PRO widgets wear the real multicolor PRO badge; free
                            // widgets carry NO tier chip (no "Free" label at all).
                            if item.isPro {
                                FocusGlobePROBadge(visibleHeight: 14)
                            }
                            ForEach(item.families, id: \.self) { fam in
                                Text(fam)
                                    .font(.system(size: 11, weight: .semibold, design: .default))
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
                        AppPrimaryButton(title: "Unlock Widgets with FocusGlobe PRO", systemImage: "sparkles") {
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
                                            .font(.system(size: 14, weight: .heavy, design: .default))
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
            // The shared utility control — same liquid-glass substrate, press
            // behaviour and hit target as every other close/back button.
            AppIconButton(systemImage: "xmark", size: 38,
                          accessibilityLabel: "Close") {
                appModel.tapFeedback(); dismiss()
            }
        }
    }
}
