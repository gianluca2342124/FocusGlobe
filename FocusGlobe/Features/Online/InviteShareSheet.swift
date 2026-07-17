import SwiftUI
#if canImport(UIKit)
import UIKit
import LinkPresentation

/// A proper system share sheet for a private-flight invitation. It shares
/// EXACTLY ONE item — an `LPLinkMetadata`-backed activity source — so the URL
/// is never duplicated (no "link in the text AND the link again"). The rich
/// preview uses the committed FocusGlobe logo (`AppLogo`), and the copy is
/// clearly an invitation, never generic promotion.
struct InviteShareSheet: UIViewControllerRepresentable {
    let url: URL
    var title: String = "Join my FocusGlobe Flight"

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let source = InviteActivityItemSource(url: url, title: title)
        let controller = UIActivityViewController(activityItems: [source], applicationActivities: nil)
        // The invitation is private access — exclude noisy destinations.
        controller.excludedActivityTypes = [.assignToContact, .addToReadingList, .markupAsPDF]
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// One activity item: the URL, with a link-preview (title + logo) and a single
/// short invitation subject. Messages/Mail render one tappable link with the
/// preview — the URL is not repeated in a text blob.
final class InviteActivityItemSource: NSObject, UIActivityItemSource {
    let url: URL
    let title: String
    init(url: URL, title: String) { self.url = url; self.title = title }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any { url }

    func activityViewController(_ controller: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        // Return the URL alone — the preview metadata carries the title/image,
        // so nothing appends the link a second time.
        url
    }

    func activityViewController(_ controller: UIActivityViewController,
                                subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        title
    }

    func activityViewControllerLinkMetadata(_ controller: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.originalURL = url
        metadata.url = url
        if let logo = UIImage(named: MarketingConfig.previewImageName) ?? UIImage(named: "AppLogo") {
            metadata.iconProvider = NSItemProvider(object: logo)
            metadata.imageProvider = NSItemProvider(object: logo)
        }
        return metadata
    }
}
#endif
