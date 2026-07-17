-- ============================================================================
-- FocusGlobe Online — Active Private Flight: server-canonical Global-flight
-- timing, server-validated promotion, a two-step invitation contract
-- (preview → accept) with active-state revalidation, server-clock sync, and an
-- Infinite-flight lifecycle tied to the owner heartbeat.
-- Idempotent; safe to run once. PREREQUISITE: the three prior migrations
-- (…_online, …_online_pass2, …_profiles_backfill) must already be applied.
--
-- SECURITY MODEL
--   Every function here is SECURITY DEFINER with `set search_path = ''` and
--   fully-qualified object names; EXECUTE is revoked from PUBLIC + anon and
--   granted only to authenticated. auth.uid() is authoritative — no function
--   ever accepts a caller-supplied owner UUID or absolute timestamp.
--
-- CANONICAL TIME
--   A Global flight's started_at / expected_end_at are STAMPED BY THE SERVER in
--   publish_global_flight (clock_timestamp()), never by the client. Heartbeats
--   preserve them and never extend a finite deadline. Promotion, preview and
--   accept all derive their flight state from these server-canonical rows and
--   return server_now so clients can run a shared clock.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. One private flight per (owner, journey) — DB-enforced, race-safe.
-- ----------------------------------------------------------------------------
alter table public.focus_rooms add column if not exists client_session_id text;
drop index if exists public.focus_rooms_client_session_idx;
create unique index if not exists focus_rooms_client_session_uk
  on public.focus_rooms (owner_id, client_session_id)
  where client_session_id is not null;

-- ----------------------------------------------------------------------------
-- 2. Bind the Global presence row to its client session id, so the promotion
--    can prove the session identifier belongs to THIS active Global flight.
-- ----------------------------------------------------------------------------
alter table public.active_flights add column if not exists client_session_id text;

-- ----------------------------------------------------------------------------
-- 3. publish_global_flight — the CANONICAL Global-flight writer. Replaces the
--    old direct client upsert. The server stamps started_at = clock_timestamp()
--    and (finite) expected_end_at = started_at + duration on a NEW journey; a
--    repeat call for the SAME client_session_id preserves the original
--    started_at and finite deadline and NEVER extends them. A new
--    client_session_id is a new journey and gets a fresh server clock. Returns
--    the canonical timing plus server_now for client clock-offset sync.
-- ----------------------------------------------------------------------------
create or replace function public.publish_global_flight(
    p_client_session_id text,
    p_sky_id            text,
    p_balloon_skin_id   text,
    p_focus_category    text,
    p_duration_seconds  integer,
    p_is_infinite       boolean,
    p_is_paused         boolean default false)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  existing public.active_flights;
  v_started timestamptz;
  v_end timestamptz;
  result public.active_flights;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if p_client_session_id is null or length(p_client_session_id) = 0 then
    raise exception 'invalid_session';
  end if;
  if p_sky_id is null or length(p_sky_id) = 0 then raise exception 'invalid_sky'; end if;
  perform private.ensure_profile(uid);

  select * into existing from public.active_flights where user_id = uid for update;

  if existing.user_id is not null
     and existing.client_session_id is not distinct from p_client_session_id then
    -- Same journey → PRESERVE the server-canonical start and finite deadline.
    -- A heartbeat must never move the start or extend a finite flight.
    v_started := existing.started_at;
    v_end     := existing.expected_end_at;
  else
    -- New journey (new/first session id) → the server stamps the truth now.
    v_started := clock_timestamp();
    v_end     := case when coalesce(p_is_infinite, false) then null
                      else v_started + greatest(1, p_duration_seconds) * interval '1 second' end;
  end if;

  insert into public.active_flights
      (user_id, client_session_id, sky_id, balloon_skin_id, session_kind, focus_category,
       started_at, expected_end_at, paused_at, status, last_heartbeat_at, expires_at)
  values (uid, p_client_session_id, p_sky_id, coalesce(nullif(p_balloon_skin_id, ''), 'default'),
          'public', coalesce(nullif(p_focus_category, ''), 'Focus'),
          v_started, v_end,
          case when coalesce(p_is_paused, false) then clock_timestamp() else null end,
          'active', clock_timestamp(), clock_timestamp() + interval '13 hours')
  on conflict (user_id) do update
     set client_session_id = excluded.client_session_id,
         sky_id            = excluded.sky_id,
         balloon_skin_id   = excluded.balloon_skin_id,
         session_kind      = 'public',
         focus_category    = excluded.focus_category,
         started_at        = excluded.started_at,      -- v_started (preserved for same journey)
         expected_end_at   = excluded.expected_end_at, -- v_end     (preserved for same journey)
         paused_at         = excluded.paused_at,
         status            = 'active',
         last_heartbeat_at = excluded.last_heartbeat_at,
         expires_at        = excluded.expires_at
  returning * into result;

  return jsonb_build_object('server_now',        clock_timestamp(),
                            'started_at',         result.started_at,
                            'expected_end_at',    result.expected_end_at,
                            'client_session_id',  result.client_session_id);
end $$;

-- ----------------------------------------------------------------------------
-- 4. heartbeat_global_flight — a LIGHTWEIGHT liveness ping. Updates only
--    last_heartbeat_at / paused / visibility window; it can NEVER replace the
--    canonical start or finite deadline. Returns server_now + the canonical
--    timing so the poll pipeline keeps the shared clock fresh. A missing row
--    raises `no_active_global_session` so the client republishes.
-- ----------------------------------------------------------------------------
create or replace function public.heartbeat_global_flight(
    p_client_session_id text,
    p_is_paused boolean default false)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare uid uuid := auth.uid(); f public.active_flights;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  update public.active_flights
     set last_heartbeat_at = clock_timestamp(),
         status            = 'active',
         paused_at         = case when coalesce(p_is_paused, false) then clock_timestamp() else null end,
         expires_at        = clock_timestamp() + interval '13 hours'
   where user_id = uid and client_session_id = p_client_session_id
   returning * into f;
  if f.user_id is null then raise exception 'no_active_global_session'; end if;
  return jsonb_build_object('server_now',      clock_timestamp(),
                            'started_at',       f.started_at,
                            'expected_end_at',  f.expected_end_at,
                            'status',           f.status);
end $$;

-- ----------------------------------------------------------------------------
-- 5. expire_stale_rooms — owner-heartbeat + canonical-deadline aware.
--    • Finite room: expired strictly by its canonical ends_at (+ grace),
--      independent of the owner heartbeat.
--    • Infinite room (ends_at is null): expired AS SOON AS the owner is no
--      longer actively flying (stale membership heartbeat) — it does NOT wait
--      for the 13h backstop, so killing the host frees the room within the
--      stale threshold.
--    • Hard backstop: any room past expires_at.
--    Invites for closed/completed/expired rooms are then revoked.
-- ----------------------------------------------------------------------------
create or replace function private.expire_stale_rooms()
returns void language plpgsql volatile security definer set search_path = '' as $$
begin
  update public.focus_rooms r set status = 'expired'
   where r.status in ('lobby','active')
     and (
       -- Finite: expire by the canonical deadline plus a short cleanup grace.
       (r.ends_at is not null and r.ends_at + interval '2 minutes' <= now())
       -- Infinite / lobby (no canonical end): expire the moment the owner is no
       -- longer actively flying — no fresh owner membership heartbeat.
       or (r.ends_at is null
           and not exists (
             select 1 from public.room_members m
              where m.room_id = r.id and m.user_id = r.owner_id
                and m.status = 'joined'
                and m.last_heartbeat_at > now() - interval '150 seconds'))
       -- Hard backstop.
       or r.expires_at <= now());

  update public.room_invites i set revoked_at = now()
   where i.revoked_at is null
     and exists (
       select 1 from public.focus_rooms r
        where r.id = i.room_id
          and r.status in ('closed','completed','expired'));
end $$;

-- ----------------------------------------------------------------------------
-- 6. heartbeat_room — the member heartbeat. The OWNER of an Infinite flight
--    rolls the room's stale-cleanup window forward so it never expires while
--    they keep flying; when the owner heartbeat disappears, stale cleanup
--    expires it within the stale threshold. Returns server_now + the canonical
--    room ends_at / status so the guest's poll keeps the shared clock fresh.
-- ----------------------------------------------------------------------------
create or replace function public.heartbeat_room(p_room_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare uid uuid := auth.uid(); r public.focus_rooms;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  update public.room_members
     set last_heartbeat_at = now()
   where room_id = p_room_id and user_id = uid and status = 'joined';
  -- Only an Infinite flight (null ends_at) rolls its window forward; a finite
  -- room's expiry stays pinned to its canonical deadline.
  update public.focus_rooms
     set expires_at = greatest(expires_at, now() + interval '13 hours')
   where id = p_room_id and owner_id = uid and status = 'active' and ends_at is null;
  select * into r from public.focus_rooms where id = p_room_id;
  return jsonb_build_object('server_now', clock_timestamp(),
                            'ends_at',     r.ends_at,
                            'status',      r.status);
end $$;

-- ----------------------------------------------------------------------------
-- 7. promote_global_flight_to_private(client_session_id) — CANONICAL ONLY.
--    All flight state is read from the caller's live active_flights row matched
--    by user_id AND client_session_id. There is NO client-timestamp fallback:
--    a missing/stale/foreign session id raises `no_active_global_session`, which
--    the client resolves by refreshing its presence and retrying once. Atomic
--    upsert keyed by the journey; one owner membership (fresh heartbeat); fresh
--    single-use invite. Carries the SERVER-canonical starts_at / ends_at.
-- ----------------------------------------------------------------------------
create or replace function public.promote_global_flight_to_private(p_client_session_id text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  flight public.active_flights;
  room public.focus_rooms;
  raw_token text;
  v_expires timestamptz;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if p_client_session_id is null or length(p_client_session_id) = 0 then
    raise exception 'invalid_session';
  end if;
  perform private.ensure_profile(uid);
  perform private.expire_stale_rooms();

  -- The canonical Global session — the caller's own, matched by the EXACT
  -- client session id, active, public, freshly heartbeating.
  select * into flight from public.active_flights
   where user_id = uid
     and client_session_id = p_client_session_id
     and status = 'active'
     and session_kind = 'public'
     and last_heartbeat_at > now() - interval '150 seconds';
  if flight.user_id is null then raise exception 'no_active_global_session'; end if;

  -- A finite deadline must still be in the future; Infinite keeps a null end.
  if flight.expected_end_at is not null and flight.expected_end_at <= now() then
    raise exception 'session_ended';
  end if;
  v_expires := case when flight.expected_end_at is null then now() + interval '13 hours'
                    else flight.expected_end_at + interval '2 hours' end;

  insert into public.focus_rooms
      (owner_id, sky_id, purpose, status, client_session_id, starts_at, ends_at, expires_at)
  values (uid, flight.sky_id, 'flight', 'active', p_client_session_id,
          flight.started_at, flight.expected_end_at, v_expires)
  on conflict (owner_id, client_session_id) where client_session_id is not null
  do update set ends_at    = excluded.ends_at,
                sky_id     = excluded.sky_id,
                status     = 'active',
                expires_at = greatest(focus_rooms.expires_at, excluded.expires_at)
  returning * into room;

  insert into public.room_members (room_id, user_id, role, status, last_heartbeat_at)
  values (room.id, uid, 'owner', 'joined', now())
  on conflict (room_id, user_id)
    do update set status = 'joined', left_at = null, last_heartbeat_at = now();

  raw_token := private.new_invite(room.id, uid);

  return jsonb_build_object('room', private.room_payload(room),
                            'members', private.members_payload(room.id),
                            'invite_token', raw_token,
                            'membership', 'already_owner',
                            'server_now', clock_timestamp());
end $$;

-- ----------------------------------------------------------------------------
-- 8. preview_active_flight_invite — READ-ONLY. Never consumes the token, never
--    creates membership, never changes the count. Returns one explicit status
--    plus server_now. Precedence (spec-mandated): invalid → blocked → ended
--    (closed/completed/expired room) → ended (finite deadline passed) → ended
--    (Infinite host gone) → owner → already_member → revoked → expired → full →
--    valid. So owner/already-member are NEVER routed back into an ended flight,
--    yet always return to a still-active one; blocked/invalid leak nothing.
-- ----------------------------------------------------------------------------
create or replace function public.preview_active_flight_invite(p_raw_token text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  invite public.room_invites;
  room public.focus_rooms;
  owner_p public.profiles;
  cnt integer;
  v_status text;
  owner_active boolean;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  perform private.expire_stale_rooms();

  select * into invite from public.room_invites
   where token_hash = encode(extensions.digest(p_raw_token, 'sha256'), 'hex');
  if invite.id is null then
    return jsonb_build_object('status', 'invalid', 'server_now', clock_timestamp());
  end if;
  select * into room from public.focus_rooms where id = invite.room_id;
  if room.id is null then
    return jsonb_build_object('status', 'invalid', 'server_now', clock_timestamp());
  end if;

  select exists (
    select 1 from public.room_members m
     where m.room_id = room.id and m.user_id = room.owner_id
       and m.status = 'joined' and m.last_heartbeat_at > now() - interval '150 seconds'
  ) into owner_active;
  select count(*) into cnt from public.room_members
   where room_id = room.id and status = 'joined';

  -- Precedence: block / ended states BEFORE identity, so an owner or member can
  -- never be routed back into a flight that has already ended.
  if private.is_blocked_pair(room.owner_id, uid) then
    return jsonb_build_object('status', 'blocked', 'server_now', clock_timestamp());
  elsif room.status not in ('lobby','active') then v_status := 'ended';
  elsif room.ends_at is not null and room.ends_at <= now() then v_status := 'ended';
  elsif room.ends_at is null and not owner_active then v_status := 'ended';
  elsif room.owner_id = uid then v_status := 'owner';
  elsif private.is_room_member(room.id, uid) then v_status := 'already_member';
  elsif invite.revoked_at is not null then v_status := 'revoked';
  elsif invite.expires_at <= now() then v_status := 'expired';
  elsif invite.uses >= invite.max_uses then v_status := 'expired';
  elsif cnt >= room.max_members then v_status := 'full';
  else v_status := 'valid';
  end if;

  select * into owner_p from public.profiles where id = room.owner_id;
  return jsonb_build_object(
    'room',              private.room_payload(room),
    'host_alias',        coalesce(nullif(owner_p.public_alias, ''), 'a pilot'),
    'host_skin',         coalesce(nullif(owner_p.balloon_skin_id, ''), 'default'),
    'participant_count', cnt,
    'status',            v_status,
    'server_now',        clock_timestamp());
end $$;

-- ----------------------------------------------------------------------------
-- 9. accept_active_flight_invite — the ONLY join path. Re-validates the ACTIVE
--    state ATOMICALLY at acceptance (a preview seconds earlier is not trusted):
--    a NEW joiner is refused if the room is blocked/ended, the finite deadline
--    passed, or the Infinite host went stale — BEFORE delegating to the
--    canonical join helper (which enforces token / capacity / owner-member
--    idempotency and re-checks room status under a row lock). Returns the join
--    result plus server_now.
-- ----------------------------------------------------------------------------
create or replace function public.accept_active_flight_invite(p_raw_token text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  invite public.room_invites;
  room public.focus_rooms;
  owner_active boolean;
  is_incumbent boolean;
  result jsonb;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  perform private.expire_stale_rooms();

  select * into invite from public.room_invites
   where token_hash = encode(extensions.digest(p_raw_token, 'sha256'), 'hex');
  if invite.id is null then raise exception 'invite_invalid'; end if;
  select * into room from public.focus_rooms where id = invite.room_id;
  if room.id is null then raise exception 'invite_invalid'; end if;

  -- Owner / existing member are idempotent and bypass token & capacity, but the
  -- ended-state checks below still apply to everyone via the join helper's final
  -- room-status gate. A genuinely NEW joiner is validated against the live
  -- active state here so nothing joins a flight that ended after preview.
  is_incumbent := (room.owner_id = uid) or private.is_room_member(room.id, uid);
  if not is_incumbent then
    if private.is_blocked_pair(room.owner_id, uid) then raise exception 'blocked'; end if;
    if room.status not in ('lobby','active') then raise exception 'room_closed'; end if;
    if room.ends_at is not null and room.ends_at <= now() then raise exception 'room_closed'; end if;
    if room.ends_at is null then
      select exists (
        select 1 from public.room_members m
         where m.room_id = room.id and m.user_id = room.owner_id
           and m.status = 'joined' and m.last_heartbeat_at > now() - interval '150 seconds'
      ) into owner_active;
      if not owner_active then raise exception 'room_closed'; end if;
    end if;
  end if;

  result := public.join_room_by_token(p_raw_token);
  return result || jsonb_build_object('server_now', clock_timestamp());
end $$;

-- ----------------------------------------------------------------------------
-- 10. Grants — revoke from PUBLIC + anon, grant authenticated only.
-- ----------------------------------------------------------------------------
revoke execute on function public.publish_global_flight(text, text, text, text, integer, boolean, boolean) from public, anon;
revoke execute on function public.heartbeat_global_flight(text, boolean)              from public, anon;
revoke execute on function public.promote_global_flight_to_private(text)              from public, anon;
revoke execute on function public.preview_active_flight_invite(text)                  from public, anon;
revoke execute on function public.accept_active_flight_invite(text)                   from public, anon;
revoke execute on function public.heartbeat_room(uuid)                                from public, anon;
grant  execute on function public.publish_global_flight(text, text, text, text, integer, boolean, boolean) to authenticated;
grant  execute on function public.heartbeat_global_flight(text, boolean)              to authenticated;
grant  execute on function public.promote_global_flight_to_private(text)              to authenticated;
grant  execute on function public.preview_active_flight_invite(text)                  to authenticated;
grant  execute on function public.accept_active_flight_invite(text)                   to authenticated;
grant  execute on function public.heartbeat_room(uuid)                                to authenticated;
