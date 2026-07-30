-- ============================================================================
-- FocusGlobe Online — PRIVATE-ROOM PER-PILOT PAUSE
--
-- PROBLEM THIS FIXES
--   Per-pilot pause (20260730120000) only ever reached Public Sky flights.
--   A private/invited flight had no authoritative participant timer at all:
--
--     • Promotion called stopPublishing(), which DELETES the caller's
--       active_flights row. The one record carrying started_at /
--       expected_end_at / paused_at / paused_remaining_seconds was destroyed at
--       the exact moment the journey became private, so pause had nothing to
--       write to and silently no-opped for the rest of the flight.
--     • Room co-members were rendered from private.members_payload(), which
--       carries alias/skin/country/heartbeat and NO timing whatsoever — so the
--       client synthesised every member's countdown from the ROOM-WIDE
--       focus_rooms.ends_at and hardcoded is_paused = false. One shared clock
--       for everybody is precisely what per-pilot pause must not be.
--
-- THE INSIGHT
--   No new visibility machinery is needed. The active_flights SELECT policy
--   (20260717090000) ALREADY has a room branch:
--
--     status = 'active' AND last_heartbeat_at > now() - 120s
--       AND session_kind = 'room'
--       AND private.in_same_active_room(user_id, auth.uid())
--       AND NOT private.is_blocked_pair(user_id, auth.uid())
--
--   So a participant session that is CONVERTED (session_kind 'public' → 'room')
--   rather than deleted is automatically hidden from Public Sky discovery and
--   simultaneously visible to exactly that room's co-members — carrying its own
--   per-pilot expected_end_at, paused_at and paused_remaining_seconds.
--
-- WHAT THIS MIGRATION ADDS
--   1. active_flights.room_id — which room a room-kind session belongs to.
--   2. publish_flight_session(...) — a superset of publish_global_flight with an
--      optional p_room_id. One writer for BOTH journey kinds, so a heartbeat
--      self-heal can never silently flip a private session back into public
--      discovery (publish_global_flight hardcodes session_kind = 'public').
--   3. bind_flight_session_to_room(...) — the non-destructive promotion step
--      that replaces stopPublishing(): converts the caller's OWN live session to
--      the room, preserving its start, deadline and pause state exactly.
--
--   publish_global_flight and heartbeat_global_flight are NOT modified.
--   heartbeat_global_flight already touches only liveness + the pause
--   transition and never writes session_kind, so it works unchanged for room
--   sessions.
--
-- SECURITY
--   Every function is SECURITY DEFINER with `set search_path = ''` and fully
--   qualified names. Identity is auth.uid(); the row is matched by
--   `user_id = uid AND client_session_id = p_client_session_id`. Binding to a
--   room additionally requires a JOINED membership in that room. No function
--   accepts a caller-supplied pilot/user id, so a client can observe every room
--   member's pause state and mutate only its own.
--
-- Idempotent; safe to re-run. Requires all six prior migrations.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Which room a room-kind participant session belongs to. Nullable: null for
--    a Public Sky session. Visibility still derives from room_members via
--    in_same_active_room; this column makes the binding explicit and lets a
--    client scope its query to one room.
-- ----------------------------------------------------------------------------
alter table public.active_flights
  add column if not exists room_id uuid;

-- ----------------------------------------------------------------------------
-- 2. publish_flight_session — the canonical participant-session writer for BOTH
--    Public Sky and private rooms.
--
--    Same contract as publish_global_flight (server stamps started_at and the
--    finite expected_end_at on a NEW journey; a repeat call for the SAME
--    client_session_id preserves them and never extends a finite deadline, and
--    preserves live pause state), PLUS:
--      • p_room_id null     → session_kind 'public', room_id null
--      • p_room_id supplied → session_kind 'room',  room_id set, after proving
--                             the caller is a joined member of that room
--
--    Crucially the preservation branch is keyed on the client session id ALONE,
--    so a host promoting a Global flight keeps their existing start, deadline
--    and pause — the timer does not restart and the host is never duplicated
--    (the row is keyed unique on user_id).
-- ----------------------------------------------------------------------------
create or replace function public.publish_flight_session(
    p_client_session_id text,
    p_sky_id            text,
    p_balloon_skin_id   text,
    p_focus_category    text,
    p_duration_seconds  integer,
    p_is_infinite       boolean,
    p_is_paused         boolean default false,
    p_sound_id          text    default null,
    p_room_id           uuid    default null)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  existing public.active_flights;
  same_journey boolean;
  v_started timestamptz;
  v_end timestamptz;
  v_paused_at timestamptz;
  v_paused_remaining integer;
  v_kind text;
  result public.active_flights;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if p_client_session_id is null or length(p_client_session_id) = 0 then
    raise exception 'invalid_session';
  end if;
  if p_sky_id is null or length(p_sky_id) = 0 then raise exception 'invalid_sky'; end if;
  perform private.ensure_profile(uid);

  -- A room-bound session must be proven: only a JOINED member of that room may
  -- attach their participant session to it.
  if p_room_id is not null then
    if not exists (select 1 from public.room_members m
                    where m.room_id = p_room_id and m.user_id = uid and m.status = 'joined') then
      raise exception 'not_member';
    end if;
    v_kind := 'room';
  else
    v_kind := 'public';
  end if;

  select * into existing from public.active_flights where user_id = uid for update;
  same_journey := existing.user_id is not null
              and existing.client_session_id is not distinct from p_client_session_id;

  if same_journey then
    -- Same journey → PRESERVE the server-canonical start, the finite deadline
    -- and the authoritative pause state. This is also what makes promotion
    -- non-destructive: only session_kind / room_id change.
    v_started          := existing.started_at;
    v_end              := existing.expected_end_at;
    v_paused_at        := existing.paused_at;
    v_paused_remaining := existing.paused_remaining_seconds;
  else
    v_started := clock_timestamp();
    v_end     := case when coalesce(p_is_infinite, false) then null
                      else v_started + greatest(1, p_duration_seconds) * interval '1 second' end;
    if coalesce(p_is_paused, false) then
      v_paused_at        := clock_timestamp();
      v_paused_remaining := case when v_end is null then null
                                 else greatest(1, p_duration_seconds) end;
    else
      v_paused_at        := null;
      v_paused_remaining := null;
    end if;
  end if;

  insert into public.active_flights
      (user_id, client_session_id, sky_id, balloon_skin_id, session_kind, focus_category,
       started_at, expected_end_at, paused_at, paused_remaining_seconds,
       status, last_heartbeat_at, expires_at, sound_id, room_id)
  values (uid, p_client_session_id, p_sky_id, coalesce(nullif(p_balloon_skin_id, ''), 'default'),
          v_kind, coalesce(nullif(p_focus_category, ''), 'Focus'),
          v_started, v_end, v_paused_at, v_paused_remaining,
          'active', clock_timestamp(), clock_timestamp() + interval '13 hours',
          nullif(p_sound_id, ''), p_room_id)
  on conflict (user_id) do update
     set client_session_id        = excluded.client_session_id,
         sky_id                   = excluded.sky_id,
         balloon_skin_id          = excluded.balloon_skin_id,
         session_kind             = excluded.session_kind,
         room_id                  = excluded.room_id,
         focus_category           = excluded.focus_category,
         started_at               = excluded.started_at,
         expected_end_at          = excluded.expected_end_at,
         paused_at                = excluded.paused_at,
         paused_remaining_seconds = excluded.paused_remaining_seconds,
         status                   = 'active',
         last_heartbeat_at        = excluded.last_heartbeat_at,
         expires_at               = excluded.expires_at,
         sound_id                 = excluded.sound_id
  returning * into result;

  return jsonb_build_object('server_now',               clock_timestamp(),
                            'started_at',               result.started_at,
                            'expected_end_at',          result.expected_end_at,
                            'is_paused',                result.paused_at is not null,
                            'paused_remaining_seconds', result.paused_remaining_seconds,
                            'session_kind',             result.session_kind,
                            'client_session_id',        result.client_session_id);
end $$;

-- ----------------------------------------------------------------------------
-- 3. bind_flight_session_to_room — the NON-DESTRUCTIVE promotion step.
--
--    Replaces the old "delete the row" behaviour. Converts the caller's own live
--    participant session to the room: it leaves Public Sky discovery (the public
--    RLS branch requires session_kind = 'public') and becomes visible to that
--    room's co-members instead — while started_at, expected_end_at, paused_at and
--    paused_remaining_seconds are all left exactly as they are, so the host's
--    timer neither restarts nor forgets an in-progress pause.
--
--    Ownership predicate: user_id = auth.uid() AND client_session_id = the
--    caller's own session, plus a joined membership in the target room.
-- ----------------------------------------------------------------------------
create or replace function public.bind_flight_session_to_room(
    p_client_session_id text,
    p_room_id           uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare uid uuid := auth.uid(); f public.active_flights;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if p_client_session_id is null or length(p_client_session_id) = 0 then
    raise exception 'invalid_session';
  end if;
  if p_room_id is null then raise exception 'invalid_room'; end if;

  if not exists (select 1 from public.room_members m
                  where m.room_id = p_room_id and m.user_id = uid and m.status = 'joined') then
    raise exception 'not_member';
  end if;

  update public.active_flights
     set session_kind      = 'room',
         room_id           = p_room_id,
         status            = 'active',
         last_heartbeat_at = clock_timestamp(),
         expires_at        = clock_timestamp() + interval '13 hours'
   where user_id = uid and client_session_id = p_client_session_id
   returning * into f;
  -- No row → the caller has no canonical session to bind. The client repairs
  -- this by publishing (with p_room_id) rather than silently continuing.
  if f.user_id is null then raise exception 'no_active_global_session'; end if;

  return jsonb_build_object('server_now',               clock_timestamp(),
                            'started_at',               f.started_at,
                            'expected_end_at',          f.expected_end_at,
                            'is_paused',                f.paused_at is not null,
                            'paused_remaining_seconds', f.paused_remaining_seconds,
                            'session_kind',             f.session_kind,
                            'client_session_id',        f.client_session_id);
end $$;

-- ----------------------------------------------------------------------------
-- 4. Grants — never PUBLIC/anon; authenticated only, matching every other RPC.
-- ----------------------------------------------------------------------------
revoke execute on function public.publish_flight_session(text, text, text, text, integer, boolean, boolean, text, uuid)
  from public, anon;
grant  execute on function public.publish_flight_session(text, text, text, text, integer, boolean, boolean, text, uuid)
  to authenticated;
revoke execute on function public.bind_flight_session_to_room(text, uuid) from public, anon;
grant  execute on function public.bind_flight_session_to_room(text, uuid) to authenticated;
