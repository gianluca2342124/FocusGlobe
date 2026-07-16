# FocusGlobe Online — Test Plan (Supabase)

## A. Preconditions

1. Migration deployed and verified (Setup doc §1/§5); project not paused.
2. Build 46+ installed from Xcode (packages resolved at first open).
3. Two physical devices with different Apple IDs for the two-account flow.

## B. Two-device manual checklist

1. **Sign in** — Device A and B: pre-flight → Online Flight card → "Sign in"
   → Apple sheet → success; card flips to Live; Settings shows
   "Signed in as SkyPilot####".
2. **Public Sky** — both enable *Appear in Public Skies*, start Online flights
   in the SAME Sky → each sees the other's REAL balloon (alias/skin/flag)
   within ~35 s, mixed above decorative bots.
3. **Pause/resume** — pause on A → within a heartbeat B sees A paused
   (badge/opacity per existing UI).
4. **Force quit** — kill the app on A → A's balloon disappears from B within
   ~2 min (stale heartbeat filter).
5. **Create private room** — A: pre-flight → "Create a Private Flight" →
   row shows *Creating…* then *Private room ready — invite friends*. Rapid
   taps never create a second room (single-flight + server lobby reuse).
6. **Send invitation** — A: *Send private invitation* → share sheet carries a
   `focusglobe://join/<token>` link + preview.
7. **Join** — B opens the link → app opens → (sign-in first if needed, invite
   is kept and consumed) → B lands in the SAME lobby; A sees "1 friend
   joined" and B's real skin.
8. **Ready** — B taps *I'm Ready* → A's lobby updates live (realtime).
9. **Start** — A taps *Start Flight* → server stamps starts_at.
10. **Shared start** — B's lobby auto-dismisses into the same flight (member
    auto-start via realtime; pull-to-refresh is the fallback).
11. **Disconnect** — airplane-mode B for 1 min mid-flight → timer keeps
    running locally, *Reconnecting* pill shows, recovery reconciles from the
    server without duplicating anything.
12. **Overlap** — both stay ≥ 5 focused minutes together.
13. **Friend bonus** — on landing, the 2× friend bonus is granted exactly
    once per pilot (server-verified; relaunching/re-completing never doubles
    it — `online_reward_claims` has one row per session).
14. **Crew request** — B taps A's balloon → *Add to Crew* → A accepts in
    Friends → both see each other as Crew; "Focusing now" appears when the
    other is genuinely flying.
15. **Block** — A blocks B (pilot sheet → Block) → B disappears from A's sky
    and vice versa; B can no longer send requests or join A's rooms
    (server rejects with `blocked`).
16. **Report** — report a pilot → confirmation; row exists in `pilot_reports`
    (visible only via Dashboard, not to any client).
17. **Delete Online Data** — Settings → Manage Online Data → delete →
    profile/presence/rooms/requests/friendships gone (Dashboard check);
    local flights, coins, streak, purchases untouched; signing back in
    recreates a fresh anonymous profile.
18. **Solo** — sign out (Settings) + airplane mode → Solo flight works fully;
    zero online calls; no sign-in prompt appears anywhere uninvited.

## C. Invite edge cases

| Case | Expected |
|---|---|
| Invalid token (`focusglobe://join/abc`) | "This invitation link isn't valid." — nothing joins |
| Expired token (48 h) / revoked (room closed) | "This invitation has expired — ask for a new one." |
| Room full (8) | "This Focus Room is full." |
| Already joined | Opens the lobby again, no duplicate membership |
| Sender blocked you / you blocked sender | "You can't join this Focus Room." |
| Not signed in | Token kept; after sign-in the join completes automatically |
| Cold launch via link | Same as warm launch (token handled post-launch) |

## D. Unit-test targets (when a test target exists)

The Xcode project currently has **no test target**, so these are specified,
not implemented. Add a unit-test target, then cover:

- `DeepLinkService.inviteToken(from:)` — valid scheme/https forms, rejects
  wrong hosts, short/oversized/invalid-charset tokens.
- `PostgresDate.parse` — RPC (`…​.123Z`) and PostgREST (`…​.123456+00:00`)
  forms, nil/garbage.
- `OnlineError.serverToken/map/category` — every token; URLError → network.
- Room single-flight: two concurrent `requestPrivateFlightRoom` calls award
  the same room (stub RoomService protocol).
- Reward idempotency: repeated `completeSession` returns one claim.
- Solo isolation: with `flightMode == .solo`, `flightDidStart` performs no
  service calls (spy services).
- Sign-out cleanup: published social state resets; pending invite cleared.
- Stale pilot filtering: heartbeat older than 120 s excluded.
- Bots: `AmbientPilotsLayer` sources only decorative data; `realPilots` is
  the only interactive source.

## E. Release-build pass

Archive a Release build (TestFlight) and repeat B.1–B.10 — Release uses the
same Supabase project (no environment split, unlike CloudKit), so behavior
must match Debug exactly; DEBUG diagnostics simply don't exist there.
