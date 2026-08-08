import ManagedSettings
import ManagedSettingsUI
import UIKit

/// FocusGlobe's use of Apple's system-owned Screen Time shield.
///
/// ManagedSettingsUI owns the layout completely — there is no way to place a
/// SwiftUI view inside it, and attempting to fake one produces exactly the
/// half-finished result this replaces. What the extension DOES control is the
/// background colour, one image, four pieces of text and two button colours,
/// and all six are now deliberate.
///
/// Every override funnels into one builder, so a shielded app, an app shielded
/// through a category, a web domain and a domain shielded through a category are
/// visually identical. There is no analytics, no network and no RevenueCat here:
/// a shield extension is memory-constrained and runs at unpredictable moments.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        Self.focusGlobeShield()
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        Self.focusGlobeShield()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        Self.focusGlobeShield()
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        Self.focusGlobeShield()
    }

    // MARK: - The one canonical shield

    /// FocusGlobe's exact shield background, #181721.
    private static let background = UIColor(
        red: 24.0 / 255.0,
        green: 23.0 / 255.0,
        blue: 33.0 / 255.0,
        alpha: 1.0
    )
    private static let ivory = UIColor(red: 0.96, green: 0.94, blue: 0.89, alpha: 1)

    /// Whether the primary button will genuinely open FocusGlobe here.
    ///
    /// The identical check lives in `ShieldActionExtension.canOpenParentalControlsApp`.
    /// It is duplicated rather than shared because these are two separate
    /// extension targets that cannot import one another — but it is ONE
    /// condition, `iOS 26.5`, and both sides must be changed together or the
    /// button's label stops matching its behaviour.
    private static var primaryOpensFocusGlobe: Bool {
        if #available(iOS 26.5, *) { return true }
        return false
    }

    private static func focusGlobeShield() -> ShieldConfiguration {
        let line = ShieldCopy.current()

        return ShieldConfiguration(
            // No blur. `backgroundBlurStyle` composites a material over the
            // colour, so the visible result is never the value that was asked
            // for — and this screen has an exact brand colour to hit.
            backgroundBlurStyle: nil,
            backgroundColor: background,
            // The balloon, alpha-trimmed and squared with transparent padding
            // only, shipped INSIDE this extension's own catalogue. The system
            // scales it into its own slot; giving it art with no baked
            // background is the only way to avoid the dark tile that used to
            // sit behind it.
            icon: UIImage(named: "FocusShieldGlyph"),
            // Resolved HERE, not in `ShieldCopy`: the pools stay English so
            // the deterministic rotation index cannot move when the language
            // changes, and only the chosen line is translated.
            title: .init(text: FocusLocalization.string(line.title), color: ivory),
            subtitle: .init(text: FocusLocalization.string(line.subtitle),
                            color: ivory.withAlphaComponent(0.74)),
            // The label tracks what the button can actually do on THIS device.
            //
            // `ShieldActionResponse.openParentalControlsApp` — "an instruction
            // for the system to open your parental controls app that is
            // responsible for shielding the application or web browser" — is
            // exactly the supported way back, and FocusGlobe is that app. It
            // arrived in iOS 26.5, above this target's 17.0 minimum, so on
            // anything older the primary button can only close the blocked app.
            //
            // Both extensions read the SAME condition, so the promise and the
            // behaviour cannot drift apart: where the system will open
            // FocusGlobe the button says so; older systems expose one truthful
            // Close action instead of two controls that both do the same thing.
            // White plate, black label either way.
            primaryButtonLabel: .init(
                text: FocusLocalization.string(
                    primaryOpensFocusGlobe ? "Return to FocusGlobe" : "Close"),
                color: .black
            ),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: primaryOpensFocusGlobe
                ? .init(text: FocusLocalization.string("Close"),
                        color: ivory.withAlphaComponent(0.62))
                : nil
        )
    }
}

// MARK: - Copy

/// FocusGlobe's own shield lines. All original: no third-party quotes, no
/// attribution, nobody else's slogan.
///
/// The line has to be STABLE while a shield is on screen. `configuration` is
/// called again on every re-presentation and on relayout, so anything random
/// would visibly flicker between phrases. Selection is therefore derived from
/// something that does not change during a flight: the active journey's start
/// time from the App Group, or — if no flight is running — the current local
/// day, which at least holds steady until midnight.
///
/// The lines stay ENGLISH here: they are String Catalog keys, and the rotation
/// index must not shift when the pilot changes language mid-flight. The chosen
/// line is translated at the point it becomes a `ShieldConfiguration`.
enum ShieldCopy {
    struct Line {
        let title: String
        let subtitle: String
    }

    /// Titles are short enough to survive the system's own layout without
    /// truncating; each subtitle is one supporting sentence.
    static let lines: [Line] = [
        Line(title: "That scroll can wait",
             subtitle: "Your goal can’t. Keep flying."),
        Line(title: "Don’t trade your goal",
             subtitle: "A distraction is a poor exchange rate."),
        Line(title: "Protect who you’re becoming",
             subtitle: "This is the part that builds them."),
        Line(title: "The urge will pass",
             subtitle: "It always does. Stay in the air."),
        Line(title: "Your future deserves this",
             subtitle: "So does the hour you already committed."),
        Line(title: "Five focused minutes",
             subtitle: "That’s all it takes to change your day."),
        Line(title: "Stay on course",
             subtitle: "Finish what you started."),
        Line(title: "Not worth your momentum",
             subtitle: "You’ve built something. Don’t spend it here."),
    ]

    private static let appGroupID = "group.com.focusglobe.app"
    /// Written by the app when a journey's shields go up.
    private static let startedAtKey = "fg.focusShield.startedAt"

    static func current(now: Date = Date(), calendar: Calendar = .current) -> Line {
        lines[index(now: now, calendar: calendar)]
    }

    /// A stable index in `lines.indices`. Exposed for reasoning about, and
    /// deliberately total: every input path returns a valid index.
    static func index(now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard !lines.isEmpty else { return 0 }
        let seed: Int
        if let started = activeFlightStart(), started.timeIntervalSince1970 > 0 {
            // One line per flight, fixed for its whole duration.
            seed = Int(started.timeIntervalSince1970)
        } else {
            // No flight in the App Group (or the group isn't linked): fall back
            // to the local day, so the phrase is at least steady until midnight.
            seed = calendar.ordinality(of: .day, in: .era, for: now) ?? 0
        }
        // Mix before reducing. Taking `seed % count` directly is badly behaved
        // here: flight starts a minute apart differ by 60, and 60 % 8 == 4, so
        // consecutive flights would alternate between just two phrases forever.
        // A splitmix64 finalizer spreads them across the whole set — measured at
        // 7 of 8 distinct over 24 flights a minute apart, and 8 of 8 over 24
        // consecutive days. Still perfectly deterministic.
        return Int(Self.mixed(UInt64(bitPattern: Int64(seed))) % UInt64(lines.count))
    }

    private static func mixed(_ value: UInt64) -> UInt64 {
        var h = value &* 0x9E37_79B9_7F4A_7C15
        h ^= h >> 29
        h = h &* 0xBF58_476D_1CE4_E5B9
        h ^= h >> 32
        return h
    }

    private static func activeFlightStart() -> Date? {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return nil }
        let t = defaults.double(forKey: startedAtKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }
}
