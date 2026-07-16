import Foundation
import Supabase
import OSLog

/// The ONE shared Supabase client. Every online service reads it from here —
/// never construct competing clients. Sessions persist in the keychain via
/// supabase-swift's default secure storage.
enum SupabaseService {
    static let log = Logger(subsystem: "com.focusglobe.app", category: "online")

    /// nil when configuration is missing/invalid — the online layer then fails
    /// safe (Solo untouched) and diagnostics say exactly why.
    static let client: SupabaseClient? = {
        guard SupabaseConfig.isConfigured, let url = SupabaseConfig.projectURL else {
            log.error("Supabase configuration missing/invalid — online disabled (Solo unaffected)")
            return nil
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: SupabaseConfig.publishableKey)
    }()
}

/// Parses the timestamp shapes this backend produces:
/// RPC payloads — `2026-07-16T09:31:12.123Z` (UTC, milliseconds), and
/// PostgREST rows — `2026-07-16T09:31:12.123456+00:00`.
enum PostgresDate {
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ raw: String?) -> Date? {
        guard var s = raw, !s.isEmpty else { return nil }
        // Normalize: strip fractional seconds, force Z.
        if let dot = s.firstIndex(of: ".") {
            let tail = s[dot...]
            if let tzStart = tail.firstIndex(where: { $0 == "+" || $0 == "Z" || $0 == "-" }) {
                s.removeSubrange(dot..<tzStart)
            } else {
                s.removeSubrange(dot..<s.endIndex)
            }
        }
        s = s.replacingOccurrences(of: "+00:00", with: "Z")
        if !s.hasSuffix("Z"), !s.contains("+") {
            // Bare timestamp without zone → treat as UTC.
            if let tIndex = s.firstIndex(of: "T"), s[tIndex...].count >= 9 { s += "Z" }
        }
        return iso.date(from: s)
    }

    static func string(_ date: Date) -> String {
        iso.string(from: date)
    }
}
