import Foundation
import os

/// Lightweight, production-safe **launch breadcrumbs**.
///
/// Why this exists (build 5): App Review 1.0(2) crashed on launch with a Swift
/// runtime trap on the concurrency cooperative pool, and the submitted binary's
/// dSYM was not available to symbolicate the exact line. These breadcrumbs make
/// the *next* launch self-diagnosing: each `mark` emits one `os.Logger` line, so
/// if a launch crash ever recurs, the **last** breadcrumb visible in Console
/// (Mac Console.app or `log stream`, filtered to subsystem `com.focusglobe.app`,
/// category `launch`) is the last stage that completed before the crash — which
/// pinpoints the faulting stage without a dSYM.
///
/// Safety:
///  • `StaticString` stages only — compile-time constants, so no user data,
///    coordinates, tokens, or other PII can ever be interpolated in.
///  • A handful of calls per launch — never in a loop, never per-frame.
///  • Uses the unified logging system (no files, no network, no external SDK).
enum LaunchLog {
    private static let logger = Logger(subsystem: "com.focusglobe.app", category: "launch")

    /// Record that a named launch stage was reached. `stage` must be a literal.
    static func mark(_ stage: StaticString) {
        logger.log("launch ▸ \(stage, privacy: .public)")
    }
}
