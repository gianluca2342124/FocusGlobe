# FocusGlobe — Privacy Data Map (Online / Supabase)

The user-facing promises this app makes, and exactly what data backs them.
Use this to fill App Store privacy labels and the Privacy Policy.

## 1. What NEVER leaves the device

- Focus history, streaks, coins, Store ownership, purchases (RevenueCat holds
  receipts), onboarding answers, Solo settings, notification preferences.
- Contacts (the contact-picker flow was removed entirely; the app requests no
  Contacts permission).
- Precise location (never collected).

## 2. Sign in with Apple

- Optional — only when the user explicitly chooses Online/Friends/an invite.
- The Apple identity token goes ONLY to Supabase Auth to mint the account.
- Email (or Apple's private relay address) lives in `auth.users`, which no
  client can read (RLS: profiles never expose it; the API never returns other
  users' auth rows). It is never shown in any UI.
- Full name: captured once (first authorization, if granted) into private
  auth metadata; never displayed, never in any public table.
- Public identity = a random anonymous alias (`SkyPilot####`, user-editable).

## 3. What FocusGlobe Online stores server-side (per user)

| Data | Table | Visible to | Lifetime |
|---|---|---|---|
| Anonymous alias, balloon skin, optional country code, discoverability + request toggles | `profiles` | Self; others only if discoverable / friends / co-members / request counterpart — never blocked pairs | Until Delete Online Data |
| Live flight (sky, skin, category label, timing, paused, heartbeat) | `active_flights` | Self; other signed-in users only while fresh (<2 min), discoverable, public-mode, not blocked | Deleted on landing/sign-out; stale rows expire |
| Friend requests (sender/receiver ids + status) | `friend_requests` | The two participants only | Until answered/cancelled/blocked |
| Friendships (canonical pair) | `friendships` | The two participants only | Until removed/blocked |
| Blocks (blocker → blocked) | `blocks` | Blocker only | Until unblocked |
| Reports (reporter, reported, closed reason category) | `pilot_reports` | No client; moderation via Dashboard only | Retained for moderation |
| Private rooms + membership + ready/heartbeat | `focus_rooms`, `room_members` | Room members only | Rooms expire ≤24 h / on close |
| Invite tokens | `room_invites` | **No client can read this table**; SHA-256 hashes only | Expire ≤48 h / revoked |
| Room flight sessions + verified friend-bonus claims | `online_sessions`, `online_reward_claims` | Own rows only | Until Delete Online Data (sessions); claims keep the ledger consistent |

No message content, no free-text between users, no emails/phones/names in any
of the tables above.

## 4. User controls (Settings)

- **Appear in Public Skies** — off by default; consent sheet on first online
  flight; turning it off removes live presence immediately.
- **Allow Friend Requests** — server-enforced (insert policy checks it).
- **Public alias** — editable (validated, rate-limited 1/day).
- **Sign out** — ends the session on this device; data remains until deleted.
- **Manage Online Data → Delete Online Data** — runs `delete_my_online_data()`
  server-side: profile, presence, rooms/memberships/invites (closed+revoked),
  requests, friendships, sessions removed. Local progress untouched. The
  reports table keeps moderation records (industry standard); blocks are kept
  so a deleted-then-recreated profile stays blocked.
- Full account deletion (auth row) can be offered later via a dashboard
  action or an edge function; deleting the auth user cascades everything.

## 5. App Store privacy label (suggested)

- **Data linked to you**: none. (The account identifier is a random UUID;
  alias is user-chosen and anonymous; email is never used in-app.)
- **Data not linked to you**: Identifiers (anonymous user ID), Usage Data
  (focus session timing while online, coarse — for the social features
  themselves, not tracking).
- **Tracking**: none by FocusGlobe Online. (Declare AdMob's own collection
  separately per Google's guidance — unchanged by this migration.)

## 6. Report / moderation copy (already in-app)

- Reports send: reported pilot's anonymous ID + a closed reason category.
- Blocking hides both pilots from each other and stops requests/joins.
- Reports are rate-limited (10/day) and reviewed out-of-band.
