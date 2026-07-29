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
            if family == .systemSmall {
                smallLayout
            } else {
                mediumLayout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(ContainerRelativeShape())
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

    private var displayedSkyName: String {
        if snapshot.activeFlight {
            return snapshot.activeSkyName ?? snapshot.selectedSkyName ?? "Focus"
        }
        return snapshot.selectedSkyName ?? "Ready to focus"
    }

    private var actionTitle: String {
        snapshot.activeFlight || snapshot.hasResumable ? "Resume" : "Start Focus"
    }

    private var actionIcon: String {
        snapshot.activeFlight || snapshot.hasResumable ? "arrow.uturn.up" : "arrow.up"
    }

    /// Small is a true edge-to-edge widget, not a resized phone card. Every
    /// element stays inside the family container and the CTA uses compact copy.
    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(displayedSkyName)
                .font(.system(size: 15, weight: .heavy, design: .default))
                .foregroundStyle(WTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 0)

            if snapshot.activeFlight {
                remainingTime(fontSize: 28)
            }

            actionCapsule(compact: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// Medium uses its horizontal room intentionally: state and remaining time
    /// stay on the left; the compact action remains safely inset on the right.
    private var mediumLayout: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(snapshot.activeFlight ? "IN FLIGHT" : "FOCUS NOW")
                    .font(.system(size: 10, weight: .heavy, design: .default))
                    .tracking(1.1)
                    .foregroundStyle(snapshot.activeFlight ? WTheme.teal : WTheme.inkSoft)
                    .lineLimit(1)

                Text(displayedSkyName)
                    .font(.system(size: 19, weight: .heavy, design: .default))
                    .foregroundStyle(WTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if snapshot.activeFlight {
                    remainingTime(fontSize: 27)
                } else {
                    Text(snapshot.hasResumable ? "Your flight is ready to continue." : "A quiet flight is one tap away.")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(WTheme.inkSoft)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            actionCapsule(compact: false)
        }
        .padding(15)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    @ViewBuilder
    private func remainingTime(fontSize: CGFloat) -> some View {
        if snapshot.activeInfinite || snapshot.activeEndDate == nil {
            Text("∞")
                .font(.system(size: fontSize, weight: .black, design: .default))
                .foregroundStyle(WTheme.ink)
        } else if let end = snapshot.activeEndDate {
            Text(timerInterval: Date()...max(Date(), end), countsDown: true)
                .font(.system(size: fontSize, weight: .black, design: .default))
                .foregroundStyle(WTheme.ink)
                .monospacedDigit()
                .minimumScaleFactor(0.65)
                .lineLimit(1)
        }
    }

    private func actionCapsule(compact: Bool) -> some View {
        HStack(spacing: compact ? 5 : 7) {
            Image(systemName: actionIcon)
                .font(.system(size: compact ? 11 : 12, weight: .heavy))
            ViewThatFits(in: .horizontal) {
                Text(actionTitle)
                Text(snapshot.activeFlight || snapshot.hasResumable ? "Resume" : "Start")
            }
            .font(.system(size: compact ? 12 : 13, weight: .heavy, design: .default))
            .lineLimit(1)
        }
        .foregroundStyle(Color(red: 0.08, green: 0.07, blue: 0.05))
        .padding(.horizontal, compact ? 10 : 13)
        .padding(.vertical, compact ? 7 : 9)
        .frame(maxWidth: compact ? .infinity : nil)
        .background(Capsule().fill(WTheme.gold))
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
