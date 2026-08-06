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
    /// A real, unclaimed daily gift is waiting (drives `dailyGiftReady`).
    var dailyGiftAvailable: Bool = false
    /// PRO / Lifetime — never receives PRO / feature-discovery notifications.
    var isPremium: Bool = false
}

/// The retention notification categories. `transactional` categories (a reminder
/// the user effectively asked for, or a real waiting reward) do NOT count toward
/// the marketing frequency cap; every other category does.
enum NotificationCategory: String {
    case streakAtRisk, plannedFocus, dailyGiftReady, dailyGoalIncomplete
    case reactivation, friendsActivity, featureDiscovery, unfinishedJourney

    var isTransactional: Bool {
        switch self {
        case .plannedFocus, .dailyGiftReady, .unfinishedJourney: return true
        default: return false
        }
    }
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
        static let today   = "fg.notif.day0"
        static let day1    = "fg.notif.day1"
        static let react3  = "fg.notif.react3"
        static let react7  = "fg.notif.react7"
        static let react14 = "fg.notif.react14"
    }

    /// Analytics sink for the scheduling side (scheduled / cancelled). AppModel
    /// wires this to its analytics pipeline; opened / delivered are observed by the
    /// `UNUserNotificationCenterDelegate`. `(action, category)`.
    var onEvent: ((String, String) -> Void)?

    /// Quiet hours 21:30–08:00 — never fire a notification before 08:00 or after
    /// 21:30 in the user's local time (a scheduled focus reminder the user set for
    /// themselves would be the only exception; the app has no such feature yet).
    private func clampToWakingHours(_ hour: Int, _ minute: Int) -> (Int, Int) {
        let mins = hour * 60 + minute
        if mins < 8 * 60 { return (8, 0) }
        if mins > 21 * 60 + 30 { return (21, 0) }
        return (hour, minute)
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
        Task { @MainActor [weak self] in
            guard let self else { return }
            _ = await self.requestAuthorization(state: state)
        }
    }

    /// Awaitable variant, for a caller that must know whether the pilot said
    /// yes. Onboarding itself asks for nothing — a system sheet before the offer
    /// is friction at the worst possible moment — so the first-run request is
    /// made by Home on arrival, plus the in-context asks from Passport and
    /// Settings. Every one of them lands here, and every one is a no-op unless
    /// iOS has genuinely never asked.
    @discardableResult
    func requestAuthorization(state: NotificationState) async -> Bool {
        guard isEnabled else { return false }
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(
                options: [.alert, .sound, .badge]
            )) ?? false
            if granted { reschedule(state: state) }
            return granted
        case .authorized, .provisional, .ephemeral:
            reschedule(state: state)
            return true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    /// **Provisional** authorization (no prompt, quiet delivery) the first time the
    /// user reaches a calm surface (Passport / Settings). iOS grants it silently;
    /// the user can promote it to prominent alerts in iOS Settings. Only acts while
    /// undecided, so it never prompts twice. Graceful if denied (nothing schedules).
    func requestProvisionalAuthorizationIfNeeded(state: NotificationState) {
        guard isEnabled else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let settings = await self.center.notificationSettings()
            guard settings.authorizationStatus == .notDetermined else { return }
            let granted = (try? await self.center.requestAuthorization(options: [.alert, .sound, .badge, .provisional])) ?? false
            if granted { self.reschedule(state: state) }
        }
    }

    /// Rebuild the plan from the latest state (only if enabled + authorised). Safe
    /// to call on launch, when the app returns to the foreground, after a landing,
    /// and when settings change.
    func refresh(state: NotificationState) {
        guard isEnabled else { center.removeAllPendingNotificationRequests(); return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let settings = await self.center.notificationSettings()
            let ok = settings.authorizationStatus == .authorized
                  || settings.authorizationStatus == .provisional
            if ok { self.reschedule(state: state) }
            else { self.center.removeAllPendingNotificationRequests() }
        }
    }

    // MARK: The strategic plan (≤ 1 per day, no duplicates)

    private func reschedule(state: NotificationState) {
        center.removeAllPendingNotificationRequests()
        onEvent?("cancelled", "all")
        let cal = Calendar.current
        let now = Date()
        // Non-transactional (marketing) frequency cap across the forward plan.
        var marketing = 0
        let marketingCap = 4

        func plan(dayOffset: Int, hour: Int, minute: Int = 0, id: String,
                  category: NotificationCategory, title: String, body: String) {
            // A PRO / Lifetime pilot never gets feature-discovery / PRO nudges.
            if category == .featureDiscovery && state.isPremium { return }
            if !category.isTransactional && marketing >= marketingCap { return }
            let (h, m) = clampToWakingHours(hour, minute)
            guard let dayStart = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: now)),
                  let fire = cal.date(bySettingHour: h, minute: m, second: 0, of: dayStart),
                  fire > now else { return }
            schedule(id, category: category, title: title, body: body, at: fire)
            if !category.isTransactional { marketing += 1 }
        }

        // TODAY — at most ONE reminder, best-fit by priority, only while it can
        // still fire and the user hasn't already focused. It is cancelled the moment
        // they land (this reschedule runs on completion with landedToday == true).
        if state.hasUnfinishedJourney {
            plan(dayOffset: 0, hour: 19, id: ID.today, category: .unfinishedJourney,
                 title: "Your balloon is still waiting", body: unfinishedBody(state))
        } else if state.streak > 0 && !state.landedToday {
            // Streak-at-risk ONLY when a streak actually exists.
            plan(dayOffset: 0, hour: 19, minute: 30, id: ID.today, category: .streakAtRisk,
                 title: "Your \(state.streak)-day streak is waiting 🔥", body: pick(Self.streakBodies))
        } else if state.dailyGiftAvailable {
            plan(dayOffset: 0, hour: 18, id: ID.today, category: .dailyGiftReady,
                 title: "A gift is waiting in FocusGlobe",
                 body: "Open your daily gift before it flies away.")
        } else if state.goalsRemaining > 0 && !state.landedToday {
            // Daily-goal reminder ONLY when today's goal is still incomplete.
            plan(dayOffset: 0, hour: 19, minute: 30, id: ID.today, category: .dailyGoalIncomplete,
                 title: "One calm flight can finish today", body: pick(Self.focusBodies))
        }

        // TOMORROW — a calm daily focus / study nudge (alternating, personalised).
        plan(dayOffset: 1, hour: 10, id: ID.day1, category: .dailyGoalIncomplete,
             title: dailyTitle(offset: 1), body: dailyBody(state, offset: 1))

        // REACTIVATION milestones at +3 / +7 / +14 days. Only genuinely inactive
        // users ever reach them — opening the app reschedules and pushes them out.
        plan(dayOffset: 3, hour: 11, id: ID.react3, category: .reactivation,
             title: "The sky is still here", body: pick(Self.comebackBodies))
        plan(dayOffset: 7, hour: 11, id: ID.react7, category: .reactivation,
             title: "Ready for another quiet flight?", body: pick(Self.comebackBodies, offset: 1))
        plan(dayOffset: 14, hour: 11, id: ID.react14, category: .reactivation,
             title: "A new expedition is waiting", body: pick(Self.comebackBodies, offset: 2))

        log("rescheduled; streak=\(state.streak) landedToday=\(state.landedToday) gift=\(state.dailyGiftAvailable) goals=\(state.goalsRemaining)")
    }

    private func schedule(_ id: String, category: NotificationCategory,
                          title: String, body: String, at date: Date) {
        // Calendar trigger → fires at this wall-clock time in the user's current
        // time zone (robust if they travel after scheduling).
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["category": category.rawValue]   // for opened-analytics
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        Task { try? await center.add(request) }
        onEvent?("scheduled", category.rawValue)
        log("scheduled \(id) [\(category.rawValue)] — \"\(title)\"")
    }

    private func log(_ msg: String) {
        #if DEBUG
        print("[Notifications] \(msg)")
        #endif
    }

    // MARK: Copy (warm, concise, personalised — no guilt, no fake urgency)

    private func unfinishedBody(_ s: NotificationState) -> String {
        if let o = s.unfinishedOrigin, let d = s.unfinishedDestination {
            return "Continue your expedition from \(o) to \(d)."
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
        "Ready for one focused expedition?",
        "One focused drift before the day ends?",
        "Your next deep-work block awaits",
    ]
    private static let streakBodies = [
        "One short expedition keeps your focus streak alive.",
        "Your streak is too good to lose now.",
        "A 20-minute expedition is enough to protect your streak.",
        "Set off on one short session and keep your streak alive.",
    ]
    private static let focusBodies = [
        "Pick a destination and give yourself 25 minutes.",
        "Your balloon hasn't taken off yet today.",
        "Complete one expedition today and keep your momentum.",
        "Your journal is missing today's stamp.",
    ]
    private static let studyBodies = [
        "Need to study? Start with one calm expedition.",
        "One focused session before distractions win.",
        "Turn your next destination into a deep-work block.",
    ]
    private static let comebackBodies = [
        "The globe is ready when you are.",
        "Your balloon is ready whenever you are.",
        "Come back for one calm focus trip.",
        "A new expedition is waiting when you are.",
    ]
}
