import SwiftUI
import WidgetKit

/// The FocusGlobe Home Screen widgets — the FINAL five, no more.
///
/// This file (and the rest of `FocusGlobeWidgets/`) belongs to the **widget
/// extension target**, NOT the app target — see WIDGETS_SETUP.md for the one-time
/// Xcode setup (create the Widget Extension target, enable the App Group on both
/// targets).
///
/// FREE: Streak Companion · Focus Now.
/// FocusGlobe PRO: Focus Grid · Passport Stats · Badge Collection (each gates
/// itself against the shared `isPro` snapshot and deep-links to the Widget
/// paywall when locked).
@main
struct FocusGlobeWidgetBundle: WidgetBundle {
    var body: some Widget {
        StreakCompanionWidget()
        FocusNowWidget()
        FocusGridWidget()
        PassportStatsWidget()
        BadgeCollectionWidget()
    }
}
