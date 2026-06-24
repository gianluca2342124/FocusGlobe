import SwiftUI
import WidgetKit

/// The FocusGlobe Home Screen widgets.
///
/// This file (and the rest of `FocusGlobeWidgets/`) belongs to the **widget
/// extension target**, NOT the app target — see WIDGETS_SETUP.md for the one-time
/// Xcode setup (create the Widget Extension target, enable the App Group on both
/// targets, and add `Shared/WidgetSharedData.swift` to this target).
@main
struct FocusGlobeWidgetBundle: WidgetBundle {
    var body: some Widget {
        StreakWidget()
        StartJourneyWidget()
        CurrentJourneyWidget()
        AroundEarthWidget()
        LongestRouteWidget()
        DailyGoalsWidget()
        PassportWidget()
    }
}
