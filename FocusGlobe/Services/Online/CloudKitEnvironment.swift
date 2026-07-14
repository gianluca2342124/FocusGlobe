import Foundation
import CloudKit
import OSLog

/// Watches CloudKit account availability. Checked at launch, on foreground,
/// on `CKAccountChanged`, and before room create/accept. Failures degrade to
/// friendly states — never raw errors, never blocking Solo.
actor CloudKitEnvironment {
    static let log = Logger(subsystem: "com.focusglobe.app", category: "online")

    private var lastStatus: CloudAvailability = .checking

    func currentAvailability() async -> CloudAvailability {
        do {
            let status = try await CloudKitConfig.container.accountStatus()
            let availability: CloudAvailability
            switch status {
            case .available:              availability = .available
            case .noAccount:              availability = .noAccount
            case .restricted:             availability = .restricted
            case .couldNotDetermine:      availability = .temporarilyUnavailable
            case .temporarilyUnavailable: availability = .temporarilyUnavailable
            @unknown default:             availability = .temporarilyUnavailable
            }
            lastStatus = availability
            Self.log.info("cloud availability: \(String(describing: availability), privacy: .public)")
            return availability
        } catch {
            let category = OnlineError.category(for: error)
            Self.log.error("accountStatus failed: \(category, privacy: .public)")
            lastStatus = category == "network" ? .networkUnavailable : .temporarilyUnavailable
            return lastStatus
        }
    }
}
