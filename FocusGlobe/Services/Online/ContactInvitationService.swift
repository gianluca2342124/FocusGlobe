import SwiftUI
import ContactsUI

/// Contact-based invitations. Uses the out-of-process `CNContactPickerViewController`
/// — the user intentionally picks ONE person; the address book is never read in
/// bulk, never uploaded, never matched against CloudKit users, and nothing is
/// stored after the flow ends. Presented only after an explicit tap plus a
/// pre-permission explanation sheet.
struct ContactPicker: UIViewControllerRepresentable {
    /// Called with the display name + best available email/phone. Used ONCE to
    /// resolve an explicit CKShare participant for the current invitation,
    /// then discarded — never stored, never uploaded, never matched in bulk.
    var onPick: (_ name: String, _ email: String?, _ phone: String?) -> Void
    var onCancel: () -> Void = {}

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: CNContactPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onCancel: onCancel) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (String, String?, String?) -> Void
        let onCancel: () -> Void
        init(onPick: @escaping (String, String?, String?) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let name = CNContactFormatter.string(from: contact, style: .fullName) ?? "a friend"
            let email = contact.emailAddresses.first.map { String($0.value) }
            let phone = contact.phoneNumbers.first?.value.stringValue
            onPick(name, email, phone)
        }
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) { onCancel() }
    }
}
