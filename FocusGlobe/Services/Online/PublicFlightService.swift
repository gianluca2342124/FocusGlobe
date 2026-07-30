import Foundation
import Supabase
import OSLog

/// Public-sky discoverability: one `active_flights` row per user (durable
/// state), heartbeat ~35 s + lifecycle edges — never per-second. All timing is
/// SERVER-CANONICAL: the row is created/refreshed through `publish_global_flight`
/// / `heartbeat_global_flight` (the server stamps started_at / expected_end_at),
/// never a direct client upsert. Fetching merges profile fields so pilots render
/// with alias/skin/flag.
actor PublicFlightService {
    private var client: SupabaseClient? { SupabaseService.client }
    private var current: OnlinePresence?
    private var userID: String?

    /// Canonical timing returned by the publish / heartbeat RPCs, plus the
    /// server clock at response — everything the model needs to anchor the host
    /// timer and the shared clock. `requestStartedAt` is stamped by the CALLER.
    struct FlightPublishResult: Sendable {
        let serverNow: Date?
        let startedAt: Date?
        let expectedEndAt: Date?
        /// The server's authoritative pause state for MY row.
        var isPaused: Bool = false
        /// The remaining seconds the server froze when this flight paused.
        var pausedRemainingSeconds: Int? = nil
    }

    func configure(userID: String?) { self.userID = userID }

    // MARK: Publishing (server-canonical)

    /// The session id whose canonical `active_flights` row the SERVER has
    /// confirmed. Set only by a successful publish/heartbeat, cleared when the row
    /// is deleted.
    ///
    /// This exists because the app used to treat its own locally-minted
    /// `flightSessionID` as proof that the server row existed. It is not: the
    /// publish RPC runs in a detached task, is never awaited, and returns nil on
    /// failure with nothing observing it. Invite Friends then promoted a session
    /// the server had never heard of and got `no_active_global_session`.
    private var publishedSessionID: String?

    /// Whether the server has confirmed a row for this exact journey.
    func isPublished(_ sessionID: String) -> Bool { publishedSessionID == sessionID }

    /// The room this participant session is bound to, once the journey has been
    /// promoted to (or joined as) a private flight. Retained so every subsequent
    /// publish — including the heartbeat's `no_active_global_session` self-heal —
    /// re-asserts `session_kind = 'room'`. Without it a self-heal would silently
    /// republish a private flight back into Public Sky discovery.
    private var boundRoomID: String?

    /// Bind the caller's OWN live session to a room WITHOUT destroying it.
    ///
    /// This replaces `stopPublishing()` on promotion. The row is converted, not
    /// deleted: it leaves public discovery (the public RLS branch requires
    /// `session_kind = 'public'`) and becomes visible to that room's co-members,
    /// keeping its start, deadline and pause state. Deleting it was what left
    /// private flights with no authoritative timer and made pause a silent no-op.
    /// Record the room binding WITHOUT issuing an RPC, so the next publish carries
    /// `session_kind = 'room'` from the start (used when a session must be created
    /// already bound rather than converted).
    func noteRoomBinding(_ roomID: String) { boundRoomID = roomID }

    @discardableResult
    func bindToRoom(_ roomID: String) async -> FlightPublishResult? {
        boundRoomID = roomID
        guard let client, let presence = current else {
            // No live presence to convert — the caller repairs by publishing.
            return nil
        }
        struct Params: Encodable { let p_client_session_id: String; let p_room_id: String }
        do {
            let p: Payload = try await client
                .rpc("bind_flight_session_to_room",
                     params: Params(p_client_session_id: presence.sessionID, p_room_id: roomID))
                .execute().value
            publishedSessionID = presence.sessionID
            #if DEBUG
            SupabaseService.log.debug("online: participant session bound to private room")
            #endif
            return Self.result(from: p, fallbackPaused: presence.isPaused)
        } catch {
            SupabaseService.log.error("flight room bind failed: \(OnlineError.category(for: error), privacy: .public)")
            #if DEBUG
            SupabaseService.log.debug("online: bind detail \(OnlineError.detail(for: error), privacy: .public)")
            #endif
            // Fall back to a full publish that carries the room binding, so a
            // missing row is repaired rather than leaving the pilot timerless.
            return await ensurePublished(presence)
        }
    }

    /// The shared decode for every session-writing RPC — they all return the same
    /// canonical envelope, so there is exactly one place that reads it.
    struct Payload: Decodable {
        let server_now: String?
        let started_at: String?
        let expected_end_at: String?
        let is_paused: Bool?
        let paused_remaining_seconds: Int?
    }

    private static func result(from p: Payload, fallbackPaused: Bool) -> FlightPublishResult {
        FlightPublishResult(serverNow: PostgresDate.parse(p.server_now),
                            startedAt: PostgresDate.parse(p.started_at),
                            expectedEndAt: PostgresDate.parse(p.expected_end_at),
                            isPaused: p.is_paused ?? fallbackPaused,
                            pausedRemainingSeconds: p.paused_remaining_seconds)
    }

    /// Create (or refresh) the canonical Global-flight row. The SERVER stamps
    /// started_at / expected_end_at; we only pass the intended duration (a
    /// clock-skew-immune delta) and Sky. Returns the canonical timing so the host
    /// timer can adopt the exact server deadline.
    func startPublishing(_ presence: OnlinePresence) async -> FlightPublishResult? {
        current = presence
        return await publish(presence)
    }

    /// Guarantee a canonical server row for `presence`, retrying a few times with
    /// a short backoff. Idempotent: returns immediately once the server has
    /// confirmed this session, so repeated Invite taps never publish twice.
    ///
    /// Takes the presence as an argument rather than relying on `current`, because
    /// `current` is nil on exactly the paths that used to make recovery
    /// impossible (a private-room flight that never published, or a
    /// discoverability toggle that cleared it) — `republish()` silently no-opped
    /// there and the invite could never succeed.
    @discardableResult
    func ensurePublished(_ presence: OnlinePresence, attempts: Int = 3) async -> FlightPublishResult? {
        if current == nil { current = presence }
        for attempt in 0..<max(1, attempts) {
            if let result = await publish(presence) { return result }
            // 0.4 s, 0.8 s — short enough that Invite still feels immediate.
            if attempt + 1 < attempts {
                try? await Task.sleep(nanoseconds: UInt64(400_000_000 * (attempt + 1)))
            }
        }
        return nil
    }

    /// Re-publish the current presence (recovery path: e.g. the promotion RPC
    /// could not yet see the canonical row). Preserves timing for the same
    /// session id server-side.
    @discardableResult
    func republish() async -> FlightPublishResult? {
        guard let presence = current else { return nil }
        return await publish(presence)
    }

    @discardableResult
    func setPaused(_ paused: Bool) async -> FlightPublishResult? {
        guard current != nil else { return nil }
        current?.isPaused = paused
        return await heartbeatNow()
    }

    /// One lightweight liveness ping (server_now + canonical timing). Falls back
    /// to a full re-publish if the row has vanished (never fabricates timing).
    @discardableResult
    func heartbeatNow() async -> FlightPublishResult? {
        guard let client, let presence = current else { return nil }
        struct Params: Encodable { let p_client_session_id: String; let p_is_paused: Bool }
        do {
            let p: Payload = try await client
                .rpc("heartbeat_global_flight",
                     params: Params(p_client_session_id: presence.sessionID, p_is_paused: presence.isPaused))
                .execute().value
            // A successful heartbeat proves the canonical row exists. It never
            // writes session_kind, so it is correct for room sessions unchanged.
            publishedSessionID = presence.sessionID
            return Self.result(from: p, fallbackPaused: presence.isPaused)
        } catch {
            if OnlineError.isNoActiveGlobalSession(error) {
                publishedSessionID = nil
                return await publish(presence)
            }
            SupabaseService.log.error("flight heartbeat failed: \(OnlineError.category(for: error), privacy: .public)")
            return nil
        }
    }

    /// Stop publishing and delete the row (every termination path).
    func stopPublishing() async {
        current = nil
        publishedSessionID = nil
        boundRoomID = nil
        guard let client, let userID else { return }
        _ = try? await client.from("active_flights").delete()
            .eq("user_id", value: userID).execute()
    }

    private func publish(_ presence: OnlinePresence) async -> FlightPublishResult? {
        guard let client else { return nil }
        // Intended focus length as a RELATIVE delta (both timestamps come from the
        // same client clock, so their difference is skew-immune); the server owns
        // the absolute start. Infinite flights carry no end.
        let isInfinite = presence.expectedEndAt == nil
        let duration = presence.expectedEndAt.map {
            max(1, Int($0.timeIntervalSince(presence.startedAt).rounded()))
        } ?? 0
        struct Params: Encodable {
            let p_client_session_id: String
            let p_sky_id: String
            let p_balloon_skin_id: String
            let p_focus_category: String
            let p_duration_seconds: Int
            let p_is_infinite: Bool
            let p_is_paused: Bool
            let p_sound_id: String?
            let p_room_id: String?
        }
        do {
            // `publish_flight_session` supersedes `publish_global_flight`: it is the
            // ONE writer for both journey kinds. Passing the bound room keeps a
            // private flight private on every republish — the old RPC hardcoded
            // session_kind = 'public', so a heartbeat self-heal would have quietly
            // pushed a private participant back into Public Sky discovery.
            let p: Payload = try await client
                .rpc("publish_flight_session",
                     params: Params(p_client_session_id: presence.sessionID,
                                    p_sky_id: presence.skyID,
                                    p_balloon_skin_id: presence.balloonSkinID,
                                    p_focus_category: presence.focusCategory,
                                    p_duration_seconds: duration,
                                    p_is_infinite: isInfinite,
                                    p_is_paused: presence.isPaused,
                                    p_sound_id: presence.soundID,
                                    p_room_id: boundRoomID))
                .execute().value
            // The ONLY place a session is marked as existing on the server.
            publishedSessionID = presence.sessionID
            #if DEBUG
            SupabaseService.log.debug("online: canonical session published")
            #endif
            return Self.result(from: p, fallbackPaused: presence.isPaused)
        } catch {
            // The coarse category alone hid the real cause (e.g. PGRST202 when the
            // deployed RPC signature is stale), so a permanently-failing publish
            // looked identical to a transient blip. The detail is DEBUG-only — it
            // can carry backend specifics that don't belong in Release logs.
            SupabaseService.log.error("flight publish failed: \(OnlineError.category(for: error), privacy: .public)")
            #if DEBUG
            SupabaseService.log.debug("online: publish detail \(OnlineError.detail(for: error), privacy: .public)")
            #endif
            return nil
        }
    }

    // MARK: Fetching pilots

    /// The ONE mapping from an authoritative `active_flights` row to a pilot.
    /// Public Sky and private rooms share it, so their countdown and pause state
    /// can never drift apart.
    ///
    /// `sessionID` is the pilot's stable participant-session id (falling back to
    /// the user id only for rows written before that column existed) — not the
    /// user id, so the same account taking off on a NEW flight is correctly seen
    /// as a new arrival rather than the old one continuing.
    private static func pilot(from flight: ActiveFlightRow,
                              profile: ProfileRow?,
                              heartbeat: Date) -> OnlinePilot {
        OnlinePilot(
            id: flight.userID,
            sessionID: flight.clientSessionID ?? flight.userID,
            displayName: profile?.publicAlias ?? "Sky Pilot",
            countryCode: profile?.countryCode,
            balloonSkinID: flight.balloonSkinID,
            skyID: flight.skyID,
            startedAt: PostgresDate.parse(flight.startedAt) ?? heartbeat,
            expectedEndAt: PostgresDate.parse(flight.expectedEndAt),
            lastHeartbeatAt: heartbeat,
            isPaused: flight.pausedAt != nil,
            pausedRemainingSeconds: flight.pausedRemainingSeconds,
            focusCategory: flight.focusCategory,
            allowsFriendRequest: profile?.allowFriendRequests ?? true,
            hasLiveSession: true,
            soundID: flight.soundID)
    }

    /// The REAL participants of a private room, read from their own authoritative
    /// `active_flights` rows.
    ///
    /// Private-room pilots used to be synthesised from `members_payload`, which
    /// carries no timing at all — so every member displayed the ROOM-WIDE
    /// `focus_rooms.ends_at` and a hardcoded `isPaused: false`. That is one shared
    /// clock for everybody, the precise opposite of per-pilot pause. These rows
    /// carry each pilot's own `expected_end_at`, `paused_at` and
    /// `paused_remaining_seconds`.
    ///
    /// No membership filter is needed here: the deployed `active_flights` SELECT
    /// policy already restricts room-kind rows to `in_same_active_room(...)` and
    /// excludes blocked pairs, so RLS returns exactly this room's co-members.
    func fetchRoomPilots(roomID: String, excluding publicID: String?, limit: Int = 24) async -> [OnlinePilot] {
        guard let client else { return [] }
        let cutoff = Date().addingTimeInterval(-SupabaseConfig.presenceStaleInterval)
        do {
            let flights: [ActiveFlightRow] = try await client.from("active_flights")
                .select()
                .eq("session_kind", value: "room")
                .eq("room_id", value: roomID)
                .eq("status", value: "active")
                .gte("last_heartbeat_at", value: PostgresDate.string(cutoff))
                .order("last_heartbeat_at", ascending: false)
                .limit(limit)
                .execute().value
            let others = flights.filter { $0.userID != publicID }
            guard !others.isEmpty else { return [] }
            let profiles: [ProfileRow] = (try? await client.from("profiles")
                .select().in("id", values: others.map(\.userID))
                .execute().value) ?? []
            let byID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
            var seen = Set<String>()
            var pilots: [OnlinePilot] = []
            for flight in others {
                guard !seen.contains(flight.userID),
                      let heartbeat = PostgresDate.parse(flight.lastHeartbeatAt) else { continue }
                seen.insert(flight.userID)
                pilots.append(Self.pilot(from: flight, profile: byID[flight.userID], heartbeat: heartbeat))
            }
            return pilots
        } catch {
            SupabaseService.log.error("room pilot fetch failed: \(OnlineError.category(for: error), privacy: .public)")
            return []
        }
    }


    /// Fresh, discoverable pilots in a Sky (excluding self). RLS already
    /// filters blocked pairs and non-discoverable profiles server-side.
    func fetchPilots(skyID: String, excluding publicID: String?, limit: Int = 24) async -> [OnlinePilot] {
        guard let client else { return [] }
        let cutoff = Date().addingTimeInterval(-SupabaseConfig.presenceStaleInterval)
        do {
            let flights: [ActiveFlightRow] = try await client.from("active_flights")
                .select()
                .eq("sky_id", value: skyID)
                .eq("status", value: "active")
                .gte("last_heartbeat_at", value: PostgresDate.string(cutoff))
                .order("last_heartbeat_at", ascending: false)
                .limit(limit)
                .execute().value
            // NEVER render myself as a remote pilot (self-filter by auth UUID).
            let others = flights.filter { $0.userID != publicID }
            guard !others.isEmpty else { return [] }
            let profiles: [ProfileRow] = (try? await client.from("profiles")
                .select().in("id", values: others.map(\.userID))
                .execute().value) ?? []
            let byID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
            var seen = Set<String>()
            var pilots: [OnlinePilot] = []
            for flight in others {
                guard !seen.contains(flight.userID),
                      let heartbeat = PostgresDate.parse(flight.lastHeartbeatAt) else { continue }
                seen.insert(flight.userID)
                pilots.append(Self.pilot(from: flight, profile: byID[flight.userID], heartbeat: heartbeat))
            }
            return pilots
        } catch {
            SupabaseService.log.error("pilot fetch failed: \(OnlineError.category(for: error), privacy: .public)")
            return []
        }
    }

    /// One pilot's live flight (for the Crew "Focusing now" badge).
    func activeFlight(of publicID: String) async -> OnlinePilot? {
        await fetchSingle(publicID: publicID)
    }

    private func fetchSingle(publicID: String) async -> OnlinePilot? {
        guard let client else { return nil }
        let cutoff = Date().addingTimeInterval(-SupabaseConfig.presenceStaleInterval)
        guard let flights: [ActiveFlightRow] = try? await client.from("active_flights")
            .select()
            .eq("user_id", value: publicID)
            .eq("status", value: "active")
            .gte("last_heartbeat_at", value: PostgresDate.string(cutoff))
            .limit(1)
            .execute().value,
            let flight = flights.first,
            let heartbeat = PostgresDate.parse(flight.lastHeartbeatAt) else { return nil }
        return OnlinePilot(id: flight.userID, sessionID: flight.userID,
                           displayName: "", countryCode: nil,
                           balloonSkinID: flight.balloonSkinID, skyID: flight.skyID,
                           startedAt: PostgresDate.parse(flight.startedAt) ?? heartbeat,
                           expectedEndAt: PostgresDate.parse(flight.expectedEndAt),
                           lastHeartbeatAt: heartbeat,
                           isPaused: flight.pausedAt != nil,
                           pausedRemainingSeconds: flight.pausedRemainingSeconds,
                           focusCategory: flight.focusCategory,
                           allowsFriendRequest: true, hasLiveSession: true,
                           soundID: flight.soundID)
    }

    // MARK: Applause (server-authorized)

    /// The server-authoritative outcome of a send_applause call.
    enum ApplauseResult: Sendable {
        case sent               // accepted + written by the server
        case cooldown           // 45s per-pair server cooldown
        case recipientNotFlying // recipient not a live, visible pilot anymore
        case notFlying          // sender isn't in a live public flight
        case unavailable        // network / unknown — never claimed as delivered
    }

    /// Ask the server to record one applause for `recipientID`. ALL authority is
    /// server-side: auth.uid() is the sender, the alias is filled by the RPC, and
    /// the cooldown / co-presence / self checks run in Postgres. Returns the real
    /// outcome — never optimistically "sent" on failure.
    func sendApplause(to recipientID: String) async -> ApplauseResult {
        guard let client else { return .unavailable }
        struct Params: Encodable { let p_recipient: String }
        do {
            _ = try await client.rpc("send_applause", params: Params(p_recipient: recipientID)).execute()
            return .sent
        } catch {
            switch OnlineError.serverToken(from: error) {
            case "applause_cooldown":                 return .cooldown
            case "recipient_not_flying":              return .recipientNotFlying
            case "not_flying":                        return .notFlying
            case "applause_self", "invalid_recipient", "blocked":
                return .recipientNotFlying   // treated as "can't applaud them"
            default:
                return .unavailable
            }
        }
    }

    /// Fetch applause addressed to ME created after `date`. RLS guarantees only
    /// my own rows return; the alias is the server-written `sender_alias`.
    func fetchApplause(after date: Date) async -> [(alias: String, at: Date)] {
        guard let client else { return [] }
        struct Row: Decodable { let sender_alias: String; let created_at: String }
        do {
            let rows: [Row] = try await client.from("applause_events")
                .select("sender_alias, created_at")
                .gt("created_at", value: PostgresDate.string(date))
                .order("created_at", ascending: true)
                .execute().value
            return rows.compactMap { row in
                guard let at = PostgresDate.parse(row.created_at) else { return nil }
                return (row.sender_alias, at)
            }
        } catch {
            return []
        }
    }
}
