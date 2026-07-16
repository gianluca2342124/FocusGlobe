import Foundation

// MARK: - Social / connected-focus foundation (data only, backend-ready)
//
// FocusGlobe should feel alive and connected — but never dishonest. These
// models are the architecture for real connected focus (friends, shared
// flights, live Sky presence) WITHOUT any pretend users today:
//
//  • Nothing here generates fake people. `isSample` exists so that, if design
//    previews ever need placeholder rows, they are marked as samples at the
//    type level and can never be presented as real pilots.
//  • Live counts stay in `SkyActivity` (clearly simulated, `isLive == false`)
//    until a backend provides real numbers.
//  • A future backend hydrates these types 1:1; UI written against them today
//    keeps working when real data arrives.

// NOTE: the canonical `FocusFriend` model now lives in
// `Models/Online/FocusFriend.swift`, backed by the real FocusGlobe Online
// (Supabase) Crew system. The placeholder friend model that used to live here
// was removed — it was never persisted or populated (the local fallback always
// returned an empty list), so no saved data is affected.

/// A pilot present in a Sky during a shared session (future live presence).
struct SkyParticipant: Identifiable, Codable, Hashable {
    let id: String
    var displayName: String
    var skyID: String
    /// Seconds into their current flight (for ambient "flying now" context).
    var elapsedSeconds: Int = 0
    var isSample: Bool = false
}

/// An invitation to fly together in one Sky at the same time — the "crew
/// flight" seed. Local-only until a backend can deliver these.
struct SharedFlightInvite: Identifiable, Codable, Hashable {
    let id: String
    var skyID: String
    var hostName: String
    var plannedMinutes: Int
    var createdAt: Date
}
