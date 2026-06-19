import SwiftUI

/// A collectible postcard / stamp. Renders the premium procedural
/// `DestinationPostcard` (landmark silhouette, atmospheric light). Used
/// full-width on the Landing screen and as compact tiles in the Globe Passport.
struct PostcardTile: View {
    let postcard: Postcard
    var isNew: Bool = false
    var compact: Bool = false

    var body: some View {
        DestinationPostcard(title: postcard.title, place: postcard.place,
                            mood: postcard.mood, theme: postcard.theme,
                            landmark: postcard.landmark ?? .generic,
                            compact: compact, isNew: isNew)
    }
}
