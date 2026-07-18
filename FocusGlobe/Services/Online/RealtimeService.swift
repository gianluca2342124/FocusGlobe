import Foundation
import Supabase

/// Supabase Realtime for FocusGlobe Online:
///  • Room channel — postgres change feeds on `room_members` / `focus_rooms`
///    (RLS-authorized) drive live lobby updates and the shared flight start.
///  • Sky presence channel — tracks my ephemeral presence in `sky:<id>` and
///    nudges an early pilot refresh when peers join/leave.
/// Channels are deduplicated (one room + one sky at a time) and removed on
/// leave/sign-out; polling remains the resilient fallback if a socket drops.
actor RealtimeService {
    private var client: SupabaseClient? { SupabaseService.client }

    private var roomChannel: RealtimeChannelV2?
    private var roomTasks: [Task<Void, Never>] = []
    private var skyChannel: RealtimeChannelV2?
    private var skyTasks: [Task<Void, Never>] = []

    // MARK: Room lobby

    /// Subscribe to a room's live changes. `onChange` fires on ANY member or
    /// room-row change (client-side filtered to this room id).
    func subscribeRoom(roomID: String, onChange: @escaping @Sendable () -> Void) async {
        await unsubscribeRoom()
        guard let client else { return }
        let channel = client.channel("room:\(roomID)")
        let memberChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "room_members")
        let roomChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "focus_rooms")
        try? await channel.subscribe()
        roomChannel = channel
        roomTasks.append(Task {
            for await _ in memberChanges {
                if Task.isCancelled { break }
                onChange()
            }
        })
        roomTasks.append(Task {
            for await _ in roomChanges {
                if Task.isCancelled { break }
                onChange()
            }
        })
    }

    func unsubscribeRoom() async {
        roomTasks.forEach { $0.cancel() }
        roomTasks = []
        if let channel = roomChannel {
            await client?.removeChannel(channel)
            roomChannel = nil
        }
    }

    // MARK: Sky presence

    /// Join a public Sky's presence set: track my ephemeral state and nudge a
    /// pilots refresh when the peer set changes.
    func joinSky(skyID: String, myID: String, onPeersChanged: @escaping @Sendable () -> Void) async {
        await leaveSky()
        guard let client else { return }
        let channel = client.channel("sky:\(skyID)")
        let presence = channel.presenceChange()
        try? await channel.subscribe()
        skyChannel = channel
        try? await channel.track(["user_id": AnyJSON.string(myID)])
        skyTasks.append(Task {
            for await _ in presence {
                if Task.isCancelled { break }
                onPeersChanged()
            }
        })
    }

    func leaveSky() async {
        skyTasks.forEach { $0.cancel() }
        skyTasks = []
        if let channel = skyChannel {
            try? await channel.untrack()
            await client?.removeChannel(channel)
            skyChannel = nil
        }
    }

    // MARK: Applause (per-user broadcast channel)

    private var applauseChannel: RealtimeChannelV2?
    private var applauseTasks: [Task<Void, Never>] = []

    /// Listen for applause addressed to ME for the duration of an online flight.
    /// A dedicated `applause:<uid>` broadcast topic — ephemeral social pings only
    /// (a sender alias string), no personal data and no database writes.
    func subscribeApplause(myID: String, onApplause: @escaping @Sendable (String) -> Void) async {
        await unsubscribeApplause()
        guard let client else { return }
        let channel = client.channel("applause:\(myID)")
        let stream = channel.broadcastStream(event: "applause")
        try? await channel.subscribe()
        applauseChannel = channel
        applauseTasks.append(Task {
            for await message in stream {
                if Task.isCancelled { break }
                let from: String
                if case .string(let alias)? = message["from"] { from = alias } else { from = "A pilot" }
                onApplause(from)
            }
        })
    }

    func unsubscribeApplause() async {
        applauseTasks.forEach { $0.cancel() }
        applauseTasks = []
        if let channel = applauseChannel {
            await client?.removeChannel(channel)
            applauseChannel = nil
        }
    }

    /// Send one applause ping to another pilot's personal topic. Genuinely
    /// delivered over the socket when the recipient is flying (they subscribe
    /// for their whole online flight); best-effort otherwise.
    func sendApplause(to recipientID: String, fromAlias: String) async {
        guard let client else { return }
        let channel = client.channel("applause:\(recipientID)")
        try? await channel.subscribe()
        try? await channel.broadcast(event: "applause", message: ["from": AnyJSON.string(fromAlias)])
        await client.removeChannel(channel)
    }

    func teardown() async {
        await unsubscribeRoom()
        await leaveSky()
        await unsubscribeApplause()
    }
}
