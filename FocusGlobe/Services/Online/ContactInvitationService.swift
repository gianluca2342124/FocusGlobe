import SwiftUI
import ContactsUI

/// Contact-based invitations. Uses the out-of-process `CNContactPickerViewController`
/// — the user intentionally picks ONE person; the address book is never read in
/// bulk, never uploaded, never matched against CloudKit users, and nothing is
/// stored after the flow ends. Presented only after an explicit tap plus a
/// pre-permission explanation sheet.
struct ContactPicker: UIViewControllerRepresentable {
    /// Called with a display name + the best available phone/email (used only
    /// to prefill the system message composer; discarded afterwards).
    var onPick: (String) -> Void
    var onCancel: () -> Void = {}

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: CNContactPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onCancel: onCancel) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (String) -> Void
        let onCancel: () -> Void
        init(onPick: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let name = CNContactFormatter.string(from: contact, style: .fullName) ?? "a friend"
            onPick(name)
        }
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) { onCancel() }
    }
}
