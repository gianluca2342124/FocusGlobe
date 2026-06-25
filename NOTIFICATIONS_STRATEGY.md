# FocusGlobe — Local Notification Strategy

Tasteful, Duolingo-inspired retention using **local notifications only** (no
backend, no push). The whole plan lives in `FocusGlobe/Services/NotificationService.swift`.

## Principles

- **At most one notification per day.** Stable per-day identifiers (`fg.notif.day0…day3`)
  mean each reschedule *replaces* rather than stacks.
- **Rebuild from state, never append.** `refresh(state:)` clears all pending and
  rebuilds. Called on launch, on **return to foreground** (`FocusGlobeApp` scene
  phase), after a **landing** (`completeJourney`), and when settings change — so
  comeback messages are always pushed out for an active user and never duplicate.
- **Time-zone safe.** `UNCalendarNotificationTrigger` fires at the right wall-clock
  time in the user's current calendar.
- **No guilt / no fake urgency.** Warm, concise copy. Never a streak-loss message
  once today's journey is done (`landedToday`).
- **Permission** is **provisional** (no prompt) on first Passport/Settings visit;
  the Settings → Reminders toggle is the explicit on/off. Never asked at first launch.

## The daily plan (priority-ordered, one per day)

| Slot | When | Condition | Message (personalised) |
|------|------|-----------|------------------------|
| Today | ~19:00 | has an **unfinished journey** | "Your balloon is still waiting" · *Continue your journey from {origin} to {destination}.* |
| Today | ~20:00 | active **streak** & not landed today | "Your N-day streak is waiting 🔥" |
| Today | ~17:00 | hasn't focused today | "Ready for one focused journey?" (focus / study copy) |
| +1 day | ~10:00 | always | Daily focus / study nudge (alternates; uses current city) |
| +2 days | ~11:00 | only if app not reopened | "Your passport has been quiet" (comeback) |
| +3 days | ~11:00 | only if app not reopened | "A new journey is waiting" (comeback) |

"Today" schedules **one** best-fit reminder (unfinished → streak → focus) and only
if it would still fire later today. Opening the app reschedules everything, so the
+2/+3 comebacks only ever reach genuinely inactive users.

## Personalisation

- **Streak count** in the streak title.
- **Origin → destination** in the unfinished-journey body.
- **Current city** substituted into the daily focus copy when available.

## Copy categories (see source for the full pools)

A. Streak protection · B. Daily focus · C. Study/work motivation (alternates with B)
· D. Unfinished journey (personalised) · E. Comeback (+2/+3 days).
F. Celebration/milestone copy is intentionally **not** auto-scheduled yet (it would
fire immediately on a milestone, a separate mechanism) — a future enhancement.

## Debug

In DEBUG, every schedule/clear logs `[Notifications] …` (scheduled id + title,
"cleared all pending", and the per-reschedule summary with streak/landedToday/unfinished).
Compiled out of Release.

## Settings & privacy

- Settings ▸ Reminders toggles the whole system (`setEnabled` clears pending when off).
- If permission is denied, nothing is scheduled (graceful) and we never re-prompt.
- No personal data leaves the device; copy is assembled locally from on-device state.
