import Foundation
import UserNotifications

/// A lightweight snapshot of the state notifications care about.
struct NotificationState {
    var streak: Int
    var landedToday: Bool
    var goalsRemaining: Int
    var allGoalsDoneToday: Bool
    /// An unfinished, resumable journey (for a "continue your journey" reminder).
    var hasUnfinishedJourney: Bool = false
    var unfinishedOrigin: String? = nil
    var unfinishedDestination: String? = nil
    /// The user's current origin city, for warm, personalised copy.
    var originCity: String? = nil
}

/// Centralised, tasteful **local** notification strategy for retention — streak
/// protection, a daily focus / study nudge, unfinished-journey reminders and a
/// gentle comeback sequence. Duolingo-inspired but never manipulative: warm,
/// concise copy, **at most one notification per day**, with no guilt, shame or
/// fake urgency.
///
/// No backend / no push. Every reschedule clears the pending set and rebuilds the
/// plan from the latest state, so opening the app or completing a journey
/// naturally pushes the comeback messages out and prevents duplicates. Stable
/// per-day identifiers mean a notification is *replaced*, never stacked. Calendar
/// triggers fire at the right wall-clock time in the user's current time zone.
///
/// Permission is requested **provisionally** (no prompt, quiet delivery) only when
/// the user opens Passport or Settings — never at first launch and never after a
/// journey. The Settings → Reminders toggle is the explicit on/off.
/// See NOTIFICATIONS_STRATEGY.md.
@MainActor
final class NotificationService {
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private let enabledKey = "fg.notifications.enabled"

    /// Stable identifiers — one slot per upcoming day, so a reschedule *replaces*
    /// (never stacks) and we keep at most one notification per day.
    private enum ID {
        static let today = "fg.notif.day0"
        static let day1  = "fg.notif.day1"
        static let day2  = "fg.notif.day2"
        static let day3  = "fg.notif.day3"
    }

    /// User-facing toggle (defaults ON; only schedules once authorised).
    var isEnabled: Bool {
        get { defaults.object(forKey: enabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    func setEnabled(_ on: Bool) {
        isEnabled = on
        if !on {
            center.removeAllPendingNotificationRequests()
            log("disabled → cleared all pending")
        }
    }

    // MARK: Permission

    /// Normal, prompting permission — only for an **explicit** opt-in (the Settings
    /// → Reminders toggle). Requests once, when undecided.
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

    /// **Provisional** authorization (no prompt, quiet delivery) the first time the
    /// user reaches a calm surface (Passport / Settings). iOS grants it silently;
    /// the user can promote it to prominent alerts in iOS Settings. Only acts while
    /// undecided, so it never prompts twice. Graceful if denied (nothing schedules).
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

    /// Rebuild the plan from the latest state (only if enabled + authorised). Safe
    /// to call on launch, when the app returns to the foreground, after a landing,
    /// and when settings change.
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

    // MARK: The strategic plan (≤ 1 per day, no duplicates)

    private func reschedule(state: NotificationState) {
        center.removeAllPendingNotificationRequests()
        let cal = Calendar.current
        let now = Date()
        var scheduled = 0

        func plan(dayOffset: Int, hour: Int, id: String, title: String, body: String) {
            guard let dayStart = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: now)),
                  let fire = cal.date(bySettingHour: hour, minute: 0, second: 0, of: dayStart),
                  fire > now else { return }
            schedule(id, title: title, body: body, at: fire)
            scheduled += 1
        }

        // TODAY — one best-fit reminder, only if it'd still fire later today and the
        // user hasn't already focused. Priority: unfinished journey → streak → focus.
        // (Never a streak-loss message once today's journey is done — `landedToday`.)
        if state.hasUnfinishedJourney {
            plan(dayOffset: 0, hour: 19, id: ID.today,
                 title: "Your balloon is still waiting", body: unfinishedBody(state))
        } else if state.streak > 0 && !state.landedToday {
            plan(dayOffset: 0, hour: 20, id: ID.today,
                 title: "Your \(state.streak)-day streak is waiting 🔥", body: pick(Self.streakBodies))
        } else if !state.landedToday {
            plan(dayOffset: 0, hour: 17, id: ID.today,
                 title: "Ready for one focused journey?", body: dailyBody(state, offset: 0))
        }

        // TOMORROW — a calm daily focus / study nudge (alternating, personalised).
        plan(dayOffset: 1, hour: 10, id: ID.day1,
             title: dailyTitle(offset: 1), body: dailyBody(state, offset: 1))

        // +2 / +3 days — gentle comeback. Only reaches genuinely inactive users:
        // opening the app reschedules and pushes these later.
        plan(dayOffset: 2, hour: 11, id: ID.day2,
             title: "Your passport has been quiet", body: pick(Self.comebackBodies))
        plan(dayOffset: 3, hour: 11, id: ID.day3,
             title: "A new journey is waiting", body: pick(Self.comebackBodies, offset: 1))

        log("rescheduled \(scheduled) reminder(s); streak=\(state.streak) landedToday=\(state.landedToday) unfinished=\(state.hasUnfinishedJourney)")
    }

    private func schedule(_ id: String, title: String, body: String, at date: Date) {
        // Calendar trigger → fires at this wall-clock time in the user's current
        // time zone (robust if they travel after scheduling).
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        log("scheduled \(id) — \"\(title)\"")
    }

    private func log(_ msg: String) {
        #if DEBUG
        print("[Notifications] \(msg)")
        #endif
    }

    // MARK: Copy (warm, concise, personalised — no guilt, no fake urgency)

    private func unfinishedBody(_ s: NotificationState) -> String {
        if let o = s.unfinishedOrigin, let d = s.unfinishedDestination {
            return "Continue your journey from \(o) to \(d)."
        }
        return "Pick up the route you started whenever you're ready."
    }

    private func dailyTitle(offset: Int) -> String {
        Self.dailyTitles[abs(dayIndex() + offset) % Self.dailyTitles.count]
    }

    /// Alternates calm focus copy with light study/work motivation. No location
    /// data (no city name, no coordinates) ever appears in notification text.
    private func dailyBody(_ s: NotificationState, offset: Int) -> String {
        let useFocus = (dayIndex() + offset).isMultiple(of: 2)
        let pool = useFocus ? Self.focusBodies : Self.studyBodies
        return pool[abs(dayIndex() + offset) % pool.count]
    }

    /// Deterministic, day-rotating pick so copy varies without feeling random.
    private func pick(_ options: [String], offset: Int = 0) -> String {
        options[abs(dayIndex() + offset) % options.count]
    }

    private func dayIndex() -> Int {
        Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
    }

    // Warm, premium, slightly playful. No guilt, no "you failed", no fake urgency,
    // and never any location data.
    private static let dailyTitles = [
        "Ready for one focused journey?",
        "One focus flight before the day ends?",
        "Your next deep-work block awaits",
    ]
    private static let streakBodies = [
        "One short journey keeps your focus streak alive.",
        "Your streak is too good to lose now.",
        "A 20-minute journey is enough to protect your streak.",
        "Take off for one short session and keep your streak alive.",
    ]
    private static let focusBodies = [
        "Pick a destination and give yourself 25 minutes.",
        "Your balloon hasn't taken off yet today.",
        "Land one journey today and keep your momentum.",
        "Your passport is missing today's stamp.",
    ]
    private static let studyBodies = [
        "Need to study? Start with one calm journey.",
        "One focused session before distractions win.",
        "Turn your next destination into a deep-work block.",
    ]
    private static let comebackBodies = [
        "The globe is ready when you are.",
        "Your balloon is ready whenever you are.",
        "Come back for one calm focus trip.",
        "A new journey is waiting when you are.",
    ]
}
