import Foundation
import Supabase
import OSLog

/// Private focus rooms on Supabase. Every mutation goes through a SECURITY
/// DEFINER RPC (create / invite / join / ready / start / leave / remove /
/// close) — the client can never write room state directly. Invite tokens are
/// returned exactly once by the server and never stored anywhere but the URL
/// handed to the share sheet.
actor RoomService {
    private var client: SupabaseClient? { SupabaseService.client }

    struct CreatedRoom: Sendable {
        var room: FocusRoom
        var members: [RoomParticipant]
    }

    /// Create (or reuse the fresh lobby of) a private room. The returned
    /// room's `shareURL` carries a REAL one-time invite token from the server —
    /// the room is never "ready" without it.
    func createRoom(skyID: String, durationSeconds: Int?, purpose: FocusRoom.Purpose,
                    myID: String) async throws -> CreatedRoom {
        guard let client else { throw OnlineError.unavailable(.projectUnavailable) }
        struct Params: Encodable {
            let p_sky_id: String
            let p_duration_seconds: Int?
            let p_purpose: String
        }
        do {
            let payload: RoomBundlePayload = try await client
                .rpc("create_private_room",
                     params: Params(p_sky_id: skyID,
                                    p_duration_seconds: durationSeconds,
                                    p_purpose: purpose == .skyUnlock ? "sky_unlock" : "flight"))
                .execute().value
            var room = payload.room.room(myID: myID)
            guard let token = payload.inviteToken,
                  let url = SupabaseConfig.inviteURL(token: token) else {
                SupabaseService.log.error("createRoom: server returned no invite token [rpc=create_private_room]")
                throw OnlineError.roomUnavailable
            }
            room.shareURL = url
            let active = room.status == .active
            let members = (payload.members ?? []).map { $0.participant(roomID: room.id, roomActive: active) }
            SupabaseService.log.log("createRoom OK room=\(room.id, privacy: .public) purpose=\(room.purpose.rawValue, privacy: .public)")
            return CreatedRoom(room: room, members: members)
        } catch {
            SupabaseService.log.error("createRoom FAILED: \(OnlineError.detail(for: error), privacy: .public) [rpc=create_private_room sky=\(skyID, privacy: .public)]")
            throw error
        }
    }

    /// A fresh invite URL for an existing owned room (tokens are hashed
    /// server-side, so re-opening the sheet mints a new one).
    func freshInviteURL(roomID: String) async throws -> URL {
        guard let client else { throw OnlineError.unavailable(.projectUnavailable) }
        struct Params: Encodable { let p_room_id: String }
        let payload: InvitePayload = try await client
            .rpc("create_room_invite", params: Params(p_room_id: roomID))
            .execute().value
        guard let url = SupabaseConfig.inviteURL(token: payload.inviteToken) else {
            throw OnlineError.roomUnavailable
        }
        return url
    }

    /// Join a room from an invitation token (deep link).
    func joinRoom(token: String, myID: String) async throws -> CreatedRoom {
        guard let client else { throw OnlineError.unavailable(.projectUnavailable) }
        struct Params: Encodable { let p_raw_token: String }
        let payload: RoomBundlePayload = try await client
            .rpc("join_room_by_token", params: Params(p_raw_token: token))
            .execute().value
        let room = payload.room.room(myID: myID)
        let members = (payload.members ?? []).map {
            $0.participant(roomID: room.id, roomActive: room.status == .active)
        }
        return CreatedRoom(room: room, members: members)
    }

    func setReady(roomID: String, ready: Bool) async throws {
        guard let client else { throw OnlineError.unavailable(.projectUnavailable) }
        struct Params: Encodable { let p_room_id: String; let p_ready: Bool }
        try await client.rpc("set_room_ready", params: Params(p_room_id: roomID, p_ready: ready)).execute()
    }

    /// Owner starts the shared flight; the server stamps the canonical
    /// starts_at and creates every member's online session row.
    func startRoom(roomID: String, myID: String) async throws -> CreatedRoom {
        guard let client else { throw OnlineError.unavailable(.projectUnavailable) }
        struct Params: Encodable { let p_room_id: String }
        let payload: RoomBundlePayload = try await client
            .rpc("start_private_room", params: Params(p_room_id: roomID))
            .execute().value
        let room = payload.room.room(myID: myID)
        let members = (payload.members ?? []).map { $0.participant(roomID: room.id, roomActive: true) }
        return CreatedRoom(room: room, members: members)
    }

    func leaveRoom(roomID: String) async {
        guard let client else { return }
        struct Params: Encodable { let p_room_id: String }
        _ = try? await client.rpc("leave_private_room", params: Params(p_room_id: roomID)).execute()
    }

    func removeMember(roomID: String, userID: String) async {
        guard let client else { return }
        struct Params: Encodable { let p_room_id: String; let p_user_id: String }
        _ = try? await client.rpc("remove_room_member",
                                  params: Params(p_room_id: roomID, p_user_id: userID)).execute()
    }

    func closeRoom(roomID: String) async {
        guard let client else { return }
        struct Params: Encodable { let p_room_id: String }
        _ = try? await client.rpc("close_private_room", params: Params(p_room_id: roomID)).execute()
    }

    /// Member heartbeat while in a lobby/flight (direct column-granted update).
    func heartbeat(roomID: String, myID: String) async {
        guard let client else { return }
        _ = try? await client.from("room_members")
            .update(["last_heartbeat_at": PostgresDate.string(Date())])
            .eq("room_id", value: roomID)
            .eq("user_id", value: myID)
            .execute()
    }

    // MARK: Reads

    /// My open rooms (owned and joined), reconciled from the database.
    func myRooms(myID: String) async -> (owned: [FocusRoom], joined: [FocusRoom]) {
        guard let client else { return ([], []) }
        struct RoomRow: Codable {
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
        guard let rows: [RoomRow] = try? await client.from("focus_rooms")
            .select()
            .filter("status", operator: "in", value: "(lobby,active)")
            .gte("expires_at", value: PostgresDate.string(Date()))
            .order("created_at", ascending: false)
            .limit(25)
            .execute().value else { return ([], []) }
        var owned: [FocusRoom] = []
        var joined: [FocusRoom] = []
        for row in rows {
            let payload = RoomPayload(id: row.id, ownerID: row.ownerID, skyID: row.skyID,
                                      purpose: row.purpose, status: row.status,
                                      durationSeconds: row.durationSeconds, maxMembers: row.maxMembers,
                                      startsAt: row.startsAt, endsAt: row.endsAt,
                                      createdAt: row.createdAt, expiresAt: row.expiresAt)
            let room = payload.room(myID: myID)
            if room.isOwned { owned.append(room) } else { joined.append(room) }
        }
        return (owned, joined)
    }

    /// Live members of a room (RLS: members only) merged with profile fields.
    func participants(roomID: String, roomActive: Bool) async -> [RoomParticipant] {
        guard let client else { return [] }
        guard let rows: [RoomMemberRow] = try? await client.from("room_members")
            .select()
            .eq("room_id", value: roomID)
            .eq("status", value: "joined")
            .order("joined_at", ascending: true)
            .limit(16)
            .execute().value, !rows.isEmpty else { return [] }
        let ids = rows.map(\.userID)
        let list = "(\(ids.joined(separator: ",")))"
        let profiles: [ProfileRow] = (try? await client.from("profiles")
            .select().filter("id", operator: "in", value: list)
            .execute().value) ?? []
        let byID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        return rows.map { row in
            let profile = byID[row.userID]
            let heartbeat = PostgresDate.parse(row.lastHeartbeatAt)
            let fresh = heartbeat.map { Date().timeIntervalSince($0) < SupabaseConfig.presenceStaleInterval } ?? false
            let status: RoomParticipant.Status = (roomActive && fresh) ? .flying : (row.isReady ? .ready : .joined)
            return RoomParticipant(id: "\(row.roomID)_\(row.userID)",
                                   roomPublicID: row.roomID,
                                   publicID: row.userID,
                                   displayName: profile?.publicAlias ?? "Sky Pilot",
                                   balloonSkinID: profile?.balloonSkinID ?? "default",
                                   countryCode: profile?.countryCode,
                                   joinedAt: PostgresDate.parse(row.joinedAt) ?? Date(),
                                   status: status,
                                   readyAt: nil,
                                   activeSessionID: nil,
                                   lastHeartbeatAt: heartbeat)
        }
    }

    /// One room by id (reconnect reconciliation).
    func room(id: String, myID: String) async -> FocusRoom? {
        let (owned, joined) = await myRooms(myID: myID)
        return (owned + joined).first { $0.id == id }
    }

    /// My active server session for a started room (created by start RPC).
    func mySession(roomID: String, myID: String) async -> String? {
        guard let client else { return nil }
        guard let rows: [OnlineSessionRow] = try? await client.from("online_sessions")
            .select()
            .eq("room_id", value: roomID)
            .eq("user_id", value: myID)
            .eq("status", value: "active")
            .order("started_at", ascending: false)
            .limit(1)
            .execute().value else { return nil }
        return rows.first?.id
    }

    /// Verified sky-unlock campaign progress (distinct real joins, owner
    /// excluded — server-computed).
    func campaignProgress(skyID: String) async -> Int? {
        guard let client else { return nil }
        struct Params: Encodable { let p_sky_id: String }
        return try? await client.rpc("campaign_progress", params: Params(p_sky_id: skyID))
            .execute().value
    }
}
