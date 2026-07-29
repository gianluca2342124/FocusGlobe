import Foundation
import SwiftUI

/// The ONE source of presentation truth for remote balloons during an Online
/// flight.
///
/// `FocusOnlineModel.realPilots` is a networking snapshot: a pilot is simply
/// present or absent. That is correct for the model but useless for animation —
/// a balloon cannot fade out after its data has already been deleted. This stage
/// sits between the two and holds a short-lived lifecycle phase per pilot, so the
/// view can animate an arrival and, crucially, a departure.
///
/// Deliberately NOT a second networking model: it stores no server state, fetches
/// nothing, and derives everything from the snapshots handed to `sync(with:)`.
/// One entry per stable pilot id, never a parallel array.
@MainActor
final class OnlinePilotStage: ObservableObject {

    enum Phase: Equatable {
        /// Just observed — the view plays a fade-and-rise, then it becomes active.
        case entering
        case active
        /// Networking dropped this pilot (or their timer reached zero). The entry
        /// is retained purely so the balloon can animate away.
        case exiting(Reason)

        var isExiting: Bool { if case .exiting = self { return true } else { return false } }
    }

    /// Why a pilot is leaving. Only the duration differs — a timeout is quicker
    /// because there is nothing to celebrate, but it still never blinks out.
    enum Reason: Equatable {
        /// Their countdown reached zero: they finished and continued upward.
        case completed
        /// A normal departure, or presence we stopped seeing.
        case departed

        var duration: Double {
            switch self {
            case .completed: return 0.95
            case .departed:  return 0.65
            }
        }
    }

    struct Entry: Identifiable, Equatable {
        /// The stable pilot id — the ForEach identity, never an array index.
        let id: String
        /// The last known model. Kept for the whole exit so the balloon and its
        /// label can still render after networking forgot the pilot.
        var pilot: OnlinePilot
        var phase: Phase
    }

    /// Ordered by stable id so slot assignment downstream stays deterministic.
    @Published private(set) var entries: [Entry] = []

    /// One removal task per exiting pilot, so cancellation is precise and a
    /// journey teardown can drop them all.
    private var exitTasks: [String: Task<Void, Never>] = [:]
    /// Ids currently mid-exit. Consulted by `sync` to ignore stale re-additions —
    /// this is what stops a delayed Supabase update resurrecting a balloon for a
    /// frame, or restarting its entry animation.
    private var exiting: Set<String> = []
    /// Ids we have shown the brief arrival label for, so it happens once each.
    private(set) var recentlyEntered: Set<String> = []

    // MARK: Sync

    /// Reconcile the live snapshot into presentation entries.
    ///
    /// - newly seen id            → `.entering`
    /// - still-present id        → model refreshed, phase untouched
    /// - id that vanished        → `.exiting(.departed)` + scheduled removal
    /// - id whose timer hit zero → `.exiting(.completed)` + scheduled removal
    /// - stale re-add of an exiting id → IGNORED until its exit finishes
    func sync(with live: [OnlinePilot], now: Date = Date()) {
        let liveByID = Dictionary(live.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var next: [Entry] = []

        for existing in entries {
            if existing.phase.isExiting {
                // Hold it exactly as it is. A re-add during the exit window is
                // deliberately ignored — see `exiting`.
                next.append(existing)
                continue
            }
            if let fresh = liveByID[existing.id] {
                if Self.hasFinished(fresh, now: now) {
                    next.append(Entry(id: existing.id, pilot: fresh, phase: .exiting(.completed)))
                    beginExit(existing.id, reason: .completed)
                } else {
                    // Refresh the model in place; never re-enter, never re-slot.
                    next.append(Entry(id: existing.id, pilot: fresh, phase: existing.phase))
                }
            } else {
                next.append(Entry(id: existing.id, pilot: existing.pilot, phase: .exiting(.departed)))
                beginExit(existing.id, reason: .departed)
            }
        }

        let known = Set(next.map(\.id))
        for pilot in live where !known.contains(pilot.id) && !exiting.contains(pilot.id) {
            // A genuinely new pilot — or the same person on a NEW session, which
            // carries a different stable id and is therefore allowed straight in.
            // Nothing is blacklisted by alias or account.
            guard !Self.hasFinished(pilot, now: now) else { continue }
            next.append(Entry(id: pilot.id, pilot: pilot, phase: .entering))
            recentlyEntered.insert(pilot.id)
        }

        let sorted = next.sorted { $0.id < $1.id }
        if sorted != entries { entries = sorted }
    }

    /// Promote an entering pilot to active once its arrival animation has played.
    /// Called by the view; keeps the phase machine in one place.
    func settle(_ id: String) {
        guard let i = entries.firstIndex(where: { $0.id == id }), entries[i].phase == .entering else { return }
        entries[i].phase = .active
    }

    /// Stop showing the brief arrival label for this pilot.
    func clearArrivalLabel(_ id: String) { recentlyEntered.remove(id) }

    /// Cancel everything — called when the journey goes away so no task outlives it.
    func teardown() {
        exitTasks.values.forEach { $0.cancel() }
        exitTasks.removeAll()
        exiting.removeAll()
        recentlyEntered.removeAll()
        entries.removeAll()
    }

    // MARK: Internals

    /// A pilot with a real live session whose canonical end has passed.
    /// Timestamp-derived — no per-pilot timer anywhere.
    private static func hasFinished(_ pilot: OnlinePilot, now: Date) -> Bool {
        guard pilot.hasLiveSession, let end = pilot.expectedEndAt else { return false }
        return end <= now
    }

    /// Retain the entry for exactly as long as its animation needs, then drop it.
    /// Re-entrant-safe: an id already exiting keeps its original task.
    private func beginExit(_ id: String, reason: Reason) {
        guard !exiting.contains(id) else { return }
        exiting.insert(id)
        exitTasks[id]?.cancel()
        exitTasks[id] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(reason.duration * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.entries.removeAll { $0.id == id }
            self.exiting.remove(id)
            self.recentlyEntered.remove(id)
            self.exitTasks[id] = nil
        }
    }
}
