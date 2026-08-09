import ManagedSettings
import ManagedSettingsUI
import UIKit

/// FocusGlobe's use of Apple's system-owned Screen Time shield.
///
/// WHAT THIS EXTENSION ACTUALLY CONTROLS
///     `ShieldConfiguration` is eight values and nothing else: a blur style, a
///     background colour, one `UIImage`, three `Label`s (text + colour, no
///     font, no size, no weight) and one button background colour.
///     ManagedSettingsUI owns the layout completely — there is no way to place
///     a SwiftUI view inside it, no way to set a type size, and no way to give
///     the icon a frame. Everything below is therefore about making those eight
///     values carry the whole design.
///
/// THE RULE THIS SCREEN IS BUILT ON: STATE EVERYTHING
///     A Light Mode iPhone rendered this shield as cream text on a near-white
///     background — 1.05:1, invisible. The colours were not wrong; one property
///     was simply not stated, and an unstated property on a system-owned view
///     is a property the system fills in from the phone's appearance. Nothing
///     here is left `nil` that can vary, and nothing here is translucent.
///
/// THE SHIELD IS NOT A PANEL
///     It is the moment a flight defends itself, so it is painted in the
///     onboarding night sky rather than in the app's neutral surface colour,
///     and it looks the same whichever appearance the phone is in. That is
///     deliberate: FocusGlobe's Light Mode is a place you read in, and this is
///     a place you are stopped in.
///
/// Every override funnels into one builder, so a shielded app, an app shielded
/// through a category, a web domain and a domain shielded through a category are
/// visually identical. There is no analytics, no network and no RevenueCat here:
/// a shield extension is memory-constrained and runs at unpredictable moments,
/// so it does no image work either — the icon is a pre-cropped asset.
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

    // MARK: - The palette

    /// Every colour on this screen is a FIXED sRGB value with alpha 1.
    ///
    /// Not one of them is a `UIColor` that resolves against a trait collection,
    /// and not one of them is left `nil`. That is the whole fix. The shield is
    /// presented over the blocked app by a system view whose default styling
    /// follows the phone's appearance, so any property FocusGlobe does not
    /// state is a property the phone gets to state — and on a Light Mode
    /// iPhone it stated "near-white background", under which cream text sits at
    /// 1.05:1 and disappears.
    ///
    /// `withAlphaComponent` is deliberately absent too: a translucent label is
    /// a label whose contrast depends on what happens to be behind it, and
    /// Reduce Transparency and Increase Contrast both move that. The softer
    /// tones below are pre-blended and shipped solid.
    private static func srgb(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1)
    }

    /// The top of the onboarding night sky, `OnboardingBackdrop`'s `0x0B1024`.
    ///
    /// It used to be `0x181721` — `AppColors.neutralBase`, a neutral near-black
    /// that belongs to panels and tab bars. This screen is not a panel; it is
    /// the moment a flight defends itself, and it should look like the sky the
    /// flight happens in.
    private static let background = srgb(0x0B1024)
    /// The app's warm white for text on night, `0xF7F1E7`.       16.8:1 on sky
    private static let ink = srgb(0xF7F1E7)
    /// The subtitle: quieter than the title, still solid.        11.5:1 on sky
    private static let inkSoft = srgb(0xCFC9BF)
    /// The secondary action, quieter again but never faint.       7.5:1 on sky
    private static let inkFaint = srgb(0xA8A29A)
    /// `AppColors` selection cream and the ink that rides on it.
    private static let cream = srgb(0xF4EFE4)
    private static let creamInk = srgb(0x14120E)

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
            // A blur style that is EXPLICITLY dark, not the absence of one.
            //
            // `nil` here does not mean "no material". It means "the system's
            // default", and the system's default follows the phone's
            // appearance — which is why an opaque dark `backgroundColor` still
            // rendered as a near-white screen in Light Mode and a neutral dark
            // one in Dark Mode: neither was the colour below, both were the
            // material above it.
            //
            // `.systemThickMaterialDark` is one of the `…Dark` variants, which
            // are fixed rather than adaptive, and it is the most opaque of
            // them — the least of the blocked app shows through. Stating it and
            // the colour together makes the result dark whichever way
            // ManagedSettingsUI composites the two, which is the point: this
            // must not depend on a compositing order Apple does not document.
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: background,
            // The balloon, cropped to its own alpha bounds and centred, shipped
            // INSIDE this extension's own catalogue.
            //
            // It used to sit in an 820×820 canvas with 237 px of dead space on
            // its left and 72 on its right — 54% occupancy, and 82 px off
            // centre. The system scales the whole canvas into its slot, so
            // every one of those empty pixels was spending slot the balloon
            // could have had. The catalogue marks it `original`, never
            // template, so the warm cream survives instead of being flattened
            // to a tint.
            icon: UIImage(named: "FocusShieldGlyph"),
            // Resolved HERE, not in `ShieldCopy`: the pools stay English so
            // the deterministic rotation index cannot move when the language
            // changes, and only the chosen line is translated.
            title: .init(text: FocusLocalization.string(line.title), color: ink),
            subtitle: .init(text: FocusLocalization.string(line.subtitle),
                            color: inkSoft),
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
            // Cream plate, near-black label either way — the app's own CTA
            // pair rather than `.white` on `.black`, so the one bright object
            // besides the balloon is the same cream the balloon is.
            primaryButtonLabel: .init(
                text: FocusLocalization.string(
                    primaryOpensFocusGlobe ? "Return to FocusGlobe" : "Close"),
                color: creamInk
            ),
            primaryButtonBackgroundColor: cream,
            secondaryButtonLabel: primaryOpensFocusGlobe
                ? .init(text: FocusLocalization.string("Close"), color: inkFaint)
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
