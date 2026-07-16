import Foundation

/// The ONE authoritative app-level view of FocusGlobe Online availability.
/// Every online surface renders from this; Solo flights never consult it.
/// Backed by Supabase (account session + reachability), never by iCloud.
enum OnlineState: Equatable, Sendable {
    case signedOut               // no FocusGlobe account on this device
    case authenticating          // Sign in with Apple in progress
    case ready                   // signed in, backend reachable
    case reconnecting            // transient interruption; retrying reads
    case networkUnavailable      // no internet
    case projectUnavailable      // Supabase project unreachable/paused
    case rateLimited             // server asked us to slow down
    case sessionExpired          // stored session no longer valid
    case permissionDenied        // RLS/permission rejection (misconfiguration)
    case maintenance             // backend maintenance window
    case unknown                 // not yet determined (launch)

    var isAvailable: Bool { self == .ready }

    /// Short, friendly copy — never a raw backend error.
    var userMessage: String {
        switch self {
        case .signedOut:          return "Sign in to fly with other pilots."
        case .authenticating:     return "Signing in…"
        case .ready:              return "Online"
        case .reconnecting:       return "Reconnecting…"
        case .networkUnavailable: return "No internet connection."
        case .projectUnavailable: return "Online is temporarily unavailable."
        case .rateLimited:        return "Please try again in a moment."
        case .sessionExpired:     return "Please sign in again."
        case .permissionDenied:   return "Online is temporarily unavailable."
        case .maintenance:        return "Online is down for maintenance."
        case .unknown:            return "Checking…"
        }
    }
}
