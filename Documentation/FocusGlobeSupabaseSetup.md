# FocusGlobe Online — Supabase Setup

FocusGlobe Online runs entirely on Supabase (project `hmbxpkcolhloszzlqjwr`,
North EU). There is **no CloudKit dependency** and no reliance on the user's
iCloud storage quota.

> **Nothing is live until the migration below is executed.** SQL files in this
> repo do NOT deploy themselves. Follow §1 first, verify §5, then test.

---

## 1. Deploy the database migration (required, owner-only)

Option A — SQL Editor (simplest):
1. <https://supabase.com/dashboard> → project **FocusGlobe** → **SQL Editor**.
2. Paste the full contents of
   `supabase/migrations/20260716090000_focusglobe_online.sql` and **Run**.
3. Re-running is safe (idempotent `if not exists` / `or replace` almost
   everywhere); if a re-run complains about an existing constraint, that
   object is already deployed.

Option B — CLI:
```bash
supabase login
supabase init            # once, in the repo root (config.toml)
supabase link --project-ref hmbxpkcolhloszzlqjwr
supabase db push         # applies supabase/migrations/*
```

Note: the free-tier project showed **"Unhealthy"** in the dashboard — free
projects pause after inactivity. Restore/resume the project in the dashboard
BEFORE running the migration or testing the app.

## 2. Apple provider (Supabase Auth)

Dashboard → **Authentication → Sign In / Providers → Apple**:
- **Enable Sign in with Apple**: ON (already done).
- **Client IDs**: must contain the app bundle ID `com.focusglobe.app`
  (already done). This is ALL native iOS/macOS sign-in needs.
- **Secret Key (for OAuth)**: only required for *web* OAuth flows. Leave empty
  unless you later add web sign-in. (If you ever fill it: it's generated from
  the Apple .p8 key and expires every 6 months.)
- The **OAuth Server** tab (authorization path/consent screens) is NOT used by
  the app — no action needed there.

Apple Developer portal:
- The App ID `com.focusglobe.app` must have the **Sign In with Apple**
  capability enabled (Xcode automatic signing usually adds this when the
  entitlement is present — it already is in `FocusGlobe.entitlements`).

## 3. App configuration (already wired)

| Value | Where | Safe to ship? |
|---|---|---|
| Project URL `https://hmbxpkcolhloszzlqjwr.supabase.co` | `SupabaseConfig.projectURLString` (Info.plist key `SupabaseURL` overrides) | ✅ yes |
| Publishable key `sb_publishable_…` | `SupabaseConfig.publishableKey` (Info.plist key `SupabasePublishableKey` overrides) | ✅ yes — designed for clients; RLS is the security boundary |
| service_role key | — | ❌ NEVER in the app/repo |
| Database password | — | ❌ NEVER in the app/repo. **It was shared in chat — rotate it** (Dashboard → Settings → Database → Reset database password) |
| JWT secret | — | ❌ NEVER |
| Apple `.p8` key | — | ❌ NEVER |

Xcode capabilities on the app target (already in the entitlements file):
- **Sign in with Apple** (required)
- Push Notifications, App Groups, Family Controls (unrelated, preserved)
- iCloud/CloudKit: **removed** (delete the capability row in Xcode's Signing &
  Capabilities UI if it still shows; the entitlements file no longer has it)

## 4. Deep links / invitations

Working today (no domain needed): `focusglobe://join/<token>` — registered in
`FocusGlobe/Info.plist` (`CFBundleURLTypes`).

To upgrade to universal links (`https://focusglobe.app/join/<token>`):
1. Host `https://focusglobe.app/.well-known/apple-app-site-association`
   (Content-Type `application/json`, no redirect):
   ```json
   { "applinks": { "apps": [], "details": [
     { "appIDs": ["QN8S876767.com.focusglobe.app"],
       "components": [ { "/": "/join/*" } ] } ] } }
   ```
2. Add `applinks:focusglobe.app` to `com.apple.developer.associated-domains`
   in `FocusGlobe.entitlements` AND enable Associated Domains on the App ID.
3. Set `SupabaseConfig.universalLinkBaseURLString = "https://focusglobe.app"`.
4. Make `/join/<token>` serve a landing page with an App Store link as the
   not-installed fallback.
5. Supabase Auth **redirect allow-list**: not needed for native ID-token
   sign-in (no redirects). Only needed if you add web OAuth later.

## 5. Verify RLS + RPCs after deployment

1. Dashboard → **Database → Tables**: all 11 tables exist and every one shows
   **RLS enabled**.
2. SQL Editor spot-checks (run as `anon` via the API, not as postgres):
   - `select * from profiles;` with no auth → 0 rows / permission error.
   - Signed-in user A must not read user B's `friend_requests`, `blocks`,
     `online_sessions`, or non-member `focus_rooms`/`room_members`.
   - `room_invites` must not be selectable by ANY client role.
3. Dashboard → **Database → Functions**: the 17 `public.*` functions exist,
   all `SECURITY DEFINER`.
4. **Realtime**: Database → Publications → `supabase_realtime` includes
   `focus_rooms`, `room_members`, `active_flights`.

## 6. Realtime channels used by the app

- `room:<roomID>` — postgres_changes on `room_members` + `focus_rooms`
  (RLS-authorized) → live lobby + shared start.
- `sky:<skyID>` — presence; the app tracks `{user_id}` and nudges a pilot
  refresh on peer changes. Polling (~35 s) remains the resilient fallback.

## 7. Logs, test data, key rotation

- **Logs**: Dashboard → Logs → *Postgres* (RPC errors, `raise exception`
  tokens like `rate_limited`/`room_full`) and *Auth* (sign-in failures).
  On-device: DEBUG → Settings → Developer → Online diagnostics shows the exact
  last backend error; OSLog subsystem `com.focusglobe.app`, category `online`.
- **Delete test data**: SQL Editor →
  `delete from auth.users where id = '<uuid>';` (cascades through profiles →
  everything). Or per-user in-app: Settings → Manage Online Data.
- **Rotate keys**: Dashboard → Settings → API (publishable key), Settings →
  Database (password). After rotating the publishable key, update
  `SupabaseConfig.publishableKey` and ship an update — old builds lose online
  (Solo unaffected).

## 8. Client error vocabulary (server → Swift)

RPCs raise single-token errors mapped in `OnlineError.serverToken(from:)`:
`not_authenticated, rate_limited, room_full, room_not_found, room_closed,
invite_invalid, invite_expired, invite_revoked, blocked, not_owner,
not_member, request_not_found, invalid_reason, session_not_found`.
Release UI shows friendly copy only; DEBUG diagnostics show the raw detail.
