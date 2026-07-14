import Foundation
import CloudKit

/// FocusGlobe-level online errors. UI copy comes from here — raw `CKError`s
/// never reach the interface.
enum OnlineError: Error, Sendable {
    case unavailable(CloudAvailability)
    case notSignedIn
    case rateLimited
    case invalidAlias(String)
    case roomUnavailable
    case requestFailed
    case cancelled

    var userMessage: String {
        switch self {
        case .unavailable(let a):   return a.userMessage
        case .notSignedIn:          return "Online flights require an active iCloud account."
        case .rateLimited:          return "Please try again in a moment."
        case .invalidAlias(let m):  return m
        case .roomUnavailable:      return "This Focus Room is no longer available."
        case .requestFailed:        return "Something didn't reach the sky. Please try again."
        case .cancelled:            return ""
        }
    }

    /// Coarse category for diagnostics/logging (no private content).
    static func category(for error: Error) -> String {
        if let ck = error as? CKError {
            switch ck.code {
            case .networkUnavailable, .networkFailure: return "network"
            case .notAuthenticated:                    return "no-account"
            case .requestRateLimited, .zoneBusy:       return "rate-limited"
            case .serverRecordChanged:                 return "conflict"
            case .unknownItem, .zoneNotFound:          return "missing"
            case .quotaExceeded:                       return "quota"
            case .permissionFailure:                   return "permission"
            default:                                   return "ck-\(ck.code.rawValue)"
            }
        }
        return "other"
    }

    /// CloudKit's suggested retry delay, when present.
    static func retryAfter(_ error: Error) -> TimeInterval? {
        (error as? CKError)?.retryAfterSeconds
    }
}
