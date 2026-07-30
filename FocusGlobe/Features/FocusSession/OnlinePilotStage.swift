import Foundation
import SwiftUI

/// The ONE place every Online-balloon lifecycle duration is defined.
///
/// These numbers used to live as bare literals in two different files, which
/// meant the delay before a phase flipped and the animation that phase triggered
/// could drift apart — a 460 ms settle against a ~500 ms animation. Every value
/// below is read by BOTH the stage that owns the phase machine and the layer that
/// draws it, so a duration can only ever be changed in one place.
enum OnlinePilotLifecycle {

    // MARK: Arrival

    /// The fade-and-rise a newly seen balloon plays into its slot.
    static let arrival: Double = 0.52
    /// The beat between inserting a balloon at its pre-arrival transform and
    /// flipping it to `.active`.
    ///
    /// Deliberately tiny, and NOT the arrival duration: the balloon is invisible
    /// for exactly this long, so it only has to outlast a render pass — long
    /// enough for SwiftUI to commit the `.entering` transform before the change
    /// that animates away from it. (It used to be 460 ms, which meant an arriving
    /// pilot was fully invisible for almost half a second before their arrival
    /// even began.)
    static let arrivalCommit: Double = 0.12
    /// Extra delay per additional balloon arriving in the same reconciliation, so
    /// a batch reads as several arrivals rather than one pop.
    static let arrivalStagger: Double = 0.09
    /// Cap on the stagger — a busy Sky must never make the last arrival feel late.
    static let maxArrivalStagger: Double = 0.45

    // MARK: Departure

    /// A finished flight drifts up and away: the longest exit, because it is the
    /// one worth noticing.
    static let completedExit: Double = 0.90
    /// A plain departure (or presence we simply stopped seeing) leaves more quietly.
    static let departedExit: Double = 0.65

    // MARK: Labels

    /// How long a new arrival's own label stays up, even when labels are off, so a
    /// join is noticed without revealing the whole Sky.
    static let arrivalLabelReveal: Double = 2.6
    /// The automatic reveal every Online journey opens with.
    static let labelIntro: Double = 5.0
    /// The cross-fade whenever label visibility changes.
    static let labelFade: Double = 0.55

    /// `Task.sleep` wants nanoseconds. Converting here means no call site writes
    /// its own `_000_000_000` literal and quietly loses a zero.
    static func nanoseconds(_ seconds: Double) -> UInt64 {
        UInt64(max(0, seconds) * 1_000_000_000)
    }
}

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
        /// Networking dropped this pilot (or their countdown reached zero). The
        /// entry is retained purely so the balloon can animate away.
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

        /// From the centralized definition, so the animation the layer plays and
        /// the delay before the entry is dropped are the SAME number — an entry
        /// can never be removed mid-fade.
        var duration: Double {
            switch self {
            case .completed: return OnlinePilotLifecycle.completedExit
            case .departed:  return OnlinePilotLifecycle.departedExit
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
        /// Fixed when the entry is created, so a batch of arrivals is staggered
        /// and a later reconciliation can never re-stagger someone.
        var arrivalDelay: Double
        /// The Sky anchor this pilot occupies, claimed ONCE at first arrival and
        /// held until the entry is removed — including across an exit (the balloon
        /// is still on screen) and across a new session by the same account.
        var slotIndex: Int
    }

    /// Everything the drawing layer needs for one pilot, as ONE value instead of
    /// several parallel dictionaries the caller has to keep in step.
    struct Presentation: Equatable {
        var phase: Phase
        var arrivalDelay: Double
        /// The brief post-arrival window where this pilot shows their own label
        /// even while labels are globally hidden.
        var showsArrivalLabel: Bool
        /// The pinned Sky anchor — see `Entry.slotIndex`.
        var slotIndex: Int
    }

    /// Ordered by stable id so slot assignment downstream stays deterministic.
    @Published private(set) var entries: [Entry] = []

    /// Published so a label clear or a settle actually reaches the view. (When
    /// this was plain stored state, clearing an arrival label mutated nothing
    /// SwiftUI was observing, so the label never faded.)
    @Published private(set) var presentation: [String: Presentation] = [:]

    /// One removal task per exiting pilot, so cancellation is precise and a
    /// journey teardown can drop them all.
    private var exitTasks: [String: Task<Void, Never>] = [:]
    /// Ids currently mid-exit. Consulted by `sync` to ignore stale re-additions —
    /// this is what stops a delayed Supabase update resurrecting a balloon for a
    /// frame, or restarting its entry animation.
    private var exiting: Set<String> = []
    /// Ids still inside their brief arrival-label window.
    private var recentlyEntered: Set<String> = []

    /// The journey this stage is bound to. A different id means a genuinely new
    /// flight, so nothing from the previous one may survive.
    private var journeyID: String?

    /// Bumped by `teardown()`. Every delayed task captures the value it was
    /// created under and refuses to mutate anything once the journey has moved
    /// on — belt-and-braces alongside cancellation, because a task can be resumed
    /// after `teardown` has already run and before its cancellation is observed.
    private var generation: UInt64 = 0

    /// The last snapshot we reconciled, retained so the completion clock can
    /// re-evaluate it against a fresh `now` without asking the view for anything.
    private var lastLive: [OnlinePilot] = []

    /// ONE timer for the whole stage, armed for the earliest pending
    /// `expectedEndAt`: not a repeating poll, and not one task per pilot. It wakes
    /// exactly when the next countdown reaches zero — so nobody ever sits visibly
    /// at `0:00` — then re-arms for whoever finishes after that.
    private var completionTask: Task<Void, Never>?
    /// The instant `completionTask` is currently waiting for, so a poll refresh
    /// that changes nothing does not tear the task down and rebuild it.
    private var armedDeadline: Date?

    // MARK: Journey ownership

    /// Bind the stage to one journey.
    ///
    /// Calling it again with the same id is a no-op — a child layer remounting
    /// mid-flight must not restart anyone's arrival. A DIFFERENT id is a genuinely
    /// new flight, so every task, phase and entry from the previous one is
    /// cancelled and dropped before the first reconciliation.
    func begin(journeyID id: String) {
        guard journeyID != id else { return }
        teardown()
        journeyID = id
    }

    // MARK: Sync

    /// Reconcile the live snapshot into presentation entries.
    ///
    /// - newly seen id                    → `.entering` (staggered within a batch)
    /// - still-present id, same session   → model refreshed, phase untouched
    /// - still-present id, NEW session    → lifecycle restarts as a fresh arrival
    /// - id that vanished                 → `.exiting(.departed)` + scheduled removal
    /// - id whose countdown hit zero      → `.exiting(.completed)` + scheduled removal
    /// - stale re-add of an exiting id    → IGNORED until its exit finishes
    ///
    /// `now` is threaded through every completion decision below, so one
    /// reconciliation pass is evaluated against exactly one instant.
    func sync(with live: [OnlinePilot], now: Date = Date()) {
        lastLive = live
        let liveByID = Dictionary(live.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var next: [Entry] = []
        // Ordinal within THIS reconciliation, for the arrival stagger.
        var arrivals = 0

        for existing in entries {
            if existing.phase.isExiting {
                // Hold it exactly as it is. A re-add during the exit window is
                // deliberately ignored — see `exiting`.
                next.append(existing)
                continue
            }
            guard let fresh = liveByID[existing.id] else {
                next.append(Entry(id: existing.id, pilot: existing.pilot,
                                  phase: .exiting(.departed), arrivalDelay: existing.arrivalDelay,
                                  slotIndex: existing.slotIndex))
                beginExit(existing.id, reason: .departed)
                continue
            }
            if Self.hasFinished(fresh, now: now) {
                next.append(Entry(id: existing.id, pilot: fresh,
                                  phase: .exiting(.completed), arrivalDelay: existing.arrivalDelay,
                                  slotIndex: existing.slotIndex))
                beginExit(existing.id, reason: .completed)
            } else if fresh.sessionID != existing.pilot.sessionID {
                // The SAME account on a NEW flight — they landed and took off
                // again. Not a flicker, and nothing is blacklisted: the lifecycle
                // simply restarts so it reads as a fresh arrival. They keep their
                // anchor, so the new flight rises back into the same patch of sky
                // instead of jumping across it.
                next.append(Entry(id: existing.id, pilot: fresh, phase: .entering,
                                  arrivalDelay: Self.staggerDelay(arrivals),
                                  slotIndex: existing.slotIndex))
                arrivals += 1
                recentlyEntered.insert(existing.id)
            } else {
                // Refresh the model in place; never re-enter, never re-slot.
                next.append(Entry(id: existing.id, pilot: fresh, phase: existing.phase,
                                  arrivalDelay: existing.arrivalDelay,
                                  slotIndex: existing.slotIndex))
            }
        }

        // Anchors held by everyone still on screen — exiting balloons included, so
        // an arrival can never be placed on top of a departure mid-fade.
        var taken = Set(next.map(\.slotIndex))
        let known = Set(next.map(\.id))
        for pilot in live where !known.contains(pilot.id) && !exiting.contains(pilot.id) {
            // A pilot whose countdown has already passed never arrives at all —
            // that is what stops a finished balloon flickering back in.
            guard !Self.hasFinished(pilot, now: now) else { continue }
            next.append(Entry(id: pilot.id, pilot: pilot, phase: .entering,
                              arrivalDelay: Self.staggerDelay(arrivals),
                              slotIndex: Self.claimSlot(for: pilot, taken: &taken)))
            arrivals += 1
            recentlyEntered.insert(pilot.id)
        }

        let sorted = next.sorted { $0.id < $1.id }
        if sorted != entries { entries = sorted }
        armCompletionClock(now: now)
        refreshPresentation()
    }

    /// Promote an entering pilot to active once its arrival animation has been
    /// committed. Called by the view; keeps the phase machine in one place.
    ///
    /// An exiting entry is never revived: only `.entering` may become `.active`.
    func settle(_ id: String) {
        guard let i = entries.firstIndex(where: { $0.id == id }), entries[i].phase == .entering else { return }
        entries[i].phase = .active
        refreshPresentation()
    }

    /// Stop showing the brief arrival label for this pilot.
    func clearArrivalLabel(_ id: String) {
        guard recentlyEntered.remove(id) != nil else { return }
        refreshPresentation()
    }

    /// Cancel everything — called when the journey goes away so no task outlives
    /// it, and by `begin(journeyID:)` when a new flight takes over.
    func teardown() {
        generation &+= 1
        completionTask?.cancel()
        completionTask = nil
        armedDeadline = nil
        exitTasks.values.forEach { $0.cancel() }
        exitTasks.removeAll()
        exiting.removeAll()
        recentlyEntered.removeAll()
        lastLive.removeAll()
        journeyID = nil
        entries.removeAll()
        presentation.removeAll()
    }

    // MARK: Internals

    /// Rebuild the layer-facing snapshot. One assignment, and only when it
    /// actually differs, so a poll refresh that changes nothing costs no redraw.
    private func refreshPresentation() {
        var out: [String: Presentation] = [:]
        out.reserveCapacity(entries.count)
        for e in entries {
            out[e.id] = Presentation(phase: e.phase,
                                     arrivalDelay: e.arrivalDelay,
                                     showsArrivalLabel: recentlyEntered.contains(e.id),
                                     slotIndex: e.slotIndex)
        }
        if out != presentation { presentation = out }
    }

    private static func staggerDelay(_ ordinal: Int) -> Double {
        min(Double(ordinal) * OnlinePilotLifecycle.arrivalStagger,
            OnlinePilotLifecycle.maxArrivalStagger)
    }

    /// Claim a free Sky anchor for a new arrival: start at the pilot's own seeded
    /// preference, then scan forward past anything already held.
    ///
    /// Called EXACTLY once per pilot, when their entry is created, and never
    /// revisited. That is the whole point — the previous stateless assignment
    /// recomputed every pilot's anchor from the current list, so when a pilot with
    /// an earlier id departed, whoever had been pushed past their anchor
    /// instantaneously teleported into it. Pinning the anchor means a departure
    /// frees a slot and moves nobody.
    ///
    /// Indexes into `AmbientPilotsLayer.skySlots` — the stage needs the count of
    /// collision-free anchors, never their geometry.
    private static func claimSlot(for pilot: OnlinePilot, taken: inout Set<Int>) -> Int {
        let count = max(1, AmbientPilotsLayer.skySlots.count)
        var i = Int(slotSeed(for: pilot) % UInt64(count))
        var probes = 0
        while taken.contains(i) && probes < count {
            i = (i + 1) % count
            probes += 1
        }
        taken.insert(i)
        return i
    }

    /// Deterministic anchor preference: account + session + Sky. Stable for the
    /// whole flight, and a genuinely new flight prefers a different anchor.
    private static func slotSeed(for pilot: OnlinePilot) -> UInt64 {
        var h: UInt64 = 0x9E37
        for u in (pilot.id + pilot.sessionID + pilot.skyID).unicodeScalars {
            h = (h &* 31) &+ UInt64(u.value)
        }
        return h
    }

    /// A pilot with a real live session whose canonical end has passed.
    /// Timestamp-derived — no per-pilot timer anywhere.
    ///
    /// A PAUSED pilot is never "finished", however long the pause runs. Their
    /// `expectedEndAt` deliberately stays at its pre-pause value until they
    /// resume (the server pushes it out then), so judging by the raw deadline
    /// would fly a merely-paused pilot away as soon as their frozen time elapsed
    /// in real seconds.
    private static func hasFinished(_ pilot: OnlinePilot, now: Date) -> Bool {
        guard pilot.hasLiveSession, !pilot.isPaused else { return false }
        guard let end = pilot.expectedEndAt else { return false }
        return end <= now
    }

    /// Arm (or keep) the single stage-wide wake for the next countdown to reach
    /// zero.
    ///
    /// A pilot can finish while still perfectly present in the networking
    /// snapshot, so completion is the one transition no snapshot change announces.
    /// The previous implementation polled every two seconds, which could leave a
    /// balloon visibly frozen at `0:00`. This instead sleeps until the exact
    /// `expectedEndAt` of whoever finishes soonest, so the exit starts on the same
    /// tick the label reaches zero, with one task for the whole Sky.
    private func armCompletionClock(now: Date) {
        // A paused pilot has no meaningful deadline to wake for — theirs is frozen
        // until they resume, at which point the server issues a new one and the
        // next reconciliation re-arms.
        let next = entries.compactMap { entry -> Date? in
            guard !entry.phase.isExiting, entry.pilot.hasLiveSession, !entry.pilot.isPaused,
                  let end = entry.pilot.expectedEndAt, end > now else { return nil }
            return end
        }.min()

        guard let next else {
            completionTask?.cancel()
            completionTask = nil
            armedDeadline = nil
            return
        }
        // Already waiting for this exact moment — leave the task alone rather than
        // restarting it on every refresh.
        if completionTask != nil, let armed = armedDeadline,
           abs(armed.timeIntervalSince(next)) < 0.25 { return }

        completionTask?.cancel()
        armedDeadline = next
        let gen = generation
        // A hair past the deadline, so the re-evaluation below is guaranteed to
        // see `end <= now` and cannot re-arm itself at a zero delay.
        let delay = max(0, next.timeIntervalSince(now)) + 0.05
        completionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: OnlinePilotLifecycle.nanoseconds(delay))
            guard !Task.isCancelled, let self, self.generation == gen else { return }
            self.completionTask = nil
            self.armedDeadline = nil
            // Re-reconcile the SAME snapshot against a fresh `now`: the pilot is
            // still present in networking, but their canonical end has now passed.
            self.sync(with: self.lastLive)
        }
    }

    /// Retain the entry for exactly as long as its animation needs, then drop it.
    /// Re-entrant-safe: an id already exiting keeps its original task.
    private func beginExit(_ id: String, reason: Reason) {
        guard !exiting.contains(id) else { return }
        exiting.insert(id)
        exitTasks[id]?.cancel()
        let gen = generation
        exitTasks[id] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: OnlinePilotLifecycle.nanoseconds(reason.duration))
            // Cancellation, then the generation token: a task resumed after a
            // journey teardown must not touch the new flight's entries.
            guard !Task.isCancelled, let self, self.generation == gen else { return }
            self.exitTasks[id] = nil
            self.exiting.remove(id)
            self.recentlyEntered.remove(id)
            // Remove ONLY if this id is still in the exact phase this task was
            // scheduled for. Anything else means the stage moved on and whoever
            // moved it owns the entry now.
            if let i = self.entries.firstIndex(where: { $0.id == id }),
               self.entries[i].phase == .exiting(reason) {
                self.entries.remove(at: i)
            }
            self.refreshPresentation()
        }
    }
}
