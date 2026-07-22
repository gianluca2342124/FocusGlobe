import SwiftUI
import WidgetKit

// MARK: - Focus Now (FREE · medium)

/// A state-aware focus launcher. IDLE: the selected Sky + a Start Focus CTA that
/// deep-links into the setup flow. ACTIVE: the current Sky + a live remaining
/// time (native timer) + category, deep-linking back into the flight. INFINITE
/// flights show ∞.
struct FocusNowWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FGFocusNow", provider: FGProvider()) { entry in
            FocusNowView(snapshot: entry.snapshot)
                .fgWidgetBackground(glow: WTheme.gold)
                .widgetURL(FGLink.url(FocusNowView.link(entry.snapshot)))
        }
        .configurationDisplayName("Focus Now")
        .description("Start a focus flight, or watch the one you're on.")
        .supportedFamilies([.systemMedium, .systemSmall])
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

    private var skyGradient: LinearGradient {
        let top = s(snapshot.activeFlight ? snapshot.skyTopHex : snapshot.skyTopHex, 0x181721)
        let bottom = s(snapshot.skyBottomHex, 0x100F16)
        return LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    private func s(_ hex: Int, _ fallback: Int) -> Color { WColor.hex(hex == 0 ? fallback : hex) }

    var body: some View {
        ZStack {
            // The Sky itself is the backdrop tint (over the deep-space container).
            skyGradient.opacity(0.9)
            RadialGradient(colors: [WTheme.gold.opacity(0.16), .clear], center: .topTrailing,
                           startRadius: 4, endRadius: 180)
            content
        }
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
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(WTheme.ink)
            } else if let end = snapshot.activeEndDate {
                Text(timerInterval: Date()...max(Date(), end), countsDown: true)
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(WTheme.ink)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6).lineLimit(1)
            }
            HStack(spacing: 6) {
                Text(snapshot.activeSkyName ?? snapshot.selectedSkyName ?? "Focus")
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(WTheme.ink)
                if let cat = snapshot.activeCategory {
                    Text("· \(cat)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
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
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(WTheme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
                Image(systemName: "balloon.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(WTheme.gold)
            }
            Spacer(minLength: 0)
            HStack(spacing: 7) {
                Image(systemName: snapshot.hasResumable ? "arrow.uturn.up" : "arrow.up")
                    .font(.system(size: 13, weight: .heavy))
                Text(snapshot.hasResumable ? "Resume flight" : "Start Focus")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
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
