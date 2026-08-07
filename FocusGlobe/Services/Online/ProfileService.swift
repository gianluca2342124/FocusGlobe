import Foundation
import Supabase

/// The user's own `profiles` row + lightweight profile reads for other pilots.
actor ProfileService {
    private var client: SupabaseClient? { SupabaseService.client }

    /// Fetch-or-create my profile. The canonical path is the SECURITY DEFINER
    /// `ensure_current_profile` RPC: it creates the `profiles` row for
    /// `auth.uid()` if missing and returns it, bypassing RLS entirely. This is
    /// what guarantees the `focus_rooms.owner_id` / `room_members.user_id`
    /// foreign-key target always exists before any room write (the signup
    /// trigger only fires on the first auth insert, which Apple re-sign-in
    /// skips). A legacy select-or-upsert path remains only for a database that
    /// predates the RPC.
    func ensureProfile(userID: String, defaults: OnlineProfile?) async throws -> OnlineProfile {
        guard let client else { throw OnlineError.unavailable(.projectUnavailable) }
        do {
            let row: ProfileRow = try await client.rpc("ensure_current_profile").execute().value
            return Self.profile(from: row)
        } catch {
            // Only fall back when the RPC itself is absent (pre-migration DB);
            // real failures (network/auth) must propagate so Online never
            // reports "ready" without a profile.
            guard OnlineError.isMissingFunction(error) else { throw error }
            return try await legacyEnsureProfile(client: client, userID: userID, defaults: defaults)
        }
    }

    /// Pre-RPC fallback: direct select, then upsert (subject to RLS).
    private func legacyEnsureProfile(client: SupabaseClient, userID: String,
                                     defaults: OnlineProfile?) async throws -> OnlineProfile {
        if let existing: ProfileRow = try? await client.from("profiles")
            .select().eq("id", value: userID).single().execute().value {
            return Self.profile(from: existing)
        }
        let alias = defaults?.displayName ?? OnlineProfile.generatedAlias()
        let row = ProfileRow(id: userID,
                             publicAlias: alias,
                             countryCode: defaults?.countryCode,
                             balloonSkinID: defaults?.balloonSkinID ?? "default",
                             isDiscoverable: defaults?.isDiscoverable ?? false,
                             allowFriendRequests: defaults?.allowsFriendRequests ?? true,
                             createdAt: nil, updatedAt: nil)
        try await client.from("profiles").upsert(row, onConflict: "id").execute()
        return Self.profile(from: row)
    }

    /// Push profile fields (alias/skin/toggles) — own row only per RLS.
    func updateProfile(_ profile: OnlineProfile) async throws {
        guard let client else { throw OnlineError.unavailable(.projectUnavailable) }
        // `public_alias` is DELIBERATELY absent. It is globally unique now, so a
        // plain UPDATE on it can raise a constraint violation and would take
        // this settings push — skin, country, toggles — down with it. Names
        // change through `claimAlias` and nowhere else.
        struct Update: Encodable {
            let country_code: String?
            let balloon_skin_id: String
            let is_discoverable: Bool
            let allow_friend_requests: Bool
            let last_seen_at: String
        }
        try await client.from("profiles")
            .update(Update(country_code: profile.countryCode,
                           balloon_skin_id: profile.balloonSkinID,
                           is_discoverable: profile.isDiscoverable,
                           allow_friend_requests: profile.allowsFriendRequests,
                           last_seen_at: PostgresDate.string(Date())))
            .eq("id", value: profile.publicID)
            .execute()
    }

    /// The outcome of asking the database for a name.
    enum AliasClaim: Equatable {
        case claimed(OnlineProfile)
        /// Another account already owns this name, case-insensitively.
        case taken
        /// Failed the server's own length rule.
        case invalid
    }

    /// Claim a public name, atomically.
    ///
    /// One `UPDATE` inside `claim_public_alias`, guarded by the unique index on
    /// `lower(btrim(public_alias))`. There is no window between checking and
    /// writing, so two devices racing for the same name cannot both win — the
    /// loser gets `.taken` rather than silently overwriting someone.
    ///
    /// Re-casing a name you already own is not a conflict: the RPC compares
    /// normalized keys before it tries to write.
    func claimAlias(_ alias: String) async throws -> AliasClaim {
        guard let client else { throw OnlineError.unavailable(.projectUnavailable) }
        struct Params: Encodable { let p_alias: String }
        struct Result: Decodable {
            let ok: Bool
            let reason: String?
            let profile: ProfileRow?
        }
        let result: Result = try await client
            .rpc("claim_public_alias", params: Params(p_alias: alias))
            .execute().value
        if result.ok, let row = result.profile { return .claimed(Self.profile(from: row)) }
        return result.reason == "invalid" ? .invalid : .taken
    }

    /// Profiles for a set of pilot ids in ONE batched request (RLS restricts to
    /// visible profiles). Uses the idiomatic `.in(_:values:)` builder rather
    /// than a hand-built filter string.
    func fetchProfiles(publicIDs: [String]) async -> [OnlineProfile] {
        guard let client, !publicIDs.isEmpty else { return [] }
        guard let rows: [ProfileRow] = try? await client.from("profiles")
            .select().in("id", values: Array(Set(publicIDs)))
            .execute().value else { return [] }
        return rows.map(Self.profile(from:))
    }

    /// Full online-data erasure via the server RPC (profile, presence, rooms,
    /// memberships, requests, friendships). Local app data is never touched.
    func deleteAllOnlineData() async throws {
        guard let client else { throw OnlineError.unavailable(.projectUnavailable) }
        try await client.rpc("delete_my_online_data").execute()
    }

    static func profile(from row: ProfileRow) -> OnlineProfile {
        OnlineProfile(publicID: row.id,
                      displayName: row.publicAlias,
                      balloonSkinID: row.balloonSkinID,
                      countryCode: row.countryCode,
                      isDiscoverable: row.isDiscoverable,
                      allowsFriendRequests: row.allowFriendRequests,
                      createdAt: PostgresDate.parse(row.createdAt) ?? Date(),
                      updatedAt: PostgresDate.parse(row.updatedAt) ?? Date())
    }
}
