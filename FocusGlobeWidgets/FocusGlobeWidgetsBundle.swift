//
//  FocusGlobeWidgetsBundle.swift
//  FocusGlobeWidgets
//
//  Created by Gianluca Crous Capaccio on 24/06/2026.
//

import WidgetKit
import SwiftUI

@main
struct FocusGlobeWidgetsBundle: WidgetBundle {
    var body: some Widget {
        FocusGlobeWidgets()
        FocusGlobeWidgetsControl()
        FocusGlobeWidgetsLiveActivity()
    }
}
