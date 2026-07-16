import Foundation
import Supabase

/// Server-verified session completion. The friend bonus decision and its
/// ledger entry are computed by the `complete_online_session` RPC from server
/// rows (idempotent) — the client never supplies amounts.
actor OnlineRewardService {
    private var client: SupabaseClient? { SupabaseService.client }

    func completeSession(sessionID: String) async -> SessionCompletionPayload? {
        guard let client else { return nil }
        struct Params: Encodable { let p_session_id: String }
        do {
            let payload: SessionCompletionPayload = try await client
                .rpc("complete_online_session", params: Params(p_session_id: sessionID))
                .execute().value
            return payload
        } catch {
            SupabaseService.log.error("completeSession FAILED: \(OnlineError.detail(for: error), privacy: .public)")
            return nil
        }
    }
}
