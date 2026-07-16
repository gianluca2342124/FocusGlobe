import Foundation
import Supabase

/// Blocking + reporting. Reports are write-only for clients (reviewed
/// out-of-band); blocks hide pilots both ways and stop requests/joins.
actor ModerationService {
    private var client: SupabaseClient? { SupabaseService.client }

    func block(userID: String) async throws {
        guard let client else { throw OnlineError.unavailable(.projectUnavailable) }
        struct Params: Encodable { let p_user_id: String }
        try await client.rpc("block_user", params: Params(p_user_id: userID)).execute()
    }

    func report(userID: String, reason: String) async throws {
        guard let client else { throw OnlineError.unavailable(.projectUnavailable) }
        struct Params: Encodable { let p_user_id: String; let p_reason: String }
        try await client.rpc("report_pilot", params: Params(p_user_id: userID, p_reason: reason)).execute()
    }
}
