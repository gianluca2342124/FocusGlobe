import Foundation
import SwiftUI
import WidgetKit

// MARK: - Theme
//
// Self-contained styling for the widget target (it can't import the app's
// design system). Dark, premium, travel-themed — aligned with FocusGlobe.

enum WTheme {
    static let bgTop    = Color(red: 0.11, green: 0.14, blue: 0.20)
    static let bgBottom = Color(red: 0.05, green: 0.07, blue: 0.10)
    static let ink      = Color.white
    static let inkSoft  = Color.white.opacity(0.62)
    static let hair     = Color.white.opacity(0.12)
    static let gold     = Color(red: 0.95, green: 0.78, blue: 0.47)
    static let indigo   = Color(red: 0.40, green: 0.45, blue: 0.96)
    static let teal     = Color(red: 0.20, green: 0.78, blue: 0.62)
    static let coral    = Color(red: 0.96, green: 0.47, blue: 0.36)
    static let sky      = Color(red: 0.36, green: 0.56, blue: 0.95)

    /// Vivid focus-category hue for the widget Focus Grid — the EXACT palette the
    /// app uses in `FocusConsistency.categoryColor` (kept in sync by hand; the
    /// widget can't import the app's design system). Unknown / "" → signature gold.
    static func category(_ key: String?) -> Color {
        switch key {
        case "fly":      return Color(red: 0.392, green: 0.380, blue: 0.941)  // 0x6461F0 blue/violet
        case "work":     return Color(red: 0.125, green: 0.580, blue: 0.902)  // 0x2094E6 azure
        case "study":    return Color(red: 0.949, green: 0.690, blue: 0.118)  // 0xF2B01E golden yellow
        case "meditate": return Color(red: 0.125, green: 0.761, blue: 0.459)  // 0x20C275 green
        case "exercise": return Color(red: 0.984, green: 0.478, blue: 0.141)  // 0xFB7A24 orange
        case "read":     return Color(red: 0.635, green: 0.294, blue: 0.878)  // 0xA24BE0 purple
        case "create":   return Color(red: 0.925, green: 0.357, blue: 0.608)  // 0xEC5B9B pink
        case "reflect":  return Color(red: 0.173, green: 0.733, blue: 0.831)  // 0x2CBBD4 cyan
        default:         return Color(red: 0.910, green: 0.647, blue: 0.294)  // 0xE8A54B amber
        }
    }
}

extension View {
    /// The standard dark, premium "deep space" widget container background
    /// (iOS 17+). Pass a `glow` to tint each widget's signature corner light.
    func fgWidgetBackground(glow: Color = WTheme.indigo) -> some View {
        containerBackground(for: .widget) {
            WSpace(glow: glow)
        }
    }
}

// MARK: - Deep links

enum FGLink {
    static func url(_ path: String) -> URL {
        URL(string: "\(FocusGlobeShared.urlScheme)://\(path)") ?? URL(string: "\(FocusGlobeShared.urlScheme)://home")!
    }
}

extension WidgetSnapshot {
    /// Deep-link host for a Pro-gated widget: the paywall when locked, otherwise
    /// `open`. Tapping a locked widget should sell Pro, not dead-end.
    func gatedLink(_ open: String) -> String { isPro ? open : "pro" }

    /// Deep-link host for the current-journey widget: paywall when locked, resume
    /// when a flight is paused, otherwise choose a new destination.
    func journeyLink() -> String { isPro ? (hasResumable ? "resume" : "choose") : "pro" }
}

// MARK: - Timeline

struct FGEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// One shared provider for every widget — reads the App Group snapshot the app
/// publishes. A periodic refresh keeps values current even without an app launch.
struct FGProvider: TimelineProvider {
    func placeholder(in context: Context) -> FGEntry {
        FGEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (FGEntry) -> Void) {
        let snapshot = context.isPreview ? WidgetSnapshot.placeholder : WidgetStore.read()
        completion(FGEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FGEntry>) -> Void) {
        let entry = FGEntry(date: Date(), snapshot: WidgetStore.read())
        let next = Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Reusable views

/// A small uppercase section label with an icon.
struct WHeader: View {
    let icon: String
    let title: String
    var tint: Color = WTheme.gold
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold)).foregroundStyle(tint)
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(WTheme.inkSoft)
        }
    }
}

/// A slim progress bar.
struct WBar: View {
    let fraction: Double
    var tint: Color = WTheme.gold
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(WTheme.hair)
                Capsule().fill(tint)
                    .frame(width: max(5, g.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 6)
    }
}

/// A circular progress ring.
struct WRing: View {
    let fraction: Double
    var tint: Color = WTheme.teal
    var lineWidth: CGFloat = 7
    var body: some View {
        ZStack {
            Circle().stroke(WTheme.hair, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, fraction)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

/// A compact stat (value + caption).
struct WStat: View {
    let value: String
    let caption: String
    var tint: Color = WTheme.ink
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.7).lineLimit(1)
            Text(caption.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded)).tracking(0.4)
                .foregroundStyle(WTheme.inkSoft)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A minimal route arc (origin dot → balloon apex → destination dot).
struct WRouteArc: View {
    var tint: Color = WTheme.gold
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let start = CGPoint(x: 7, y: h - 6)
            let end = CGPoint(x: w - 7, y: h - 6)
            let ctrl = CGPoint(x: w / 2, y: -h * 0.10)
            ZStack {
                Path { p in p.move(to: start); p.addQuadCurve(to: end, control: ctrl) }
                    .stroke(tint.opacity(0.9), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 5]))
                Circle().fill(WTheme.ink).frame(width: 7, height: 7).position(start)
                Circle().fill(tint).frame(width: 8, height: 8).position(end)
                // A small balloon at the apex (on-theme — not an aeroplane).
                Circle()
                    .fill(WTheme.gold)
                    .frame(width: 11, height: 11)
                    .shadow(color: WTheme.gold.opacity(0.6), radius: 4)
                    .position(x: w / 2, y: h * 0.22)
            }
        }
    }
}

/// A tasteful locked state for non-Pro users — premium, never "broken".
struct LockedTeaser: View {
    let icon: String
    let title: String
    var accent: Color = WTheme.gold
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(accent)
                Spacer()
                Image(systemName: "lock.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(WTheme.inkSoft)
            }
            Spacer(minLength: 0)
            Text(title)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(WTheme.ink)
            Text("Unlock with FocusGlobe Pro")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(WTheme.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }
}

// MARK: - Formatting

extension Int {
    /// Thousands-grouped string, e.g. 12022 → "12,022".
    var fgGrouped: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension String {
    /// A 3-letter, airport-style code derived from a city name — a widget-side
    /// fallback for when the snapshot only carries a city name (e.g. the longest
    /// route). E.g. "Reykjavík" → "REY".
    var fgCityCode: String {
        let letters = uppercased().filter { $0.isLetter }
        return letters.isEmpty ? "FLY" : String(letters.prefix(3))
    }
}

/// Seconds → compact duration, e.g. 900 → "15m", 3720 → "1h 02m".
func fgDuration(_ seconds: Int) -> String {
    let m = max(0, seconds) / 60
    if m < 60 { return "\(m)m" }
    return "\(m / 60)h \(String(format: "%02d", m % 60))m"
}

// MARK: - Preview states

#if DEBUG
extension WidgetSnapshot {
    /// Preview-only: the "ready for takeoff" state (Pro, no active journey).
    static var preview: WidgetSnapshot {
        var s = WidgetSnapshot.placeholder
        s.hasResumable = false
        return s
    }

    /// Preview-only: a locked (non-Pro) snapshot for the gated widgets.
    static var previewLocked: WidgetSnapshot {
        var s = WidgetSnapshot.placeholder
        s.isPro = false
        return s
    }

    /// Preview-only: a fresh account (zero stats) — exercises empty/ember states.
    static var previewEmpty: WidgetSnapshot {
        var s = WidgetSnapshot()
        s.isPro = true
        s.originCity = "San Francisco"
        s.originCode = "SFO"
        return s
    }
}
#endif
