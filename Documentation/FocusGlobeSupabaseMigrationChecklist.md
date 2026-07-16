# FocusGlobe → Supabase migration checklist (Phase 0 artifact)

Status legend: ✅ done in code · 🖐 owner action required · 🧪 needs device/build

## Audit (Phase 0)
- ✅ Mapped every CloudKit usage (13 files importing CloudKit; CKShare UI;
  delegate hooks; entitlements; CKSharingSupported; contacts flow)
- ✅ Mapped all published state + every external caller of FocusOnlineModel
- ✅ Preserved view contracts (FriendsView / FlightModeSelector / InvitePeople /
  Lobby / AmbientPilots / FocusSession / Cabin / Settings / Diagnostics)

## Backend (Phases 2–4)
- ✅ `supabase/migrations/20260716090000_focusglobe_online.sql` — 11 tables,
  indexes, triggers, helpers, RLS on every table, grants, 17 RPCs, realtime
- ✅ `supabase/seed.sql` (deliberately empty — no fake users)
- 🖐 Execute the migration (SQL Editor or `supabase db push`)
- 🖐 Resume the paused/"Unhealthy" free-tier project before testing
- 🖐 Rotate the database password (it was pasted into chat)

## App (Phases 1, 5–12)
- ✅ supabase-swift SPM package added to the app target (pbxproj)
- ✅ SupabaseConfig (URL + publishable key only; Info.plist overrides)
- ✅ One shared client (SupabaseService); no competing clients
- ✅ Native Sign in with Apple (SwiftUI button, nonce+SHA256, ID-token flow,
  first-run full-name capture into private metadata, cancel-safe)
- ✅ Services: Auth / Profile / PublicFlight / Room / Friend / Realtime /
  Moderation / OnlineReward / DeepLink
- ✅ FocusOnlineModel rewritten (same API surface; OnlineState authoritative;
  RoomCreationState single-flight; overlap + server-verified friend bonus)
- ✅ Public flights: active_flights heartbeats (~40 s + edges), stale filter,
  sky presence channel, bots remain client-side only
- ✅ Private rooms: RPC create/invite/join/ready/start/leave/remove/close;
  realtime lobby; member auto-start; reconnect reconciliation
- ✅ Invitations: one-time hashed tokens; focusglobe://join/<token> scheme;
  pending-invite-after-sign-in; marketing share fully separate
- ✅ Friends/Crew, blocks (new), reports on Supabase
- ✅ Settings: account row (sign in/out), alias, toggles, Delete Online Data
- ✅ DEBUG diagnostics rewritten (exact backend error surfaced)
- ✅ Solo untouched: no auth, zero online calls, works offline

## CloudKit removal (Phase 13)
- ✅ Deleted: CloudKitConfig/Environment/IdentityService, FocusRoomService,
  PresenceService, PublicProfileService, OnlineNotificationService,
  ContactInvitationService, CloudShareService, CloudSharingView,
  FocusIdentity, CloudAvailability, SkySocialServices stub, CK schema doc
- ✅ Entitlements: iCloud/ubiquity keys removed; applesignin/aps/groups/family
  kept; Info.plist: CKSharingSupported + contacts usage + remote-notification
  background mode removed; URL scheme added
- ✅ Sweep: zero CloudKit/CKShare/CKContainer references remain in Swift
- 🖐 In Xcode Signing & Capabilities, delete the lingering iCloud capability
  ROW if the UI still shows one (the entitlements file is already clean)

## Docs (Phase 14)
- ✅ FocusGlobeSupabaseSetup.md / FocusGlobeOnlineTestPlan.md /
  FocusGlobePrivacyDataMap.md / this checklist

## Tests (Phase 15)
- ✅ Two-device manual checklist + edge cases (test plan doc)
- 🖐 No unit-test target exists in the project; unit specs are listed in the
  test plan to implement once a target is added

## Build & release (Phase 16)
- 🧪 Open in Xcode → resolve packages → clean build (no compiler here)
- 🧪 Two-account device pass (test plan §B)
- 🖐 Universal link domain + AASA + Associated Domains (later; scheme works now)
- 🖐 Replace MarketingConfig.appStoreURLString with the real listing URL
