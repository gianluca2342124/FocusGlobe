import Foundation
import Supabase

/// FocusGlobe-level online errors. UI copy comes from here — raw backend
/// errors never reach the interface in Release (DEBUG diagnostics show the
/// full breakdown via `detail(for:)`).
enum OnlineError: Error, Sendable {
    case unavailable(OnlineState)
    case notSignedIn
    case rateLimited
    case invalidAlias(String)
    case roomUnavailable
    case roomFull
    case inviteInvalid
    case inviteExpired
    case blocked
    case profileNotReady
    case flightNotReady
    case requestFailed
    case cancelled

    var userMessage: String {
        switch self {
        case .unavailable(let s):   return s.userMessage
        case .notSignedIn:          return "Sign in to use Online Flights."
        case .rateLimited:          return "Please try again in a moment."
        case .invalidAlias(let m):  return m
        case .roomUnavailable:      return "This Focus Room is no longer available."
        case .roomFull:             return "This Focus Room is full."
        case .inviteInvalid:        return "This invitation link isn't valid."
        case .inviteExpired:        return "This invitation has expired — ask for a new one."
        case .blocked:              return "You can't join this Focus Room."
        case .profileNotReady:      return "Finishing your online profile — please try again in a moment."
        case .flightNotReady:       return "Getting your flight ready to share — please try again in a moment."
        case .requestFailed:        return "Something didn't reach the sky. Please try again."
        case .cancelled:            return ""
        }
    }

    /// The server raises single-token errors from RPCs (e.g. `room_full`).
    /// Extract that token when present so callers can map precisely.
    static func serverToken(from error: Error) -> String? {
        if let pg = error as? PostgrestError {
            let message = pg.message
            let known = ["not_authenticated", "rate_limited", "room_full", "room_not_found",
                         "room_closed", "invite_invalid", "invite_expired", "invite_revoked",
                         "blocked", "not_owner", "not_member", "request_not_found",
                         "already_friends", "invalid_reason", "session_not_found",
                         "self", "requests_disabled", "duplicate",
                         "profile_unavailable",
                         // Global→Private promotion: the caller's canonical live
                         // session couldn't be proven yet (retryable), was empty,
                         // or its finite deadline already elapsed.
                         "no_active_global_session", "invalid_session", "session_ended",
                         "invalid_sky",
                         // Server-authoritative applause outcomes.
                         "applause_cooldown", "recipient_not_flying", "not_flying",
                         "applause_self", "invalid_recipient"]
            for token in known where message.contains(token) { return token }
        }
        return nil
    }

    /// A missing/unexposed RPC (database predates a migration): PostgREST maps
    /// it to `PGRST202`, Postgres to `42883`. Used to fall back to a legacy
    /// path instead of surfacing a hard failure.
    static func isMissingFunction(_ error: Error) -> Bool {
        guard let pg = error as? PostgrestError else { return false }
        if let code = pg.code, code == "PGRST202" || code == "42883" { return true }
        let m = pg.message.lowercased()
        return m.contains("could not find the function") || m.contains("does not exist")
    }

    /// A missing-profile foreign-key failure (`focus_rooms_owner_id_fkey` /
    /// `room_members_user_id_fkey`, SQLSTATE 23503) or the explicit
    /// `profile_unavailable` token — a transient, retryable setup gap, never
    /// the generic "didn't reach the sky".
    static func isProfileNotReady(_ error: Error) -> Bool {
        if serverToken(from: error) == "profile_unavailable" { return true }
        guard let pg = error as? PostgrestError else { return false }
        if pg.code == "23503" {
            let m = pg.message.lowercased()
            return m.contains("owner_id") || m.contains("user_id") || m.contains("profiles")
        }
        return false
    }

    /// The promotion RPC couldn't yet prove the caller's canonical live Global
    /// session (`no_active_global_session`) — a transient, retryable gap the
    /// client resolves by refreshing its presence and retrying once, NOT a hard
    /// failure.
    static func isNoActiveGlobalSession(_ error: Error) -> Bool {
        serverToken(from: error) == "no_active_global_session"
    }

    /// Map any thrown error to a FocusGlobe OnlineError with friendly copy.
    static func map(_ error: Error) -> OnlineError {
        if isProfileNotReady(error) { return .profileNotReady }
        if let token = serverToken(from: error) {
            switch token {
            case "not_authenticated":                    return .notSignedIn
            case "rate_limited":                         return .rateLimited
            case "room_full":                            return .roomFull
            case "room_not_found", "room_closed",
                 "not_owner", "not_member",
                 "session_not_found", "session_ended":   return .roomUnavailable
            case "no_active_global_session",
                 "invalid_session":                      return .flightNotReady
            case "invite_invalid":                       return .inviteInvalid
            case "invite_expired", "invite_revoked":     return .inviteExpired
            case "blocked":                              return .blocked
            default:                                     return .requestFailed
            }
        }
        if error is URLError { return .unavailable(.networkUnavailable) }
        return .requestFailed
    }

    /// Coarse category for diagnostics/logging (no private content).
    static func category(for error: Error) -> String {
        if let token = serverToken(from: error) {
            switch token {
            case "rate_limited":      return "rate-limited"
            case "not_authenticated": return "no-account"
            default:                  return token
            }
        }
        if let url = error as? URLError {
            switch url.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return "network"
            case .timedOut, .cannotConnectToHost, .cannotFindHost:
                return "unreachable"
            default:
                return "network"
            }
        }
        if let pg = error as? PostgrestError {
            if let code = pg.code, code == "42501" { return "permission" }
            return "postgrest"
        }
        return "other"
    }

    /// Throttle-pipeline hook: rate-limit style failures that must back off
    /// instead of retrying immediately.
    static func isThrottled(_ error: Error) -> Bool {
        category(for: error) == "rate-limited"
    }

    /// The `Date` until which room-creating writes must wait after a throttle:
    /// conservative exponential backoff (60 s base, 5 min cap) with jitter.
    static func throttleRetryDate(for error: Error, consecutive: Int, now: Date = Date()) -> Date? {
        guard isThrottled(error) else { return nil }
        let backoff = min(300.0, 60.0 * pow(2.0, Double(max(0, consecutive - 1))))
        let jitter = Double.random(in: 0...10)
        return now.addingTimeInterval(backoff + jitter)
    }

    /// A full one-line diagnostic breakdown of ANY error (type, code, message,
    /// underlying NSError). DEBUG diagnostics / OSLog only — never Release UI.
    static func detail(for error: Error) -> String {
        if let pg = error as? PostgrestError {
            var parts = ["PostgrestError"]
            if let code = pg.code { parts.append("code=\(code)") }
            parts.append("message=\(pg.message)")
            if let hint = pg.hint { parts.append("hint=\(hint)") }
            return parts.joined(separator: " | ")
        }
        if let url = error as? URLError {
            return "URLError#\(url.code.rawValue): \(url.localizedDescription)"
        }
        let ns = error as NSError
        var parts = ["\(type(of: error)) \(ns.domain)#\(ns.code): \(ns.localizedDescription)"]
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append("underlying \(underlying.domain)#\(underlying.code): \(underlying.localizedDescription)")
        }
        return parts.joined(separator: " | ")
    }
}
