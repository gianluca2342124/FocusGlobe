# FocusGlobe — Persistence & Pro Model (v1.0)

FocusGlobe is **local-first with no backend and no account system**. Progress lives
on the device; **Pro entitlement is handled by Apple In-App Purchase + RevenueCat**.
There is **no Supabase / Firebase / custom database / CloudKit / login** in v1.0.

## What is stored locally (on device)

All app data is `Codable` in `UserDefaults` via `Services/PersistenceService.swift`
(keys prefixed `fg.`). It never leaves the device and needs no network.

| Data | Where | Persistence key |
|------|-------|-----------------|
| Completed journeys (history) | `AppModel.history` (`[FocusSessionRecord]`) | `fg.history` |
| Completed-route set / unlocked local rewards | `UserProgress.completedRouteIDs` | `fg.progress` |
| Current / paused journey (resume) | `AppModel.resumableJourney` | `fg.resumableJourney` |
| Virtual origin after landing ("travel the world") | `AppSettings.virtualOrigin` | `fg.settings` |
| Previous origin (return trips) | `AppSettings.previousOrigin` | `fg.settings` |
| Manual starting city | `AppSettings.startingCity` | `fg.settings` |
| Passport (postcards, landings, best focus) | `UserProgress` | `fg.progress` |
| Focus miles | `UserProgress.totalFocusMiles` | `fg.progress` |
| Streak (current / longest / last-landing day) | `UserProgress.currentStreak` etc. | `fg.progress` |
| Daily goals progress | **derived** from `fg.history` (computed live); the once-per-day bonus claim is `UserProgress.missionRewardDay` | `fg.history` / `fg.progress` |
| Selected balloon skin | `AppSettings.selectedSkinID` | `fg.settings` |
| Selected journey sound | `AppSettings.selectedJourneyAudioID` | `fg.settings` |
| Skin / audio **unlock** state | **derived** from `UserProgress` milestones + Pro (never stored as "permanently unlocked") | `fg.progress` |
| Appearance (Dark/Light/System) | `AppSettings.appearance` | `fg.settings` |
| Sound / Haptics toggles | `AppSettings.soundEnabled` / `hapticsEnabled` | `fg.settings` |
| Default map style | `AppSettings.mapStyle` | `fg.settings` |
| Reminders toggle | `NotificationService.isEnabled` | `fg.notifications.enabled` |
| Pro mirror (local cache) | `AppModel.isPro` | `fg.isPro` |

Writes are immediate: `AppSettings` saves on every change (`didSet`), progress/history
save via `persistAll()` after each journey/claim, and `isPro` is mirrored on change.

> In-session map toggles (live map style, labels, 2D/3D tilt) are intentionally
> **ephemeral** per journey — only the persisted *default* map style is remembered.

## What Apple + RevenueCat handle (Pro)

- Purchases & restore go through **StoreKit via RevenueCat** (`SubscriptionManager`),
  using the SDK `Package` — never REST product-ID strings.
- **Entitlement is checked on launch and foreground**:
  - launch: `configure()` → `refreshCustomerInfo()` + a `customerInfoStream` listener;
  - foreground: `FocusGlobeApp` scene-phase `.active` → `AppModel.refreshSubscriptionStatus()`.
- RevenueCat is the **source of truth**; the local `fg.isPro` is only a cache so a
  returning Pro user isn't briefly un-Pro before RevenueCat re-resolves.
- **Pro hides all ads** (`AdService` gates rewarded / interstitial / banner on `isPro`)
  and **unlocks Long/Ultra journeys** (`AppModel.isUnlocked` → Pro) plus premium skins,
  premium journey audio, and the widgets.
- **Restore Purchases** is available in **Settings ▸ FocusGlobe Pro** and on the paywall.

## Widgets

Widgets read a **read-only snapshot from the App Group** `group.com.focusglobe.app`
(`WidgetStore`), written by `AppModel.syncWidgets()`. No backend; widgets never touch
live app state and fall back to placeholders before the group is linked.

## Reinstall (delete + reinstall the app)

- **Local progress may be lost** (miles, streak, passport, skins, settings, resume) —
  this is acceptable for v1.0 and expected for a local-first app.
- **Pro is recoverable**: tap **Restore Purchases** (Settings or paywall) while signed
  into the same Apple ID — RevenueCat/Apple restore the entitlement.

## Another device (same Apple ID)

- **Pro restores** on the new device via **Restore Purchases** (same Apple ID).
- **Local progress does NOT sync** across devices in v1.0 (each device keeps its own
  local data).

## Intentionally NOT in v1.0

- No account / login. No cloud progress sync. No iCloud/CloudKit. No backend.
- iCloud (CloudKit/NSUbiquitousKeyValueStore) progress sync **could** be added later
  behind the same `PersistenceService` boundary without changing call sites — **not**
  implemented now.

## App Store wording

- The app must **not** promise cross-device progress sync. (No such copy exists; the
  Settings privacy note states data "stays on device", which is accurate.)
- Ensure the hosted **Privacy Policy** reflects: on-device storage, no account, and
  that purchases are handled by Apple/RevenueCat. See APP_STORE_FINAL_CHECKLIST.md ▸ D.
