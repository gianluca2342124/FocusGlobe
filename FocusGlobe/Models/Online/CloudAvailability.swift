import Foundation

/// The app-level view of CloudKit availability. Online features render from
/// this; Solo flights never consult it.
enum CloudAvailability: Equatable, Sendable {
    case checking
    case available
    case noAccount
    case restricted
    case networkUnavailable
    case temporarilyUnavailable

    var isAvailable: Bool { self == .available }

    /// A short, friendly explanation (never a raw CloudKit error).
    var userMessage: String {
        switch self {
        case .checking:               return "Checking iCloud…"
        case .available:              return "Online"
        case .noAccount:              return "Online flights require an active iCloud account."
        case .restricted:             return "iCloud is restricted on this device."
        case .networkUnavailable:     return "No internet connection."
        case .temporarilyUnavailable: return "Online is temporarily unavailable."
        }
    }
}
