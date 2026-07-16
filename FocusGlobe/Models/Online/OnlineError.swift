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

    /// CloudKit throttle / quota codes — a create MUST back off (not retry
    /// immediately, and never be reinterpreted as "no Internet") when one of
    /// these fires. `quotaExceeded` and `requestRateLimited` normally carry a
    /// `retryAfterSeconds`; the others may not.
    static func isThrottled(_ error: Error) -> Bool {
        guard let ck = error as? CKError else { return false }
        switch ck.code {
        case .quotaExceeded, .requestRateLimited, .serviceUnavailable, .zoneBusy:
            return true
        default:
            return false
        }
    }

    /// The `Date` until which room-creating writes must wait after a throttle.
    /// Uses CloudKit's `retryAfterSeconds` when present; otherwise a conservative
    /// exponential backoff (capped at 5 min) with jitter, scaled by how many
    /// throttles we've hit in a row. Returns nil for non-throttle errors.
    static func throttleRetryDate(for error: Error, consecutive: Int, now: Date = Date()) -> Date? {
        guard isThrottled(error) else { return nil }
        if let s = (error as? CKError)?.retryAfterSeconds, s > 0 {
            return now.addingTimeInterval(s)
        }
        let backoff = min(300.0, 20.0 * pow(2.0, Double(max(0, consecutive - 1))))
        let jitter = Double.random(in: 0...15)
        return now.addingTimeInterval(backoff + jitter)
    }

    /// A readable name for a `CKError.Code` (for diagnostics, never shown as UI
    /// copy in Release).
    static func codeName(_ code: CKError.Code) -> String {
        switch code {
        case .networkUnavailable:            return "networkUnavailable"
        case .networkFailure:                return "networkFailure"
        case .serviceUnavailable:            return "serviceUnavailable"
        case .requestRateLimited:            return "requestRateLimited"
        case .notAuthenticated:              return "notAuthenticated"
        case .permissionFailure:             return "permissionFailure"
        case .unknownItem:                   return "unknownItem"
        case .invalidArguments:              return "invalidArguments"
        case .serverRejectedRequest:         return "serverRejectedRequest"
        case .zoneNotFound:                  return "zoneNotFound"
        case .userDeletedZone:               return "userDeletedZone"
        case .zoneBusy:                      return "zoneBusy"
        case .quotaExceeded:                 return "quotaExceeded"
        case .partialFailure:                return "partialFailure"
        case .serverRecordChanged:           return "serverRecordChanged"
        case .accountTemporarilyUnavailable: return "accountTemporarilyUnavailable"
        case .badContainer:                  return "badContainer"
        case .missingEntitlement:            return "missingEntitlement"
        case .badDatabase:                   return "badDatabase"
        case .incompatibleVersion:           return "incompatibleVersion"
        case .constraintViolation:           return "constraintViolation"
        case .limitExceeded:                 return "limitExceeded"
        case .changeTokenExpired:            return "changeTokenExpired"
        case .tooManyParticipants:           return "tooManyParticipants"
        case .alreadyShared:                 return "alreadyShared"
        case .referenceViolation:            return "referenceViolation"
        case .managedAccountRestricted:      return "managedAccountRestricted"
        case .participantMayNeedVerification: return "participantMayNeedVerification"
        case .internalError:                 return "internalError"
        case .serverResponseLost:            return "serverResponseLost"
        default:                             return "code-\(code.rawValue)"
        }
    }

    /// A full one-line diagnostic breakdown of ANY error (CKError code + name,
    /// localizedDescription, retryAfter, underlying NSError, and every partial
    /// error). DEBUG diagnostics / OSLog only — never Release UI.
    static func detail(for error: Error) -> String {
        guard let ck = error as? CKError else {
            let ns = error as NSError
            return "non-CK \(ns.domain)#\(ns.code): \(ns.localizedDescription)"
        }
        var parts = ["CKError.\(codeName(ck.code)) (\(ck.code.rawValue)): \(ck.localizedDescription)"]
        if let retry = ck.retryAfterSeconds { parts.append("retryAfter=\(Int(retry))s") }
        if let underlying = ck.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append("underlying \(underlying.domain)#\(underlying.code): \(underlying.localizedDescription)")
        }
        if let serverMsg = ck.userInfo["ServerErrorDescription"] as? String {
            parts.append("server: \(serverMsg)")
        }
        for (id, itemError) in ck.partialErrorsByItemID ?? [:] {
            let pe = itemError as NSError
            let name = (pe as? CKError).map { codeName($0.code) } ?? "\(pe.code)"
            parts.append("partial[\(String(describing: id))]=\(name): \(pe.localizedDescription)")
        }
        return parts.joined(separator: " | ")
    }
}
