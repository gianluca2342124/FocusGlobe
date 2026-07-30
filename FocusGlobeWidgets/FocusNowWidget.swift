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
    /// The margins the system WOULD have applied. `contentMarginsDisabled()` is
    /// what lets the Sky run edge to edge, but it also throws these away — so the
    /// content re-applies them itself instead of guessing a number. Floored,
    /// because the widget corner radius is what actually eats a full-width
    /// control sitting at the bottom of the container.
    @Environment(\.widgetContentMargins) private var systemMargins

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

    /// Content inset, applied to the CONTENT only so the Sky stays full-bleed.
    private var contentInsets: EdgeInsets {
        EdgeInsets(top: max(systemMargins.top, 14),
                   leading: max(systemMargins.leading, 14),
                   bottom: max(systemMargins.bottom, 15),
                   trailing: max(systemMargins.trailing, 14))
    }

    var body: some View {
        ZStack {
            skyArtwork
            // Legibility scrim. Text now lives at BOTH ends of the small layout,
            // so the previous single bottom-heavy ramp left the top title fighting
            // the artwork. This darkens both ends and leaves the Sky itself open
            // through the middle.
            LinearGradient(stops: [
                .init(color: .black.opacity(0.55), location: 0.00),
                .init(color: .black.opacity(0.14), location: 0.34),
                .init(color: .black.opacity(0.30), location: 0.62),
                .init(color: .black.opacity(0.80), location: 1.00),
            ], startPoint: .top, endPoint: .bottom)
            if family == .systemSmall {
                smallLayout
            } else {
                mediumLayout
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(ContainerRelativeShape())
    }

    /// The state eyebrow, shared by both families. Fixed size on purpose: this is
    /// the one line that must never shrink or wrap.
    private var eyebrow: some View {
        Text(snapshot.activeFlight ? "IN FLIGHT" : "FOCUS NOW")
            .font(.system(size: 10, weight: .heavy, design: .default))
            .tracking(1.1)
            .foregroundStyle(snapshot.activeFlight ? WTheme.teal : WTheme.inkSoft)
            .lineLimit(1)
            .fixedSize()
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

    /// Small: eyebrow and Sky name pinned to the top, the Sky artwork breathing
    /// through the middle, the action pinned full-width at the bottom.
    ///
    /// The previous version pinned only the title to the top and let a 28 pt live
    /// timer plus the capsule pile up under it with 13 pt of padding, which is why
    /// the title read as cut and the action sat in the corner curve. Nothing here
    /// relies on text shrinking to stay inside: the eyebrow is `fixedSize`, the
    /// Sky name never drops below 85 % of 14 pt, and the timer is the only element
    /// allowed to scale hard (a running clock genuinely varies in width).
    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            eyebrow

            Text(displayedSkyName)
                .font(.system(size: 14, weight: .heavy, design: .default))
                .foregroundStyle(WTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 4)

            if snapshot.activeFlight {
                remainingTime(fontSize: 22)
            }

            actionCapsule(compact: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(contentInsets)
    }

    /// Medium keeps the horizontal composition — text column left, action right —
    /// but is vertically CENTRED rather than pinned to the bottom edge. Bottom
    /// pinning with 15 pt of padding is exactly what pushed the title and the
    /// action into the container's lower rounded corners.
    private var mediumLayout: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                eyebrow

                Text(displayedSkyName)
                    .font(.system(size: 19, weight: .heavy, design: .default))
                    .foregroundStyle(WTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                if snapshot.activeFlight {
                    remainingTime(fontSize: 26)
                } else {
                    Text(snapshot.hasResumable ? "Your flight is ready to continue." : "A quiet flight is one tap away.")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(WTheme.inkSoft)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Fixed-size so the greedy text column can never squeeze the primary
            // action — the action is the one thing that must never truncate.
            actionCapsule(compact: false)
                .fixedSize()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(contentInsets)
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
