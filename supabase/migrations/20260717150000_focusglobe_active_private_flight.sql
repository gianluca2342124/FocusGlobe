-- ============================================================================
-- FocusGlobe Online — Global→Private promotion of an ALREADY-ACTIVE flight,
-- plus a two-step invitation contract (preview → accept).
-- Idempotent; safe to run once. PREREQUISITE: the three prior migrations
-- (…_online, …_online_pass2, …_profiles_backfill) must already be applied.
--
-- WHY THIS EXISTS
--   The host is already focusing in an active Global Flight when they tap
--   Invite Friends. This is NOT a pre-flight lobby: the flight has already taken
--   off. create_private_room can only mint a room in the artificial 'lobby'
--   state and its reuse only matches 'lobby' rooms — so once flipped 'active' a
--   second Invite tap would create a DUPLICATE. That is the wrong representation.
--
-- WHAT THIS FILE PROVIDES
--   1. focus_rooms.client_session_id + a PARTIAL UNIQUE index → exactly ONE
--      private-flight record per (owner, journey), race-safe.
--   2. promote_global_flight_to_private(): born 'active', canonical timing
--      DERIVED from the caller's active public session (active_flights), never
--      trusting client timestamps; atomic upsert (concurrent taps converge on
--      one row); one owner membership; fresh single-use invite.
--   3. preview_active_flight_invite(): validates a token and returns host/sky/
--      deadline/count WITHOUT consuming it or creating any membership.
--   4. accept_active_flight_invite(): the ONLY path that joins — atomic
--      validate+consume+membership, delegating to the canonical join logic.
--   auth.uid() is authoritative throughout; RLS and prior RPCs are untouched.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. One private flight per (owner, journey) — DB-enforced, race-safe.
-- ----------------------------------------------------------------------------
alter table public.focus_rooms add column if not exists client_session_id text;
-- Replace any earlier non-unique index with a partial UNIQUE index.
drop index if exists public.focus_rooms_client_session_idx;
create unique index if not exists focus_rooms_client_session_uk
  on public.focus_rooms (owner_id, client_session_id)
  where client_session_id is not null;

-- ----------------------------------------------------------------------------
-- 2. promote_global_flight_to_private — server-validated, atomic, idempotent.
-- ----------------------------------------------------------------------------
create or replace function public.promote_global_flight_to_private(
    p_client_session_id text,
    p_sky_id            text,
    p_ends_at           timestamptz,
    p_started_at        timestamptz)
returns jsonb language plpgsql volatile security definer set search_path = public, pg_temp as $$
declare
  uid uuid := auth.uid();
  flight public.active_flights;
  room public.focus_rooms;
  raw_token text;
  v_sky text;
  v_started timestamptz;
  v_ends timestamptz;
  v_expires timestamptz;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if p_client_session_id is null or length(p_client_session_id) = 0 then
    raise exception 'invalid_session';
  end if;
  perform private.ensure_profile(uid);       -- guarantee the owner FK target
  perform private.expire_stale_rooms();

  -- Prove the caller owns a LIVE Global session and derive canonical timing
  -- from it (server-side) — never trust unrestricted client timestamps.
  select * into flight from public.active_flights
   where user_id = uid
     and status = 'active'
     and session_kind = 'public'
     and last_heartbeat_at > now() - interval '150 seconds';

  if flight.user_id is not null then
    v_sky     := flight.sky_id;
    v_started := flight.started_at;
    v_ends    := flight.expected_end_at;      -- null = genuinely Infinite
  else
    -- No live public session row (e.g. discoverability off): fall back to the
    -- client's values, but validate them against server time below.
    if p_sky_id is null or length(p_sky_id) = 0 then raise exception 'no_active_session'; end if;
    v_sky     := p_sky_id;
    v_started := coalesce(p_started_at, now());
    v_ends    := p_ends_at;
  end if;

  -- A finite deadline must be in the FUTURE (never resurrect an ended journey);
  -- an Infinite flight keeps a null deadline.
  if v_ends is not null and v_ends <= now() then raise exception 'session_ended'; end if;
  v_expires := case when v_ends is null then now() + interval '24 hours'
                    else v_ends + interval '2 hours' end;

  -- Atomic insert-or-reuse keyed by the journey: two concurrent Invite taps for
  -- the same owner + client session ALWAYS converge on one row (no error).
  insert into public.focus_rooms
      (owner_id, sky_id, purpose, status, client_session_id, starts_at, ends_at, expires_at)
  values (uid, v_sky, 'flight', 'active', p_client_session_id, v_started, v_ends, v_expires)
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
                            'membership', 'already_owner');
end $$;

-- ----------------------------------------------------------------------------
-- 3. preview_active_flight_invite — READ-ONLY. Validates a token and returns
--    what the invitation screen needs WITHOUT consuming it or creating any
--    membership (so opening a link never joins, never counts, never toasts).
-- ----------------------------------------------------------------------------
create or replace function public.preview_active_flight_invite(p_raw_token text)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  uid uuid := auth.uid();
  invite public.room_invites;
  room public.focus_rooms;
  owner_p public.profiles;
  cnt integer;
  ok boolean;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select * into invite from public.room_invites
   where token_hash = encode(extensions.digest(p_raw_token, 'sha256'), 'hex');
  if invite.id is null then raise exception 'invite_invalid'; end if;
  select * into room from public.focus_rooms where id = invite.room_id;
  if room.id is null then raise exception 'room_not_found'; end if;
  select * into owner_p from public.profiles where id = room.owner_id;
  select count(*) into cnt from public.room_members
   where room_id = room.id and status = 'joined';

  ok := invite.revoked_at is null
        and invite.expires_at > now()
        and invite.uses < invite.max_uses
        and room.status in ('lobby','active')
        and room.expires_at > now()
        and not private.is_blocked_pair(room.owner_id, uid)
        and cnt < room.max_members;

  return jsonb_build_object(
    'room',              private.room_payload(room),
    'host_alias',        coalesce(nullif(owner_p.public_alias, ''), 'a pilot'),
    'host_skin',         coalesce(nullif(owner_p.balloon_skin_id, ''), 'default'),
    'participant_count', cnt,
    'is_owner',          (room.owner_id = uid),
    'already_member',    private.is_room_member(room.id, uid),
    'valid',             ok);
end $$;

-- ----------------------------------------------------------------------------
-- 4. accept_active_flight_invite — the ONLY join path. Atomic validate +
--    consume + membership, delegating to the canonical join_room_by_token
--    (owner/already-member idempotency + expired/full/blocked rejection).
-- ----------------------------------------------------------------------------
create or replace function public.accept_active_flight_invite(p_raw_token text)
returns jsonb language plpgsql volatile security definer set search_path = public, pg_temp as $$
begin
  return public.join_room_by_token(p_raw_token);
end $$;

-- ----------------------------------------------------------------------------
-- 5. Grants.
-- ----------------------------------------------------------------------------
grant execute on function public.promote_global_flight_to_private(text, text, timestamptz, timestamptz) to authenticated;
grant execute on function public.preview_active_flight_invite(text) to authenticated;
grant execute on function public.accept_active_flight_invite(text) to authenticated;
revoke execute on function public.promote_global_flight_to_private(text, text, timestamptz, timestamptz) from anon;
revoke execute on function public.preview_active_flight_invite(text) from anon;
revoke execute on function public.accept_active_flight_invite(text) from anon;
