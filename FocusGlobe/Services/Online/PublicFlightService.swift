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
    }

    func configure(userID: String?) { self.userID = userID }

    // MARK: Publishing (server-canonical)

    /// Create (or refresh) the canonical Global-flight row. The SERVER stamps
    /// started_at / expected_end_at; we only pass the intended duration (a
    /// clock-skew-immune delta) and Sky. Returns the canonical timing so the host
    /// timer can adopt the exact server deadline.
    func startPublishing(_ presence: OnlinePresence) async -> FlightPublishResult? {
        current = presence
        return await publish(presence)
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
        struct Payload: Decodable {
            let server_now: String?; let started_at: String?; let expected_end_at: String?
        }
        do {
            let p: Payload = try await client
                .rpc("heartbeat_global_flight",
                     params: Params(p_client_session_id: presence.sessionID, p_is_paused: presence.isPaused))
                .execute().value
            return FlightPublishResult(serverNow: PostgresDate.parse(p.server_now),
                                       startedAt: PostgresDate.parse(p.started_at),
                                       expectedEndAt: PostgresDate.parse(p.expected_end_at))
        } catch {
            if OnlineError.isNoActiveGlobalSession(error) { return await publish(presence) }
            SupabaseService.log.error("flight heartbeat failed: \(OnlineError.category(for: error), privacy: .public)")
            return nil
        }
    }

    /// Stop publishing and delete the row (every termination path).
    func stopPublishing() async {
        current = nil
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
        }
        struct Payload: Decodable {
            let server_now: String?; let started_at: String?; let expected_end_at: String?
        }
        do {
            let p: Payload = try await client
                .rpc("publish_global_flight",
                     params: Params(p_client_session_id: presence.sessionID,
                                    p_sky_id: presence.skyID,
                                    p_balloon_skin_id: presence.balloonSkinID,
                                    p_focus_category: presence.focusCategory,
                                    p_duration_seconds: duration,
                                    p_is_infinite: isInfinite,
                                    p_is_paused: presence.isPaused,
                                    p_sound_id: presence.soundID))
                .execute().value
            return FlightPublishResult(serverNow: PostgresDate.parse(p.server_now),
                                       startedAt: PostgresDate.parse(p.started_at),
                                       expectedEndAt: PostgresDate.parse(p.expected_end_at))
        } catch {
            SupabaseService.log.error("flight publish failed: \(OnlineError.category(for: error), privacy: .public)")
            return nil
        }
    }

    // MARK: Fetching pilots

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
                let profile = byID[flight.userID]
                pilots.append(OnlinePilot(
                    id: flight.userID,
                    sessionID: flight.userID,
                    displayName: profile?.publicAlias ?? "Sky Pilot",
                    countryCode: profile?.countryCode,
                    balloonSkinID: flight.balloonSkinID,
                    skyID: flight.skyID,
                    startedAt: PostgresDate.parse(flight.startedAt) ?? heartbeat,
                    expectedEndAt: PostgresDate.parse(flight.expectedEndAt),
                    lastHeartbeatAt: heartbeat,
                    isPaused: flight.pausedAt != nil,
                    focusCategory: flight.focusCategory,
                    allowsFriendRequest: profile?.allowFriendRequests ?? true,
                    hasLiveSession: true,
                    soundID: flight.soundID))
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
