import Foundation
import Supabase
import OSLog

/// Public-sky discoverability: one `active_flights` row per user (durable
/// state), heartbeat ~40 s + lifecycle edges — never per-second. Fetching
/// merges profile fields so pilots render with alias/skin/flag.
actor PublicFlightService {
    private var client: SupabaseClient? { SupabaseService.client }
    private var heartbeatTask: Task<Void, Never>?
    private var current: OnlinePresence?
    private var userID: String?

    func configure(userID: String?) { self.userID = userID }

    // MARK: Publishing

    func startPublishing(_ presence: OnlinePresence) {
        current = presence
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.pushHeartbeat()
                try? await Task.sleep(nanoseconds: UInt64(SupabaseConfig.presenceHeartbeatInterval * 1_000_000_000))
            }
        }
    }

    func setPaused(_ paused: Bool) async {
        guard current != nil else { return }
        current?.isPaused = paused
        await pushHeartbeat()
    }

    func heartbeatNow() async { await pushHeartbeat() }

    /// Stop publishing and delete the row (every termination path).
    func stopPublishing() async {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        current = nil
        guard let client, let userID else { return }
        _ = try? await client.from("active_flights").delete()
            .eq("user_id", value: userID).execute()
    }

    private func pushHeartbeat() async {
        guard let client, let presence = current, let userID else { return }
        struct Upsert: Encodable {
            let user_id: String
            let client_session_id: String
            let sky_id: String
            let balloon_skin_id: String
            let session_kind: String
            let focus_category: String
            let started_at: String
            let expected_end_at: String?
            let paused_at: String?
            let status: String
            let last_heartbeat_at: String
            let expires_at: String
        }
        let row = Upsert(user_id: userID,
                         // Binds this Global session row to its stable client id so
                         // the promotion RPC can prove the session is the caller's.
                         client_session_id: presence.sessionID,
                         sky_id: presence.skyID,
                         balloon_skin_id: presence.balloonSkinID,
                         session_kind: presence.mode == .privateRoom ? "room" : "public",
                         focus_category: presence.focusCategory,
                         started_at: PostgresDate.string(presence.startedAt),
                         expected_end_at: presence.expectedEndAt.map(PostgresDate.string),
                         paused_at: presence.isPaused ? PostgresDate.string(Date()) : nil,
                         status: "active",
                         last_heartbeat_at: PostgresDate.string(Date()),
                         expires_at: PostgresDate.string(Date().addingTimeInterval(13 * 3600)))
        do {
            try await client.from("active_flights").upsert(row, onConflict: "user_id").execute()
        } catch {
            SupabaseService.log.error("flight heartbeat failed: \(OnlineError.category(for: error), privacy: .public)")
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
                    hasLiveSession: true))
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
                           allowsFriendRequest: true, hasLiveSession: true)
    }
}
