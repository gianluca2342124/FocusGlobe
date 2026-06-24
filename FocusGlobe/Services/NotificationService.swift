import Foundation
import UserNotifications

/// A lightweight snapshot of the state notifications care about.
struct NotificationState {
    var streak: Int
    var landedToday: Bool
    var goalsRemaining: Int
    var allGoalsDoneToday: Bool
}

/// Centralised, tasteful **local** notification scheduling for re-engagement and
/// streak retention. No remote push, no analytics SDK. Every reschedule clears
/// the pending set and re-creates only the relevant reminders, so the user is
/// never spammed and reminders always reflect the latest progress.
///
/// Permission is requested only at a calm, user-initiated moment — when the user
/// opens the Passport or Settings — never after a journey completes and never
/// aggressively at first launch. That request uses **provisional** authorization,
/// which iOS grants *without a prompt* and delivers quietly, so the user is never
/// interrupted; the explicit Reminders toggle in Settings still does a normal
/// opt-in prompt. The enabled flag lives in `UserDefaults` so nothing in the
/// app's settings model changes.
@MainActor
final class NotificationService {
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private let enabledKey = "fg.notifications.enabled"

    private enum ID {
        static let streak   = "fg.notif.streak_protection"
        static let focus    = "fg.notif.daily_focus"
        static let goals    = "fg.notif.goal_progress"
        static let comeback1 = "fg.notif.comeback_1"
        static let comeback2 = "fg.notif.comeback_2"
    }

    /// User-facing toggle (defaults ON; only schedules once authorised).
    var isEnabled: Bool {
        get { defaults.object(forKey: enabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    func setEnabled(_ on: Bool) {
        isEnabled = on
        if !on { center.removeAllPendingNotificationRequests() }
    }

    // MARK: Permission

    /// Request a normal, prompting permission — used only for an **explicit**
    /// opt-in (the Settings → Reminders toggle). Requests once, when undecided.
    func requestAuthorizationIfNeeded(state: NotificationState) {
        guard isEnabled else { return }
        center.getNotificationSettings { [weak self] settings in
            guard let self, settings.authorizationStatus == .notDetermined else { return }
            self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                guard granted else { return }
                Task { @MainActor in self.reschedule(state: state) }
            }
        }
    }

    /// Request **provisional** authorization (no prompt, quiet delivery) the first
    /// time the user reaches a calm, relevant surface (Passport / Settings). iOS
    /// grants this silently — the user is never interrupted — and reminders begin
    /// arriving quietly in Notification Center; the user can promote them to
    /// prominent alerts any time in iOS Settings. Only acts while undecided, so it
    /// never overrides an explicit choice and never prompts twice. Safe/graceful
    /// if denied (nothing is scheduled). Reschedules on grant.
    func requestProvisionalAuthorizationIfNeeded(state: NotificationState) {
        guard isEnabled else { return }
        center.getNotificationSettings { [weak self] settings in
            guard let self, settings.authorizationStatus == .notDetermined else { return }
            self.center.requestAuthorization(options: [.alert, .sound, .badge, .provisional]) { granted, _ in
                guard granted else { return }
                Task { @MainActor in self.reschedule(state: state) }
            }
        }
    }

    /// Reschedule from the latest state (only if enabled + authorised). Safe to
    /// call on launch, after a landing, and when settings change.
    func refresh(state: NotificationState) {
        guard isEnabled else { center.removeAllPendingNotificationRequests(); return }
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            let ok = settings.authorizationStatus == .authorized
                  || settings.authorizationStatus == .provisional
            Task { @MainActor in
                if ok { self.reschedule(state: state) }
                else { self.center.removeAllPendingNotificationRequests() }
            }
        }
    }

    // MARK: Scheduling

    private func reschedule(state: NotificationState) {
        center.removeAllPendingNotificationRequests()
        let cal = Calendar.current
        let now = Date()

        // A. Streak protection — tonight ~20:00, only with a live streak not yet
        //    continued today (the highest-priority reminder).
        if state.streak > 0, !state.landedToday,
           let fire = cal.date(bySettingHour: 20, minute: 0, second: 0, of: now), fire > now {
            schedule(ID.streak,
                     title: "Protect your \(state.streak)-day streak 🔥",
                     body: pick(Self.streakBodies), at: fire)
        }

        // B. Daily focus — a calm morning nudge at ~10:00 (tomorrow if past, or if
        //    already flown today).
        if let base = cal.date(bySettingHour: 10, minute: 0, second: 0, of: now) {
            let fire = (base > now && !state.landedToday) ? base
                     : (cal.date(byAdding: .day, value: 1, to: base) ?? base)
            schedule(ID.focus, title: "Time to take off ✈️", body: pick(Self.focusBodies), at: fire)
        }

        // C. Goal progress — early evening ~18:00 if goals remain today.
        if state.goalsRemaining > 0, !state.allGoalsDoneToday,
           let fire = cal.date(bySettingHour: 18, minute: 0, second: 0, of: now), fire > now {
            let n = state.goalsRemaining
            schedule(ID.goals,
                     title: "\(n) goal\(n == 1 ? "" : "s") left today",
                     body: pick(Self.goalBodies), at: fire)
        }

        // D. Comeback — fires only if the app isn't reopened (each refresh pushes
        //    these out), so they reach genuinely inactive users at +2 and +3 days.
        schedule(ID.comeback1, title: "Your balloon is waiting",
                 body: pick(Self.comebackBodies), at: now.addingTimeInterval(2 * 86_400))
        schedule(ID.comeback2, title: "Keep your momentum",
                 body: pick(Self.comebackBodies, offset: 1), at: now.addingTimeInterval(3 * 86_400))
    }

    private func schedule(_ id: String, title: String, body: String, at date: Date) {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// Deterministic, day-rotating pick so copy varies without feeling random.
    private func pick(_ options: [String], offset: Int = 0) -> String {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return options[(day + offset) % options.count]
    }

    // MARK: Copy (English for now; varied so it never feels robotic)

    private static let streakBodies = [
        "A quick focus journey keeps your streak alive before midnight.",
        "Don't let your streak slip — take off for a short flight tonight.",
        "Five calm minutes is all it takes to protect your streak.",
    ]
    private static let focusBodies = [
        "Pick a destination and drift into focus.",
        "Start a calm journey and make today count.",
        "Your next destination is one take-off away.",
    ]
    private static let goalBodies = [
        "Finish strong — wrap up today's goals.",
        "You're close. Complete today's goals and earn your miles.",
        "A short journey can close out today's goals.",
    ]
    private static let comebackBodies = [
        "Your balloon misses you — take off for a quick journey.",
        "Come back and drift somewhere new today.",
        "A calm focus flight is waiting whenever you're ready.",
    ]
}
