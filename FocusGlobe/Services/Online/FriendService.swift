import Foundation
import Supabase

/// The Crew system on Supabase:
///  • `friend_requests` — sender inserts (policy-validated: no self, no dup,
///    no blocked pair, recipient allows requests, rate-limited server-side);
///    accept/decline/cancel run through SECURITY DEFINER RPCs only.
///  • `friendships` — one canonical row per pair, created ONLY by the
///    accept RPC. Clients cannot write the friendship graph directly.
///  • `blocks` — blocker-owned; blocking cancels pending requests and
///    removes the friendship server-side.
actor FriendService {
    private var client: SupabaseClient? { SupabaseService.client }

    // MARK: Requests

    func sendRequest(from senderID: String, to recipientID: String) async throws {
        guard let client else { throw OnlineError.unavailable(.projectUnavailable) }
        guard senderID != recipientID else { throw OnlineError.requestFailed }
        if let last = OnlineCache.lastFriendRequestAt, Date().timeIntervalSince(last) < 10 {
            throw OnlineError.rateLimited
        }
        struct Insert: Encodable {
            let sender_id: String
            let receiver_id: String
        }
        try await client.from("friend_requests")
            .insert(Insert(sender_id: senderID, receiver_id: recipientID))
            .execute()
        OnlineCache.lastFriendRequestAt = Date()
    }

    func accept(requestID: String) async throws {
        guard let client else { throw OnlineError.unavailable(.projectUnavailable) }
        struct Params: Encodable { let p_request_id: String }
        try await client.rpc("accept_friend_request", params: Params(p_request_id: requestID)).execute()
    }

    func decline(requestID: String) async throws {
        guard let client else { throw OnlineError.unavailable(.projectUnavailable) }
        struct Params: Encodable { let p_request_id: String }
        try await client.rpc("decline_friend_request", params: Params(p_request_id: requestID)).execute()
    }

    func cancel(requestID: String) async throws {
        guard let client else { throw OnlineError.unavailable(.projectUnavailable) }
        struct Params: Encodable { let p_request_id: String }
        try await client.rpc("cancel_friend_request", params: Params(p_request_id: requestID)).execute()
    }

    /// Pending requests addressed to me / sent by me.
    func pendingRequests(myID: String) async -> (incoming: [FriendRequestRow], outgoing: [FriendRequestRow]) {
        guard let client else { return ([], []) }
        let incoming: [FriendRequestRow] = (try? await client.from("friend_requests")
            .select()
            .eq("receiver_id", value: myID)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .limit(40)
            .execute().value) ?? []
        let outgoing: [FriendRequestRow] = (try? await client.from("friend_requests")
            .select()
            .eq("sender_id", value: myID)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .limit(40)
            .execute().value) ?? []
        return (incoming, outgoing)
    }

    // MARK: Friendships

    /// The other participant of each of my friendships.
    func friendIDs(myID: String) async -> [String] {
        guard let client else { return [] }
        let rows: [FriendshipRow] = (try? await client.from("friendships")
            .select()
            .or("user_low.eq.\(myID),user_high.eq.\(myID)")
            .limit(200)
            .execute().value) ?? []
        return rows.map { $0.userLow == myID ? $0.userHigh : $0.userLow }
    }

    func removeFriend(myID: String, otherID: String) async {
        guard let client else { return }
        struct Params: Encodable { let p_friend_id: String }
        _ = try? await client.rpc("remove_friend", params: Params(p_friend_id: otherID)).execute()
    }
}
