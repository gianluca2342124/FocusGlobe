import SwiftUI
import UIKit
import CloudKit

/// The system CloudKit sharing sheet (`UICloudSharingController`) for a room's
/// existing CKShare. This is the ONLY delivery path for private invitations:
/// the share's `publicPermission` is `.none`, so access exists solely for the
/// participants explicitly invited here (or via the contact lookup). The
/// system UI covers Messages / WhatsApp / AirDrop delivery AND participant
/// management — the owner can remove a participant or stop sharing entirely.
struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    var title: String = "FocusGlobe Flight"

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share,
                                                  container: CloudKitConfig.container)
        // Private, read/write only — never "anyone with the link".
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(title: title) }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let title: String
        init(title: String) { self.title = title }

        func itemTitle(for csc: UICloudSharingController) -> String? { title }

        func cloudSharingController(_ csc: UICloudSharingController,
                                    failedToSaveShareWithError error: Error) {
            // Never surfaced raw to the UI; the lobby refreshes on its next
            // poll and the room stays usable for already-accepted pilots.
        }
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {}
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {}
    }
}
