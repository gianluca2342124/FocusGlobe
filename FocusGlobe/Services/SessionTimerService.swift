import Combine
import Foundation

/// The focus timer engine. Provider-independent and UI-independent: it knows
/// nothing about maps, balloons or rewards — only elapsed time.
///
/// Accuracy: elapsed time is always derived from the wall clock (`Date`), not by
/// counting timer ticks. This keeps the countdown correct even if ticks are
/// dropped, and lets the session "catch up" after the app returns from the
/// background (call `refresh()` when becoming active).
///
/// Background limitation (MVP): iOS suspends the repeating timer while the app
/// is backgrounded, so the visible countdown freezes; on return it snaps to the
/// correct wall-clock value. A future version can add a Live Activity / local
/// notification so the journey stays alive on the Lock Screen — see
/// MAP_PROVIDER_MIGRATION.md and the app's roadmap.
@MainActor
final class SessionTimerService: ObservableObject {

    /// Duration for a normal (Solo / local) flight. For a canonical flight — the
    /// host of an online flight and any joined guest — the effective total is
    /// captured from the server deadline via the shared clock (see below).
    private let localTotal: TimeInterval

    /// The ABSOLUTE **server** deadline this flight counts down to — set for the
    /// online host (its finite Global deadline, adopted from the publish RPC) and
    /// for a guest who joined an in-progress Private Flight. Remaining is always
    /// `deadline − estimatedServerNow`, recomputed on every read/tick from the
    /// shared clock, so two devices land together regardless of clock skew and it
    /// survives background/foreground and reconnect. `nil` for Solo and Infinite
    /// flights (their local timer path is unchanged).
    private(set) var canonicalDeadline: Date?

    /// Server-estimated "now", injected by the online model's shared clock. It is
    /// monotonic (backed by an uptime reference), so a manual wall-clock change
    /// mid-flight does not jump the countdown. Defaults to the device clock for
    /// Solo / preview. `@MainActor` — this service is main-actor isolated and the
    /// provider reads main-actor state.
    var serverNow: @MainActor () -> Date = { Date() }

    /// The stable total for a canonical flight, captured once from the shared
    /// clock — remaining-at-join for a guest, the full nominal duration for the
    /// host. `nil` until the canonical deadline is captured/adopted.
    private var canonicalTotal: TimeInterval?

    /// The effective total used by progress/remaining: the canonical total when
    /// counting down to a server deadline, else the local duration.
    var total: TimeInterval { canonicalTotal ?? localTotal }

    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var isRunning = false
    @Published private(set) var isFinished = false

    /// Called once when the session reaches its full duration.
    var onFinish: (() -> Void)?

    private var accumulated: TimeInterval = 0
    private var lastResume: Date?
    private var timer: Timer?
    private let tickInterval: TimeInterval = 1.0

    init(total: TimeInterval, startElapsed: TimeInterval = 0, canonicalDeadline: Date? = nil) {
        self.localTotal = max(1, total)
        self.canonicalDeadline = canonicalDeadline
        // Resume support: seed accumulated time so `start()` continues from here.
        self.accumulated = min(self.localTotal, max(0, startElapsed))
        self.elapsed = self.accumulated
    }

    /// The online HOST adopts its server-canonical deadline mid-flight, the
    /// instant the publish RPC returns. Keeps the full nominal duration as the
    /// total (the host started ~now), so the countdown is continuous and now
    /// derives from the exact same absolute server instant the guests use.
    func adoptCanonicalDeadline(_ deadline: Date) {
        canonicalDeadline = deadline
        if canonicalTotal == nil { canonicalTotal = localTotal }
        tick()
    }

    // MARK: - Derived

    var progress: Double { min(1, elapsed / total) }
    var remaining: TimeInterval { max(0, total - elapsed) }

    /// Elapsed computed **live from the wall clock on every read** (not the
    /// last-published `elapsed`). Reading this inside a `TimelineView` gives a
    /// countdown that is always correct and never stalls on the publish cadence.
    /// Pause-aware: returns the frozen accumulated value while paused.
    var liveElapsed: TimeInterval { min(total, currentElapsed()) }
    var liveProgress: Double { min(1, liveElapsed / total) }
    var liveRemaining: TimeInterval { max(0, total - liveElapsed) }

    // MARK: - Control

    func start() {
        guard !isRunning, !isFinished else { return }
        // A guest enters already counting down to the server deadline: capture the
        // remaining-at-join from the shared clock as the stable total.
        if let deadline = canonicalDeadline, canonicalTotal == nil {
            canonicalTotal = max(1, deadline.timeIntervalSince(serverNow()))
        }
        lastResume = Date()
        isRunning = true
        scheduleTimer()
        tick()
    }

    func pause() {
        guard isRunning else { return }
        commitElapsed()
        lastResume = nil
        isRunning = false
        invalidate()
    }

    func resume() {
        guard !isRunning, !isFinished else { return }
        lastResume = Date()
        isRunning = true
        scheduleTimer()
        tick()
    }

    /// Stops permanently (used on cancel). Does not fire `onFinish`.
    func stop() {
        commitElapsed()
        isRunning = false
        invalidate()
    }

    /// Recomputes elapsed from the wall clock — call when the scene becomes
    /// active so a backgrounded session shows the correct time immediately.
    func refresh() {
        guard isRunning else { return }
        tick()
    }

    // MARK: - Internals

    private func scheduleTimer() {
        invalidate()
        let t = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        // .common so it keeps firing during scroll / interaction.
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func invalidate() {
        timer?.invalidate()
        timer = nil
    }

    private func currentElapsed() -> TimeInterval {
        if let canonicalDeadline {
            // Canonical (host + guest) flight: elapsed is derived from the ABSOLUTE
            // server deadline and the shared clock on every read, so remaining =
            // deadline − estimatedServerNow exactly, with no dependence on
            // start/pause bookkeeping or the device wall clock. This is what keeps
            // both devices' countdowns locked together across skew, background and
            // reconnect.
            let t = canonicalTotal ?? localTotal
            return max(0, t - max(0, canonicalDeadline.timeIntervalSince(serverNow())))
        }
        if let lastResume {
            return accumulated + Date().timeIntervalSince(lastResume)
        }
        return accumulated
    }

    private func commitElapsed() {
        accumulated = min(total, currentElapsed())
        lastResume = nil
    }

    private func tick() {
        let value = min(total, currentElapsed())
        elapsed = value
        if value >= total {
            finish()
        }
    }

    private func finish() {
        guard !isFinished else { return }
        elapsed = total
        accumulated = total
        lastResume = nil
        isRunning = false
        isFinished = true
        invalidate()
        onFinish?()
    }
}
