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
        // The gallery is system UI: it is composed by the widget picker in the
        // DEVICE language, which is the one surface FocusGlobe's own language
        // choice cannot reach. Shipping it translated is still right — a Spanish
        // phone gets a Spanish gallery entry.
        .configurationDisplayName(Text("Focus Now"))
        .description(Text("Start a focus flight, or watch the one you're on."))
        .supportedFamilies([.systemMedium])
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
    ///
    /// Small is inset a little harder than medium: a 158 pt tile has the same
    /// corner radius as a 338 pt one, so the corners eat proportionally far more
    /// of it, and text starting at the very top-left runs straight into the
    /// curve.
    private var contentInsets: EdgeInsets {
        let floor: CGFloat = family == .systemSmall ? 15 : 14
        return EdgeInsets(top: max(systemMargins.top, floor + (family == .systemSmall ? 2 : 0)),
                          leading: max(systemMargins.leading, floor),
                          bottom: max(systemMargins.bottom, floor),
                          trailing: max(systemMargins.trailing, floor))
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

    /// The state eyebrow.
    ///
    /// It used to be `.fixedSize()`, described as "must never shrink". That is
    /// what let it size the tile instead of the tile sizing it: a fixed-size
    /// child that does not fit makes its ancestors wider than the container, and
    /// `ContainerRelativeShape` then clips the overflow symmetrically — which is
    /// why "FOCUS NOW" appeared as "US NOW", losing characters off the LEFT edge
    /// where nothing was ever laid out. Shrinking a little is strictly better
    /// than being cut in half.
    private func eyebrow(size: CGFloat) -> some View {
        Text(FocusLocalization.string(snapshot.activeFlight ? "IN FLIGHT" : "FOCUS NOW"))
            .font(.system(size: size, weight: .heavy, design: .default))
            .tracking(1.0)
            .foregroundStyle(snapshot.activeFlight ? WTheme.teal : WTheme.inkSoft)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
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
            // Sky names are catalog content, resolved by the app before it
            // writes the snapshot; only the fallback is a key.
            return snapshot.activeSkyName ?? snapshot.selectedSkyName
                ?? FocusLocalization.string("Focus")
        }
        return snapshot.selectedSkyName ?? FocusLocalization.string("Ready to focus")
    }

    private var actionTitle: String {
        FocusLocalization.string(
            snapshot.activeFlight || snapshot.hasResumable ? "Resume" : "Start Focus")
    }

    private var actionIcon: String {
        snapshot.activeFlight || snapshot.hasResumable ? "arrow.uturn.up" : "arrow.up"
    }

    /// Small: rebuilt as its own layout, sized by the CONTAINER rather than by
    /// its content.
    ///
    /// The clipping had two causes stacked on each other. The first was modifier
    /// order — `.frame(maxWidth: .infinity)` before `.padding(...)` grows to the
    /// full container and then adds insets outside it. The second, which
    /// survived that fix, was `.fixedSize()` on the eyebrow and the action pill:
    /// a fixed-size child that does not fit makes the whole stack wider than the
    /// tile, and `ContainerRelativeShape` clips the excess EVENLY, which is why
    /// characters disappeared off the left edge as well as the right.
    ///
    /// So nothing in here is fixed-size and every row is `maxWidth: .infinity`.
    /// The tile's width is the authority: text scales inside it and the button
    /// is measured from it. Overflow is not tuned down, it is impossible.
    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 5) {
            // TOP — eyebrow + Sky name as one tight block, inset from the curve.
            VStack(alignment: .leading, spacing: 1) {
                eyebrow(size: 10)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(displayedSkyName)
                    .font(.system(size: 14.5, weight: .heavy, design: .default))
                    .foregroundStyle(WTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // MIDDLE — the Sky itself, which is the ZStack behind this. Nothing
            // is drawn over it: a balloon here would compete with a 158 pt tile
            // that already has a title and a button on it.
            Spacer(minLength: 2)

            if snapshot.activeFlight {
                remainingTime(fontSize: 19)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // BOTTOM — a centred pill, deliberately narrower than the tile.
            smallActionButton
        }
        .padding(contentInsets)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// The small action pill: 74 % of the CONTENT width (inside the 65–78 %
    /// target), centred, and measured from the row it is given rather than from
    /// any screen or device metric. A full-width pill turned the bottom of a
    /// 158 pt square into a solid gold bar; a fixed-width one clipped.
    private var smallActionButton: some View {
        GeometryReader { geo in
            actionCapsuleBody(compact: true)
                .frame(width: max(64, geo.size.width * 0.74), height: geo.size.height)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: 28)
    }

    /// Medium keeps the horizontal composition — text column left, action right —
    /// vertically centred rather than pinned to the bottom edge. Same padding /
    /// frame ordering fix as small: it was overflowing its container by the inset
    /// on every side, which centring merely disguised.
    private var mediumLayout: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                eyebrow(size: 10)

                Text(displayedSkyName)
                    .font(.system(size: 19, weight: .heavy, design: .default))
                    .foregroundStyle(WTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                if snapshot.activeFlight {
                    remainingTime(fontSize: 26)
                } else {
                    Text(FocusLocalization.string(snapshot.hasResumable
                        ? "Your flight is ready to continue."
                        : "A quiet flight is one tap away."))
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
        .padding(contentInsets)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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

    /// The pill's contents and plate, WITHOUT deciding its own width. Small
    /// gives it a measured fraction of the row; medium hugs the label.
    private func actionCapsuleBody(compact: Bool) -> some View {
        HStack(spacing: compact ? 5 : 7) {
            Image(systemName: actionIcon)
                .font(.system(size: compact ? 11 : 12, weight: .heavy))
            ViewThatFits(in: .horizontal) {
                Text(actionTitle)
                Text(FocusLocalization.string(
                    snapshot.activeFlight || snapshot.hasResumable ? "Resume" : "Start"))
            }
            .font(.system(size: compact ? 12 : 13, weight: .heavy, design: .default))
            .lineLimit(1)
            // A long state word still shrinks rather than pushing the plate
            // wider than the space it was given.
            .minimumScaleFactor(0.75)
        }
        .foregroundStyle(Color(red: 0.08, green: 0.07, blue: 0.05))
        .padding(.horizontal, compact ? 10 : 13)
        .padding(.vertical, compact ? 6 : 9)
        .frame(maxWidth: .infinity)
        .background(Capsule().fill(WTheme.gold))
    }

    /// Medium: hugs its label, so the greedy text column beside it can never
    /// squeeze the primary action.
    private func actionCapsule(compact: Bool) -> some View {
        actionCapsuleBody(compact: compact).fixedSize()
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
