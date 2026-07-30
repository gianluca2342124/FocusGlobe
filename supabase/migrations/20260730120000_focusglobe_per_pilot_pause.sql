-- ============================================================================
-- FocusGlobe Online — AUTHORITATIVE PER-PILOT PAUSE
--
-- PROBLEM THIS FIXES
--   `active_flights.paused_at` was the ONLY pause column, and
--   `heartbeat_global_flight` rewrote it to clock_timestamp() on EVERY ping
--   while paused. So it recorded "last seen paused", not "when the pause
--   began" — pause duration was not modelled at all. Nothing ever shifted
--   `expected_end_at`, so a paused pilot's countdown kept draining to zero on
--   every other client, and on resume their own deadline had silently moved
--   closer. One pilot could never be frozen independently of the rest.
--
-- DESIGN (Design A — freeze the remaining time)
--   PAUSE  : paused_at = server now (stamped ONCE, on the transition only)
--            paused_remaining_seconds = expected_end_at - server now
--   RESUME : expected_end_at = server now + paused_remaining_seconds
--            paused_at = null, paused_remaining_seconds = null
--   A steady-state heartbeat now touches ONLY liveness — never the deadline
--   and never the pause stamp — so repeated pings can no longer corrupt
--   either. Infinite flights (expected_end_at is null) keep a null deadline
--   and a null remaining; they are simply flagged paused.
--
-- OWNERSHIP
--   Unchanged and re-verified: every function is SECURITY DEFINER with
--   `set search_path = ''`, derives identity from auth.uid(), and matches the
--   row by `user_id = uid AND client_session_id = p_client_session_id`. No
--   function accepts a caller-supplied pilot id, so a client can observe every
--   pilot's pause state but can only ever mutate its own.
--
-- Idempotent; safe to re-run. Requires the five prior migrations.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. The frozen remaining time. Nullable: null for an Infinite flight and for
--    any flight that is not currently paused.
-- ----------------------------------------------------------------------------
alter table public.active_flights
  add column if not exists paused_remaining_seconds integer;

-- ----------------------------------------------------------------------------
-- 2. heartbeat_global_flight — liveness ping + the ONLY pause/resume writer.
--    Three explicit branches so a repeated ping is idempotent:
--      • pause TRANSITION  (not paused → paused): stamp + freeze remaining
--      • resume TRANSITION (paused → not paused): push the deadline out
--      • steady state: liveness only; deadline and pause stamp untouched
--    Returns the canonical pause fields so the caller can reconcile.
-- ----------------------------------------------------------------------------
create or replace function public.heartbeat_global_flight(
    p_client_session_id text,
    p_is_paused boolean default false)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  cur public.active_flights;
  f   public.active_flights;
  want_paused boolean := coalesce(p_is_paused, false);
begin
  if uid is null then raise exception 'not_authenticated'; end if;

  -- Lock the caller's OWN row for this exact journey. Ownership is enforced
  -- here: no other pilot's row is reachable from this function.
  select * into cur from public.active_flights
   where user_id = uid and client_session_id = p_client_session_id
   for update;
  if cur.user_id is null then raise exception 'no_active_global_session'; end if;

  if want_paused and cur.paused_at is null then
    -- PAUSE transition — stamp once and freeze what is left.
    update public.active_flights
       set paused_at = clock_timestamp(),
           paused_remaining_seconds =
             case when cur.expected_end_at is null then null
                  else greatest(0, ceil(extract(epoch from
                         (cur.expected_end_at - clock_timestamp()))))::integer end,
           last_heartbeat_at = clock_timestamp(),
           status            = 'active',
           expires_at        = clock_timestamp() + interval '13 hours'
     where user_id = uid and client_session_id = p_client_session_id
     returning * into f;

  elsif not want_paused and cur.paused_at is not null then
    -- RESUME transition — the deadline moves out by exactly the frozen span,
    -- so the pilot resumes from the value everyone saw while they were paused.
    update public.active_flights
       set expected_end_at =
             case when cur.expected_end_at is null then null
                  else clock_timestamp()
                       + coalesce(cur.paused_remaining_seconds, 0) * interval '1 second' end,
           paused_at                = null,
           paused_remaining_seconds = null,
           last_heartbeat_at        = clock_timestamp(),
           status                   = 'active',
           expires_at               = clock_timestamp() + interval '13 hours'
     where user_id = uid and client_session_id = p_client_session_id
     returning * into f;

  else
    -- STEADY STATE — liveness only. Never touches expected_end_at, paused_at
    -- or paused_remaining_seconds, so a 35 s ping loop cannot drift the clock.
    update public.active_flights
       set last_heartbeat_at = clock_timestamp(),
           status            = 'active',
           expires_at        = clock_timestamp() + interval '13 hours'
     where user_id = uid and client_session_id = p_client_session_id
     returning * into f;
  end if;

  return jsonb_build_object('server_now',               clock_timestamp(),
                            'started_at',               f.started_at,
                            'expected_end_at',          f.expected_end_at,
                            'is_paused',                f.paused_at is not null,
                            'paused_remaining_seconds', f.paused_remaining_seconds,
                            'status',                   f.status);
end $$;

-- ----------------------------------------------------------------------------
-- 3. publish_global_flight — unchanged contract, with ONE correction: a repeat
--    publish for the SAME client_session_id must preserve the live pause state
--    exactly as it already preserves started_at / expected_end_at. Previously
--    it recomputed paused_at from p_is_paused on every call, so a republish
--    (e.g. the no_active_global_session recovery path) silently cleared a live
--    pause or re-stamped it, losing the frozen remaining time.
-- ----------------------------------------------------------------------------
create or replace function public.publish_global_flight(
    p_client_session_id text,
    p_sky_id            text,
    p_balloon_skin_id   text,
    p_focus_category    text,
    p_duration_seconds  integer,
    p_is_infinite       boolean,
    p_is_paused         boolean default false,
    p_sound_id          text default null)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  existing public.active_flights;
  same_journey boolean;
  v_started timestamptz;
  v_end timestamptz;
  v_paused_at timestamptz;
  v_paused_remaining integer;
  result public.active_flights;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if p_client_session_id is null or length(p_client_session_id) = 0 then
    raise exception 'invalid_session';
  end if;
  if p_sky_id is null or length(p_sky_id) = 0 then raise exception 'invalid_sky'; end if;
  perform private.ensure_profile(uid);

  select * into existing from public.active_flights where user_id = uid for update;
  same_journey := existing.user_id is not null
              and existing.client_session_id is not distinct from p_client_session_id;

  if same_journey then
    -- Same journey → PRESERVE the server-canonical start, the finite deadline
    -- AND the authoritative pause state. A heartbeat/republish must never move
    -- the start, extend a finite flight, or forget an in-progress pause.
    v_started          := existing.started_at;
    v_end              := existing.expected_end_at;
    v_paused_at        := existing.paused_at;
    v_paused_remaining := existing.paused_remaining_seconds;
  else
    -- New journey (new/first session id) → the server stamps the truth now.
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
       status, last_heartbeat_at, expires_at, sound_id)
  values (uid, p_client_session_id, p_sky_id, coalesce(nullif(p_balloon_skin_id, ''), 'default'),
          'public', coalesce(nullif(p_focus_category, ''), 'Focus'),
          v_started, v_end, v_paused_at, v_paused_remaining,
          'active', clock_timestamp(), clock_timestamp() + interval '13 hours',
          nullif(p_sound_id, ''))
  on conflict (user_id) do update
     set client_session_id        = excluded.client_session_id,
         sky_id                   = excluded.sky_id,
         balloon_skin_id          = excluded.balloon_skin_id,
         session_kind             = 'public',
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
                            'client_session_id',        result.client_session_id);
end $$;

-- ----------------------------------------------------------------------------
-- 4. Grants — unchanged policy: never PUBLIC/anon, authenticated only.
-- ----------------------------------------------------------------------------
revoke execute on function public.heartbeat_global_flight(text, boolean) from public, anon;
grant  execute on function public.heartbeat_global_flight(text, boolean) to authenticated;
revoke execute on function public.publish_global_flight(text, text, text, text, integer, boolean, boolean, text)
  from public, anon;
grant  execute on function public.publish_global_flight(text, text, text, text, integer, boolean, boolean, text)
  to authenticated;
