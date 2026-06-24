//
//  FocusGlobeWidgetsLiveActivity.swift
//  FocusGlobeWidgets
//
//  Created by Gianluca Crous Capaccio on 24/06/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct FocusGlobeWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct FocusGlobeWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusGlobeWidgetsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension FocusGlobeWidgetsAttributes {
    fileprivate static var preview: FocusGlobeWidgetsAttributes {
        FocusGlobeWidgetsAttributes(name: "World")
    }
}

extension FocusGlobeWidgetsAttributes.ContentState {
    fileprivate static var smiley: FocusGlobeWidgetsAttributes.ContentState {
        FocusGlobeWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: FocusGlobeWidgetsAttributes.ContentState {
         FocusGlobeWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: FocusGlobeWidgetsAttributes.preview) {
   FocusGlobeWidgetsLiveActivity()
} contentStates: {
    FocusGlobeWidgetsAttributes.ContentState.smiley
    FocusGlobeWidgetsAttributes.ContentState.starEyes
}
