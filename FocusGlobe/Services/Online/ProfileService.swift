import Foundation
import Supabase

/// The user's own `profiles` row + lightweight profile reads for other pilots.
actor ProfileService {
    private var client: SupabaseClient? { SupabaseService.client }

    /// Fetch-or-create my profile (the signup trigger normally creates it; the
    /// upsert makes this robust even if the trigger predates this account).
    func ensureProfile(userID: String, defaults: OnlineProfile?) async throws -> OnlineProfile {
        guard let client else { throw OnlineError.unavailable(.projectUnavailable) }
        if let existing: ProfileRow = try? await client.from("profiles")
            .select().eq("id", value: userID).single().execute().value {
            return Self.profile(from: existing)
        }
        let alias = defaults?.displayName ?? "SkyPilot\(Int.random(in: 1000...9999))"
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
        struct Update: Encodable {
            let public_alias: String
            let country_code: String?
            let balloon_skin_id: String
            let is_discoverable: Bool
            let allow_friend_requests: Bool
            let last_seen_at: String
        }
        try await client.from("profiles")
            .update(Update(public_alias: profile.displayName,
                           country_code: profile.countryCode,
                           balloon_skin_id: profile.balloonSkinID,
                           is_discoverable: profile.isDiscoverable,
                           allow_friend_requests: profile.allowsFriendRequests,
                           last_seen_at: PostgresDate.string(Date())))
            .eq("id", value: profile.publicID)
            .execute()
    }

    /// Profiles for a set of pilot ids (RLS restricts to visible profiles).
    func fetchProfiles(publicIDs: [String]) async -> [OnlineProfile] {
        guard let client, !publicIDs.isEmpty else { return [] }
        let list = "(\(publicIDs.joined(separator: ",")))"
        guard let rows: [ProfileRow] = try? await client.from("profiles")
            .select().filter("id", operator: "in", value: list)
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
