-- ============================================================================
-- FocusGlobe Online — Active Private Flight: server-validated promotion, a
-- two-step invitation contract (preview → accept), server-clock sync, and an
-- Infinite-flight lifecycle tied to the owner heartbeat.
-- Idempotent; safe to run once. PREREQUISITE: the three prior migrations
-- (…_online, …_online_pass2, …_profiles_backfill) must already be applied.
--
-- SECURITY MODEL
--   Every function here is SECURITY DEFINER with `set search_path = ''` and
--   fully-qualified object names; EXECUTE is revoked from PUBLIC + anon and
--   granted only to authenticated. auth.uid() is authoritative — no function
--   ever accepts a caller-supplied owner UUID, sky or timestamp. All canonical
--   flight state (owner, sky, started_at, expected_end_at, active status) is
--   DERIVED from the caller's live Global session row in active_flights, bound
--   by BOTH the user id AND the exact client_session_id.
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
-- 3. expire_stale_rooms — owner-heartbeat aware. A room past its window is
--    expired ONLY when its owner is no longer actively flying (no fresh
--    membership heartbeat), so an Infinite flight is never silently terminated
--    while the authenticated owner keeps flying.
-- ----------------------------------------------------------------------------
create or replace function private.expire_stale_rooms()
returns void language plpgsql volatile security definer set search_path = '' as $$
begin
  update public.focus_rooms r set status = 'expired'
   where r.status in ('lobby','active')
     and r.expires_at <= now()
     and not exists (
       select 1 from public.room_members m
        where m.room_id = r.id and m.user_id = r.owner_id
          and m.status = 'joined'
          and m.last_heartbeat_at > now() - interval '150 seconds');

  update public.room_invites i set revoked_at = now()
   where i.revoked_at is null
     and exists (
       select 1 from public.focus_rooms r
        where r.id = i.room_id
          and (r.status in ('closed','completed','expired')
               or (r.expires_at <= now()
                   and not exists (
                     select 1 from public.room_members m
                      where m.room_id = r.id and m.user_id = r.owner_id
                        and m.status = 'joined'
                        and m.last_heartbeat_at > now() - interval '150 seconds'))));
end $$;

-- ----------------------------------------------------------------------------
-- 4. heartbeat_room — the member heartbeat. The OWNER of an Infinite flight
--    rolls the room's stale-cleanup window forward so it never expires while
--    they keep flying; when the owner heartbeat disappears, stale cleanup
--    expires it normally.
-- ----------------------------------------------------------------------------
create or replace function public.heartbeat_room(p_room_id uuid)
returns void language plpgsql volatile security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then return; end if;
  update public.room_members
     set last_heartbeat_at = now()
   where room_id = p_room_id and user_id = uid and status = 'joined';
  update public.focus_rooms
     set expires_at = greatest(expires_at, now() + interval '13 hours')
   where id = p_room_id and owner_id = uid and status = 'active' and ends_at is null;
end $$;

-- ----------------------------------------------------------------------------
-- 5. promote_global_flight_to_private(client_session_id) — CANONICAL ONLY.
--    All flight state is read from the caller's live active_flights row matched
--    by user_id AND client_session_id. There is NO client-timestamp fallback:
--    a missing/stale/foreign session id raises `no_active_global_session`, which
--    the client resolves by refreshing its presence and retrying once. Atomic
--    upsert keyed by the journey; one owner membership; fresh single-use invite.
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

  insert into public.room_members (room_id, user_id, role, status)
  values (room.id, uid, 'owner', 'joined')
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
-- 6. preview_active_flight_invite — READ-ONLY. Never consumes the token, never
--    creates membership, never changes the count. Returns one explicit status
--    (valid / owner / already_member / expired / revoked / ended / full /
--    blocked / invalid) plus server_now for clock sync. Owner + already-member
--    are recognised regardless of full/consumed so they always return to their
--    flight; blocked/invalid leak no flight details.
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

  -- Identity precedence first (owner/member can always return to the flight),
  -- then availability.
  if room.owner_id = uid then v_status := 'owner';
  elsif private.is_room_member(room.id, uid) then v_status := 'already_member';
  elsif private.is_blocked_pair(room.owner_id, uid) then
    return jsonb_build_object('status', 'blocked', 'server_now', clock_timestamp());
  elsif room.status not in ('lobby','active') then v_status := 'ended';
  elsif room.expires_at <= now() and not owner_active then v_status := 'ended';
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
-- 7. accept_active_flight_invite — the ONLY join path. Atomic validate +
--    consume + membership via the canonical join_room_by_token, plus server_now.
-- ----------------------------------------------------------------------------
create or replace function public.accept_active_flight_invite(p_raw_token text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare result jsonb;
begin
  result := public.join_room_by_token(p_raw_token);
  return result || jsonb_build_object('server_now', clock_timestamp());
end $$;

-- ----------------------------------------------------------------------------
-- 8. Grants — revoke from PUBLIC + anon, grant authenticated only.
-- ----------------------------------------------------------------------------
revoke execute on function public.promote_global_flight_to_private(text) from public, anon;
revoke execute on function public.preview_active_flight_invite(text)      from public, anon;
revoke execute on function public.accept_active_flight_invite(text)       from public, anon;
revoke execute on function public.heartbeat_room(uuid)                    from public, anon;
grant  execute on function public.promote_global_flight_to_private(text) to authenticated;
grant  execute on function public.preview_active_flight_invite(text)      to authenticated;
grant  execute on function public.accept_active_flight_invite(text)       to authenticated;
grant  execute on function public.heartbeat_room(uuid)                    to authenticated;
