import SwiftUI
import WidgetKit

/// The FocusGlobe Home Screen widgets — the FINAL four, no more.
///
/// This file (and the rest of `FocusGlobeWidgets/`) belongs to the **widget
/// extension target**, NOT the app target — see WIDGETS_SETUP.md for the one-time
/// Xcode setup (create the Widget Extension target, enable the App Group on both
/// targets).
///
/// FREE: Streak Companion · Focus Now.
/// FocusGlobe PRO: Focus Grid · Passport Dashboard (each gates itself against the
/// shared `isPro` snapshot and deep-links to the Widget paywall when locked). The
/// standalone Badge Collection widget was retired — a few unlocked badges now live
/// inside Passport Dashboard.
@main
struct FocusGlobeWidgetBundle: WidgetBundle {
    var body: some Widget {
        StreakCompanionWidget()
        FocusNowWidget()
        FocusGridWidget()
        PassportStatsWidget()
    }
}
