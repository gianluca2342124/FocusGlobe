import Foundation
import CloudKit

/// Central CloudKit configuration — the ONLY place the container identifier
/// lives. Never use `CKContainer.default()` for FocusGlobe Online.
enum CloudKitConfig {
    static let containerIdentifier = "iCloud.com.mobitegames.FocusGlobe"

    static let presenceHeartbeatInterval: TimeInterval = 45
    static let presenceStaleInterval: TimeInterval = 120
    static let publicRefreshInterval: TimeInterval = 35

    /// The private custom zone that hosts shareable focus rooms.
    static let roomsZoneName = "FocusGlobeRoomsZone"

    static var container: CKContainer {
        CKContainer(identifier: containerIdentifier)
    }

    // Record type names (single source of truth; see
    // Documentation/FocusGlobeOnlineCloudKitSchema.md).
    enum RecordType {
        static let identity = "FocusIdentity"
        static let publicProfile = "PublicProfile"
        static let presence = "SkyPresence"
        static let friendRequest = "FriendRequest"
        static let friendConnection = "FriendConnection"
        static let room = "FocusRoom"
        static let roomParticipant = "RoomParticipant"
        static let roomFlightSession = "RoomFlightSession"
        static let unlockCampaign = "SkyUnlockCampaign"
    }
}
