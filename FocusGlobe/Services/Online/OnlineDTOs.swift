import Foundation

/// Wire types for the Supabase backend. Every struct declares explicit
/// snake_case CodingKeys and decodes timestamps as strings (parsed via
/// `PostgresDate`) so decoding never depends on a library date strategy.

// MARK: - Table rows

struct ProfileRow: Codable, Sendable {
    let id: String
    var publicAlias: String
    var countryCode: String?
    var balloonSkinID: String
    var isDiscoverable: Bool
    var allowFriendRequests: Bool
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case publicAlias = "public_alias"
        case countryCode = "country_code"
        case balloonSkinID = "balloon_skin_id"
        case isDiscoverable = "is_discoverable"
        case allowFriendRequests = "allow_friend_requests"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ActiveFlightRow: Codable, Sendable {
    let userID: String
    var skyID: String
    var balloonSkinID: String
    var sessionKind: String
    var focusCategory: String
    var startedAt: String
    var expectedEndAt: String?
    var pausedAt: String?
    var status: String
    var lastHeartbeatAt: String
    var expiresAt: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case skyID = "sky_id"
        case balloonSkinID = "balloon_skin_id"
        case sessionKind = "session_kind"
        case focusCategory = "focus_category"
        case startedAt = "started_at"
        case expectedEndAt = "expected_end_at"
        case pausedAt = "paused_at"
        case status
        case lastHeartbeatAt = "last_heartbeat_at"
        case expiresAt = "expires_at"
    }
}

struct FriendRequestRow: Codable, Sendable {
    let id: String
    let senderID: String
    let receiverID: String
    var status: String
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case senderID = "sender_id"
        case receiverID = "receiver_id"
        case status
        case createdAt = "created_at"
    }
}

struct FriendshipRow: Codable, Sendable {
    let userLow: String
    let userHigh: String
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case userLow = "user_low"
        case userHigh = "user_high"
        case createdAt = "created_at"
    }
}

struct RoomMemberRow: Codable, Sendable {
    let roomID: String
    let userID: String
    var role: String
    var status: String
    var isReady: Bool
    var joinedAt: String?
    var lastHeartbeatAt: String?

    enum CodingKeys: String, CodingKey {
        case roomID = "room_id"
        case userID = "user_id"
        case role
        case status
        case isReady = "is_ready"
        case joinedAt = "joined_at"
        case lastHeartbeatAt = "last_heartbeat_at"
    }
}

// MARK: - RPC payloads

struct RoomPayload: Codable, Sendable {
    let id: String
    let ownerID: String
    let skyID: String
    let purpose: String
    let status: String
    let durationSeconds: Int?
    let maxMembers: Int
    let startsAt: String?
    let endsAt: String?
    let createdAt: String?
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case skyID = "sky_id"
        case purpose, status
        case durationSeconds = "duration_seconds"
        case maxMembers = "max_members"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }
}

struct MemberPayload: Codable, Sendable {
    let userID: String
    let role: String
    let status: String
    let isReady: Bool
    let joinedAt: String?
    let lastHeartbeatAt: String?
    let alias: String?
    let balloonSkinID: String?
    let countryCode: String?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case role, status
        case isReady = "is_ready"
        case joinedAt = "joined_at"
        case lastHeartbeatAt = "last_heartbeat_at"
        case alias
        case balloonSkinID = "balloon_skin_id"
        case countryCode = "country_code"
    }
}

/// `create_private_room` / `join_room_by_token` / `start_private_room`.
struct RoomBundlePayload: Codable, Sendable {
    let room: RoomPayload
    let members: [MemberPayload]?
    let inviteToken: String?

    enum CodingKeys: String, CodingKey {
        case room, members
        case inviteToken = "invite_token"
    }
}

struct InvitePayload: Codable, Sendable {
    let inviteToken: String
    enum CodingKeys: String, CodingKey { case inviteToken = "invite_token" }
}

struct SessionCompletionPayload: Codable, Sendable {
    let focusedSeconds: Int
    let friendBonus: Bool
    let amount: Int

    enum CodingKeys: String, CodingKey {
        case focusedSeconds = "focused_seconds"
        case friendBonus = "friend_bonus"
        case amount
    }
}

struct OnlineSessionRow: Codable, Sendable {
    let id: String
    let roomID: String?
    let userID: String
    var status: String

    enum CodingKeys: String, CodingKey {
        case id
        case roomID = "room_id"
        case userID = "user_id"
        case status
    }
}

// MARK: - Model mapping

extension RoomPayload {
    func room(myID: String?) -> FocusRoom {
        FocusRoom(id: id,
                  ownerPublicID: ownerID,
                  title: purpose == "sky_unlock" ? "Sky invitation" : "FocusGlobe Flight",
                  skyID: skyID,
                  createdAt: PostgresDate.parse(createdAt) ?? Date(),
                  expiresAt: PostgresDate.parse(expiresAt),
                  maximumParticipants: maxMembers,
                  status: FocusRoom.Status(serverStatus: status),
                  allowsLateJoin: true,
                  purpose: purpose == "sky_unlock" ? .skyUnlock : .flight,
                  startedAt: PostgresDate.parse(startsAt),
                  isOwned: myID != nil && ownerID == myID,
                  shareURL: nil)
    }
}

extension MemberPayload {
    func participant(roomID: String, roomActive: Bool) -> RoomParticipant {
        let heartbeat = PostgresDate.parse(lastHeartbeatAt)
        let fresh = heartbeat.map { Date().timeIntervalSince($0) < SupabaseConfig.presenceStaleInterval } ?? false
        let state: RoomParticipant.Status = (roomActive && fresh) ? .flying : (isReady ? .ready : .joined)
        return RoomParticipant(id: "\(roomID)_\(userID)",
                               roomPublicID: roomID,
                               publicID: userID,
                               displayName: alias ?? "Sky Pilot",
                               balloonSkinID: balloonSkinID ?? "default",
                               countryCode: countryCode,
                               joinedAt: PostgresDate.parse(joinedAt) ?? Date(),
                               status: state,
                               readyAt: nil,
                               activeSessionID: nil,
                               lastHeartbeatAt: heartbeat)
    }
}
