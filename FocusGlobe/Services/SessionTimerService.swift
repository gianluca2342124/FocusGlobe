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

    let total: TimeInterval

    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var isRunning = false
    @Published private(set) var isFinished = false

    /// Called once when the session reaches its full duration.
    var onFinish: (() -> Void)?

    private var accumulated: TimeInterval = 0
    private var lastResume: Date?
    private var timer: Timer?
    private let tickInterval: TimeInterval = 1.0

    init(total: TimeInterval, startElapsed: TimeInterval = 0) {
        self.total = max(1, total)
        // Resume support: seed accumulated time so `start()` continues from here.
        self.accumulated = min(self.total, max(0, startElapsed))
        self.elapsed = self.accumulated
    }

    // MARK: - Derived

    var progress: Double { min(1, elapsed / total) }
    var remaining: TimeInterval { max(0, total - elapsed) }

    // MARK: - Control

    func start() {
        guard !isRunning, !isFinished else { return }
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
