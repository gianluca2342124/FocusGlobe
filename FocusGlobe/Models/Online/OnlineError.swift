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
                         "self", "requests_disabled", "duplicate"]
            for token in known where message.contains(token) { return token }
        }
        return nil
    }

    /// Map any thrown error to a FocusGlobe OnlineError with friendly copy.
    static func map(_ error: Error) -> OnlineError {
        if let token = serverToken(from: error) {
            switch token {
            case "not_authenticated":                    return .notSignedIn
            case "rate_limited":                         return .rateLimited
            case "room_full":                            return .roomFull
            case "room_not_found", "room_closed",
                 "not_owner", "not_member",
                 "session_not_found":                    return .roomUnavailable
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
