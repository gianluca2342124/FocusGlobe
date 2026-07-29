import SwiftUI
import WidgetKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Focus Now (FREE · medium)

/// A state-aware focus launcher. IDLE: the selected Sky + a Start Focus CTA that
/// deep-links into the setup flow. ACTIVE: the current Sky + a live remaining
/// time (native timer) + category, deep-linking back into the flight. INFINITE
/// flights show ∞.
struct FocusNowWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FGFocusNow", provider: FGProvider()) { entry in
            FocusNowView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Color.black }
                .widgetURL(FGLink.url(FocusNowView.link(entry.snapshot)))
        }
        .configurationDisplayName("Focus Now")
        .description("Start a focus flight, or watch the one you're on.")
        .supportedFamilies([.systemMedium, .systemSmall])
        .contentMarginsDisabled()
    }
}

struct FocusNowView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    /// Deep link: an active flight returns to it; otherwise the setup flow.
    static func link(_ s: WidgetSnapshot) -> String {
        if s.activeFlight { return "flight" }
        if s.hasResumable { return "resume" }
        return "start"
    }

    /// The pilot's chosen Sky, as its own colours.
    ///
    /// The snapshot carries one palette (`skyTopHex`/`skyBottomHex`, written from
    /// the selected Sky's `moodPalette`) — there is deliberately no separate
    /// active-flight palette, so this reads it directly. The previous
    /// `activeFlight ? skyTopHex : skyTopHex` picked the same value on both
    /// branches: it looked like an in-flight variant existed when none does.
    private var skyGradient: LinearGradient {
        let top = s(snapshot.skyTopHex, 0x181721)
        let bottom = s(snapshot.skyBottomHex, 0x100F16)
        return LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    private func s(_ hex: Int, _ fallback: Int) -> Color { WColor.hex(hex == 0 ? fallback : hex) }

    var body: some View {
        ZStack {
            skyArtwork
            LinearGradient(colors: [.black.opacity(0.20), .black.opacity(0.08), .black.opacity(0.72)],
                           startPoint: .top, endPoint: .bottom)
            content
        }
    }

    @ViewBuilder private var skyArtwork: some View {
        #if canImport(UIKit)
        let name = snapshot.activeFlight
            ? (snapshot.activeSkyArtworkName ?? snapshot.selectedSkyArtworkName)
            : snapshot.selectedSkyArtworkName
        if let name, let image = UIImage(named: name) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            skyGradient
        }
        #else
        skyGradient
        #endif
    }

    @ViewBuilder private var content: some View {
        if snapshot.activeFlight {
            activeContent
        } else {
            idleContent
        }
    }

    // ACTIVE: sky name + live remaining + category.
    private var activeContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            WHeader(icon: "dot.radiowaves.left.and.right", title: "In flight", tint: WTheme.teal)
            Spacer(minLength: 0)
            if snapshot.activeInfinite || snapshot.activeEndDate == nil {
                Text("∞")
                    .font(.system(size: 46, weight: .black, design: .default))
                    .foregroundStyle(WTheme.ink)
            } else if let end = snapshot.activeEndDate {
                Text(timerInterval: Date()...max(Date(), end), countsDown: true)
                    .font(.system(size: 40, weight: .black, design: .default))
                    .foregroundStyle(WTheme.ink)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6).lineLimit(1)
            }
            HStack(spacing: 6) {
                Text(snapshot.activeSkyName ?? snapshot.selectedSkyName ?? "Focus")
                    .font(.system(size: 12.5, weight: .bold, design: .default))
                    .foregroundStyle(WTheme.ink)
                if let cat = snapshot.activeCategory {
                    Text("· \(cat)")
                        .font(.system(size: 12, weight: .semibold, design: .default))
                        .foregroundStyle(WTheme.inkSoft)
                }
                Spacer(minLength: 0)
            }
            .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(15)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // IDLE: sky name + a Start Focus (or Resume) CTA.
    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(snapshot.selectedSkyName ?? "Ready to focus")
                    .font(.system(size: 15, weight: .heavy, design: .default))
                    .foregroundStyle(WTheme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(WTheme.teal)
            }
            Spacer(minLength: 0)
            HStack(spacing: 7) {
                Image(systemName: snapshot.hasResumable ? "arrow.uturn.up" : "arrow.up")
                    .font(.system(size: 13, weight: .heavy))
                Text(snapshot.hasResumable ? "Resume flight" : "Start Focus")
                    .font(.system(size: 14, weight: .heavy, design: .default))
            }
            .foregroundStyle(Color(red: 0.08, green: 0.07, blue: 0.05))
            .padding(.horizontal, 14).padding(.vertical, 9)
            .frame(maxWidth: family == .systemSmall ? .infinity : nil)
            .background(Capsule().fill(WTheme.gold))
        }
        .padding(15)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Minimal hex → Color for the widget target (no app design system available).
enum WColor {
    static func hex(_ hex: Int) -> Color {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
